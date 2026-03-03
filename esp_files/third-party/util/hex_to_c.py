#!/usr/bin/env python3
"""
Convert Verilog hex file to C header file.
The hex file format has @address markers and hex bytes.
This script creates a sparse representation suitable for loading into memory.
"""

import sys
import os

def parse_hex_file(hex_file):
    """Parse Verilog hex file and return list of (address, data) tuples"""
    sections = []
    current_addr = 0
    current_data = []
    
    with open(hex_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            if line.startswith('@'):
                # Save previous section if any
                if current_data:
                    sections.append((current_addr, bytes(current_data)))
                    current_data = []
                # Start new section
                current_addr = int(line[1:], 16)
            else:
                # Parse hex bytes
                hex_bytes = line.split()
                for hex_byte in hex_bytes:
                    current_data.append(int(hex_byte, 16))
        
        # Save last section
        if current_data:
            sections.append((current_addr, bytes(current_data)))
    
    return sections

def generate_c_header(sections, header_file, name):
    """Generate C header from sections"""
    
    # Calculate total size (max address + size of last section)
    if not sections:
        total_size = 0
    else:
        last_addr, last_data = sections[-1]
        total_size = last_addr + len(last_data)
    
    header_macro = os.path.basename(header_file).upper().replace('.', '_') + '_'
    
    with open(header_file, 'w') as f:
        # Header guard
        f.write(f'#ifndef {header_macro}\n')
        f.write(f'#define {header_macro}\n\n')
        f.write('#include <stdint.h>\n\n')
        
        # Size macro
        f.write('// Binary size\n')
        f.write('// -----------\n')
        f.write(f'#define {name.upper()}_SIZE {total_size}\n\n')
        
        # Binary data as sections
        f.write('// Binary sections\n')
        f.write('// ---------------\n')
        f.write(f'// Total sections: {len(sections)}\n\n')
        
        for idx, (addr, data) in enumerate(sections):
            section_name = f'{name}_section{idx}'
            data_len = (len(data) + 3) // 4  # Round up to words
            
            # Pad to 4-byte alignment
            padded_data = data + b'\x00' * (data_len * 4 - len(data))
            
            f.write(f'// Section {idx}: address 0x{addr:08X}, size {len(data)} bytes\n')
            f.write(f'#define {section_name.upper()}_ADDR 0x{addr:08X}\n')
            f.write(f'#define {section_name.upper()}_SIZE {len(data)}\n')
            f.write(f'uint32_t {section_name}[] = {{\n')
            
            for i in range(data_len):
                word_bytes = padded_data[i*4:(i+1)*4]
                word = int.from_bytes(word_bytes, byteorder='little')
                f.write(f'    0x{word:08X}')
                if i != data_len - 1:
                    f.write(',\n')
            f.write('\n};\n\n')
        
        # Create a helper struct for section info
        f.write('// Section information structure\n')
        f.write('typedef struct {\n')
        f.write('    uint32_t addr;\n')
        f.write('    uint32_t size;\n')
        f.write('    const uint32_t *data;\n')
        f.write('} fw_section_t;\n\n')
        
        f.write(f'#define {name.upper()}_NUM_SECTIONS {len(sections)}\n')
        f.write(f'const fw_section_t {name}_sections[] = {{\n')
        for idx, (addr, data) in enumerate(sections):
            section_name = f'{name}_section{idx}'
            f.write(f'    {{0x{addr:08X}, {len(data)}, {section_name}}}')
            if idx != len(sections) - 1:
                f.write(',\n')
        f.write('\n};\n\n')
        
        # Footer
        f.write(f'#endif // {header_macro}\n')

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f'Usage: {sys.argv[0]} <output.h> <input.hex>')
        sys.exit(1)
    
    header_file = sys.argv[1]
    hex_file = sys.argv[2]
    name = os.path.splitext(os.path.basename(header_file))[0]
    
    print(f'Parsing hex file: {hex_file}')
    sections = parse_hex_file(hex_file)
    print(f'Found {len(sections)} sections')
    for idx, (addr, data) in enumerate(sections):
        print(f'  Section {idx}: 0x{addr:08X} - 0x{addr+len(data):08X} ({len(data)} bytes)')
    
    print(f'Generating C header: {header_file}')
    generate_c_header(sections, header_file, name)
    print('Done!')
