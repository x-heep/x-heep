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
# Later it parses the allocated ELF sections, classifies them by section
# type, and maps them onto the linker memory regions to estimate the
# amount of code and data stored in each area.
# The script also handles interleaved (IL) memory banks. For regions
# mapped onto IL groups, the bank-by-bank visualization projects the
# shared address space onto each physical bank assuming a homogeneous
# distribution across the interleaved banks, although the real placement
# may differ. Multiple IL groups are handled independently.
# When code is linked in FLASH, the script reports RAM data usage,
# emits a warning instead of trying to represent FLASH-resident code in
# the RAM bank visualization, and summarizes the amount of FLASH image
# space occupied by the application.


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
    il_group_starts = {}
    il_group_sizes = {}
    il_group_first_bank = {}
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
                    continue

                il_start_match = re.search(r"RAM_IL(\d+)_START_ADDRESS = 32'h([0-9A-Fa-f]+);", line)
                if il_start_match:
                    il_group_starts[int(il_start_match.group(1))] = int(il_start_match.group(2), 16)
                    continue

                il_size_match = re.search(r"RAM_IL(\d+)_SIZE = 32'h([0-9A-Fa-f]+);", line)
                if il_size_match:
                    il_group_sizes[int(il_size_match.group(1))] = int(il_size_match.group(2), 16)
                    continue

                il_idx_match = re.search(r"RAM_IL(\d+)_IDX = RAM(\d+)_IDX;", line)
                if il_idx_match:
                    il_group_first_bank[int(il_idx_match.group(1))] = int(il_idx_match.group(2))

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

    il_groups = []
    if il_group_starts:
        for group_idx in sorted(il_group_starts):
            if group_idx not in il_group_sizes or group_idx not in il_group_first_bank:
                raise ValueError(f"Incomplete RAM_IL{group_idx} definition in {mcu_pkg_path}")

            first_bank_idx = il_group_first_bank[group_idx]
            if first_bank_idx >= num_banks:
                raise ValueError(f"RAM_IL{group_idx} starts at invalid bank index {first_bank_idx}")

            bank_size_B = sizes_B[first_bank_idx]
            group_size_B = il_group_sizes[group_idx]
            if bank_size_B <= 0 or group_size_B % bank_size_B != 0:
                raise ValueError(
                    f"RAM_IL{group_idx} size 0x{group_size_B:X} is not a multiple of bank size 0x{bank_size_B:X}"
                )

            group_bank_count = group_size_B // bank_size_B
            end_bank_idx = first_bank_idx + group_bank_count
            if end_bank_idx > num_banks:
                raise ValueError(
                    f"RAM_IL{group_idx} spans banks [{first_bank_idx}, {end_bank_idx}), beyond NUM_BANKS={num_banks}"
                )

            il_groups.append(
                {
                    "index": group_idx,
                    "origin": il_group_starts[group_idx],
                    "size": group_size_B,
                    "end": il_group_starts[group_idx] + group_size_B,
                    "first_bank_idx": first_bank_idx,
                    "num_banks": group_bank_count,
                    "bank_indices": list(range(first_bank_idx, end_bank_idx)),
                }
            )
    elif num_il_banks:
        first_il_bank = num_banks - num_il_banks
        il_origin = bank_origins[first_il_bank] if bank_origins else 0
        il_groups.append(
            {
                "index": 0,
                "origin": il_origin,
                "size": sum(sizes_B[first_il_bank:num_banks]),
                "end": il_origin + sum(sizes_B[first_il_bank:num_banks]),
                "first_bank_idx": first_il_bank,
                "num_banks": num_il_banks,
                "bank_indices": list(range(first_il_bank, num_banks)),
            }
        )

    return num_banks, num_il_banks, sizes_B[:num_banks], bank_origins, il_groups


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
    Executes readelf -W -S on the provided ELF file.
    """
    if not elf_file.is_file():
        raise FileNotFoundError(f"ELF file not found: {elf_file}")

    try:
        result = subprocess.run(["readelf", "-W", "-S", str(elf_file)], check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as error:
        stderr = error.stderr.strip()
        raise RuntimeError(f"readelf failed for {elf_file}: {stderr or error}") from error

    return result.stdout


def get_readelf_program_headers_output(elf_file):
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


def parse_section_headers(readelf_output):
    """
    Parses the readelf output to extract allocated ELF section headers.
    """
    sections = []

    for line in readelf_output.splitlines():
        match = re.match(r"^\s*\[\s*(\d+)\]\s+(.*)$", line)
        if not match:
            continue

        parts = match.group(2).split()
        if len(parts) < 10:
            continue

        name, section_type, address, _, size, _, flags = parts[:7]
        size_B = int(size, 16)
        if not name or size_B == 0 or "A" not in flags:
            continue

        start_address = int(address, 16)
        sections.append(
            {
                "name": name,
                "type": section_type,
                "flags": flags,
                "start_add": start_address,
                "size_B": size_B,
                "end_add": start_address + size_B,
            }
        )

    if not sections:
        raise ValueError("No allocated ELF sections found in readelf output")

    return sorted(sections, key=lambda section: section["start_add"])


def parse_program_headers(readelf_output):
    """
    Parses the readelf -l output to extract LOAD program headers.
    """
    program_headers = []
    headers_started = False

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
        if len(parts) < 8 or parts[0] != "LOAD":
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
            }
        )

    if not program_headers:
        raise ValueError("No LOAD program headers found in readelf output")

    return program_headers


def get_regions(section_headers):
    """
    Create a list of dictionaries describing each allocated section's start
    address, size, and type.
    """
    code_sections = {
        ".vectors",
        ".fill",
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
    interleaved_data_sections = {".data_interleaved", ".xheep_data_interleaved"}
    flash_data_sections = {".data_flash_only", ".xheep_data_flash_only"}

    regions = []

    for section in section_headers:
        section_name = section["name"]
        region_type = "d"
        name = "data"
        if section_name in interleaved_data_sections:
            region_type = "i"
            name = "IL data"
        elif section_name in flash_data_sections:
            region_type = "f"
            name = "FLASH data"
        elif section_name in code_sections or "X" in section["flags"]:
            region_type = "C"
            name = "code"

        regions.append(
            {
                "name": name,
                "symbol": region_type,
                "section_name": section_name,
                "start_add": section["start_add"],
                "size_B": section["size_B"],
                "end_add": section["end_add"],
            }
        )

    if not regions:
        raise ValueError("No allocatable memory regions could be derived from readelf output")

    return regions


def is_flash_section(name):
    return name.upper().startswith("FLASH")


def is_ram_section(name):
    return name.lower().startswith("ram")


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

    required_B = 0
    if selected_regions:
        merged_intervals = []
        for region in sorted(selected_regions, key=lambda item: item["start_add"]):
            if not merged_intervals or region["start_add"] > merged_intervals[-1][1]:
                merged_intervals.append([region["start_add"], region["end_add"]])
            else:
                merged_intervals[-1][1] = max(merged_intervals[-1][1], region["end_add"])
        required_B = sum(interval_end - interval_start for interval_start, interval_end in merged_intervals)

    return {
        "mem": ",".join(name for name, _ in host_sections),
        "origin": start_add,
        "end": end_add,
        "length": capacity_B,
        "used": used_B,
        "required": required_B,
        "host_sections": [name for name, _ in host_sections],
    }


def summarize_flash_image(memory_sections, program_headers):
    flash_sections = [(name, section) for name, section in memory_sections.items() if is_flash_section(name)]
    if not flash_sections:
        return None

    flash_regions = []
    for ph in program_headers:
        if ph["FileSiz"] == 0:
            continue

        region = {
            "start_add": ph["PhysAddr"],
            "end_add": ph["PhysAddr"] + ph["FileSiz"],
            "size_B": ph["FileSiz"],
        }
        if any(
            regions_overlap(region["start_add"], region["end_add"], section["origin"], section["origin"] + section["length"])
            for _, section in flash_sections
        ):
            flash_regions.append(region)

    if not flash_regions:
        return None

    capacity_B = sum(section["length"] for _, section in flash_sections)
    flash_base = min(section["origin"] for _, section in flash_sections)
    start_add = min(region["start_add"] for region in flash_regions)
    end_add = max(region["end_add"] for region in flash_regions)
    used_B = sum(region["size_B"] for region in flash_regions)

    merged_intervals = []
    for region in sorted(flash_regions, key=lambda item: item["start_add"]):
        if not merged_intervals or region["start_add"] > merged_intervals[-1][1]:
            merged_intervals.append([region["start_add"], region["end_add"]])
        else:
            merged_intervals[-1][1] = max(merged_intervals[-1][1], region["end_add"])
    required_B = sum(interval_end - interval_start for interval_start, interval_end in merged_intervals)

    return {
        "end_offset": end_add - flash_base,
        "length": capacity_B,
        "used": used_B,
        "required": required_B,
    }


def create_banks(num_banks, bank_sizes_B, bank_origins, il_groups, ram_base_address):
    banks = []
    il_group_by_bank = {}

    for group in il_groups:
        for bank_idx in group["bank_indices"]:
            il_group_by_bank[bank_idx] = group

    for index in range(num_banks):
        size_B = bank_sizes_B[index]
        origin = bank_origins[index] if bank_origins else ram_base_address + sum(bank_sizes_B[:index])
        il_group = il_group_by_bank.get(index)
        bank = {
            "type": "IntL" if il_group is not None else "Cont",
            "size": size_B,
            "origin": origin,
            "il_group": il_group,
        }
        banks.append(bank)

    return banks


def project_region_onto_bank(bank, region):
    """
    Project a memory region onto the visualization space of a single bank.

    For interleaved groups, the visualization compresses the shared address
    space into the per-bank physical capacity by dividing both offset and size
    by the number of banks in the group.
    """
    if bank["type"] == "Cont":
        bank_start = bank["origin"]
        bank_end = bank_start + bank["size"]
        if not regions_overlap(region["start_add"], region["end_add"], bank_start, bank_end):
            return None
        return max(region["start_add"], bank_start), min(region["end_add"], bank_end)

    il_group = bank["il_group"]
    if il_group is None:
        return None

    overlap_start = max(region["start_add"], il_group["origin"])
    overlap_end = min(region["end_add"], il_group["end"])
    if overlap_start >= overlap_end:
        return None

    group_origin = il_group["origin"]
    group_bank_count = il_group["num_banks"]
    bank_view_start = group_origin + (overlap_start - group_origin) // group_bank_count
    bank_view_end = group_origin + (overlap_end - group_origin + group_bank_count - 1) // group_bank_count
    bank_view_limit = group_origin + bank["size"]
    if bank_view_start >= bank_view_limit:
        return None

    return bank_view_start, min(bank_view_end, bank_view_limit)


def interval_overlap(start_a, end_a, start_b, end_b):
    return max(0, min(end_a, end_b) - max(start_a, start_b))


def print_summary_and_bank_usage(memory_sections, regions, program_headers, banks):
    summaries = {
        "Code": summarize_region(memory_sections, regions, "code", ("ram0", "FLASH0", "FLASH")),
        "Data": summarize_region(memory_sections, regions, "data", ("ram1", "RAM")),
        "ILdata": summarize_region(memory_sections, regions, "IL data", ()),
    }
    flash_summary = summarize_flash_image(memory_sections, program_headers)

    continuous_sizes_kB = [int(bank["size"] / 1024) for bank in banks if bank["type"] == "Cont"]
    interleaved_sizes_kB = [int(bank["size"] / 1024) for bank in banks if bank["type"] == "IntL"]
    total_size_B = sum(bank["size"] for bank in banks)
    print(
        f"Total space: {total_size_B/1024:0.1f} kB = Continuous:",
        continuous_sizes_kB if continuous_sizes_kB else [],
        "kB + Interleaved:",
        interleaved_sizes_kB if interleaved_sizes_kB else [0],
        "kB",
    )

    flash_code = summaries["Code"] is not None and any(is_flash_section(name) for name in summaries["Code"]["host_sections"])
    flash_load_code = (
        summaries["Code"] is not None
        and not flash_code
        and any(is_ram_section(name) for name in summaries["Code"]["host_sections"])
        and any(re.fullmatch(r"FLASH\d+", name) for name in memory_sections)
    )

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

    if summaries["Code"] is not None:
        if flash_code:
            print("Code placement: execute in FLASH; RAM bank visualization excludes FLASH-resident code.")
        elif flash_load_code:
            print("Code placement: load from FLASH, execute from RAM; bank visualization reflects RAM execution addresses.")
        else:
            print("Code placement: execute from RAM.")

    if flash_summary is not None:
        flash_utilization = 0.0 if flash_summary["length"] == 0 else 100 * flash_summary["required"] / flash_summary["length"]
        print(
            f"Flash usage: {flash_summary['used']/1024:0.1f} kB stored, "
            f"{flash_summary['required']/1024:0.1f} kB occupied "
            f"({flash_utilization:0.1f}% of available FLASH image space)."
        )

    granularity_B = 1024

    print("")
    for bank_idx, bank in enumerate(banks):
        bank["use"] = ["-"] * int(bank["size"] / granularity_B)
        utilization = 0

        for piece in range(len(bank["use"])):
            address_base = bank["origin"] if bank["type"] == "Cont" else bank["il_group"]["origin"]
            address = address_base + granularity_B * piece
            address_end = address + granularity_B

            for region in regions:
                if region["name"] == "FLASH data":
                    continue

                bank_region = project_region_onto_bank(bank, region)
                if bank_region is None:
                    continue

                region_start, region_end = bank_region
                overlap = interval_overlap(address, address_end, region_start, region_end)
                if overlap > 0:
                    bank["use"][piece] = region["symbol"]
                    utilization += overlap

        bank["use"] = "".join(bank["use"])
        print(bank["type"], bank_idx, bank["use"], f"\t{100*(utilization/bank['size']):5.1f}%")


def main():
    args = parse_args()

    if not is_readelf_available():
        print("readelf not available. Will not print the memory utilization report.", file=sys.stderr)
        return 1

    try:
        readelf_sections_output = get_readelf_output(args.elf)
        readelf_program_headers_output = get_readelf_program_headers_output(args.elf)
        section_headers = parse_section_headers(readelf_sections_output)
        program_headers = parse_program_headers(readelf_program_headers_output)
        regions = get_regions(section_headers)

        num_banks, _, bank_sizes_B, bank_origins, il_groups = get_banks_and_sizes(args.mcu_pkg)
        memory_sections = get_memory_sections(args.ld)

        ram_sections = [section for name, section in memory_sections.items() if not is_flash_section(name)]
        if not ram_sections:
            raise ValueError(f"No RAM sections found in linker script: {args.ld}")

        ram_base_address = min(section["origin"] for section in ram_sections)
        banks = create_banks(num_banks, bank_sizes_B, bank_origins, il_groups, ram_base_address)
        print_summary_and_bank_usage(memory_sections, regions, program_headers, banks)
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
