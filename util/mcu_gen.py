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
    pad_ring = x_heep_gen.load_config.load_pad_cfg(pathlib.PurePath(str(args.pads_cfg)))
    if pad_ring is None:
        exit(f"Error loading pads configuration file: {args.pads_cfg}")
    xheep.set_padring(pad_ring)

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

    print(f"{Colors.BLUE}[MCU-GEN]{Colors.RESET} Generating X-HEEP configuration...")
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
