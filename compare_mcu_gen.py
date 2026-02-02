import subprocess
import pathlib
import shutil
import sys
import tempfile
from typing import List

REPO_ROOT = pathlib.Path(__file__).resolve().parent
PYTHON = sys.executable
MCU_GEN = ["util/mcu_gen.py"]

PRUNE_DIRS = {"hw/vendor", "util", "test"}


def run(cmd: List[str], cwd=None, check=True):
    print("+", " ".join(map(str, cmd)))
    subprocess.run(cmd, cwd=cwd, check=check)


def find_tpl_files(repo_root: pathlib.Path):
    tpl_files = []
    for path in repo_root.rglob("*.tpl"):
        rel = path.relative_to(repo_root)
        if any(str(rel).startswith(p) for p in PRUNE_DIRS):
            continue
        tpl_files.append(path)
    return tpl_files


def mcu_gen(repo_root: pathlib.Path, pads_cfg: pathlib.Path, outdir: pathlib.Path):
    build_dir = repo_root / "build"
    build_dir.mkdir(exist_ok=True)

    xheep_cache = build_dir / "xheep_config_cache.pickle"
    x_heep_cfg = repo_root / "configs/general.hjson"

    tpl_files = find_tpl_files(repo_root)
    tpl_list = " ".join(str(p) for p in tpl_files)

    base_cmd = [
        PYTHON,
        "util/mcu_gen.py",
        "--cached_path", str(xheep_cache),
        "--config", str(x_heep_cfg),
        "--pads_cfg", str(pads_cfg),
    ]

    run(base_cmd, cwd=repo_root)

    run(
        [
            PYTHON,
            "util/mcu_gen.py",
            "--cached_path", str(xheep_cache),
            "--cached",
            "--outtpl", tpl_list,
        ],
        cwd=repo_root,
    )

    run(
        ["make", "verible"],
        cwd=repo_root,
    )

    for tpl in tpl_files:
        gen = tpl.with_suffix("")
        if gen.exists():
            target = outdir / gen.relative_to(repo_root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(gen, target)


def main():
    original_ref = subprocess.check_output(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        text=True,
    ).strip()

    with tempfile.TemporaryDirectory(prefix="mcu-gen-main-") as tmp:
        tmp = pathlib.Path(tmp)

        print("Creating worktree for main...")
        run(["git", "worktree", "add", tmp, "main"])

        out_main = REPO_ROOT / "_mcu_gen_main"
        out_curr = REPO_ROOT / "_mcu_gen_current"

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
        run(
            ["diff", "-ruN", str(out_main), str(out_curr)],
            check=False,
        )

        print("\nCleaning up worktree...")
        run(["git", "worktree", "remove", "--force", tmp])


if __name__ == "__main__":
    main()