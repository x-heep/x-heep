#!/usr/bin/env python3

# Copyright (c) 2011-2024 Columbia University, System Level Design Group
# SPDX-License-Identifier: Apache-2.0

"""
Create multiple instances of X-HEEP accelerator for ESP.

This script creates numbered instances of the X-HEEP accelerator,
allowing multiple X-HEEP cores to be integrated into an ESP SoC.
"""

import os
import sys
import shutil
import re
from pathlib import Path


def get_script_dir():
    """Get the directory where this script is located (xheep base folder)."""
    return Path(__file__).parent.resolve()


def get_esp_root():
    """Get the ESP root directory."""
    return get_script_dir().parent.parent.parent


def create_xheep_instance(instance_num):
    """
    Create a new X-HEEP instance.
    
    Args:
        instance_num: Integer instance number (e.g., 1, 2, 3...)
    """
    if instance_num < 1:
        print("Error: Instance number must be >= 1")
        return False
    
    base_dir = get_script_dir()
    parent_dir = base_dir.parent
    new_instance_name = f"xheep{instance_num}"
    new_instance_dir = parent_dir / new_instance_name
    
    print(f"Creating X-HEEP instance: {new_instance_name}")
    print(f"Target directory: {new_instance_dir}")
    
    # Check if instance already exists
    if new_instance_dir.exists():
        response = input(f"\nInstance '{new_instance_name}' already exists. Overwrite? [y/N]: ")
        if response.lower() != 'y':
            print("Aborted.")
            return False
        print(f"Removing existing instance at {new_instance_dir}")
        shutil.rmtree(new_instance_dir)
    
    # Copy the entire xheep directory to the new instance
    print(f"\nCopying xheep -> {new_instance_name}...")
    shutil.copytree(base_dir, new_instance_dir, 
                    ignore=shutil.ignore_patterns('create_xheep_instance.py', 'out'))
    
    # Remove esp_files directory (not used in our case)
    esp_files_dir = new_instance_dir / "ip" / "x-heep" / "esp_files"
    if esp_files_dir.exists():
        print(f"\nRemoving unused esp_files directory...")
        shutil.rmtree(esp_files_dir)
        print(f"  Removed {esp_files_dir}")
    
    # Rename files in the top-level directory only (not recursive)
    print(f"\nRenaming files containing 'xheep' in {new_instance_name}/...")
    for item in new_instance_dir.iterdir():
        if item.is_file() and 'xheep' in item.name.lower():
            new_name = item.name.replace('xheep', new_instance_name)
            new_path = item.parent / new_name
            print(f"  Renaming: {item.name} -> {new_name}")
            item.rename(new_path)
    
    # Empty the .sverilog and .verilog files (they will be regenerated)
    sverilog_file = new_instance_dir / f"{new_instance_name}.sverilog"
    verilog_file = new_instance_dir / f"{new_instance_name}.verilog"
    
    if sverilog_file.exists():
        print(f"\nClearing {sverilog_file.name} (will be regenerated)...")
        with open(sverilog_file, 'w') as f:
            f.write("")
    
    if verilog_file.exists():
        print(f"Clearing {verilog_file.name} (will be regenerated)...")
        with open(verilog_file, 'w') as f:
            f.write("")
    
    # Update XML file - full string replacement of 'xheep' to 'xheep<N>'
    xml_file = new_instance_dir / f"{new_instance_name}.xml"
    if xml_file.exists():
        print(f"\nUpdating {xml_file.name}...")
        with open(xml_file, 'r') as f:
            content = f.read()
        
        # Replace all occurrences of 'xheep' with the new instance name
        # This includes accelerator name="xheep" and signal prefixes like x_heep_
        content = content.replace('name="xheep"', f'name="{new_instance_name}"')
        content = content.replace('x_heep_', f'x_{new_instance_name}_')
        
        # Update device_id to match the instance number (200 + instance_num)
        content = re.sub(
            r'device_id="200"',
            f'device_id="{200 + instance_num}"',
            content
        )
        
        with open(xml_file, 'w') as f:
            f.write(content)
        print(f"  Updated device_id: 200 -> {200 + instance_num}")
        print(f"  Updated signal names: x_heep_* -> x_{new_instance_name}_*")
    else:
        print(f"Warning: XML file {xml_file.name} not found!")
    
    # Update XHEEP_INSTANCE_ID and module name in the wrapper file
    wrapper_file = new_instance_dir / f"{new_instance_name}_wrapper.v"
    if wrapper_file.exists():
        print(f"\nUpdating {wrapper_file.name}...")
        with open(wrapper_file, 'r') as f:
            content = f.read()
        
        # Replace the XHEEP_INSTANCE_ID localparam
        pattern = r'localparam\s+logic\s+\[31:0\]\s+XHEEP_INSTANCE_ID\s+=\s+32\'d\d+;'
        replacement = f"localparam logic [31:0] XHEEP_INSTANCE_ID = 32'd{instance_num};"
        content = re.sub(pattern, replacement, content)
        
        # Replace module name from XHEEP_wrapper to XHEEP<N>_wrapper
        content = re.sub(r'\bmodule\s+XHEEP_wrapper\b', f'module {new_instance_name.upper()}_wrapper', content)
        
        # Replace signal names in the module interface
        # x_heep_clk -> x_xheep<N>_clk, x_heep_rstn -> x_xheep<N>_rstn, etc.
        content = content.replace('x_heep_', f'x_{new_instance_name}_')
        
        with open(wrapper_file, 'w') as f:
            f.write(content)
        print(f"  Set XHEEP_INSTANCE_ID = {instance_num}")
        print(f"  Renamed module: XHEEP_wrapper -> {new_instance_name.upper()}_wrapper")
        print(f"  Updated signal names: x_heep_* -> x_{new_instance_name}_*")
    else:
        print(f"Warning: Wrapper file {wrapper_file.name} not found!")
    
    # Update ACCEL_NAME in Makefile and remove certain targets
    makefile = new_instance_dir / "Makefile"
    if makefile.exists():
        print(f"\nUpdating ACCEL_NAME in Makefile...")
        with open(makefile, 'r') as f:
            content = f.read()
        
        # Replace ACCEL_NAME := xheep with ACCEL_NAME := xheep<N>
        content = re.sub(
            r'^ACCEL_NAME\s*:=\s*xheep\s*$',
            f'ACCEL_NAME := {new_instance_name}',
            content,
            flags=re.MULTILINE
        )
        
        # Remove mirror-filelist, update-sverilog, update-verilog from hw target
        # hw: mcu-gen questa update-$(ACCEL_NAME)-sverilog update-$(ACCEL_NAME)-verilog mirror-filelist
        # becomes: hw: mcu-gen questa
        content = re.sub(
            r'^hw:\s+mcu-gen\s+questa\s+update-\$\(ACCEL_NAME\)-sverilog\s+update-\$\(ACCEL_NAME\)-verilog\s+mirror-filelist\s*$',
            'hw: mcu-gen questa',
            content,
            flags=re.MULTILINE
        )
        
        # Remove the same targets from $(ACCEL_NAME)-vivado target
        # $(ACCEL_NAME)-vivado: mcu-gen vivado-setup update-$(ACCEL_NAME)-sverilog-vivado update-$(ACCEL_NAME)-verilog-vivado mirror-filelist generate-fpga-ips sw-vivado
        # becomes: $(ACCEL_NAME)-vivado: mcu-gen vivado-setup generate-fpga-ips sw-vivado
        content = re.sub(
            r'^(\$\(ACCEL_NAME\)-vivado:)\s+mcu-gen\s+vivado-setup\s+update-\$\(ACCEL_NAME\)-sverilog-vivado\s+update-\$\(ACCEL_NAME\)-verilog-vivado\s+mirror-filelist\s+generate-fpga-ips\s+sw-vivado\s*$',
            r'\1 mcu-gen vivado-setup generate-fpga-ips sw-vivado',
            content,
            flags=re.MULTILINE
        )
        
        with open(makefile, 'w') as f:
            f.write(content)
        print(f"  Set ACCEL_NAME := {new_instance_name}")
        print(f"  Removed mirror-filelist and update targets from hw and {new_instance_name}-vivado")
    else:
        print(f"Warning: Makefile not found!")
    
    # Update thirdparty.py
    thirdparty_file = get_esp_root() / "tools" / "socgen" / "thirdparty.py"
    print(f"\nUpdating {thirdparty_file}...")
    
    if not thirdparty_file.exists():
        print(f"Error: thirdparty.py not found at {thirdparty_file}")
        return False
    
    with open(thirdparty_file, 'r') as f:
        lines = f.readlines()
    
    # Find where to insert the new entry (after the X-HEEP section)
    insert_idx = None
    for i, line in enumerate(lines):
        if 'THIRDPARTY_IRQ_TYPE["xheep"]' in line:
            insert_idx = i + 1
            break
    
    if insert_idx is None:
        print("Error: Could not find xheep entry in thirdparty.py")
        return False
    
    # Check if entry already exists
    entry_exists = any(f'THIRDPARTY_COMPATIBLE["{new_instance_name}"]' in line for line in lines)
    
    if not entry_exists:
        # Add the new instance entries
        new_entries = [
            f'\n# X-HEEP Instance {instance_num}\n',
            f'THIRDPARTY_COMPATIBLE["{new_instance_name}"] = "epfl,{200 + instance_num}"\n',
            f'THIRDPARTY_IRQ_TYPE["{new_instance_name}"]   = "1"            # 1 = level-sensitive IRQ\n'
        ]
        
        lines[insert_idx:insert_idx] = new_entries
        
        with open(thirdparty_file, 'w') as f:
            f.writelines(lines)
        
        print(f"  Added {new_instance_name} entry to thirdparty.py")
        print(f"  Device ID: epfl,{200 + instance_num}")
    else:
        print(f"  Entry for {new_instance_name} already exists in thirdparty.py")
    
    print(f"\n✓ Successfully created X-HEEP instance '{new_instance_name}'")
    print(f"\nNext steps:")
    print(f"  1. Build the accelerator:")
    print(f"     Go to $ESP_ROOT/socs/<soc_name> and run:")
    print(f"       make {new_instance_name}        (for Modelsim/Questasim)")
    print(f"       make {new_instance_name}-vivado (for Vivado simulation)")
    print(f"")
    print(f"  2. Application and Configuration:")
    print(f"     - Application source: {new_instance_name}/ip/x-heep/sw/applications/esp_app")
    print(f"     - Generates firmware: {new_instance_name}_firmware.h")
    print(f"     - X-HEEP config:      {new_instance_name}/ip/x-heep/configs/esp_heep.hjson")
    print(f"")
    print(f"  3. Configure your ESP SoC:")
    print(f"     Run 'make esp-xconfig' and select '{new_instance_name.upper()}' from the accelerator list")
    
    return True


def main():
    if len(sys.argv) != 2:
        print("Usage: ./create_xheep_instance.py <instance_number>")
        print("\nExample:")
        print("  ./create_xheep_instance.py 1    # Creates xheep1")
        print("  ./create_xheep_instance.py 2    # Creates xheep2")
        sys.exit(1)
    
    try:
        instance_num = int(sys.argv[1])
    except ValueError:
        print(f"Error: Instance number must be an integer, got '{sys.argv[1]}'")
        sys.exit(1)
    
    success = create_xheep_instance(instance_num)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
