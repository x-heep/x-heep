# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""
This script compiles or runs all the apps in X-HEEP

FUTURE WORK:
- The current setup only uses the on_chip linker.
"""

import argparse
import os

from simulator import Simulator, SimResult
from bcolors import BColors
from utils import (
    in_list,
    get_apps,
    filter_results,
    print_results,
    print_table_header,
    print_table_row,
    print_table_summary,
)

# Default available compilers
COMPILERS = ["gcc", "clang"]
COMPILER_PATH = [os.environ.get("RISCV_XHEEP") for _ in COMPILERS]
COMPILER_PREFIXES = ["riscv32-unknown-" for _ in COMPILERS]

# Available simulators
SIMULATORS = ["verilator"]

# Pattern to look for when simulating an app to see if the app finished
# correctly or not
ERROR_PATTERN_DICT = {
    "verilator": r"Program Finished with value (\d+)",
}

# Timeout for the simulation in seconds
SIM_TIMEOUT_S = 180

# Whitelist of apps. Has priority over the blacklist.
# Useful if you only want to test certain apps
WHITELIST = []

# Blacklist of apps to skip
BLACKLIST = [
    "example_spi_read",
    "example_spidma_powergate",
    "example_spi_write",
    "example_dma_subaddressing",
    "example_pdm2pcm",
    "example_dma_slow_mem",  # TODO: @tommaso remove this once it's fixed
    "example_matmul_quadrilatero",
    "example_w25q128jw_write",
]
# TODO : The example_pdm2pcm app is testing a wrong version of the PDM2PCM acting only as a CIC filter.
#        When fixed, it not passes anymore. Need to be updated.

# Blacklist of apps to skip with clang
CLANG_BLACKLIST = []

# Blacklist of apps to skip with verilator
VERILATOR_BLACKLIST = []


def main():
    """
    Compiles and runs all the apps in X-HEEP.

    If the --compile-only flag is set, it only compiles the apps.
    The script outputs the results of the tests.
    It exits with error if any app failed to compile or run.
    """
    parser = argparse.ArgumentParser(description="Test script")
    parser.add_argument(
        "--compile-only", action="store_true", help="Only compile the applications"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the commands that would be run without executing them",
    )
    parser.add_argument(
        "--table", action="store_true", help="Print results in a table format"
    )
    parser.add_argument(
        "--compilers",
        help="Override default list of compilers to test.",
    )
    parser.add_argument(
        "--compiler-paths",
        help="Override default compiler paths. Can be a single path (shared among all the compilers) or a comma-separated list (a different path for each compiler).",
    )
    parser.add_argument(
        "--compiler-prefixes",
        help="Override default compiler prefixes. Can be a single prefix (shared among all the compilers) or a comma-separated list (a different prefix for each compiler).",
    )
    args = parser.parse_args()

    # Override the default list of compilers if specified
    compilers = COMPILERS
    if args.compilers:
        compilers = args.compilers.split(",")

    # Override the default list of compiler paths if specified
    compiler_paths = COMPILER_PATH
    if args.compiler_paths:
        paths = args.compiler_paths.split(",")
        if len(paths) == 1:
            # Use this path for all compilers
            compiler_paths = [paths[0] for _ in compilers]
        elif len(paths) == len(compilers):
            # Use the provided list of paths
            compiler_paths = paths
        else:
            print(
                BColors.FAIL
                + f"Error: The number of compiler paths ({len(paths)}) does not match the number of compilers: {compilers} ({len(compilers)})."
                + BColors.ENDC
            )
            exit(1)

    # Override the default list of compiler prefixes if specified
    compiler_prefixes = COMPILER_PREFIXES
    if args.compiler_prefixes:
        prefixes = args.compiler_prefixes.split(",")
        if len(prefixes) == 1:
            # Use this prefix for all compilers
            compiler_prefixes = [prefixes[0] for _ in compilers]
        elif len(prefixes) == len(compilers):
            # Use the provided list of prefixes
            compiler_prefixes = prefixes
        else:
            print(
                BColors.FAIL
                + f"Error: The number of compiler prefixes ({len(prefixes)}) does not match the number of compilers: {compilers} ({len(compilers)})."
                + BColors.ENDC
            )
            exit(1)

    # Get a list with all the applications we want to test
    app_list = get_apps("sw/applications", WHITELIST, BLACKLIST)

    simulators = []
    for simulator_name in SIMULATORS:
        error_pattern = ERROR_PATTERN_DICT.get(simulator_name)
        if error_pattern is None:
            print(
                BColors.FAIL
                + f"Error: No error pattern defined for simulator {simulator_name}."
                + BColors.ENDC
            )
            exit(1)
        simulators.append(Simulator(simulator_name, error_pattern))

    if not args.compile_only:
        for simulator in simulators:
            simulator.build(args.dry_run, verbose=not args.table)

    if args.table:
        max_app_name_len, max_col_width = print_table_header(
            app_list,
            BLACKLIST,
            compilers,
            compiler_prefixes,
            args.compile_only,
            simulators,
        )

    # Compile every app and run with the simulators
    for an_app in app_list:
        # If the app is in the blacklist, print a message and skip it
        if in_list(an_app.name, BLACKLIST):
            if not args.table:
                print(
                    BColors.WARNING + f"Skipping {an_app.name}..." + BColors.ENDC,
                    flush=True,
                )
        else:
            # Compile the app with every compiler, leaving gcc for last
            #   so the simulation is done with gcc
            for compiler_path, compiler_prefix, compiler in zip(
                compiler_paths, compiler_prefixes, compilers
            ):
                if in_list(an_app.name, CLANG_BLACKLIST) and compiler == "clang":
                    if not args.table:
                        print(
                            BColors.WARNING
                            + f"Skipping compiling {an_app.name} with {compiler}..."
                            + BColors.ENDC,
                            flush=True,
                        )
                    an_app.set_compilation_status(compiler, None)  # Mark as skipped
                else:
                    compilation_result = an_app.compile(
                        compiler_path,
                        compiler_prefix,
                        compiler,
                        "on_chip",
                        None,
                        args.dry_run,
                        verbose=not args.table,
                    )
                    an_app.set_compilation_status(compiler, compilation_result)

            # Run the app with every simulator if the compilation was successful
            if not args.compile_only and an_app.compilation_succeeded():
                for simulator in simulators:
                    # Only run the app with verilator if it is not in the verilator_blacklist
                    if simulator.name == "verilator" and in_list(
                        an_app.name, VERILATOR_BLACKLIST
                    ):
                        an_app.add_simulation_result(simulator.name, SimResult.SKIPPED)
                        if not args.table:
                            print(
                                BColors.WARNING
                                + f"Skipping running {an_app.name} with verilator..."
                                + BColors.ENDC,
                                flush=True,
                            )
                    else:
                        simulation_result = simulator.run_app(
                            an_app, SIM_TIMEOUT_S, args.dry_run, verbose=not args.table
                        )
                        an_app.add_simulation_result(simulator.name, simulation_result)

            # Print table row if table mode is enabled
            if args.table:
                print_table_row(
                    an_app,
                    max_app_name_len,
                    max_col_width,
                    compilers,
                    args.dry_run,
                    args.compile_only,
                    simulators,
                )

    # Filter and print the results
    (
        skipped_apps,
        ok_apps,
        compilation_failed_apps,
        simulation_failed_apps,
        simulation_timed_out_apps,
    ) = filter_results(app_list, BLACKLIST)

    if not args.table:
        print_results(
            app_list,
            skipped_apps,
            ok_apps,
            compilation_failed_apps,
            simulation_failed_apps,
            simulation_timed_out_apps,
        )
    else:
        print_table_summary(
            app_list,
            skipped_apps,
            ok_apps,
            compilation_failed_apps,
            simulation_failed_apps,
            simulation_timed_out_apps,
        )

    # Exit with error if any app failed to compile or run
    if len(compilation_failed_apps) > 0 or len(simulation_failed_apps) > 0:
        exit(1)


if __name__ == "__main__":
    main()
