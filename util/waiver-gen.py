#!/usr/bin/env python3

import subprocess
import re
import sys
import os
import yaml


def get_verilator_major_version():
    """
    Runs 'verilator --version' and parses the output to find the major version number.
    Returns the major version as an integer or None if it fails.
    """
    try:
        # Extract the Verilator major version number
        result = subprocess.run(
            ["verilator", "--version"], capture_output=True, text=True, check=True
        )
        output = result.stdout
        match = re.search(r"rev v(\d+)\.\d+", output)

        if not match:
            print(
                "Error: Could not parse Verilator version from the output.",
                file=sys.stderr,
            )
            return None

        major_version = int(match.group(1))
        return major_version

    except FileNotFoundError:
        print("Error: 'verilator' command not found.", file=sys.stderr)
        print(
            "Please ensure Verilator is installed and in your system's PATH.",
            file=sys.stderr,
        )
        return None
    except subprocess.CalledProcessError as e:
        print(f"Error executing 'verilator --version': {e}", file=sys.stderr)
        return None


def generate_core_file(config, major_version):
    """
    Generates and writes the .core file based on the parsed config and Verilator version.
    """
    # Name the output file as specified in the configuration
    try:
        vlnv = config["vlnv"]
        core_name = vlnv.split(":")[2]
        output_filename = f"{core_name}.core"
    except (KeyError, IndexError):
        print(
            "Error: 'vlnv' key is missing, malformed, or has too few parts in the config.",
            file=sys.stderr,
        )
        return False

    # Append a list of Verilator 5.X specific waivers if the major version is >=5
    file_paths = []
    if major_version == 5:
        print(
            f"> INFO: Detected Verilator 5.X, adding dedicated waivers to '{output_filename}'"
        )
        files_root = config["files_root"]
        waivers_v5_list = config["parameters"]["waivers_v5"]

        if waivers_v5_list:
            # Make paths absolute since the .core file will be in a different directory
            file_paths = [os.path.join(files_root, f) for f in waivers_v5_list]

    # Generate the output .core file content
    core_contents = {
        "name": vlnv,
        "description": "Generated waivers for Verilator 5.XXX",
        "filesets": {
            "waivers": {"files": file_paths, "file_type": "vlt"},
        },
        "targets": {
            "default": {
                "filesets": [
                    "tool_verilator? (waivers)",
                ],
            },
        },
    }

    # Write the output .core file
    try:
        with open(output_filename, "w", encoding="utf-8") as f:
            f.write("CAPI=2:\n")
            yaml.dump(core_contents, f, encoding="utf-8", Dumper=yaml.CSafeDumper)
            print(
                f"> INFO: Successfully wrote additional dependencies to '{output_filename}'"
            )
        return True
    except IOError as e:
        print(
            f"Error: Could not write to file '{output_filename}': {e}", file=sys.stderr
        )
        return False


def main():
    """Main function to run the script logic."""
    # Check command-line arguments
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path_to_config.yaml>", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]

    # Parse the generator's YAML config file
    try:
        with open(config_path, "r") as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        print(
            f"Error: Configuration file not found at '{config_path}'", file=sys.stderr
        )
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error: Could not parse YAML file '{config_path}': {e}", file=sys.stderr)
        sys.exit(1)

    major_version = get_verilator_major_version()

    if major_version is None:
        sys.exit(1)  # Exit if version check failed

    if not generate_core_file(config, major_version):
        print("Failed to generate .core file.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
