# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Luigi Giuffrida
# Description: Bus class

import warnings

from bus_type import BusType
from typing import List, Optional

from peripherals.peripheral_domain import PeripheralDomain
from bus.axi_slave import AxiSlave
from bus.axi_master import AxiMaster


def _macro_name(name: str) -> str:
    """
    Normalize a node name into an uppercase macro-friendly identifier.

    Strips the " Peripheral Domain" suffix that :class:`PeripheralDomain`
    appends, then uppercases and replaces spaces with underscores. E.g.
    "Peripherals Peripheral Domain" -> "PERIPHERALS", "soc_ctrl" -> "SOC_CTRL".
    """
    suffix = " Peripheral Domain"
    if name.endswith(suffix):
        name = name[: -len(suffix)]
    return name.strip().upper().replace(" ", "_")


#: Default size used when an AXI slave is added without an explicit size.
DEFAULT_SLAVE_SIZE = 0x1000


class Bus:
    """
    Represents a system bus.

    In bus-centric systems (see :class:`XAlp`) the bus is created first and
    every component (CPU, memory subsystem, domains) is then
    connected to it.

    :param BusType bus_type: The type of the bus.
    :raise TypeError: when parameters are of incorrect type.
    """

    def __init__(self, bus_type: Optional[BusType] = None):
        if bus_type is not None and not type(bus_type) is BusType:
            raise TypeError(
                f"Bus.bus_type should be of type BusType not {type(bus_type)}"
            )
        self._bus_type = bus_type
        self._masters: List[AxiMaster] = []
        self._slaves: list = []
        self._addr_rules: list = []

    def bus_type(self) -> Optional[BusType]:
        """
        :return: the type of the bus
        :rtype: BusType
        """
        return self._bus_type

    # ------------------------------------------------------------
    # Masters / AXI slaves (bus-centric address model)
    # ------------------------------------------------------------

    def add_master(self, master: AxiMaster):
        """
        Add an AXI master endpoint to the bus.

        :param AxiMaster master: The master to add.
        :raise TypeError: when master is of incorrect type.
        """
        if not isinstance(master, AxiMaster):
            raise TypeError("Bus master should be of type AxiMaster")
        self._masters.append(master)

    def get_masters(self):
        """:return: The ordered list of AXI masters."""
        return list(self._masters)

    def add_slave(self, slave):
        """
        Add an AXI slave to the bus. A slave is either a :class:`AxiSlave`
        (a plain address region such as MEM / DEBUG_MODULE / EXT_SLAVE) or a
        :class:`PeripheralDomain` (a domain whose register-interface
        peripherals become REG slaves nested in its region).

        :param slave: The slave node to add.
        :raise TypeError: when slave is of incorrect type.
        """
        if not isinstance(slave, (AxiSlave, PeripheralDomain)):
            raise TypeError(
                "Bus slave should be a AxiSlave or a PeripheralDomain (domain)"
            )
        if slave.get_length() is None:
            warnings.warn(
                f"The length of {slave.get_name()} is not set, a default value of "
                f"{hex(DEFAULT_SLAVE_SIZE)} will be used."
            )
        self._slaves.append(slave)

    def add_addr_rule(self, name: str, base: int, size: int, slave):
        """
        Decode another address region onto the port of an already added slave.
        The crossbar takes more address rules than it has ports, so a single
        port can answer several disjoint regions: the LLC, for instance, has
        its cached region as the region of its slave and its scratchpad as an
        extra rule.

        :param str name: The name of the region, used for its address parameters.
        :param int base: The start address of the region.
        :param int size: The size of the region in bytes.
        :param slave: The already added slave whose port decodes the region.
        :raise ValueError: when a parameter is invalid or the slave is unknown.
        """
        if type(name) is not str or name == "":
            raise ValueError("Address rule name should be a non-empty string")
        if type(base) is not int or base < 0:
            raise ValueError("Address rule base should be a positive integer")
        if type(size) is not int or size <= 0:
            raise ValueError("Address rule size should be a strictly positive integer")
        if not any(slave is s for s in self._slaves):
            raise ValueError(
                f"The slave decoding {name} should be added to the bus first"
            )
        self._addr_rules.append((name, base, size, slave))

    def get_slaves(self):
        """:return: The ordered list of AXI slave nodes."""
        return list(self._slaves)

    def build_address_map(self, start_address: int = 0):
        """
        Build the AXI slave regions and their nested register sub-buses, then
        validate that the AXI slave regions do not overlap.

        Slaves are placed in the order they were added. A slave with no explicit
        size gets :data:`DEFAULT_SLAVE_SIZE`. A slave with no explicit base is
        placed at the next free address after the previous slave (starting from
        ``start_address``); a slave with an explicit base must not start before
        that next free address. Domain slaves are then built so
        their register-interface peripherals get offsets assigned.

        :param int start_address: First address used for auto-placed slaves.
        """
        if type(start_address) is not int or start_address < 0:
            raise ValueError("start_address should be a positive integer")

        next_address = start_address
        for slave in self._slaves:
            if slave.get_length() is None:
                slave.set_length(DEFAULT_SLAVE_SIZE)

            base = slave.get_start_address()
            if base is None:
                base = next_address
                slave.set_start_address(base)
            elif base < next_address:
                raise ValueError(
                    f"AXI slave {slave.get_name()} starts at {hex(base)}, before "
                    f"the next free bus address {hex(next_address)}"
                )

            next_address = base + slave.get_length()

            if isinstance(slave, PeripheralDomain):
                slave.build()
        self._validate_axi_slaves()

    def _validate_axi_slaves(self):
        # Checked per decoder rule, not per slave: a port may be decoded by
        # several rules and none of them may overlap another.
        rules = sorted(self.get_axi_addr_rules(), key=lambda r: r["base"])
        for current, nxt in zip(rules, rules[1:]):
            if current["end"] > nxt["base"]:
                raise ValueError(
                    f"AXI region {current['name']} (ends at {hex(current['end'])}) "
                    f"overlaps {nxt['name']} (starts at {hex(nxt['base'])})"
                )

    def get_axi_masters(self):
        """
        :return: Ordered AXI masters as ``{name, macro, idx}`` entries.
        :rtype: list[dict]
        """
        return [
            {"name": m.get_name(), "macro": _macro_name(m.get_name()), "idx": i}
            for i, m in enumerate(self._masters)
        ]

    def get_axi_slaves(self):
        """
        :return: Ordered AXI slaves as ``{name, macro, idx, base, size, end}``.
        :rtype: list[dict]
        """
        result = []
        for i, slave in enumerate(self._slaves):
            base = slave.get_start_address()
            size = slave.get_length()
            result.append(
                {
                    "name": slave.get_name(),
                    "macro": _macro_name(slave.get_name()),
                    "idx": i,
                    "base": base,
                    "size": size,
                    "end": base + size,
                }
            )
        return result

    def get_axi_addr_rules(self):
        """
        :return: One decoder rule per address region, as
            ``{name, macro, port, idx, base, size, end}``, in slave order with
            the extra rules of a slave right after its own. ``macro`` names the
            region while ``port`` names the slave decoding it, so a slave given
            extra regions with :meth:`add_addr_rule` contributes one rule per
            region, all pointing at the same port index.
        :rtype: list[dict]
        """
        rules = []
        for entry, slave in zip(self.get_axi_slaves(), self._slaves):
            rules.append(dict(entry, port=entry["macro"]))
            for name, base, size, target in self._addr_rules:
                if target is slave:
                    rules.append(
                        {
                            "name": name,
                            "macro": _macro_name(name),
                            "port": entry["macro"],
                            "idx": entry["idx"],
                            "base": base,
                            "size": size,
                            "end": base + size,
                        }
                    )
        return rules

    def get_reg_slaves(self):
        """
        :return: Register-interface slaves nested in domain AXI
            regions, as ``{name, macro, idx, base, size, end}`` with absolute
            addresses (domain base + peripheral offset).
        :rtype: list[dict]
        """
        result = []
        idx = 0
        for slave in self._slaves:
            if not isinstance(slave, PeripheralDomain):
                continue
            sub_base = slave.get_start_address()
            for peripheral in slave.get_peripherals():
                offset = peripheral.get_address() or 0
                base = sub_base + offset
                size = peripheral.get_length()
                result.append(
                    {
                        "name": peripheral.get_name(),
                        "macro": _macro_name(peripheral.get_name()),
                        "idx": idx,
                        "base": base,
                        "size": size,
                        "end": base + size,
                    }
                )
                idx += 1
        return result
