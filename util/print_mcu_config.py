# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Description: Print a compact view of the selected MCU configuration.

import argparse
import contextlib
import io
import pathlib
import sys
from collections import Counter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "xheep_gen"))

import load_config
from bus_type import BusType
from cpu.cpu import CPU


def print_branch(label, children=(), prefix="", last=True):
    lines = [prefix + ("`-- " if last else "|-- ") + label]
    for index, (child_label, grandchildren) in enumerate(children):
        lines.extend(print_branch(child_label, grandchildren, prefix + ("    " if last else "|   "), index == len(children) - 1))
    return lines


def peripheral_names(domain, base_address):
    names = []
    for peripheral in domain.get_peripherals():
        if hasattr(peripheral, "get_is_included") and not peripheral.get_is_included():
            continue
        name = peripheral.get_name()
        if name == "dma":
            name += f" ({peripheral.get_num_channels()} channels, {peripheral.get_num_master_ports()} master ports)"
        elif name == "w25q128jw_controller" and peripheral.get_cache():
            name += " (cache enabled)"
        names.append(f"{name} @ 0x{base_address + peripheral.get_address():08X}")
    return names


def print_config_tree(xheep, config):
    cpu = xheep.cpu()
    cpu_details = ", ".join(f"{key}={value}" for key, value in cpu.params.items())
    cpu_label = f"CPU: {cpu.get_name()}" + (f" ({cpu_details})" if cpu_details else "")

    memory = xheep.memory_ss()
    banks = list(memory.iter_ram_banks())
    continuous_banks = [bank for bank in banks if not bank.il_level()]
    continuous = Counter(bank.size() // 1024 for bank in continuous_banks)
    memory_children = []
    if continuous:
        sizes = ", ".join(f"{count} x {size} KiB" for size, count in continuous.items())
        memory_children.append((f"Continuous: {sizes}", [(f"Bank {bank.name()}: {bank.size() // 1024} KiB @ 0x{bank.start_address():08X}", ()) for bank in continuous_banks]))
    for group in memory.iter_il_groups():
        name = f" ({group.group_name})" if group.group_name else ""
        memory_children.append((f"Interleaved{name}: {group.n} x {group.banks[0].size() // 1024} KiB (shared address window)", [(f"Bank {bank.name()} (lane {bank.il_offset()}): {bank.size() // 1024} KiB @ 0x{bank.start_address():08X}", ()) for bank in group.banks]))

    address_map = xheep.address_map()
    base = peripheral_names(xheep.get_base_peripheral_domain(), address_map.get_region("base_peripheral_domain").get_start_address())
    user = peripheral_names(xheep.get_user_peripheral_domain(), address_map.get_region("user_peripheral_domain").get_start_address())
    nodes = [
        (cpu_label, ()),
        (f"Bus: {xheep.bus_type().value}", ()),
        (f"RAM: {sum(bank.size() for bank in banks) // 1024} KiB", memory_children),
        (f"Debug: SPI slave {'enabled' if xheep.debug_ss().has_spi_slave() else 'disabled'}", ()),
    ]
    if xheep.xif() is not None:
        nodes.append(("CV-X-IF: enabled", ()))
    nodes.extend(
        [
            (f"Always-on peripherals ({len(base)})", [(name, ()) for name in base]),
            (f"User peripherals ({len(user)})", [(name, ()) for name in user]),
        ]
    )

    lines = []
    for index, (label, children) in enumerate(nodes):
        lines.extend(print_branch(label, children, last=index == len(nodes) - 1))
    address_column = max(len(line.rsplit(" @ 0x", 1)[0]) for line in lines if " @ 0x" in line)

    print(f"\nX-HEEP MCU: {config}")
    for line in lines:
        if " @ 0x" in line:
            label, address = line.rsplit(" @ 0x", 1)
            line = f"{label:<{address_column}} @ 0x{address}"
        print(line)


def main():
    parser = argparse.ArgumentParser(description="Print the selected X-HEEP MCU configuration")
    parser.add_argument("--config", type=pathlib.Path, required=True)
    parser.add_argument("--cpu", nargs="?", default="")
    parser.add_argument("--bus", nargs="?", default="")
    parser.add_argument("--memorybanks", nargs="?", default="")
    parser.add_argument("--memorybanks_il", nargs="?", default="")
    args = parser.parse_args()

    # Python configurations may print their own diagnostics; keep the final summary compact.
    with contextlib.redirect_stdout(io.StringIO()):
        xheep = load_config.load_cfg_file(args.config)
        if args.bus:
            xheep.set_bus_type(BusType(args.bus))
        if args.memorybanks:
            xheep.memory_ss().override_ram_banks(int(args.memorybanks))
        if args.memorybanks_il:
            xheep.memory_ss().override_ram_banks_il(int(args.memorybanks_il))
        if args.cpu:
            xheep.set_cpu(CPU(args.cpu))
        xheep.build()

    print_config_tree(xheep, args.config)


if __name__ == "__main__":
    main()
