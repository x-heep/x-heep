#!/usr/bin/env python3

# Copyright 2020 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Simplified version of occamygen.py https://github.com/pulp-platform/snitch/blob/master/util/occamygen.py

import argparse
import hjson
import pathlib
import sys
import re
import logging
import pickle
from jsonref import JsonRef
from mako.template import Template
import x_heep_gen.load_config
from x_heep_gen.load_config import load_peripherals_config
from x_heep_gen.pads.PadRing import PadRing
from x_heep_gen.xheep import BusType
from x_heep_gen.cpu.cpu import CPU
import os


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


"""
    Ideally, generate the xheep object with the configuration passed in args. After generating the xheep object, serialize it to a file and save it.

    Currently, generates xheep object with other parameters (and serialize everything)
"""


def generate_xheep(args):

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)

    # Load general configuration file.
    # This can be either the Python or HJSON config file.
    # If using the Python config file, the HJSON parameters that are supported by Python will be ignored
    # except for the peripherals. Any peripheral not configured in Python will be added from the HJSON config.
    if args.python_config != None and args.python_config != "":
        xheep = x_heep_gen.load_config.load_cfg_file(
            pathlib.PurePath(str(args.python_config))
        )
    else:
        xheep = x_heep_gen.load_config.load_cfg_file(pathlib.PurePath(str(args.config)))

    # We still need to load from the HJSON config the configuration options that are not yet supported in the Python model of X-HEEP
    with open(args.config, "r") as file:
        try:
            srcfull = file.read()
            config = hjson.loads(srcfull, use_decimal=True)
            config = JsonRef.replace_refs(config)
        except ValueError:
            raise SystemExit(sys.exc_info()[1])

    # Load pads HJSON configuration file
    with open(args.pads_cfg, "r") as file:
        try:
            srcfull = file.read()
            pad_cfg = hjson.loads(srcfull, use_decimal=True)
            pad_cfg = JsonRef.replace_refs(pad_cfg)
        except ValueError:
            raise SystemExit(sys.exc_info()[1])

    if args.external_domains != None and args.external_domains != "":
        external_domains = int(args.external_domains)
    else:
        external_domains = 0

    if external_domains > 32:
        exit(
            "external_domains must be less than 32 instead of " + str(external_domains)
        )

    try:
        has_spi_slave = 1 if config["debug"]["has_spi_slave"] == "yes" else 0
    except KeyError:
        has_spi_slave = 0

    # config is used as the base config for peripherals (if a domain is not defined in the config, it will be added to xheep using informations in config)
    load_peripherals_config(xheep, args.config)

    if args.bus != None and args.bus != "":
        xheep.set_bus_type(BusType(args.bus))

    if args.memorybanks != None and args.memorybanks != "":
        xheep.memory_ss().override_ram_banks(int(args.memorybanks))

    if args.memorybanks_il != None and args.memorybanks_il != "":
        xheep.memory_ss().override_ram_banks_il(int(args.memorybanks_il))

    # Override CPU setting if specified in the make arguments
    if args.cpu != None and args.cpu != "":
        xheep.set_cpu(CPU(args.cpu))

    debug_start_address = string2int(config["debug"]["address"])
    if int(debug_start_address, 16) < int("10000", 16):
        exit("debug start address must be greater than 0x10000")

    debug_size_address = string2int(config["debug"]["length"])
    ext_slave_start_address = string2int(config["ext_slaves"]["address"])
    ext_slave_size_address = string2int(config["ext_slaves"]["length"])

    flash_mem_start_address = string2int(config["flash_mem"]["address"])
    flash_mem_size_address = string2int(config["flash_mem"]["length"])

    stack_size = string2int(config["linker_script"]["stack_size"])
    heap_size = string2int(config["linker_script"]["heap_size"])

    plic_used_n_interrupts = len(config["interrupts"]["list"])
    plit_n_interrupts = config["interrupts"]["number"]
    ext_int_list = {
        f"EXT_INTR_{k}": v
        for k, v in enumerate(range(plic_used_n_interrupts, plit_n_interrupts))
    }

    interrupts = {**config["interrupts"]["list"], **ext_int_list}

    # Here the xheep system is built,
    # The missing gaps are filled, like the missing end address of the data section.
    xheep.build()
    pad_ring = PadRing(pad_cfg)
    xheep.set_padring(pad_ring)
    if not xheep.validate():
        raise RuntimeError("There are errors when configuring X-HEEP")

    if (
        int(stack_size, 16) + int(heap_size, 16)
    ) > xheep.memory_ss().ram_size_address():
        exit(
            "The stack and heap section must fit in the RAM size, instead they take "
            + str(int(stack_size, 16) + int(heap_size, 16))
            + " bytes while RAM size is "
            + str(xheep.memory_ss().ram_size_address())
            + " bytes."
        )

    kwargs = {
        "xheep": xheep,
        "external_domains": external_domains,
        "debug_start_address": debug_start_address,
        "debug_size_address": debug_size_address,
        "has_spi_slave": has_spi_slave,
        "ext_slave_start_address": ext_slave_start_address,
        "ext_slave_size_address": ext_slave_size_address,
        "flash_mem_start_address": flash_mem_start_address,
        "flash_mem_size_address": flash_mem_size_address,
        "stack_size": stack_size,
        "heap_size": heap_size,
        "plic_used_n_interrupts": plic_used_n_interrupts,
        "plit_n_interrupts": plit_n_interrupts,
        "interrupts": interrupts,
    }

    return kwargs


def main():
    parser = argparse.ArgumentParser(prog="mcugen")

    parser.add_argument(
        "--cached_path", "-cp", help="Path to the cached xheep file", required=True
    )

    parser.add_argument(
        "--cached",
        "-ca",
        help="If set, the script will not generate the xheep object, but will use the cached version instead",
        required=False,
        action="store_true",
    )

    args, _ = parser.parse_known_args()

    if args.cached:
        # Validate cached file exists
        if not os.path.exists(args.cached_path):
            parser.error(
                f"Cached file {args.cached_path} does not exist. Cannot use --cached flag."
            )

        # X-Heep object has been generated
        print(
            f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Loading cached configuration from: {Colors.BOLD}{args.cached_path}{Colors.RESET}"
        )
        with open(args.cached_path, "rb") as f:
            kwargs = pickle.load(f)
        print(f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} Cache loaded successfully")

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

        args = parser.parse_args()
        outtpl = args.outtpl
        outfile = args.outfile

        # Handle single template or multiple templates
        outtpl_list = [t.strip() for t in outtpl.split(",")]

        if len(outtpl_list) == 1:
            # Single template case
            print(
                f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Processing template: {Colors.BOLD}{outtpl_list[0]}{Colors.RESET}"
            )
            write_template(pathlib.Path(outtpl_list[0]), outfile, **kwargs)
            print(
                f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} Template processed successfully"
            )
        else:
            # Multiple templates case
            if outfile is not None:
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

    else:
        # X-Heep object must be generated
        cached_path = args.cached_path

        parser.add_argument(
            "--config",
            metavar="file",
            type=str,
            required=True,
            help="X-HEEP general HJSON configuration",
        )

        parser.add_argument(
            "--python_config",
            metavar="file",
            type=str,
            required=False,
            nargs="?",
            default="",
            help="X-HEEP general Python configuration",
        )

        parser.add_argument(
            "--pads_cfg",
            "-pc",
            metavar="file",
            type=str,
            required=True,
            help="Pads HJSON configuration",
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
            "--external_domains",
            metavar="from 0 to 32",
            nargs="?",
            default="1",
            help="Number of external domains",
        )

        parser.add_argument(
            "-v", "--verbose", help="increase output verbosity", action="store_true"
        )

        args = parser.parse_args()
        print(
            f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Generating X-HEEP configuration..."
        )
        kwargs = generate_xheep(args)
        print(
            f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} X-HEEP configuration generated successfully"
        )

        # Create directory structure if it doesn't exist
        print(
            f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Saving configuration cache to: {Colors.BOLD}{cached_path}{Colors.RESET}"
        )
        os.makedirs(os.path.dirname(cached_path), exist_ok=True)
        with open(cached_path, "wb") as f:
            pickle.dump(kwargs, f)
        print(
            f"{Colors.GREEN}[MCU-GEN]{Colors.RESET} Configuration cache saved successfully"
        )


if __name__ == "__main__":
    main()
