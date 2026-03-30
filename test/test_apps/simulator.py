# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import subprocess
import re

from bcolors import BColors


class SimResult:
    """
    Possible simulation results.
    """

    PASSED = "Passed"
    FAILED = "Failed"
    TIMED_OUT = "Timed out"
    SKIPPED = "Skipped"


class Simulator:
    """
    Represents a simulator.
    """

    def __init__(self, name: str, error_pattern: str):
        """
        Constructor for Simulator.

        :param str name: The name of the simulator.
        :param str error_pattern: The pattern to look for in the output of the simulator. This
            pattern should contain a group that captures the return value of the program. For
            example, "Program Finished with value (\d+)".
        """
        self.name = name
        self.error_pattern = error_pattern

    def build(self, dry_run=False, verbose=True):
        """
        Build the simulator model.
        """
        if verbose:
            print(
                BColors.OKBLUE + f"Generating {self.name} model..." + BColors.ENDC,
                flush=True,
            )

        if dry_run:
            if verbose:
                print(
                    BColors.OKCYAN + f"[DRY RUN] make {self.name}-build" + BColors.ENDC,
                    flush=True,
                )
            return

        try:
            _ = subprocess.run(
                ["make", f"{self.name}-build"], capture_output=True, check=True
            )
        except subprocess.CalledProcessError as exc:
            print(BColors.FAIL + f"Error building {self.name} model." + BColors.ENDC)
            print(str(exc.stderr.decode("utf-8")), flush=True)
            exit(1)
        else:
            print(
                BColors.OKGREEN
                + f"Generated {self.name} model successfully."
                + BColors.ENDC,
                flush=True,
            )

    def run_app(self, an_app, simulation_timeout, dry_run=False, verbose=True):
        """
        Runs an_app with the simulator. Checks if it times out. Outputs if it finishes with errors or
        without.

        :param Application an_app: The application to run.
        :param int simulation_timeout: The timeout for the simulation in seconds.
        :param bool dry_run: If True, only print the simulation command without executing it.
        :param bool verbose: If True, print detailed messages about the simulation process.

        :return: SimResult for the simulation of an_app.
        """
        if verbose:
            print(
                BColors.OKBLUE
                + f"Running {an_app.name} with {self.name}..."
                + BColors.ENDC,
                flush=True,
            )

        if dry_run:
            if verbose:
                print(
                    BColors.OKCYAN + f"[DRY RUN] make {self.name}-run" + BColors.ENDC,
                    flush=True,
                )
            return SimResult.PASSED

        try:
            run_output = subprocess.run(
                ["make", f"{self.name}-run"],
                capture_output=True,
                timeout=simulation_timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            print(
                BColors.FAIL
                + f"Simulation of {an_app.name} with {self.name} timed out."
                + BColors.ENDC,
                flush=True,
            )
            return SimResult.TIMED_OUT
        else:
            match = re.search(
                self.error_pattern, str(run_output.stdout.decode("utf-8"))
            )
            if match and match.group(1) == "0":
                if verbose:
                    print(
                        BColors.OKGREEN
                        + f"Ran {an_app.name} with {self.name} successfully."
                        + BColors.ENDC,
                        flush=True,
                    )
                return SimResult.PASSED
            else:
                print(
                    BColors.FAIL
                    + f"Simulation of {an_app.name} with {self.name} failed."
                    + BColors.ENDC
                )
                print(
                    BColors.FAIL + str(run_output.stdout.decode("utf-8")) + BColors.ENDC
                )
                return SimResult.FAILED
