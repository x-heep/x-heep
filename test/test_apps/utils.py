# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import os

from simulator import SimResult
from application import Application
from bcolors import BColors


def in_list(name, item_list):
    """
    Checks if the given name is in the list. This allows for pattern
    matching. For example, if "example" is in the list, in_list("my_example_app")
    will return True.
    """
    return any(word in name for word in item_list)


def get_apps(apps_dir: str, whitelist: list, blacklist: list):
    """
    Get all apps from apps_dir. If the whitelist contains any elements,
    it only obtains those apps. Skips the blacklist apps.

    :param str apps_dir: The directory where the apps are located.
    :param list whitelist: The list of apps to test. If empty, all apps are tested.
    :param list blacklist: The list of apps to skip. Has lower priority than the whitelist.

    :return: A list of Application objects corresponding to the apps to test.
    """
    if not whitelist:
        app_list = [Application(app) for app in os.listdir(apps_dir)]
    else:
        app_list = [
            Application(app) for app in os.listdir(apps_dir) if in_list(app, whitelist)
        ]

    print(BColors.OKCYAN + "Apps to test from " + apps_dir + ":" + BColors.ENDC)
    for app in app_list:
        if not in_list(app.name, blacklist):
            print(BColors.OKCYAN + f"    - {app.name}" + BColors.ENDC)

    return app_list


def filter_results(app_list: list, blacklist: list):
    """
    Filters the results from compiling or running the apps and divides
    them into different lists.

    :param list app_list: The list of all the apps.
    :param list blacklist: The list of apps that were skipped.

    Returns the filtered lists. These are:
    - skipped_apps
    - ok_apps
    - compilation_failed_apps
    - simulation_failed_apps
    - simulation_timed_out_apps
    """

    skipped_apps = []
    ok_apps = []
    compilation_failed_apps = []
    simulation_failed_apps = []
    simulation_timed_out_apps = []

    for app in app_list:
        # If the app is in the blacklist, no need to check the rest
        if in_list(app.name, blacklist):
            skipped_apps.append(app)
        # If the app didn't compile, no need to check the simulations
        elif not app.compilation_succeeded():
            compilation_failed_apps.append(app)
        else:
            # Check if the app failed in any simulator
            all_sim_passed = True
            for _, res in app.simulation_results.items():
                if res == SimResult.FAILED:
                    simulation_failed_apps.append(app)
                    all_sim_passed = False
                elif res == SimResult.TIMED_OUT:
                    simulation_timed_out_apps.append(app)
                    all_sim_passed = False
            if all_sim_passed:
                ok_apps.append(app)

    return (
        skipped_apps,
        ok_apps,
        compilation_failed_apps,
        simulation_failed_apps,
        simulation_timed_out_apps,
    )


def print_results(
    app_list: list,
    skipped_apps: list,
    ok_apps: list,
    compilation_failed_apps: list,
    simulation_failed_apps: list,
    simulation_timed_out_apps: list,
):
    """
    Print the results of the tests.

    :param list app_list: The list of all the apps that were tested.
    :param list skipped_apps: The list of apps that were skipped.
    :param list ok_apps: The list of apps that finished successfully.
    :param list compilation_failed_apps: The list of apps that failed to compile.
    :param list simulation_failed_apps: The list of apps that failed to run.
    :param list simulation_timed_out_apps: The list of apps that timed out.
    """
    print(BColors.BOLD + "=================================" + BColors.ENDC)
    print(BColors.BOLD + "Results:" + BColors.ENDC)
    print(BColors.BOLD + "=================================" + BColors.ENDC)

    print(
        BColors.OKGREEN
        + f"{len(ok_apps)} out of {len(app_list)} apps finished successfully."
        + BColors.ENDC
    )

    if len(skipped_apps) > 0:
        print(
            BColors.WARNING + f"{len(skipped_apps)} apps were skipped." + BColors.ENDC
        )
        for app in skipped_apps:
            print(BColors.WARNING + f"    - {app.name}" + BColors.ENDC)

    if len(compilation_failed_apps) > 0:
        print(
            BColors.FAIL
            + f"{len(compilation_failed_apps)} apps failed to compile."
            + BColors.ENDC
        )
        for app in compilation_failed_apps:
            print(BColors.FAIL + f"    - {app.name}" + BColors.ENDC)

    if len(simulation_failed_apps) > 0:
        print(
            BColors.FAIL
            + f"{len(simulation_failed_apps)} apps failed to run."
            + BColors.ENDC
        )
        for app in simulation_failed_apps:
            for sim, res in app.simulation_results.items():
                if res == SimResult.FAILED:
                    print(
                        BColors.FAIL
                        + f"    - {app.name} with {sim} failed"
                        + BColors.ENDC
                    )

    if len(simulation_timed_out_apps) > 0:
        print(
            BColors.FAIL
            + f"{len(simulation_timed_out_apps)} apps timed out."
            + BColors.ENDC
        )
        for app in simulation_timed_out_apps:
            for sim, res in app.simulation_results.items():
                if res == SimResult.TIMED_OUT:
                    print(
                        BColors.FAIL
                        + f"    - {app.name} with {sim} timed out"
                        + BColors.ENDC
                    )

    print(BColors.BOLD + "=================================" + BColors.ENDC, flush=True)


def print_table_header(
    app_list: list,
    app_blacklist: list,
    compilers: list,
    compiler_prefixes: list,
    compile_only: bool,
    simulators: list,
):
    """
    Print the header of the results table.

    :param list app_list: The list of all the apps.
    :param list app_blacklist: The list of apps to be skipped.
    :param list compilers: The list of compilers to use for testing.
    :param list compiler_prefixes: The list of compiler prefixes to use for testing.
    :param bool compile_only: If True, only print the compilation results.
    :param list simulators: The list of simulators to use for testing.

    :return: The maximum width of the application name column and the maximum width of
        the compiler/simulator result columns.
    """
    # Calculate column widths
    max_app_name_len = max(
        len(app.name) for app in app_list if not in_list(app.name, app_blacklist)
    )
    max_app_name_len = max(max_app_name_len, len("Application"))

    # Calculate max column width for compiler columns
    max_col_width = 10
    for compiler, prefix in zip(compilers, compiler_prefixes):
        col_name = f"{compiler}({prefix})"
        max_col_width = max(max_col_width, len(col_name))

    # Print header
    header = f"{'Application':<{max_app_name_len}}"
    for compiler, prefix in zip(compilers, compiler_prefixes):
        col_name = f"{compiler}({prefix})"
        header += f" | {col_name:>{max_col_width}}"
    if not compile_only:
        for simulator in simulators:
            header += f" | {simulator.name:>{max_col_width}}"
    print(BColors.BOLD + header + BColors.ENDC)
    print(BColors.BOLD + "-" * len(header) + BColors.ENDC)

    return max_app_name_len, max_col_width


def print_table_row(
    an_app: Application,
    max_app_name_len: int,
    max_col_width: int,
    compilers: list,
    dry_run: bool,
    compile_only: bool,
    simulators: list,
):
    """
    Print a row of the results table for an application.

    :param Application an_app: The application for which to print the results.
    :param int max_app_name_len: The maximum width of the application name column.
    :param int max_col_width: The maximum width of the compiler/simulator result columns.
    :param list compilers: The list of compilers used for testing.
    :param bool dry_run: If True, print "DRY RUN" instead of the actual results.
    :param bool compile_only: If True, only print the compilation results.
    :param list simulators: The list of simulators used for testing.
    """
    row = f"{an_app.name:<{max_app_name_len}}"
    for compiler in compilers:
        if compiler not in an_app.compilation_success:
            status = "SKIPPED"
            color = BColors.WARNING
        elif an_app.compilation_success[compiler] is None:
            status = "SKIPPED"
            color = BColors.WARNING
        elif dry_run:
            status = "DRY RUN"
            color = BColors.OKCYAN
        elif an_app.compilation_success[compiler]:
            status = "OK"
            color = BColors.OKGREEN
        else:
            status = "FAIL"
            color = BColors.FAIL
        row += f" | {color}{status:>{max_col_width}}{BColors.ENDC}"

    if not compile_only:
        for simulator in simulators:
            if simulator.name not in an_app.simulation_results:
                status = "SKIPPED"
                color = BColors.WARNING
            elif an_app.simulation_results[simulator.name] == SimResult.SKIPPED:
                status = "SKIPPED"
                color = BColors.WARNING
            elif dry_run:
                status = "DRY RUN"
                color = BColors.OKCYAN
            elif an_app.simulation_results[simulator.name] == SimResult.PASSED:
                status = "OK"
                color = BColors.OKGREEN
            elif an_app.simulation_results[simulator.name] == SimResult.TIMED_OUT:
                status = "TIMEOUT"
                color = BColors.FAIL
            else:
                status = "FAIL"
                color = BColors.FAIL
            row += f" | {color}{status:>{max_col_width}}{BColors.ENDC}"

    print(row, flush=True)


def print_table_summary(
    app_list: list,
    skipped_apps: list,
    ok_apps: list,
    compilation_failed_apps: list,
    simulation_failed_apps: list,
    simulation_timed_out_apps: list,
):
    """
    Print a summary of the results after the table.

    :param list app_list: The list of all the apps that were tested.
    :param list skipped_apps: The list of apps that were skipped.
    :param list ok_apps: The list of apps that finished successfully.
    :param list compilation_failed_apps: The list of apps that failed to compile.
    :param list simulation_failed_apps: The list of apps that failed to run.
    :param list simulation_timed_out_apps: The list of apps that timed out.
    """
    print()
    print(
        BColors.BOLD
        + f"Summary: {len(ok_apps)}/{len(app_list)} apps succeeded"
        + BColors.ENDC
    )
    if len(skipped_apps) > 0:
        print(BColors.WARNING + f"Skipped: {len(skipped_apps)}" + BColors.ENDC)
    if len(compilation_failed_apps) > 0:
        print(
            BColors.FAIL
            + f"Compilation failed: {len(compilation_failed_apps)}"
            + BColors.ENDC
        )
    if len(simulation_failed_apps) > 0:
        print(
            BColors.FAIL
            + f"Simulation failed: {len(simulation_failed_apps)}"
            + BColors.ENDC
        )
    if len(simulation_timed_out_apps) > 0:
        print(
            BColors.FAIL + f"Timed out: {len(simulation_timed_out_apps)}" + BColors.ENDC
        )
