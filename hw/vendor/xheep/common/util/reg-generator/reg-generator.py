#!/usr/bin/env python3

import sys
import os
import subprocess
import yaml
from mako.template import Template

def get_version_hex(version_str):
    """
    Converts a semantic version string (MAJOR.minor.PATCH) into a hexadecimal representation (0x00MMmmPP).
    """
    version_parts = version_str.split(".")
    if len(version_parts) != 3:
        print(
            "Warning: Version string does not have three parts, defaulting to 0.0.0",
            file=sys.stderr,
        )
        version_parts = ["0", "0", "0"]

    major = int(version_parts[0])
    minor = int(version_parts[1])
    patch = int(version_parts[2])
    version_hex = (major << 16) | (minor << 8) | patch
    return f"0x{version_hex:08X}"


def get_cfg_file_path(cfg: dict) -> str:
    """
    Retrieves the configuration file path from the configuration dictionary.
    """
    try:
        config_file = cfg["parameters"]["config"]
        return os.path.join(cfg["files_root"], config_file)
    except (KeyError, IndexError):
        print(
            "Error: 'parameters:config' key is missing, malformed, or has too few parts in the config.",
            file=sys.stderr,
        )
        sys.exit(1)

def get_regtool_path(cfg: dict) -> str:
    """
    Retrieves the path to regtool.py from the REGGEN_PATH environment variable,
    the configuration dictionary, or a default fallback (in this order).
    The environment variable takes highest priority to allow parent projects and
    CI environments to override the path without modifying vendored config files.
    """
    # 1. Environment variable takes highest priority (parent project/CI override)
    regtool_path = os.getenv("REGGEN_PATH")

    if regtool_path is None:
        try:
            # 2. Explicit path in config (relative to files_root)
            regtool_path = os.path.join(cfg["files_root"], cfg["parameters"]["regtool_path"])
        except (KeyError, IndexError, TypeError):
            # 3. Fallback to default path within X-HEEP
            regtool_path = os.path.join(cfg["cores"]["xheep:util:reg-generator:0.1.0"]["core_root"], "..", "..", "..", "..", "pulp_platform", "register_interface", "vendor", "lowrisc_opentitan", "util", "regtool.py")

    if not os.path.isfile(regtool_path):
        print(
            f"Error: regtool.py not found at '{regtool_path}'. "
            "Set REGGEN_PATH or 'parameters.regtool_path' in your config.",
            file=sys.stderr,
        )
        sys.exit(1)

    return regtool_path

def get_kwargs(cfg) -> tuple:
    """
    Retrieves keyword arguments for template rendering from the configuration dictionary.
    """
    # Get version core from configuration
    try:
        version_core = cfg["parameters"]["ver_core"]
    except KeyError:
        version_core = ":".join(cfg["toplevel"].split(":")[:3])

    # Get version number
    try:
        cores = cfg["cores"]
        version_str = None
        # Find the nm-carus core and extract its version
        for core_name in cores:
            if core_name.startswith(version_core + ":"):
                version_str = core_name.split(":")[-1]
                break
        if version_str is None:
            print(
                f"Error: Could not find '{version_core}' core in the configuration.",
                file=sys.stderr,
            )
            sys.exit(1)
    except KeyError:
        print(
            "Error: 'cores' key not found in the config.",
            file=sys.stderr,
        )
        sys.exit(1)
    version_hex = get_version_hex(version_str)
    print(f"> INFO: Detected version '{version_str}' ({version_hex}) for '{version_core}' core")

    # Get keyword arguments
    kwargs = {}
    try:
        kwargs.update(cfg["parameters"])
    except (KeyError, IndexError):
        pass
    kwargs["version_hex"] = version_hex
    return kwargs


def render_template(template_path, kwargs) -> str:
    """
    Renders a Mako template with the provided keyword arguments.
    """
    print(f"> INFO: Rendering configuration template '{template_path}'")
    try:
        template = Template(filename=template_path)
        rendered_content = template.render(**kwargs)
        output_path = template_path.rsplit(".tpl", 1)[0]
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(rendered_content)
            return output_path
    except Exception as e:
        print(f"Error: Could not render template '{template_path}': {e}", file=sys.stderr)
        sys.exit(1)
    
def generate_rtl(regtool_path: str, cfg: dict) -> None:
    """
    Generates the register files using regtool based on the provided configuration file.
    """
    print("> INFO: - Generating RTL...")
    # Get RTL output directory
    try:
        rtl_dir = os.path.join(cfg["files_root"], cfg["parameters"]["rtl_dir"])
    except (KeyError, IndexError):
        print(
            "Error: 'parameters:rtl_dir' key is missing, malformed, or has too few parts in the config.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Create the output directory if it doesn't exist
    os.makedirs(os.path.dirname(rtl_dir), exist_ok=True)

    # Generate RTL files
    try:
        subprocess.run(
            [sys.executable, regtool_path, '-r', '--outdir', rtl_dir, get_cfg_file_path(cfg)],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error: regtool failed with error: {e}", file=sys.stderr)
        sys.exit(1)

def generate_c_header(regtool_path: str, cfg: dict) -> None:
    """
    Generates the C header file using regtool based on the provided configuration file.
    """
    print("> INFO: - Generating C header...")
    # Get software output directory
    try:
        sw_path = os.path.join(cfg["files_root"], cfg["parameters"]["sw_path"])
    except (KeyError, IndexError):
        print(
            "Error: 'parameters:sw_path' key is missing, malformed, or has too few parts in the config.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Create the output directory if it doesn't exist
    os.makedirs(os.path.dirname(sw_path), exist_ok=True)

    # Generate C header file
    try:
        subprocess.run(
            [sys.executable, regtool_path, '--cdefines', '--outfile', sw_path, get_cfg_file_path(cfg)],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error: regtool failed with error: {e}", file=sys.stderr)
        sys.exit(1)

def generate_docs(regtool_path: str, cfg: dict) -> None:
    """
    Generates the documentation file using regtool based on the provided configuration file.
    """
    print("> INFO: - Generating documentation...")

    # Get documentation output directory
    try:
        doc_path = os.path.join(cfg["files_root"], cfg["parameters"]["doc_path"])
    except (KeyError, IndexError):
        print(
            "Error: 'parameters:doc_path' key is missing, malformed, or has too few parts in the config.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Create the output directory if it doesn't exist
    os.makedirs(os.path.dirname(doc_path), exist_ok=True)

    # Generate documentation file
    try:
        subprocess.run(
            [sys.executable, regtool_path, '-d', '--outfile', doc_path, get_cfg_file_path(cfg)],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error: regtool failed with error: {e}", file=sys.stderr)
        sys.exit(1)

def generate_c_structs(cfg: dict) -> None:
    """
    Generates the C structs header file using a peripheral structs generator script.
    Only called when 'structs_gen_path' is present in the configuration parameters.
    """
    print("> INFO: - Generating C structs header...")

    # Resolve structs generator script path (relative to files_root)
    structs_gen_path = os.path.normpath(
        os.path.join(cfg["files_root"], cfg["parameters"]["structs_gen_path"])
    )
    if not os.path.isfile(structs_gen_path):
        print(
            f"Error: structs generator not found at '{structs_gen_path}'.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Infer template path: same directory as the script, basename without '_gen' + '.tpl'
    # Override with 'structs_tpl_path' if provided.
    script_dir = os.path.dirname(structs_gen_path)
    script_stem = os.path.splitext(os.path.basename(structs_gen_path))[0]
    template_stem = script_stem[:-4] if script_stem.endswith("_gen") else script_stem
    template_path = os.path.join(script_dir, template_stem + ".tpl")
    if "structs_tpl_path" in cfg["parameters"]:
        template_path = os.path.normpath(
            os.path.join(cfg["files_root"], cfg["parameters"]["structs_tpl_path"])
        )

    # Infer output path: same directory as sw_path, named {name}_structs.h
    # Override with 'structs_sw_path' if provided.
    sw_path = os.path.normpath(
        os.path.join(cfg["files_root"], cfg["parameters"]["sw_path"])
    )
    structs_output = os.path.join(
        os.path.dirname(sw_path), cfg["parameters"]["name"] + "_structs.h"
    )
    if "structs_sw_path" in cfg["parameters"]:
        structs_output = os.path.normpath(
            os.path.join(cfg["files_root"], cfg["parameters"]["structs_sw_path"])
        )

    # Create output directory if needed
    os.makedirs(os.path.dirname(structs_output), exist_ok=True)

    # Run the structs generator
    try:
        subprocess.run(
            [
                sys.executable, structs_gen_path,
                "--template_filename", template_path,
                "--hjson_filename", get_cfg_file_path(cfg),
                "--output_filename", structs_output,
            ],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error: structs generator failed with error: {e}", file=sys.stderr)
        sys.exit(1)


def generate_core_file(cfg: dict):
    """
    Generates and writes the .core file with the register dependencies.
    """
    # Name the output file as specified in the configuration
    try:
        vlnv = cfg["vlnv"]
        core_name = vlnv.split(":")[2]
        output_filename = f"{core_name}.core"
    except (KeyError, IndexError):
        print(
            "Error: 'vlnv' key is missing, malformed, or has too few parts in the config.",
            file=sys.stderr,
        )
        return False

    # Append a list of Verilator 5.X specific waivers if the major version is >=5
    file_list = [
        os.path.join(cfg["files_root"], cfg["parameters"]["rtl_dir"], cfg["parameters"]["name"] + "_reg_pkg.sv"),
        os.path.join(cfg["files_root"], cfg["parameters"]["rtl_dir"], cfg["parameters"]["name"] + "_reg_top.sv")
    ]

    # Generate the output .core file content
    core_contents = {
        'name': vlnv,
        'filesets': {
            'rtl': {
                'files': file_list,
                'file_type': 'systemVerilogSource'
            },
        },
        'targets': {
            'default': {
                'filesets': [
                    'rtl',
                ],
            },
        },
    }

    # Write the output .core file
    try:
        with open(output_filename, "w", encoding="utf-8") as f:
            f.write('CAPI=2:\n')
            yaml.dump(core_contents, f, encoding="utf-8", Dumper=yaml.CSafeDumper)
            print(
                f"> INFO: Successfully wrote '{output_filename}'"
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
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        print(
            f"Error: Configuration file not found at '{config_path}'", file=sys.stderr
        )
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error: Could not parse YAML file '{config_path}': {e}", file=sys.stderr)
        sys.exit(1)

    # Get regtool.py path
    regtool_path = get_regtool_path(config)
    
    # Render template if needed
    config_file = get_cfg_file_path(config)
    if config_file.split(".")[-1] == "tpl":
        kwargs = get_kwargs(config)
        config["parameters"]["config"] = render_template(config_file, kwargs)
        
    # Generate registers using regtool
    generate_rtl(regtool_path, config)
    generate_docs(regtool_path, config)
    generate_c_header(regtool_path, config)
    if "structs_gen_path" in config.get("parameters", {}):
        generate_c_structs(config)

    # Generate .core file
    generate_core_file(config)


if __name__ == "__main__":
    main()
