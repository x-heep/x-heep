# Copyright 2020 ETH Zurich and University of Bologna.
# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): David Mallasén, Luigi Giuffrida, Davide Schiavone
# Description: Configures the X-HEEP system and generates the output files from the templates.
#
# Originated from a simplified version of occamygen.py https://github.com/pulp-platform/snitch/blob/master/util/occamygen.py

import argparse
import pathlib
import re
import logging
from mako.template import Template
import load_config
from xheep import BusType
from cpu.cpu import CPU


# ANSI color codes for pretty printing
class Colors:
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


# Compile a regex to trim trailing whitespaces on lines.
re_trailws = re.compile(r"[ \t\r]+$", re.MULTILINE)


def string2int(hex_json_string):
    return (hex_json_string.split("x")[1]).split(",")[0]


def write_template(tpl_path, outfile, **kwargs):
    if tpl_path:
        tpl_path = pathlib.Path(tpl_path).absolute()
        if tpl_path.exists():
            tpl = Template(filename=str(tpl_path))
            if outfile:
                filename = outfile
            else:
                filename = tpl_path.with_suffix("")

            with open(filename, "w") as file:
                code = tpl.render_unicode(**kwargs, strict_undefined=True)
                code = re_trailws.sub("", code)
                file.write(code)
        else:
            raise FileNotFoundError("Template file not found: {0}".format(tpl_path))
    else:
        raise FileNotFoundError("Template file not provided")


def generate_xheep(args):

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)

    # Load general configuration file.
    xheep = load_config.load_cfg_file(pathlib.PurePath(str(args.config)))

    # Load pads configuration file
    pad_ring = load_config.load_pad_cfg(pathlib.PurePath(str(args.pads_cfg)), xheep)
    if pad_ring is None:
        exit(f"Error loading pads configuration file: {args.pads_cfg}")
    xheep.set_padring(pad_ring)

    if args.bus != None and args.bus != "":
        xheep.set_bus_type(BusType(args.bus))

    if args.memorybanks != None and args.memorybanks != "":
        xheep.memory_ss().override_ram_banks(int(args.memorybanks))

    if args.memorybanks_il != None and args.memorybanks_il != "":
        xheep.memory_ss().override_ram_banks_il(int(args.memorybanks_il))

    # Override CPU setting if specified in the make arguments
    if args.cpu != None and args.cpu != "":
        xheep.set_cpu(CPU(args.cpu))

    # Here the xheep system is built,
    # The missing gaps are filled, like the missing end address of the data section.
    xheep.build()

    # Validate the configuration, performing some sanity checks
    xheep.validate()

    kwargs = {
        "xheep": xheep,
    }

    return kwargs


def generate_xalp(args):

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)

    # X-ALP is configured exclusively through the Python configuration file.
    if not str(args.config).endswith(".py"):
        exit("X-ALP generation requires a Python configuration file (--config *.py)")

    xalp = load_config.load_cfg_file(pathlib.PurePath(str(args.config)))

    # Load pads configuration file
    pad_ring = load_config.load_pad_cfg(pathlib.PurePath(str(args.pads_cfg)), xalp)
    if pad_ring is None:
        exit(f"Error loading pads configuration file: {args.pads_cfg}")
    xalp.set_padring(pad_ring)

    # Here the X-ALP system is built and validated.
    xalp.build()
    xalp.validate()

    # "xalp" is the X-ALP specific handle; "xheep" is also exposed so that
    # templates shared with the X-HEEP flow (which only use system-level
    # accessors such as get_padring()) render unchanged for both systems.
    kwargs = {
        "xalp": xalp,
        "xheep": xalp,
    }

    return kwargs


def main():
    parser = argparse.ArgumentParser(prog="mcugen")

    parser.add_argument(
        "--config",
        metavar="file",
        type=str,
        required=True,
        help="System general configuration (.py or .hjson)",
    )

    parser.add_argument(
        "--system",
        metavar="xheep,xalp",
        choices=["xheep", "xalp"],
        nargs="?",
        default="xheep",
        help="System to generate: xheep or xalp (default: xheep)",
    )

    parser.add_argument(
        "--pads_cfg",
        "-pc",
        metavar="file",
        type=str,
        required=True,
        help="Pads configuration",
    )

    parser.add_argument(
        "--cpu",
        metavar="cv32e20,cv32e40p,cv32e40x,cv32e40px",
        nargs="?",
        default="",
        help="CPU type (default value from cfg file)",
    )

    parser.add_argument(
        "--bus",
        metavar="onetoM,NtoM",
        nargs="?",
        default="",
        help="Bus type (default value from cfg file)",
    )

    parser.add_argument(
        "--memorybanks",
        metavar="from 2 to 16",
        nargs="?",
        default="",
        help="Number of 32KB Banks (default value from cfg file)",
    )

    parser.add_argument(
        "--memorybanks_il",
        metavar="0, 2, 4 or 8",
        nargs="?",
        default="",
        help="Number of interleaved memory banks (default value from cfg file)",
    )

    parser.add_argument(
        "-v", "--verbose", help="increase output verbosity", action="store_true"
    )

    parser.add_argument(
        "--outfile",
        "-o",
        type=pathlib.Path,
        required=False,
        help="Target filename. If not provided, the template filename will be used as the output filename.",
    )

    parser.add_argument(
        "--outtpl",
        "-ot",
        type=str,
        required=True,
        help="Target template filename or comma-separated list of template filenames",
    )

    parser.add_argument(
        "--externaltpl",
        "-et",
        type=str,
        required=False,
        help="External template filename or comma-separated list of external template filenames. "
        "Intended for templates that are not in the X-HEEP repository, e.g. in the user's CHEEP repository.",
    )

    args = parser.parse_args()

    if args.system == "xalp":
        print(f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Generating X-ALP configuration...")
        kwargs = generate_xalp(args)
        print(
            f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} X-ALP configuration generated successfully"
        )
    else:
        print(
            f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Generating X-HEEP configuration..."
        )
        kwargs = generate_xheep(args)
        print(
            f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} X-HEEP configuration generated successfully"
        )

    # Handle single template or multiple templates
    outtpl_list = [t for t in re.split(r"[,\s]+", args.outtpl or "") if t]
    externaltpl_list = [t for t in re.split(r"[,\s]+", args.externaltpl or "") if t]

    if len(outtpl_list) == 1:  # Single template case
        if externaltpl_list:
            parser.error("Cannot specify --externaltpl when using a single template.")
        print(
            f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Processing template: {Colors.BOLD}{outtpl_list[0]}{Colors.RESET}"
        )
        write_template(pathlib.Path(outtpl_list[0]), args.outfile, **kwargs)
        print(f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} Template processed successfully")
    else:
        # Multiple templates case
        if args.outfile is not None:
            parser.error(
                "Cannot specify --outfile when using multiple templates. Filenames will be generated from template names."
            )
        print(
            f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Processing {Colors.BOLD}{len(outtpl_list)}{Colors.RESET} templates..."
        )
        for idx, tpl in enumerate(outtpl_list, 1):
            tpl_path = pathlib.Path(tpl.strip())
            # Generate output filename from template name by removing .tpl extension
            tpl_str = str(tpl_path)
            if tpl_str.endswith(".tpl"):
                generated_outfile = pathlib.Path(tpl_str[:-4])
            else:
                generated_outfile = tpl_path
            print(
                f"{Colors.YELLOW}[MCU-GEN]{Colors.RESET} [{idx}/{len(outtpl_list)}] {tpl_path.name} {Colors.YELLOW}→{Colors.RESET} {generated_outfile.name}"
            )
            write_template(tpl_path, generated_outfile, **kwargs)
        print(
            f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} All templates processed successfully"
        )
        # Process external templates if provided
        if externaltpl_list:
            print(
                f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Processing {Colors.BOLD}{len(externaltpl_list)}{Colors.RESET} external templates..."
            )
            for idx, tpl in enumerate(externaltpl_list, 1):
                tpl_path = pathlib.Path(tpl.strip())
                # Generate output filename from template name by removing .tpl extension
                tpl_str = str(tpl_path)
                if tpl_str.endswith(".tpl"):
                    generated_outfile = pathlib.Path(tpl_str[:-4])
                else:
                    generated_outfile = tpl_path
                print(
                    f"{Colors.YELLOW}[MCU-GEN]{Colors.RESET} [{idx}/{len(externaltpl_list)}] {tpl_path.name} {Colors.YELLOW}→{Colors.RESET} {generated_outfile.name}"
                )
                write_template(tpl_path, generated_outfile, **kwargs)
            print(
                f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} All external templates processed successfully"
            )


if __name__ == "__main__":
    main()
