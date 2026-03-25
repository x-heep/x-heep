# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Juan Sapriza <juan.sapriza@epfl.ch>
#
# Info: This script parses the generated main.map and core_v_mini_mcu_pkg.sv files to 
# display the usage of the different memory banks of the generated MCU for code (text) and data. 
# The script considers the possibility of having interleaved (IL) memory banks at the end of the
# continuous memory banks. In the IL banks, data is distributed homogeneously across banks (although
# this does not necessarily need to be the case). 
# The code extracts the number and size of the memory banks from the MCU package. 
# Then extracts the regions (code and data) from the main.map file -- i.e. where code and data can 
# be stored.  
# Later extracts the utilization of those regions by looking for the addresses in which text and data
# has been written in the main.map file. 
# For the IL data (ildt) only the length is extracted, for simplicity. We assume an homogeneous distribution.

import subprocess
import re
import os
from pathlib import Path


XHEEP_ROOT = Path(__file__).resolve().parents[2]
ELF_PATH = XHEEP_ROOT / "sw/build/main.elf"
MAP_PATH = XHEEP_ROOT / "sw/build/main.map"
MCU_PKG_PATH = XHEEP_ROOT / "hw/core-v-mini-mcu/include/core_v_mini_mcu_pkg.sv"

# Keep the script behavior independent from the caller's working directory.
os.chdir(XHEEP_ROOT)


def is_readelf_available():
    try:
        subprocess.run(["readelf", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except FileNotFoundError:
        return False


def get_banks_and_sizes(mcu_pkg_size):
    """
    Parses the core_v_mini_mcu_pkg.sv file to extract the count of memory banks and their sizes. 
    It looks for the definitions:
    localparam int unsigned NUM_BANKS = 5;
    localparam int unsigned NUM_BANKS_IL = 2;

    To obtain the total and IL count. 

    Later looks for 
    localparam logic [31:0] RAM0_SIZE = 32'h00008000;
    To extract the size of each. 
    They are all assumed to be contiguous. 

    Parameters:
    mcu_pkg_size - path of the .sv file, relative to the location from which this script is called (e.g. the Makefile)

    Returns: 
    num_banks       - Total count of memory banks
    num_il_banks    - How many of those banks are IL
    sizes_B         - Size in bytes of each bank
    """
    num_banks = 0
    num_il_banks = 0
    sizes_B = []
    try:
        with open(mcu_pkg_size, 'r') as file:
            for line in file:
                if "NUM_BANKS =" in line:
                    num_banks = int(line.split('=')[1].strip().strip(';'))
                elif "NUM_BANKS_IL =" in line:
                    num_il_banks = int(line.split('=')[1].strip().strip(';'))
                else: 
                    match = re.search(r"RAM(\d+)_SIZE = 32'h([0-9A-Fa-f]+);", line)
                    if match:
                        size_B      = int(match.group(2), 16)
                        sizes_B.append(size_B)               
    except FileNotFoundError:
        print("File not found. Please check the path and try again.")
    return num_banks, num_il_banks, sizes_B

def get_memory_sections(map_path):
    """
    Parses the main.map file to obtain the origin and length of each region. 
    These are called ram0 (code), ram1 (data) and ram2 (IL data) - but that does not necessarily 
    correspond with an index of memory banks. 

    The origin and size of each are defined in the configs/*.hjson files.

    Parameters:
    map_path - path of the .map file, relative to the location from which this script is called (e.g. the Makefile)

    Returns: 
    sections - Dictionary with the sections found
    """
    sections = {}
    try:
        with open(map_path, 'r') as file:
            collect = False
            for line in file:
                if "Name" in line and "Origin" in line and "Length" in line:
                    collect = True
                    continue
                if collect:
                    if line.strip() == '':
                        collect = False  # Stop collecting when a blank line is encountered
                        continue
                    parts = line.split()
                    if len(parts) >= 4:
                        name = parts[0]
                        if name == '*default*':
                            continue
                        origin = int(parts[1], 16)
                        length = int(parts[2], 16)
                        attributes = parts[3]
                        sections[name] = {'origin': origin, 'length': length, 'attributes': attributes}
    except FileNotFoundError:
        print("File not found. Please check the path and try again.")
    return sections


def zero_length_section(origin):
    return {'origin': origin, 'length': 0, 'attributes': ''}


def normalize_sections(sections):
    """
    Normalize the linker memory regions so the rest of the script can work with
    the canonical names: code, data and ildt.

    Supported layouts:
    - on_chip / flash_load: ram0, ram1, optional ram2
    - flash_exec: FLASH, RAM
    """
    if 'ram0' in sections and 'ram1' in sections:
        data_section = sections['ram1']
        return {
            'code': sections['ram0'],
            'data': data_section,
            'ildt': sections.get('ram2', zero_length_section(data_section['origin'] + data_section['length']))
        }

    if 'FLASH' in sections and 'RAM' in sections:
        data_section = sections['RAM']
        return {
            'code': sections['FLASH'],
            'data': data_section,
            'ildt': zero_length_section(data_section['origin'] + data_section['length'])
        }

    raise ValueError(f"Unsupported memory layout in map file: {', '.join(sections.keys())}")

def get_regions(program_headers, section_to_segment):
    """
    Parse program headers and section-to-segment mapping to create a list of dictionaries
    describing each segment's start address, size, and type.
    """
    # Define a mapping from section names to region types
    code_sections = {'.vectors', '.init', '.text', '.eh_frame'}
    interleaved_data_sections = {'.data_interleaved'}
    
    # List to store region dictionaries
    regions = []

    # Iterate through each program header
    for ph in program_headers:
        # Determine the type of region based on the sections it contains
        sections = section_to_segment.get(ph['SegmentIndex'], [])
        region_type = 'd'  # default to data
        name = 'data'
        if any(sec in sections for sec in interleaved_data_sections):
            region_type = 'i'  # Special data handling like interleaved can be marked differently if needed
            name = 'IL data'
        elif 'E' in ph['Flg'] or any(sec in sections for sec in code_sections):
            region_type = 'C'
            name = 'code'
        # Create dictionary for the region
        region_dict = {
            'name': name,
            'symbol': region_type,
            'start_add': ph['VirtAddr'],
            'size_B': ph['MemSiz'],
            'end_add': ph['VirtAddr'] + ph['MemSiz']
        }
        
        # Append to the list
        regions.append(region_dict)

    return regions

def get_readelf_output(elf_file):
    """
    Executes the readelf command on the provided ELF file with -l option to list program headers.
    """
    try:
        result = subprocess.run(['readelf', '-l', elf_file], capture_output=True, text=True)
        return result.stdout
    except Exception as e:
        print(f"Error running readelf: {e}")
        return None

def parse_program_headers(readelf_output):
    """
    Parses the output of readelf to extract program headers.
    """
    program_headers = []
    headers_started = False
    segment_index = 0
    for line in readelf_output.split('\n'):
        if 'Program Headers:' in line:
            headers_started = True
        elif headers_started:
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith('Type'):
                continue
            if 'Section to Segment mapping:' in line:
                break  # Stop after collecting program headers

            parts = re.split(r'\s+', stripped)
            if len(parts) < 8 or not parts[1].startswith('0x'):
                continue

            if parts[0] == 'LOAD':
                program_headers.append({
                    'Type': parts[0],
                    'Offset': int(parts[1], 16),
                    'VirtAddr': int(parts[2], 16),
                    'PhysAddr': int(parts[3], 16),
                    'FileSiz': int(parts[4], 16),
                    'MemSiz': int(parts[5], 16),
                    'Flg': parts[6],
                    'Align': int(parts[7], 16),
                    'SegmentIndex': segment_index
                })
            segment_index += 1
    return program_headers

def parse_section_to_segment(readelf_output):
    """
    Parses the 'Section to Segment mapping' from the output of readelf.
    """
    mapping = {}
    capture = False
    for line in readelf_output.split('\n'):
        if 'Section to Segment mapping:' in line:
            capture = True
        elif capture:
            stripped = line.strip()
            if not stripped or stripped.startswith("Segment"):
                continue

            match = re.match(r'^(\d+)\s+(.*)$', stripped)
            if not match:
                continue

            segment_index = int(match.group(1))
            sections = re.findall(r'\.[A-Za-z0-9_\.]+', match.group(2))
            mapping[segment_index] = sections
    return mapping


if not is_readelf_available():
    print("readelf not available. Will not print the memory utilization report.")
    quit()

# READ THE READELF OUTPUT AND PARSE TO OBTAIN THE DIFFERENT REGIONS
output              = get_readelf_output(str(ELF_PATH))
program_headers     = parse_program_headers(output)
section_to_segment  = parse_section_to_segment(output)
regions             = get_regions(program_headers, section_to_segment)

# OBTAIN THE NUMBER AND SIZE OF THE BANKS
num_banks, num_il_banks, bank_sizes_B = get_banks_and_sizes(str(MCU_PKG_PATH))
total_size_B = sum(bank_sizes_B)
print(f"Total space: {total_size_B/1024:0.1f} kB = Continuous:",[int(s/1024) for s in bank_sizes_B[:num_banks-num_il_banks]],"kB + Interleaved:", [int(s/1024) for s in bank_sizes_B[-num_il_banks:]] if num_il_banks else [0], "kB")

# CONVERT THE BANKS INTO A LIST OF DICTIONARIES
banks = []
for i in range(num_banks):
    bank = {
        'type'  : "Cont" if i<(num_banks-num_il_banks) else "IntL",
        'size'  : bank_sizes_B[i],
    }
    banks.append(bank)

# GET THE MEMORY REGIONS FOR CODE AND DATA, TRANSLATE ramx to code, data, IL
# If there are no IL banks, create an entry with length 0
sections = get_memory_sections(str(MAP_PATH))
try:
    sections = normalize_sections(sections)
except ValueError as err:
    print(err)
    quit()

# Compute the total space used for code and data
total_space_used_code = sum(region['size_B'] for region in regions if region['name'] == 'code')
total_space_used_data = sum(region['size_B'] for region in regions if region['name'] == 'data')
total_space_used_ildt = sum(region['size_B'] for region in regions if region['name'] == 'IL data')

# Compute the total space required to store code and data
code_regions = [region for region in regions if region['name'] == 'code']
data_regions = [region for region in regions if region['name'] == 'data']
ildt_regions = [region for region in regions if region['name'] == 'IL data']

min_code_start = min(region['start_add'] for region in code_regions) if code_regions else 0
max_code_end = max(region['end_add'] for region in code_regions) if code_regions else 0
total_space_required_code = max_code_end - min_code_start

min_data_start = min(region['start_add'] for region in data_regions) if data_regions else 0
max_data_end = max(region['end_add'] for region in data_regions) if data_regions else 0
total_space_required_data = max_data_end - min_data_start

min_ildt_start = min(region['start_add'] for region in ildt_regions) if ildt_regions else 0
max_ildt_end = max(region['end_add'] for region in ildt_regions) if ildt_regions else 0
total_space_required_ildt = max_ildt_end - min_ildt_start

# # PRINT THE SUMMARY OF UTILIZATION
print( "Region \t Start \tEnd\tSz(kB)\tUsd(kB)\tReq(kB)\tUtilz(%) ")
print(f"Code:  \t{sections['code']['origin']/1024:5.1f}\t{(sections['code']['origin']+sections['code']['length'])/1024:5.1f}\t{sections['code']['length']/1024:5.1f}\t{total_space_used_code/1024:0.1f}\t{total_space_required_code/1024:5.1f}\t{100*total_space_required_code/sections['code']['length']:0.1f}")
print(f"Data:  \t{sections['data']['origin']/1024:5.1f}\t{(sections['data']['origin']+sections['data']['length'])/1024:5.1f}\t{sections['data']['length']/1024:5.1f}\t{total_space_used_data/1024:0.1f}\t{total_space_required_data/1024:5.1f}\t{100*total_space_required_data/sections['data']['length']:0.1f}")
if sections['ildt']['length'] > 0:
    print(f"ILdata:\t{sections['ildt']['origin']/1024:5.1f}\t{(sections['ildt']['origin']+sections['ildt']['length'])/1024:5.1f}\t{sections['ildt']['length']/1024:5.1f}\t{total_space_used_ildt/1024:0.1f}\t{total_space_required_ildt/1024:5.1f}\t{100*total_space_required_ildt/sections['ildt']['length']:0.1f}")


# DISPLAY THE UTILIZATION BY SHOWING THE BANKS 
# Cont for continuous, IntL for interleaved
# The area used by code is identified with a C
# The area used by data is identified with a d
# The utilization is shown at the end
# The granularity stands for how many Bytes each character represents
char            = '.'
address         = 0
granularity_B   = 32*1024/100   # To show 100 divisions per bank
granularity_B   = 1024          # To show each division having a value of 1kB
start_IL_B      = sum(bank_sizes_B[:-num_il_banks])

print("")
for bank_idx, bank in enumerate(banks):
    bank['use'] = ['-']*int((bank['size']/granularity_B))
    utilization = 0

    if bank['type'] == 'Cont':
        for piece in range(len(bank['use'])):
            address += granularity_B

            bank['use'][piece] = '-'
            for region in regions:
                if address> region['start_add'] and address <= region['end_add']:
                    bank['use'][piece] = region['symbol']
                    utilization += granularity_B
            
    if bank['type'] == "IntL":
        for piece in range(len(bank['use'])):
            logical_start = start_IL_B + granularity_B * num_il_banks * piece
            logical_end = logical_start + granularity_B * num_il_banks
            bank['use'][piece] = '-'
            for region in regions:
                overlap_start = max(logical_start, region['start_add'])
                overlap_end = min(logical_end, region['end_add'])
                overlap_B = max(0, overlap_end - overlap_start)
                if overlap_B > 0:
                    bank['use'][piece] = region['symbol']
                    utilization += overlap_B / num_il_banks

    bank['use'] = ''.join([''.join(sublist) for sublist in bank['use']])
    print(bank['type'],bank_idx,bank['use'], f"\t{100*(utilization/bank['size']):0.1f}%")
