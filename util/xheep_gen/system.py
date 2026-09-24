# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Luigi Giuffrida
# Description: Generic representation of a generated system.

from typing import List

from bus_type import BusType
from cpu.cpu import CPU
from cv_x_if import CvXIf
from memory_ss.memory_ss import MemorySS
from peripherals.peripheral_domain import PeripheralDomain
from pads.pad_ring import PadRing
from debug_ss.debug_ss import DebugSS
from address_map.address_map import AddressMap


class System:
    """
    Generic representation of a generated system.

    Holds the parts shared by every system flavor (X-HEEP, X-ALP, ...):
    bus type, CPU, CORE-V eXtension Interface, memory subsystem, peripheral
    domains, pad ring and user-defined extensions. Concrete systems
    (e.g. :class:`XHeep`, :class:`XAlp`) inherit from this class and add
    their specific components and configuration style.

    Peripherals are organized in domains (see :class:`PeripheralDomain`):
    each domain is an independent group of peripherals with its own address
    range. Any number of domains can be added to the system.

    An instance of a subclass of this class is passed to the mako
    templates to generate and describe the system.

    :param BusType bus_type: The bus type chosen for this system.
    :raise TypeError: when parameters are of incorrect type.
    """

    IL_COMPATIBLE_BUS_TYPES = [BusType.NtoM]
    """Constant set of bus types that support interleaved memory banks"""

    AVAILABLE_CPUS = []
    """Constant list of CPU names available for this system flavor."""

    AVAILABLE_PERIPHERALS = []
    """Constant list of peripheral names available for this system flavor."""

    MINIMUM_PERIPHERALS = []
    """Constant list of peripheral names that must be present."""

    def __init__(self):

        self._bus_type: BusType = None

        self._cpu = None
        self._xif: CvXIf = None

        self._memory_ss = None

        self._debug_ss: DebugSS = None

        self._address_map: AddressMap = None

        self._domains: List[PeripheralDomain] = []

        self._padring: PadRing = None

        self._extensions = {}

    # ------------------------------------------------------------
    # Bus
    # ------------------------------------------------------------

    def set_bus_type(self, bus_type: BusType):
        """
        Sets the bus type of the system.

        :param BusType bus_type: The bus type to set.
        :raise TypeError: when bus_type is of incorrect type.
        """
        if not type(bus_type) is BusType:
            raise TypeError(
                f"{type(self).__name__}.bus_type should be of type BusType not {type(bus_type)}"
            )
        self._bus_type = bus_type

    def bus_type(self) -> BusType:
        """
        :return: the configured bus type
        :rtype: BusType
        """
        return self._bus_type

    # ------------------------------------------------------------
    # CPU
    # ------------------------------------------------------------

    def set_cpu(self, cpu: CPU):
        """
        Sets the CPU of the system.

        :param CPU cpu: The CPU to set.
        :raise TypeError: when cpu is of incorrect type.
        """
        if not isinstance(cpu, CPU):
            raise TypeError(
                f"{type(self).__name__}.cpu should be of type CPU not {type(cpu)}"
            )
        self._cpu = cpu

    def cpu(self) -> CPU:
        """
        :return: the configured CPU
        :rtype: CPU
        """
        return self._cpu

    def get_available_cpus(self):
        """
        :return: CPU names available for this system flavor.
        :rtype: list[str]
        """
        return list(self.AVAILABLE_CPUS)

    # ------------------------------------------------------------
    # CORE-V eXtension Interface (CV-X-IF)
    # ------------------------------------------------------------

    def set_xif(self, xif: CvXIf):
        """
        Sets the configuration of the CORE-V eXtension Interface (CV-X-IF).

        :param CvXIf xif: CV-X-IF instance with the desired paramters.

        :raise TypeError: when xif is of incorrect type.
        """
        if not isinstance(xif, CvXIf):
            raise TypeError(
                f"{type(self).__name__}.xif should be of type CvXIf not {type(xif)}"
            )
        self._xif = xif

    def xif(self) -> CvXIf:
        """
        :return: the configured CV-X-IF
        :rtype: CvXIf
        """
        return self._xif

    # ------------------------------------------------------------
    # Memory
    # ------------------------------------------------------------

    def set_memory_ss(self, memory_ss: MemorySS):
        """
        Sets the memory subsystem of the system.

        :param MemorySS memory_ss: The memory subsystem to set.
        :raise TypeError: when memory_ss is of incorrect type.
        """
        if not isinstance(memory_ss, MemorySS):
            raise TypeError(
                f"{type(self).__name__}.memory_ss should be of type MemorySS not {type(memory_ss)}"
            )
        self._memory_ss = memory_ss

    def memory_ss(self) -> MemorySS:
        """
        :return: the configured memory subsystem
        :rtype: MemorySS
        """
        return self._memory_ss

    # ------------------------------------------------------------
    # Debug Subsystem
    # ------------------------------------------------------------

    def set_debug_ss(self, debug_ss: DebugSS):
        """
        Sets the debug subsystem of the system.

        :param DebugSS debug_ss: The debug subsystem to set.
        :raise TypeError: when debug_ss is of incorrect type.
        """
        if not isinstance(debug_ss, DebugSS):
            raise TypeError(
                f"XHeep.debug_ss should be of type DebugSS not {type(self._debug_ss)}"
            )
        self._debug_ss = debug_ss

    def debug_ss(self) -> DebugSS:
        """
        :return: the configured debug subsystem
        :rtype: DebugSS
        """
        return self._debug_ss

    # ------------------------------------------------------------
    # Address Map
    # ------------------------------------------------------------

    def set_address_map(self, address_map: AddressMap):
        """
        Sets the address map of the system.

        :param AddressMap address_map: The address map to set.
        :raise TypeError: when address_map is of incorrect type.
        """
        if not isinstance(address_map, AddressMap):
            raise TypeError(
                f"XHeep.address_map should be of type AddressMap not {type(self._address_map)}"
            )
        self._address_map = address_map

    def address_map(self) -> AddressMap:
        """
        :return: the system's top-level address map.
        :rtype: AddressMap
        """
        return self._address_map

    # ------------------------------------------------------------
    # Peripheral Domains
    # ------------------------------------------------------------

    def get_peripherals(self):
        """
        :return: List of all peripherals configured in the system, gathered from its domains.
        :rtype: list[Peripheral]
        """
        return [peripheral for d in self._domains for peripheral in d.get_peripherals()]

    def add_domain(self, domain: PeripheralDomain):
        """
        Add a domain to the system. The domain should already contain all
        peripherals well configured.

        :param PeripheralDomain domain: The domain to add.
        :raise TypeError: when domain is of incorrect type.
        :raise ValueError: when a domain with the same name is already present.
        """
        if not isinstance(domain, PeripheralDomain):
            raise TypeError(
                f"{type(self).__name__} domains should be of type PeripheralDomain not {type(domain)}"
            )
        if any(d.get_name() == domain.get_name() for d in self._domains):
            raise ValueError(
                f"A domain named {domain.get_name()} is already present in the system"
            )
        self._domains.append(domain)

    def remove_domain(self, name: str):
        """
        Remove a domain from the system, together with the peripherals it
        brought in.

        :param str name: The name of the domain to remove.
        """
        for d in self._domains:
            if d.get_name() == name:
                self._domains.remove(d)
                return
        print(f"Warning : Domain {name} is not in the system")

    def _find_domain(self, name):
        """
        Returns the stored domain of the given name.

        :param str name: The name of the domain to look for.
        :return: The stored domain, `None` if not present.
        :rtype: PeripheralDomain
        """
        for d in self._domains:
            if d.get_name() == name:
                return d
        return None

    def get_domains(self):
        """
        :return: The domains.
        :rtype: list[PeripheralDomain]
        """
        return list(self._domains)

    def get_configured_peripheral_names(self):
        """
        :return: Names of peripherals configured in the system.
        :rtype: list[str]
        """
        names = []
        for d in self._domains:
            names.extend(peripheral.get_name() for peripheral in d.get_peripherals())
        return names

    # ------------------------------------------------------------
    # Pad Ring
    # ------------------------------------------------------------

    def set_padring(self, pad_ring: PadRing):
        """
        Sets the pad ring of the system.

        :param PadRing pad_ring: The pad ring to set.
        :raise TypeError: when pad_ring is of incorrect type.
        """
        if not isinstance(pad_ring, PadRing):
            raise TypeError(
                f"{type(self).__name__}.pad_ring should be of type PadRing not {type(pad_ring)}"
            )
        self._padring = pad_ring

    def get_padring(self):
        return self._padring

    # ------------------------------------------------------------
    # Extensions
    # ------------------------------------------------------------

    def add_extension(self, name, extension):
        """
        Register an external extension or configuration (object, dict, etc.).

        :param str name: Name of the extension.
        :param Any extension: The extension object.
        """
        self._extensions[name] = extension

    def get_extension(self, name):
        """
        Retrieve a previously registered extension.

        :param str name: Name of the extension.
        :return: The extension object.
        :rtype: Any
        """
        return self._extensions.get(name, None)

    def is_extension_defined(self, name):
        """
        Check if an extension is defined.

        :param str name: Name of the extension.
        :return: `True` if the extension is defined, `False` otherwise.
        :rtype: bool
        """
        return name in self._extensions

    # ------------------------------------------------------------
    # Build and Validate
    # ------------------------------------------------------------

    def build(self):
        """
        Makes the system ready to be used. Builds the memory subsystem and
        every domain.
        """
        if self.memory_ss():
            self.memory_ss().build()
        for d in self._domains:
            # A domain carries no region of its own: it takes the one of the
            # address map region sharing its name.
            region = (
                self.address_map().get_region(d.get_name())
                if self.address_map()
                else None
            )
            if region is None:
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: No address map region named {d.get_name()} for the domain of the same name"
                )
            d.set_start_address(region.get_start_address())
            d.set_length(region.get_length())
            d.build()

    def validate(self):
        """
        Does some basics checks on the configuration

        This should be called before using the system object to generate the project.
        Subclasses should extend this method with their specific checks.
        """
        if not self.cpu():
            raise RuntimeError("[MCU-GEN] ERROR: A CPU must be configured")
        self._validate_cpu_available()

        # Check that the extension interface is enabled with a supported core
        if self.xif() is not None and self.cpu().get_name() in ["cv32e40p"]:
            raise RuntimeError(
                f"[MCU-GEN] ERROR: CV-X-IF enabled (set_xif()) with incompatible CPU ({self.cpu().get_name()})."
            )

        self._validate_peripheral_availability()

        if self.memory_ss():
            self.memory_ss().validate()

        # Check that each domain is valid
        for d in self._domains:
            d.validate()

        # Check that domains do not overlap
        domains_sorted = sorted(self._domains, key=lambda d: d.get_start_address())
        for current, next_d in zip(domains_sorted, domains_sorted[1:]):
            if current.get_start_address() == next_d.get_start_address():
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: The domains {current.get_name()} and {next_d.get_name()} should not start at the same address (current address is {current.get_start_address():#08X})."
                )
            if (
                current.get_start_address() + current.get_length()
                > next_d.get_start_address()
            ):
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: The domain {current.get_name()} (ends at {current.get_start_address() + current.get_length():#08X}) overflows over {next_d.get_name()} (starts at {next_d.get_start_address():#08X})."
                )

        # Check that all domains start above the protected low address range
        for d in self._domains:
            if d.get_start_address() < 0x10000:
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: Domain start address must be greater than 0x10000, current address of {d.get_name()} is {d.get_start_address():#08X}."
                )

        if not self._padring:
            raise RuntimeError("[MCU-GEN] ERROR: A padring must be configured")
        self._padring.validate()

        return True

    def _validate_cpu_available(self):
        available_cpus = self.get_available_cpus()
        if available_cpus and self.cpu().get_name() not in available_cpus:
            raise RuntimeError(
                f"[MCU-GEN] ERROR: CPU {self.cpu().get_name()} is not available for {type(self).__name__}. Available CPUs: {', '.join(available_cpus)}"
            )

    def _validate_peripheral_availability(self):
        configured_peripherals = self.get_configured_peripheral_names()

        available_peripherals = self.AVAILABLE_PERIPHERALS
        if available_peripherals:
            unsupported = sorted(
                set(configured_peripherals) - set(available_peripherals)
            )
            if unsupported:
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: Unsupported peripherals for {type(self).__name__}: {', '.join(unsupported)}"
                )

        minimum_peripherals = self.MINIMUM_PERIPHERALS
        if minimum_peripherals:
            missing = sorted(set(minimum_peripherals) - set(configured_peripherals))
            if missing:
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: Missing minimum peripherals for {type(self).__name__}: {', '.join(missing)}"
                )
