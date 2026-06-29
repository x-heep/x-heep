#!/usr/bin/env python3

import sys
import os
import subprocess
import hashlib
import json
import shutil
import yaml


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
    Retrieves the path to regtool.py from the REGTOOL environment variable,
    the configuration dictionary, or a default fallback (in this order).
    The environment variable takes highest priority to allow parent projects and
    CI environments to override the path without modifying vendored config files.
    """
    # 1. Environment variable takes highest priority (parent project/CI override)
    regtool_path = os.getenv("REGTOOL")

    if regtool_path is None:
        try:
            # 2. Explicit path in config (relative to files_root)
            regtool_path = os.path.join(
                cfg["files_root"], cfg["parameters"]["regtool_path"]
            )
        except (KeyError, IndexError, TypeError):
            # 3. Fallback: plain name, assumed to be in PATH
            regtool_path = "regtool.py"

    if not os.path.isfile(regtool_path):
        regtool_path = shutil.which(regtool_path) or ""
    if not regtool_path:
        print(
            "Error: regtool.py not found. "
            "Set REGTOOL or 'parameters.regtool_path' in your config.",
            file=sys.stderr,
        )
        sys.exit(1)

    return regtool_path


def get_structs_gen_path(cfg: dict) -> str:
    """
    Retrieves the path to periph_structs_gen.py from the PERIPH_STRUCTS_GEN
    environment variable, the configuration dictionary, or a default fallback
    (in this order). The environment variable takes highest priority to allow
    parent projects and CI environments to override the path without modifying
    vendored config files.
    """
    # 1. Environment variable takes highest priority (parent project/CI override)
    structs_gen_path = os.getenv("PERIPH_STRUCTS_GEN")

    if structs_gen_path is None:
        try:
            # 2. Explicit path in config (relative to files_root)
            structs_gen_path = os.path.join(
                cfg["files_root"], cfg["parameters"]["structs_gen_path"]
            )
        except (KeyError, IndexError, TypeError):
            # 3. Fallback: plain name, assumed to be in PATH
            structs_gen_path = "periph_structs_gen.py"

    if not os.path.isfile(structs_gen_path):
        structs_gen_path = shutil.which(structs_gen_path) or ""
    if not structs_gen_path:
        print(
            "Error: structs generator not found. "
            "Set PERIPH_STRUCTS_GEN or 'parameters.structs_gen_path' in your config.",
            file=sys.stderr,
        )
        sys.exit(1)

    return structs_gen_path


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
    print(
        f"> INFO: Detected version '{version_str}' ({version_hex}) for '{version_core}' core"
    )

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
    from mako.template import Template  # lazy import: only pay the cost when rendering

    print(f"> INFO: Rendering configuration template '{template_path}'")
    try:
        template = Template(filename=template_path)
        rendered_content = template.render(**kwargs)
        output_path = template_path.rsplit(".tpl", 1)[0]
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(rendered_content)
            return output_path
    except Exception as e:
        print(
            f"Error: Could not render template '{template_path}': {e}", file=sys.stderr
        )
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
            [
                sys.executable,
                regtool_path,
                "-r",
                "--outdir",
                rtl_dir,
                get_cfg_file_path(cfg),
            ],
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
            [
                sys.executable,
                regtool_path,
                "--cdefines",
                "--outfile",
                sw_path,
                get_cfg_file_path(cfg),
            ],
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
            [
                sys.executable,
                regtool_path,
                "-d",
                "--outfile",
                doc_path,
                get_cfg_file_path(cfg),
            ],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error: regtool failed with error: {e}", file=sys.stderr)
        sys.exit(1)


def generate_c_structs(structs_gen_path: str, cfg: dict) -> None:
    """
    Generates the C structs header file using a peripheral structs generator script.
    Only called when 'structs_sw_path' is present in the configuration parameters.
    """
    print("> INFO: - Generating C structs header...")

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

    # Get output path from 'structs_sw_path' parameter
    structs_output = os.path.normpath(
        os.path.join(cfg["files_root"], cfg["parameters"]["structs_sw_path"])
    )

    # Create output directory if needed
    os.makedirs(os.path.dirname(structs_output), exist_ok=True)

    # Run the structs generator
    try:
        subprocess.run(
            [
                sys.executable,
                structs_gen_path,
                "--template_filename",
                template_path,
                "--hjson_filename",
                get_cfg_file_path(cfg),
                "--output_filename",
                structs_output,
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

    # Build RTL file list only when rtl_dir was provided
    file_list = []
    if "rtl_dir" in cfg.get("parameters", {}):
        file_list = [
            os.path.join(
                cfg["files_root"],
                cfg["parameters"]["rtl_dir"],
                cfg["parameters"]["name"] + "_reg_pkg.sv",
            ),
            os.path.join(
                cfg["files_root"],
                cfg["parameters"]["rtl_dir"],
                cfg["parameters"]["name"] + "_reg_top.sv",
            ),
        ]

    # Generate the output .core file content
    core_contents = {"name": vlnv, "targets": {"default": {}}}
    if file_list:
        core_contents["filesets"] = {
            "rtl": {"files": file_list, "file_type": "systemVerilogSource"},
        }
        core_contents["targets"]["default"]["filesets"] = ["rtl"]

    # Write the output .core file
    try:
        with open(output_filename, "w", encoding="utf-8") as f:
            f.write("CAPI=2:\n")
            yaml.dump(core_contents, f, encoding="utf-8", Dumper=yaml.CSafeDumper)
            print(f"> INFO: Successfully wrote '{output_filename}'")
        return True
    except IOError as e:
        print(
            f"Error: Could not write to file '{output_filename}': {e}", file=sys.stderr
        )
        return False


def get_expected_outputs(cfg: dict) -> list:
    """Returns the list of all file paths that the generator is expected to produce."""
    files_root = cfg["files_root"]
    name = cfg["parameters"]["name"]
    params = cfg.get("parameters", {})
    outputs = []
    if "rtl_dir" in params:
        outputs.extend(
            [
                os.path.join(files_root, params["rtl_dir"], name + "_reg_pkg.sv"),
                os.path.join(files_root, params["rtl_dir"], name + "_reg_top.sv"),
            ]
        )
    if "sw_path" in params:
        outputs.append(os.path.normpath(os.path.join(files_root, params["sw_path"])))
    if "doc_path" in params:
        outputs.append(os.path.normpath(os.path.join(files_root, params["doc_path"])))
    if "structs_sw_path" in params:
        outputs.append(
            os.path.normpath(os.path.join(files_root, params["structs_sw_path"]))
        )
    return outputs


def compute_cache_key(file_path: str, kwargs: dict = None) -> str:
    """Returns a SHA-256 hex digest of the file content and optional rendering kwargs."""
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        h.update(f.read())
    if kwargs is not None:
        h.update(json.dumps(kwargs, sort_keys=True, default=str).encode())
    return h.hexdigest()


def is_cache_valid(cache_path: str, input_hash: str, output_files: list) -> bool:
    """Returns True if the cache hash matches and every expected output exists."""
    if not os.path.isfile(cache_path):
        return False
    if any(not os.path.isfile(f) for f in output_files):
        return False
    with open(cache_path, "r", encoding="utf-8") as f:
        return f.read().strip() == input_hash


def save_cache(cache_path: str, input_hash: str) -> None:
    """Writes the input hash to the cache file."""
    with open(cache_path, "w", encoding="utf-8") as f:
        f.write(input_hash)


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

    # Compute cache key: hash(tpl + kwargs) for templates, hash(HJSON) for plain files
    config_file = get_cfg_file_path(config)
    if config_file.endswith(".tpl"):
        kwargs = get_kwargs(config)
        cache_key = compute_cache_key(config_file, kwargs)
    else:
        cache_key = compute_cache_key(config_file)

    cache_path = os.path.join(
        config["files_root"], f".{config['parameters']['name']}_reg_gen.cache"
    )
    expected_outputs = get_expected_outputs(config)

    if is_cache_valid(cache_path, cache_key, expected_outputs):
        print("> INFO: All outputs are up to date. Skipping generation.")
    else:
        # Render template if needed (only on cache miss)
        if config_file.endswith(".tpl"):
            config["parameters"]["config"] = render_template(config_file, kwargs)

        # Resolve tool paths and generate
        params = config.get("parameters", {})
        needs_regtool = any(k in params for k in ("rtl_dir", "sw_path", "doc_path"))
        regtool_path = get_regtool_path(config) if needs_regtool else None
        structs_gen_path = None
        if "structs_sw_path" in params:
            structs_gen_path = get_structs_gen_path(config)

        if "rtl_dir" in params:
            generate_rtl(regtool_path, config)
        if "doc_path" in params:
            generate_docs(regtool_path, config)
        if "sw_path" in params:
            generate_c_header(regtool_path, config)
        if structs_gen_path is not None:
            generate_c_structs(structs_gen_path, config)

        # Save cache only after all steps succeed
        save_cache(cache_path, cache_key)

    # Always write the .core file: FuseSoC expects it on every generator invocation
    generate_core_file(config)


if __name__ == "__main__":
    main()
