# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): David Mallasen
# Description: Utility to compare the outputs of mcu-gen between the current branch and main. This
#   can be useful to manually check if changes in the configuration or in the MCU-Gen code have an
#   effect on the generated files.

import subprocess
import pathlib
import shutil
import tempfile
from typing import List
import filecmp

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST_X_HEEP_GEN_DIR = pathlib.Path(__file__).resolve().parent


def run(cmd: List[str], cwd=None, check=True, env=None):
    """
    Run a command and print it to stdout.

    :param cmd: Command to run as a list of strings.
    :param cwd: Current working directory to run the command in.
    :param check: Whether to raise an exception on non-zero exit code.
    """
    print("+", " ".join(map(str, cmd)))
    subprocess.run(cmd, cwd=cwd, check=check, env=env)


def get_mcu_gen_templates(repo_root: pathlib.Path) -> List[pathlib.Path]:
    """
    Get mcu-gen templates via the Makefile's MCU_GEN_TEMPLATES definition.

    :param repo_root: Root of the repository.
    :return: List of pathlib.Path objects pointing to .tpl files.
    """
    output = subprocess.check_output(
        [
            "make",
            "-s",
            "--eval",
            "print-mcu-gen-templates:;@echo $(MCU_GEN_TEMPLATES)",
            "print-mcu-gen-templates",
        ],
        cwd=repo_root,
        text=True,
    ).strip()

    if not output:
        return []

    return [repo_root / path for path in output.split()]


def mcu_gen(repo_root: pathlib.Path, pads_cfg: pathlib.Path, outdir: pathlib.Path):
    """
    Run the mcu-gen process. Copies generated files to the specified output directory.

    :param repo_root: Root of the repository.
    :param pads_cfg: Path to the pads configuration file.
    :param outdir: Output directory to copy generated files.
    """
    build_dir = repo_root / "build"
    build_dir.mkdir(exist_ok=True)

    tpl_files = get_mcu_gen_templates(repo_root)

    run(
        [
            "make",
            "mcu-gen",
            f"PADS_CFG={pads_cfg}",
        ],
        cwd=repo_root,
    )

    for tpl in tpl_files:
        gen = tpl.with_suffix("")
        if gen.is_file():
            target = outdir / gen.relative_to(repo_root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(gen, target)


def list_diff_files(left: pathlib.Path, right: pathlib.Path) -> List[str]:
    """
    Recursively list files that differ between two directories.

    :param left: First directory to compare.
    :param right: Second directory to compare.
    :return: List of relative file paths that differ between the two directories.
    """

    def walk(cmp: filecmp.dircmp, rel: pathlib.Path) -> List[str]:
        diffs = []
        for name in cmp.diff_files + cmp.left_only + cmp.right_only:
            diffs.append(str(rel / name))
        for subname, subcmp in cmp.subdirs.items():
            diffs.extend(walk(subcmp, rel / subname))
        return diffs

    return walk(filecmp.dircmp(left, right), pathlib.Path("."))


def get_main_worktree_path(repo_root: pathlib.Path):
    """
    Find the existing git worktree path for branch 'main'.
    """
    output = subprocess.check_output(
        ["git", "worktree", "list", "--porcelain"],
        cwd=repo_root,
        text=True,
    )
    lines = output.splitlines()
    current_path = None
    for line in lines:
        if line.startswith("worktree "):
            current_path = pathlib.Path(line.split(" ", 1)[1])
        elif line.startswith("branch refs/heads/main") and current_path:
            return current_path
    return None


def main():
    with tempfile.TemporaryDirectory(prefix="mcu-gen-main-") as tmp:
        tmp = pathlib.Path(tmp)

        print("Creating worktree for main...")
        try:
            run(["git", "worktree", "add", tmp, "main"])
        except subprocess.CalledProcessError:
            main_wt = get_main_worktree_path(REPO_ROOT)
            reply = (
                input(
                    f"Git worktree add failed. Delete existing git worktree main ({main_wt}) and continue? [y/N] "
                )
                .strip()
                .lower()
            )
            if reply not in {"y", "yes"}:
                print("Aborting.")
                return
            if not main_wt:
                print("Could not find existing main worktree. Aborting.")
                return
            run(["git", "worktree", "remove", "--force", main_wt], check=False)
            run(["git", "worktree", "add", tmp, "main"])

        out_main = TEST_X_HEEP_GEN_DIR / "_mcu_gen_main"
        out_curr = TEST_X_HEEP_GEN_DIR / "_mcu_gen_current"

        shutil.rmtree(out_main, ignore_errors=True)
        shutil.rmtree(out_curr, ignore_errors=True)

        print("\n=== Generating on main ===")
        mcu_gen(
            repo_root=tmp,
            pads_cfg=tmp / "configs/pad_cfg.hjson",
            outdir=out_main,
        )

        print("\n=== Generating on current branch ===")
        mcu_gen(
            repo_root=REPO_ROOT,
            pads_cfg=REPO_ROOT / "configs/pad_cfg.py",
            outdir=out_curr,
        )

        print("\n=== MCU-GEN DIFF ===")
        print(f"Comparing {out_main} and {out_curr}...")
        diff_files = list_diff_files(out_main, out_curr)
        if not diff_files:
            print("No differences found.")
        else:
            print(f"Found {len(diff_files)} differing file(s):")
            for path in diff_files:
                print(f" - {path}")

        print("\nCleaning up worktree...")
        run(["git", "worktree", "remove", "--force", tmp])


if __name__ == "__main__":
    main()
