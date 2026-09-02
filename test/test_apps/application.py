# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import os
import subprocess

from simulator import SimResult
from bcolors import BColors


class Application:
    """
    Represents an application. Contains its compilation and simulation
    results.
    """

    def __init__(self, name: str):
        """
        Constructor for Application.

        :param str name: The name of the application.
        """
        self.name = name

        # Compilation results for each compiler. Key is the compiler and value is a boolean
        # indicating if the compilation was successful or not.
        self.compilation_success: dict = {}

        # Simulation results for each simulator. Key is the simulator and value is a SimResult
        # indicating the result of the simulation.
        self.simulation_results: dict = {}

    def set_compilation_status(self, compiler: str, success: bool):
        """
        Set if the compilation with the compiler was successful or not.
        """
        self.compilation_success[compiler] = success

    def add_simulation_result(self, simulator: str, result: SimResult):
        """
        Add the simulation result for the simulator.
        """
        self.simulation_results[simulator] = result

    def compilation_succeeded(self):
        """
        Check if the compilation was successful with every compiler.
        """
        return all(self.compilation_success.values())

    def compile(
        self,
        compiler_path: str,
        compiler_prefix: str,
        compiler: str,
        linker: str,
        extra_parameters: str,
        dry_run: bool = False,
        verbose: bool = True,
    ):
        """
        Compile the application with the compiler and linker. Outputs if it finishes with errors or
        without.

        :param str compiler_path: The path to the RISC-V compiler toolchain.
        :param str compiler_prefix: The prefix for the compiler binaries.
        :param str compiler: The compiler to use (e.g., "gcc" or "clang").
        :param str linker: The linker to use (e.g., "on_chip").
        :param str extra_parameters: Extra parameters to pass to the "make app" command.
        :param bool dry_run: If True, only print the compilation command without executing it.
        :param bool verbose: If True, print detailed messages about the compilation process.

        :return: True if the compilation succeded and False otherwise.
        """
        if verbose:
            print(
                BColors.OKBLUE
                + f"Compiling {self.name} with {compiler} ({compiler_prefix}) and linker {linker}."
                + BColors.ENDC,
                flush=True,
            )
        try:
            compile_command = ["make", "app", f"PROJECT={self.name}"]
            os.environ["RISCV_XHEEP"] = compiler_path
            if compiler_prefix:
                compile_command.append(f"COMPILER_PREFIX={compiler_prefix}")
            if compiler:
                compile_command.append(f"COMPILER={compiler}")
            if linker:
                compile_command.append(f"LINKER={linker}")
            if extra_parameters:
                compile_command.append(extra_parameters)

            if dry_run:
                if verbose:
                    env_str = f"RISCV_XHEEP={compiler_path} " if compiler_path else ""
                    print(
                        BColors.OKCYAN
                        + f"[DRY RUN] {env_str}{' '.join(compile_command)}"
                        + BColors.ENDC,
                        flush=True,
                    )
                return True

            _ = subprocess.run(compile_command, capture_output=True, check=True)
        except subprocess.CalledProcessError as exc:
            print(
                BColors.FAIL
                + f"Error compiling {self.name} with {compiler} ({compiler_prefix}) and linker {linker}."
                + BColors.ENDC
            )
            print(exc.stderr.decode("utf-8"), flush=True)
            return False
        else:
            if verbose:
                print(
                    BColors.OKGREEN
                    + f"Compiled {self.name} with {compiler} ({compiler_prefix}) and linker {linker} successfully."
                    + BColors.ENDC,
                    flush=True,
                )
            return True
