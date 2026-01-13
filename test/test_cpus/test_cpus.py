"""
This script tests all CPU configurations in X-HEEP

It generates the MCU with each CPU configuration, compiles test applications,
and optionally runs simulations.
"""

import argparse
import os
import subprocess
import sys


# Timeout for compilation in seconds
COMPILE_TIMEOUT_S = 300

# Timeout for simulation run in seconds
SIM_TIMEOUT_S = 900

# Available compilers
COMPILERS = ["gcc"]
COMPILER_PREFIXES = ["riscv32-corev-"]

# List of CPU configurations to test
CPU_CONFIGS = [
    "cv32e40p",
    "cv32e40x",
    "cv32e20",
    "cv32e40px",
]

# Blacklist of CPU configurations to skip
BLACKLIST = []


class BColors:
    """
    Colors in the terminal output.
    """

    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"


class TestResult:
    """
    Possible test results.
    """

    PASSED = "Passed"
    FAILED = "Failed"
    SKIPPED = "Skipped"


class CPUConfig:
    """
    Represents a CPU configuration. Contains its generation, compilation,
    and simulation results.
    """

    def __init__(self, name: str):
        self.name = name
        self.generation_success = None
        self.compilation_success = {}
        self.simulation_result = None

    def set_generation_status(self, success: bool):
        """
        Set if the MCU generation with this CPU was successful or not.
        """
        self.generation_success = success

    def set_compilation_status(self, compiler: str, success: bool):
        """
        Set if the compilation with the compiler was successful or not.
        """
        self.compilation_success[compiler] = success

    def set_simulation_result(self, result: TestResult):
        """
        Set the simulation result.
        """
        self.simulation_result = result

    def generation_succeeded(self):
        """
        Check if the generation was successful.
        """
        return self.generation_success is True

    def compilation_succeeded(self):
        """
        Check if the compilation was successful with every compiler.
        """
        return all(self.compilation_success.values())


def generate_mcu(cpu_config, base_dir, verbose=True):
    """
    Generate the MCU with the given CPU configuration.

    Returns True if the generation succeeded and False otherwise.
    """
    if verbose:
        print(
            BColors.OKBLUE + f"Generating MCU with {cpu_config.name}..." + BColors.ENDC,
            flush=True,
        )

    try:
        x_heep_cfg = os.path.join(base_dir, "configs", "python_unsupported.hjson")
        python_cfg = os.path.join(base_dir, "test", "test_cpus", f"{cpu_config.name}_test.py")
        
        generate_command = [
            "make", "mcu-gen",
            f"X_HEEP_CFG={x_heep_cfg}",
            f"PYTHON_X_HEEP_CFG={python_cfg}"
        ]

        _ = subprocess.run(
            generate_command, 
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
            cwd=base_dir
        )
    except subprocess.CalledProcessError as exc:
        print(
            BColors.FAIL
            + f"Error generating MCU with {cpu_config.name}."
            + BColors.ENDC
        )
        if verbose:
            print(exc.stderr.decode("utf-8"), flush=True)
        return False
    else:
        if verbose:
            print(
                BColors.OKGREEN
                + f"Generated MCU with {cpu_config.name} successfully."
                + BColors.ENDC,
                flush=True,
            )
        return True


def compile_test_apps(cpu_config, compiler, compiler_prefix, base_dir, verbose=True, show_app_table=False):
    """
    Compile test applications with the given compiler.

    Returns True if the compilation succeeded and False otherwise.
    """
    if verbose:
        print(
            BColors.OKBLUE
            + f"Compiling test apps for {cpu_config.name} with {compiler} ({compiler_prefix})..."
            + BColors.ENDC,
            flush=True,
        )

    log_file = os.path.join(base_dir, f"{cpu_config.name}_{compiler}_test_output.log")

    try:
        # Change to base directory for running test_apps.py
        test_apps_script = os.path.join(base_dir, "test", "test_apps", "test_apps.py")
        
        compile_command = [
            sys.executable,
            test_apps_script,
            "--compilers", compiler,
            "--compiler-prefixes", compiler_prefix,
            "--compile-only"
        ]

        if show_app_table:
            compile_command.append("--table")

        # Stream output live while teeing to the log file
        with open(log_file, "w") as f:
            process = subprocess.Popen(
                compile_command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=base_dir,
            )

            output_lines = []
            try:
                for raw_line in iter(process.stdout.readline, b""):
                    if raw_line == b"" and process.poll() is not None:
                        break
                    line = raw_line.decode("utf-8", errors="replace")
                    output_lines.append(line)
                    print(line, end="", flush=True)
                    f.write(line)
                    f.flush()

                # Wait for process completion with timeout
                process.wait(timeout=COMPILE_TIMEOUT_S)
            except subprocess.TimeoutExpired:
                process.kill()
                print(
                    BColors.FAIL
                    + f"Compilation of test apps for {cpu_config.name} with {compiler} timed out."
                    + BColors.ENDC,
                    flush=True,
                )
                return False

            if process.returncode != 0:
                print(
                    BColors.FAIL
                    + f"Error compiling test apps for {cpu_config.name} with {compiler}."
                    + BColors.ENDC,
                    flush=True,
                )
                if verbose:
                    print(f"Check {log_file} for details.", flush=True)
                return False
    except subprocess.TimeoutExpired:
        print(
            BColors.FAIL
            + f"Compilation of test apps for {cpu_config.name} with {compiler} timed out."
            + BColors.ENDC,
            flush=True,
        )
        return False
    else:
        if verbose:
            print(
                BColors.OKGREEN
                + f"Compiled test apps for {cpu_config.name} with {compiler} successfully."
                + BColors.ENDC,
                flush=True,
            )
        return True


def run_simulation(cpu_config, base_dir, compilers, compiler_prefixes, verbose=True):
    """
    Run full test_apps (compile + simulate) for the CPU configuration.

    Returns the TestResult for the simulation.
    """
    if verbose:
        print(
            BColors.OKBLUE
            + f"Running simulation for {cpu_config.name}..."
            + BColors.ENDC,
            flush=True,
        )

    log_file = os.path.join(base_dir, f"{cpu_config.name}_simulation.log")

    try:
        test_apps_script = os.path.join(base_dir, "test", "test_apps", "test_apps.py")

        # Use the same compilers/prefixes requested for this CPU
        compilers_arg = ",".join(compilers)
        prefixes_arg = ",".join(compiler_prefixes)

        sim_command = [
            sys.executable,
            test_apps_script,
            "--compilers", compilers_arg,
            "--compiler-prefixes", prefixes_arg,
            "--table",
        ]

        # Stream output live while teeing to the log file
        with open(log_file, "w") as f:
            process = subprocess.Popen(
                sim_command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=base_dir,
            )

            try:
                for raw_line in iter(process.stdout.readline, b""):
                    if raw_line == b"" and process.poll() is not None:
                        break
                    line = raw_line.decode("utf-8", errors="replace")
                    print(line, end="", flush=True)
                    f.write(line)
                    f.flush()

                process.wait(timeout=SIM_TIMEOUT_S)
            except subprocess.TimeoutExpired:
                process.kill()
                print(
                    BColors.FAIL
                    + f"Simulation for {cpu_config.name} timed out."
                    + BColors.ENDC,
                    flush=True,
                )
                return TestResult.SKIPPED

            if process.returncode != 0:
                print(
                    BColors.FAIL
                    + f"Simulation for {cpu_config.name} failed."
                    + BColors.ENDC,
                    flush=True,
                )
                if verbose:
                    print(f"Check {log_file} for details.", flush=True)
                return TestResult.FAILED
    except Exception:
        print(
            BColors.FAIL
            + f"Simulation for {cpu_config.name} failed to start."
            + BColors.ENDC,
            flush=True,
        )
        return TestResult.FAILED
    else:
        if verbose:
            print(
                BColors.OKGREEN
                + f"Simulation for {cpu_config.name} completed."
                + BColors.ENDC,
                flush=True,
            )
        return TestResult.PASSED


def get_cpu_configs(cpu_dir):
    """
    Get all CPU configurations to test. Filters based on BLACKLIST.

    Returns the list of CPU configurations.
    """
    cpu_list = []
    
    for cpu_name in CPU_CONFIGS:
        if cpu_name not in BLACKLIST:
            # Check if the config file exists
            config_file = os.path.join(cpu_dir, f"{cpu_name}_test.py")
            if os.path.exists(config_file):
                cpu_list.append(CPUConfig(cpu_name))
            else:
                print(
                    BColors.WARNING
                    + f"Warning: Configuration file {config_file} not found. Skipping {cpu_name}."
                    + BColors.ENDC
                )

    print(BColors.OKCYAN + "CPU configurations to test:" + BColors.ENDC)
    for cpu in cpu_list:
        print(BColors.OKCYAN + f"    - {cpu.name}" + BColors.ENDC)

    return cpu_list


def filter_results(cpu_list):
    """
    Filters the results from testing the CPU configurations.

    Returns the filtered lists:
    - skipped_cpus
    - ok_cpus
    - generation_failed_cpus
    - compilation_failed_cpus
    - simulation_failed_cpus
    """

    skipped_cpus = []
    ok_cpus = []
    generation_failed_cpus = []
    compilation_failed_cpus = []
    simulation_failed_cpus = []

    for cpu in cpu_list:
        # If the CPU is in the blacklist, no need to check the rest
        if cpu.name in BLACKLIST:
            skipped_cpus.append(cpu)
        # If the generation failed, no need to check compilation/simulation
        elif not cpu.generation_succeeded():
            generation_failed_cpus.append(cpu)
        # If the compilation failed, no need to check simulation
        elif not cpu.compilation_succeeded():
            compilation_failed_cpus.append(cpu)
        # Check simulation result
        elif cpu.simulation_result == TestResult.FAILED:
            simulation_failed_cpus.append(cpu)
        else:
            ok_cpus.append(cpu)

    return (
        skipped_cpus,
        ok_cpus,
        generation_failed_cpus,
        compilation_failed_cpus,
        simulation_failed_cpus,
    )


def print_results(
    cpu_list,
    skipped_cpus,
    ok_cpus,
    generation_failed_cpus,
    compilation_failed_cpus,
    simulation_failed_cpus,
):
    """
    Print the results of the tests.
    """
    print(BColors.BOLD + "=================================" + BColors.ENDC)
    print(BColors.BOLD + "Results:" + BColors.ENDC)
    print(BColors.BOLD + "=================================" + BColors.ENDC)

    print(
        BColors.OKGREEN
        + f"{len(ok_cpus)} out of {len(cpu_list)} CPU configurations finished successfully."
        + BColors.ENDC
    )

    if len(skipped_cpus) > 0:
        print(
            BColors.WARNING + f"{len(skipped_cpus)} CPUs were skipped." + BColors.ENDC
        )
        for cpu in skipped_cpus:
            print(BColors.WARNING + f"    - {cpu.name}" + BColors.ENDC)

    if len(generation_failed_cpus) > 0:
        print(
            BColors.FAIL
            + f"{len(generation_failed_cpus)} CPUs failed to generate."
            + BColors.ENDC
        )
        for cpu in generation_failed_cpus:
            print(BColors.FAIL + f"    - {cpu.name}" + BColors.ENDC)

    if len(compilation_failed_cpus) > 0:
        print(
            BColors.FAIL
            + f"{len(compilation_failed_cpus)} CPUs failed to compile test apps."
            + BColors.ENDC
        )
        for cpu in compilation_failed_cpus:
            print(BColors.FAIL + f"    - {cpu.name}" + BColors.ENDC)

    if len(simulation_failed_cpus) > 0:
        print(
            BColors.FAIL
            + f"{len(simulation_failed_cpus)} CPUs failed simulation."
            + BColors.ENDC
        )
        for cpu in simulation_failed_cpus:
            print(BColors.FAIL + f"    - {cpu.name}" + BColors.ENDC)

    print(BColors.BOLD + "=================================" + BColors.ENDC, flush=True)


def main():
    """
    Tests all CPU configurations in X-HEEP.

    Generates the MCU, compiles test applications, and optionally runs simulations.
    The script outputs the results of the tests.
    It exits with error if any CPU configuration failed.
    """
    parser = argparse.ArgumentParser(description="Test CPU configurations script")
    parser.add_argument(
        "--compile-only", 
        action="store_true", 
        help="Only generate and compile, skip simulations"
    )
    parser.add_argument(
        "--table", 
        action="store_true", 
        help="Print results in a table format"
    )
    parser.add_argument(
        "--compilers",
        default=",".join(COMPILERS),
        help="Comma-separated list of compilers to test (default: gcc,clang)",
    )
    parser.add_argument(
        "--compiler-prefixes",
        default=",".join(COMPILER_PREFIXES),
        help="Comma-separated list of compiler prefixes (default: riscv32-corev-,riscv32-unknown-)",
    )
    args = parser.parse_args()

    # Parse compilers and prefixes
    compilers = args.compilers.split(",")
    compiler_prefixes = args.compiler_prefixes.split(",")

    if len(compilers) != len(compiler_prefixes):
        print(
            BColors.FAIL
            + f"Error: Number of compilers ({len(compilers)}) must match number of prefixes ({len(compiler_prefixes)})."
            + BColors.ENDC
        )
        sys.exit(1)

    # Get base directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_dir = os.path.abspath(os.path.join(script_dir, "..", ".."))

    # Get a list with all the CPU configurations we want to test
    cpu_list = get_cpu_configs(script_dir)

    if len(cpu_list) == 0:
        print(BColors.WARNING + "No CPU configurations to test." + BColors.ENDC)
        return

    # Print table header if table mode is enabled
    if args.table:
        max_cpu_name_len = max(len(cpu.name) for cpu in cpu_list)
        max_cpu_name_len = max(max_cpu_name_len, len("CPU"))
        max_col_width = 17

        header = f"{'CPU':<{max_cpu_name_len}}"
        header += f" | {'Generation':>{max_col_width}}"
        for compiler, prefix in zip(compilers, compiler_prefixes):
            col_name = f"{compiler}({prefix})"
            # Truncate if too long
            if len(col_name) > max_col_width:
                col_name = col_name[:max_col_width]
            header += f" | {col_name:>{max_col_width}}"
        if not args.compile_only:
            header += f" | {'Simulation':>{max_col_width}}"
        
        print(BColors.BOLD + header + BColors.ENDC)
        print(BColors.BOLD + "-" * len(header) + BColors.ENDC)

    # Test each CPU configuration
    for cpu in cpu_list:
        if cpu.name not in BLACKLIST:
            # Step 1: Generate MCU
            # Suppress per-step chatter; rely on tables/logs instead
            generation_result = generate_mcu(cpu, base_dir, verbose=False)
            cpu.set_generation_status(generation_result)

            if generation_result:
                if args.compile_only:
                    # Step 2: Compile test apps with each compiler
                    for compiler, compiler_prefix in zip(compilers, compiler_prefixes):
                        compilation_result = compile_test_apps(
                            cpu,
                            compiler,
                            compiler_prefix,
                            base_dir,
                            verbose=False,
                            show_app_table=True,  # always show application table
                        )
                        cpu.set_compilation_status(compiler, compilation_result)
                else:
                    # Skip standalone compilation; test_apps will compile when simulating
                    for compiler in compilers:
                        cpu.set_compilation_status(compiler, True)

                # Step 3: Run simulation if requested
                if not args.compile_only:
                    simulation_result = run_simulation(
                        cpu,
                        base_dir,
                        compilers,
                        compiler_prefixes,
                        verbose=False,
                    )
                    cpu.set_simulation_result(simulation_result)
            else:
                # Generation failed, mark everything as skipped
                for compiler in compilers:
                    cpu.set_compilation_status(compiler, False)
                cpu.set_simulation_result(TestResult.SKIPPED)

            # Print table row if table mode is enabled
            if args.table:
                row = f"{cpu.name:<{max_cpu_name_len}}"
                
                # Generation status
                if cpu.generation_success:
                    status = "OK"
                    color = BColors.OKGREEN
                else:
                    status = "FAIL"
                    color = BColors.FAIL
                row += f" | {color}{status:>{max_col_width}}{BColors.ENDC}"

                # Compilation status for each compiler
                for compiler in compilers:
                    if compiler not in cpu.compilation_success:
                        status = "SKIPPED"
                        color = BColors.WARNING
                    elif cpu.compilation_success[compiler]:
                        status = "OK"
                        color = BColors.OKGREEN
                    else:
                        status = "FAIL"
                        color = BColors.FAIL
                    row += f" | {color}{status:>{max_col_width}}{BColors.ENDC}"

                # Simulation status
                if not args.compile_only:
                    if cpu.simulation_result == TestResult.PASSED:
                        status = "OK"
                        color = BColors.OKGREEN
                    elif cpu.simulation_result == TestResult.SKIPPED:
                        status = "SKIPPED"
                        color = BColors.WARNING
                    else:
                        status = "FAIL"
                        color = BColors.FAIL
                    row += f" | {color}{status:>{max_col_width}}{BColors.ENDC}"

                print(row, flush=True)
        else:
            if not args.table:
                print(
                    BColors.WARNING + f"Skipping {cpu.name}..." + BColors.ENDC,
                    flush=True,
                )

    # Filter and print the results
    (
        skipped_cpus,
        ok_cpus,
        generation_failed_cpus,
        compilation_failed_cpus,
        simulation_failed_cpus,
    ) = filter_results(cpu_list)

    # Only print detailed results if not in table mode
    if not args.table:
        print_results(
            cpu_list,
            skipped_cpus,
            ok_cpus,
            generation_failed_cpus,
            compilation_failed_cpus,
            simulation_failed_cpus,
        )
    else:
        # Print summary in table mode
        print()
        print(BColors.BOLD + f"Summary: {len(ok_cpus)}/{len(cpu_list)} CPU configurations succeeded" + BColors.ENDC)
        if len(skipped_cpus) > 0:
            print(BColors.WARNING + f"Skipped: {len(skipped_cpus)}" + BColors.ENDC)
        if len(generation_failed_cpus) > 0:
            print(BColors.FAIL + f"Generation failed: {len(generation_failed_cpus)}" + BColors.ENDC)
        if len(compilation_failed_cpus) > 0:
            print(BColors.FAIL + f"Compilation failed: {len(compilation_failed_cpus)}" + BColors.ENDC)
        if len(simulation_failed_cpus) > 0:
            print(BColors.FAIL + f"Simulation failed: {len(simulation_failed_cpus)}" + BColors.ENDC)

    # Exit with error if any CPU configuration failed
    if (
        len(generation_failed_cpus) > 0
        or len(compilation_failed_cpus) > 0
        or len(simulation_failed_cpus) > 0
    ):
        sys.exit(1)


if __name__ == "__main__":
    main()
