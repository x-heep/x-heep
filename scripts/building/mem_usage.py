# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Juan Sapriza <juan.sapriza@epfl.ch>
# Modified by: Alessandro Varaldi <alessandro.varaldi@polito.it>
#
# Info: This script parses the generated ELF, linker script, and
# core_v_mini_mcu_pkg.sv file to display the usage of the different
# memory banks of the generated MCU for code and data.
# The script supports builds where the application artifacts are not
# located under x-heep/sw/build by accepting explicit paths to the ELF
# and linker script, while resolving X-HEEP internal files relative to
# the location of this script.
# The code extracts the number, size, and physical start address of the
# memory banks from the MCU package.
# Then it extracts the memory regions defined in the linker script, i.e.
# where code and data can be stored for the selected linker mode.
# Later it parses the LOAD segments from the ELF, classifies them by
# section type, and maps them onto the linker memory regions to estimate
# the amount of code and data stored in each area.
# The script also handles interleaved (IL) memory banks. For IL data,
# the bank-by-bank visualization assumes a homogeneous distribution
# across the interleaved banks, although the real placement may differ.
# When code is linked in FLASH, the script reports RAM data usage and
# emits a warning instead of trying to represent FLASH-resident code in
# the RAM bank visualization.


import argparse
from pathlib import Path
import re
import subprocess
import sys


X_HEEP_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ELF_PATH = X_HEEP_ROOT / "sw" / "build" / "main.elf"
DEFAULT_LD_PATH = X_HEEP_ROOT / "sw" / "build" / "main.ld"
DEFAULT_MCU_PKG_PATH = X_HEEP_ROOT / "hw" / "core-v-mini-mcu" / "include" / "core_v_mini_mcu_pkg.sv"


def is_readelf_available():
    try:
        subprocess.run(["readelf", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except FileNotFoundError:
        return False


def parse_args():
    parser = argparse.ArgumentParser(description="Display the memory utilization of an X-HEEP application build.")
    parser.add_argument("--elf", type=Path, default=DEFAULT_ELF_PATH, help="Path to the ELF file to analyze.")
    parser.add_argument("--ld", type=Path, default=DEFAULT_LD_PATH, help="Path to the linker script copy used for the build.")
    parser.add_argument(
        "--mcu-pkg",
        dest="mcu_pkg",
        type=Path,
        default=DEFAULT_MCU_PKG_PATH,
        help="Path to core_v_mini_mcu_pkg.sv.",
    )
    args = parser.parse_args()
    args.elf = args.elf.expanduser().resolve(strict=False)
    args.ld = args.ld.expanduser().resolve(strict=False)
    args.mcu_pkg = args.mcu_pkg.expanduser().resolve(strict=False)
    return args


def get_banks_and_sizes(mcu_pkg_path):
    """
    Parses the core_v_mini_mcu_pkg.sv file to extract the count of memory banks
    and their sizes.
    """
    if not mcu_pkg_path.is_file():
        raise FileNotFoundError(f"MCU package file not found: {mcu_pkg_path}")

    num_banks = 0
    num_il_banks = 0
    sizes_B = []
    bank_starts = {}
    with mcu_pkg_path.open("r", encoding="utf-8") as file:
        for line in file:
            if "NUM_BANKS =" in line:
                num_banks = int(line.split("=")[1].strip().strip(";"))
            elif "NUM_BANKS_IL =" in line:
                num_il_banks = int(line.split("=")[1].strip().strip(";"))
            else:
                size_match = re.search(r"RAM(\d+)_SIZE = 32'h([0-9A-Fa-f]+);", line)
                if size_match:
                    sizes_B.append(int(size_match.group(2), 16))
                    continue

                start_match = re.search(r"RAM(\d+)_START_ADDRESS = 32'h([0-9A-Fa-f]+);", line)
                if start_match:
                    bank_starts[int(start_match.group(1))] = int(start_match.group(2), 16)

    if num_banks <= 0:
        raise ValueError(f"Could not parse NUM_BANKS from {mcu_pkg_path}")
    if num_il_banks < 0 or num_il_banks > num_banks:
        raise ValueError(f"Invalid NUM_BANKS_IL={num_il_banks} parsed from {mcu_pkg_path}")
    if len(sizes_B) < num_banks:
        raise ValueError(
            f"Parsed only {len(sizes_B)} RAMx_SIZE entries from {mcu_pkg_path}, expected at least {num_banks}"
        )

    if len(bank_starts) >= num_banks:
        bank_origins = [bank_starts[index] for index in range(num_banks)]
    else:
        bank_origins = []

    return num_banks, num_il_banks, sizes_B[:num_banks], bank_origins


def get_memory_sections(ld_path):
    """
    Parses the linker script to obtain the origin and length of each memory region.
    """
    if not ld_path.is_file():
        raise FileNotFoundError(f"Linker script not found: {ld_path}")

    sections = {}
    section_re = re.compile(
        r"^\s*(\S+)\s*\(([^)]*)\)\s*:\s*ORIGIN\s*=\s*(0x[0-9A-Fa-f]+)\s*,\s*LENGTH\s*=\s*(0x[0-9A-Fa-f]+)"
    )

    with ld_path.open("r", encoding="utf-8") as file:
        collect = False
        for line in file:
            if "MEMORY" in line:
                collect = True
                continue
            if not collect:
                continue
            if line.strip() == "}":
                break

            match = section_re.match(line)
            if not match:
                continue

            name, attributes, origin, length = match.groups()
            sections[name] = {
                "origin": int(origin, 16),
                "length": int(length, 16),
                "attributes": attributes,
            }

    if not sections:
        raise ValueError(f"Could not parse any MEMORY section entries from {ld_path}")

    return sections


def get_readelf_output(elf_file):
    """
    Executes readelf -l on the provided ELF file.
    """
    if not elf_file.is_file():
        raise FileNotFoundError(f"ELF file not found: {elf_file}")

    try:
        result = subprocess.run(["readelf", "-l", str(elf_file)], check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as error:
        stderr = error.stderr.strip()
        raise RuntimeError(f"readelf failed for {elf_file}: {stderr or error}") from error

    return result.stdout


def parse_program_headers(readelf_output):
    """
    Parses the readelf output to extract LOAD program headers.
    """
    program_headers = []
    headers_started = False
    segment_index = 0

    for line in readelf_output.splitlines():
        stripped = line.strip()
        if stripped == "Program Headers:":
            headers_started = True
            continue
        if not headers_started:
            continue
        if stripped.startswith("Section to Segment mapping:"):
            break
        if not stripped or stripped.startswith("Type"):
            continue

        parts = re.split(r"\s+", stripped)
        if len(parts) < 8:
            continue

        current_index = segment_index
        segment_index += 1

        if parts[0] != "LOAD":
            continue

        program_headers.append(
            {
                "Type": parts[0],
                "Offset": int(parts[1], 16),
                "VirtAddr": int(parts[2], 16),
                "PhysAddr": int(parts[3], 16),
                "FileSiz": int(parts[4], 16),
                "MemSiz": int(parts[5], 16),
                "Flg": "".join(parts[6:-1]),
                "Align": int(parts[-1], 16),
                "Idx": current_index,
            }
        )

    if not program_headers:
        raise ValueError("No LOAD program headers found in readelf output")

    return program_headers


def parse_section_to_segment(readelf_output):
    """
    Parses the 'Section to Segment mapping' from the output of readelf.
    """
    mapping = {}
    capture = False

    for line in readelf_output.splitlines():
        if "Section to Segment mapping:" in line:
            capture = True
            continue
        if not capture:
            continue

        match = re.match(r"\s*(\d+)\s*(.*)$", line)
        if not match:
            continue

        segment_index = int(match.group(1))
        sections = re.findall(r"\.[^\s]+", match.group(2))
        mapping[segment_index] = sections

    return mapping


def get_regions(program_headers, section_to_segment):
    """
    Create a list of dictionaries describing each loadable segment's start
    address, size, and type.
    """
    code_sections = {
        ".vectors",
        ".init",
        ".text",
        ".fini",
        ".eh_frame",
        ".eh_frame_hdr",
        ".gcc_except_table",
        ".gnu_extab",
        ".ctors",
        ".dtors",
    }
    data_sections = {
        ".power_manager",
        ".rodata",
        ".data",
        ".xheep_init_data_crt0",
        ".sdata",
        ".sbss",
        ".bss",
        ".heap",
        ".stack",
    }
    interleaved_data_sections = {".data_interleaved", ".xheep_data_interleaved"}
    flash_data_sections = {".data_flash_only", ".xheep_data_flash_only"}

    regions = []

    for ph in program_headers:
        sections = section_to_segment.get(ph["Idx"], [])
        if not sections:
            continue

        region_type = "d"
        name = "data"
        if any(sec in sections for sec in code_sections):
            region_type = "C"
            name = "code"
        elif any(sec in sections for sec in interleaved_data_sections):
            region_type = "i"
            name = "IL data"
        elif any(sec in sections for sec in data_sections):
            region_type = "d"
            name = "data"
        elif all(sec in flash_data_sections for sec in sections):
            region_type = "f"
            name = "FLASH data"

        regions.append(
            {
                "name": name,
                "symbol": region_type,
                "start_add": ph["VirtAddr"],
                "size_B": ph["MemSiz"],
                "end_add": ph["VirtAddr"] + ph["MemSiz"],
            }
        )

    if not regions:
        raise ValueError("No loadable memory regions could be derived from readelf output")

    return regions


def is_flash_section(name):
    return name.upper().startswith("FLASH")


def regions_overlap(start_a, end_a, start_b, end_b):
    return start_a < end_b and start_b < end_a


def find_host_sections(memory_sections, regions):
    host_sections = []
    for name, section in sorted(memory_sections.items(), key=lambda item: item[1]["origin"]):
        section_start = section["origin"]
        section_end = section_start + section["length"]
        if any(regions_overlap(region["start_add"], region["end_add"], section_start, section_end) for region in regions):
            host_sections.append((name, section))
    return host_sections


def summarize_region(memory_sections, regions, region_name, fallback_section_names):
    selected_regions = [region for region in regions if region["name"] == region_name]
    host_sections = find_host_sections(memory_sections, selected_regions) if selected_regions else []

    if not host_sections:
        for section_name in fallback_section_names:
            if section_name in memory_sections:
                host_sections = [(section_name, memory_sections[section_name])]
                break

    if not host_sections:
        return None

    capacity_B = sum(section["length"] for _, section in host_sections)
    start_add = min(section["origin"] for _, section in host_sections)
    end_add = max(section["origin"] + section["length"] for _, section in host_sections)
    used_B = sum(region["size_B"] for region in selected_regions)

    if selected_regions:
        required_B = max(region["end_add"] for region in selected_regions) - min(region["start_add"] for region in selected_regions)
    else:
        required_B = 0

    return {
        "mem": ",".join(name for name, _ in host_sections),
        "origin": start_add,
        "end": end_add,
        "length": capacity_B,
        "used": used_B,
        "required": required_B,
        "host_sections": [name for name, _ in host_sections],
    }


def create_banks(num_banks, num_il_banks, bank_sizes_B, bank_origins, ram_base_address):
    banks = []

    for index in range(num_banks):
        size_B = bank_sizes_B[index]
        origin = bank_origins[index] if bank_origins else ram_base_address + sum(bank_sizes_B[:index])
        bank = {
            "type": "Cont" if index < (num_banks - num_il_banks) else "IntL",
            "size": size_B,
            "origin": origin,
        }
        banks.append(bank)

    return banks


def print_summary_and_bank_usage(memory_sections, regions, banks, num_il_banks, bank_sizes_B):
    summaries = {
        "Code": summarize_region(memory_sections, regions, "code", ("ram0", "FLASH0", "FLASH")),
        "Data": summarize_region(memory_sections, regions, "data", ("ram1", "RAM")),
        "ILdata": summarize_region(memory_sections, regions, "IL data", ("ram2",)),
    }

    total_size_B = sum(bank_sizes_B)
    print(
        f"Total space: {total_size_B/1024:0.1f} kB = Continuous:",
        [int(size_B / 1024) for size_B in bank_sizes_B[: len(bank_sizes_B) - num_il_banks]],
        "kB + Interleaved:",
        [int(size_B / 1024) for size_B in bank_sizes_B[-num_il_banks:]] if num_il_banks else [0],
        "kB",
    )

    flash_code = summaries["Code"] is not None and any(is_flash_section(name) for name in summaries["Code"]["host_sections"])

    print(f"{'Region':<8} {'Mem':<9} {'Start':>8} {'End':>8} {'Sz(kB)':>8} {'Usd(kB)':>8} {'Req(kB)':>8} {'Utilz(%)':>9}")
    for label in ("Code", "Data", "ILdata"):
        summary = summaries[label]
        if summary is None:
            continue
        if label == "Code" and flash_code:
            continue
        utilization = 0.0 if summary["length"] == 0 else 100 * summary["required"] / summary["length"]
        print(
            f"{label + ':':<8} {summary['mem']:<9} {summary['origin']/1024:8.1f} {summary['end']/1024:8.1f} "
            f"{summary['length']/1024:8.1f} {summary['used']/1024:8.1f} {summary['required']/1024:8.1f} {utilization:9.1f}"
        )

    if flash_code:
        print("Warning: code is linked in FLASH; the RAM bank visualization excludes code stored in FLASH.")

    granularity_B = 1024
    il_base_address = banks[len(banks) - num_il_banks]["origin"] if num_il_banks else 0

    print("")
    for bank_idx, bank in enumerate(banks):
        bank["use"] = ["-"] * int(bank["size"] / granularity_B)
        utilization = 0

        for piece in range(len(bank["use"])):
            if bank["type"] == "Cont":
                address = bank["origin"] + granularity_B * piece
            else:
                address = il_base_address + granularity_B * piece

            for region in regions:
                region_end = region["end_add"]
                if bank["type"] == "IntL":
                    used_by_others = int(region["size_B"] * (num_il_banks - 1) / num_il_banks)
                    region_end -= used_by_others

                if region["start_add"] < address and region_end > (address + granularity_B):
                    bank["use"][piece] = region["symbol"]
                    utilization += granularity_B
                elif region["start_add"] < address and region_end > address and region_end <= (address + granularity_B):
                    bank["use"][piece] = region["symbol"]
                    utilization += region_end - address
                elif region["start_add"] >= address and region["start_add"] < (address + granularity_B) and region_end > (address + granularity_B):
                    bank["use"][piece] = region["symbol"]
                    utilization += (address + granularity_B) - region["start_add"]
                elif (
                    region["start_add"] >= address
                    and region["start_add"] < (address + granularity_B)
                    and region_end > address
                    and region_end <= (address + granularity_B)
                ):
                    bank["use"][piece] = region["symbol"]
                    utilization += region_end - region["start_add"]

        bank["use"] = "".join(bank["use"])
        print(bank["type"], bank_idx, bank["use"], f"\t{100*(utilization/bank['size']):5.1f}%")


def main():
    args = parse_args()

    if not is_readelf_available():
        print("readelf not available. Will not print the memory utilization report.", file=sys.stderr)
        return 1

    try:
        readelf_output = get_readelf_output(args.elf)
        program_headers = parse_program_headers(readelf_output)
        section_to_segment = parse_section_to_segment(readelf_output)
        regions = get_regions(program_headers, section_to_segment)

        num_banks, num_il_banks, bank_sizes_B, bank_origins = get_banks_and_sizes(args.mcu_pkg)
        memory_sections = get_memory_sections(args.ld)

        ram_sections = [section for name, section in memory_sections.items() if not is_flash_section(name)]
        if not ram_sections:
            raise ValueError(f"No RAM sections found in linker script: {args.ld}")

        ram_base_address = min(section["origin"] for section in ram_sections)
        banks = create_banks(num_banks, num_il_banks, bank_sizes_B, bank_origins, ram_base_address)
        print_summary_and_bank_usage(memory_sections, regions, banks, num_il_banks, bank_sizes_B)
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
