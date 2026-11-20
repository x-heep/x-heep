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


def mcu_gen(repo_root: pathlib.Path, outdir: pathlib.Path):
    """
    Run the mcu-gen process. Copies generated files to the specified output directory.

    :param repo_root: Root of the repository.
    :param outdir: Output directory to copy generated files.
    """
    build_dir = repo_root / "build"
    build_dir.mkdir(exist_ok=True)

    tpl_files = get_mcu_gen_templates(repo_root)

    run(
        [
            "make",
            "mcu-gen",
            "X_HEEP_CFG=configs/ci.py",
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


def get_main_commit(repo_root: pathlib.Path) -> str:
    """
    Get the commit hash of the main branch.
    """
    return subprocess.check_output(
        ["git", "rev-parse", "refs/heads/main"],
        cwd=repo_root,
        text=True,
    ).strip()


def main():
    with tempfile.TemporaryDirectory(prefix="mcu-gen-main-") as tmp:
        tmp = pathlib.Path(tmp)

        main_commit = get_main_commit(REPO_ROOT)

        print(f"Creating detached worktree for main ({main_commit[:8]})...")
        run(["git", "worktree", "add", "--detach", tmp, main_commit])

        out_main = TEST_X_HEEP_GEN_DIR / "_mcu_gen_main"
        out_curr = TEST_X_HEEP_GEN_DIR / "_mcu_gen_current"

        shutil.rmtree(out_main, ignore_errors=True)
        shutil.rmtree(out_curr, ignore_errors=True)

        print("\n=== Generating on main ===")
        mcu_gen(
            repo_root=tmp,
            outdir=out_main,
        )

        print("\nCleaning up worktree...")
        run(["git", "worktree", "remove", "--force", tmp])

        print("\n=== Generating on current branch ===")
        mcu_gen(
            repo_root=REPO_ROOT,
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

        print(
            "\nRemember to make sure that your main branch is up to date with the latest changes from the remote repository before running this script."
            "\nYou can update your main branch with 'git fetch origin main' or 'git fetch upstream main' depending on your remote setup."
        )


if __name__ == "__main__":
    main()
