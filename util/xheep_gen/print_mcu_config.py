# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Description: Print a compact tree view of the selected MCU configuration.

import argparse
import contextlib
import io
import pathlib

from mcu_gen import generate_xheep


def main():
    parser = argparse.ArgumentParser(
        description="Print a compact tree view of the selected MCU configuration"
    )
    parser.add_argument("--config", type=pathlib.Path, required=True)
    parser.add_argument("--pads_cfg", type=pathlib.Path, default="configs/pad_cfg.py")
    parser.add_argument("--cpu", nargs="?", default="")
    parser.add_argument("--bus", nargs="?", default="")
    parser.add_argument("--memorybanks", nargs="?", default="")
    parser.add_argument("--memorybanks_il", nargs="?", default="")
    parser.add_argument(
        "-v", "--verbose", help="increase output verbosity", action="store_true"
    )
    args = parser.parse_args()

    # Python configurations may print their own diagnostics; keep the final summary compact.
    with contextlib.redirect_stdout(io.StringIO()):
        xheep = generate_xheep(args)["xheep"]

    print(f"\nX-HEEP MCU: {args.config}")
    print(xheep.pretty_print())


if __name__ == "__main__":
    main()
