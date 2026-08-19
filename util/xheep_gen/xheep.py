# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): marinPh, David Mallasén
# Description: X-HEEP System configuration.

from copy import deepcopy

from bus_type import BusType
from debug_ss.debug_ss import DebugSS
from memory_ss.memory_ss import MemorySS
from cpu.cpu import CPU
from cv_x_if import CvXIf
from address_map.address_map import AddressMap
from peripherals.abstractions import PeripheralDomain
from peripherals.base_peripherals_domain import BasePeripheralDomain
from peripherals.user_peripherals_domain import UserPeripheralDomain
from pads.pad_ring import PadRing
from linker_script.linker_script import LinkerScript
from interrupts.interrupts import Interrupts


class XHeep:
    """
    Represents the whole X-HEEP system.

    An instance of this class is passed to the mako templates.

    :param BusType bus_type: The bus type chosen for this mcu.
    :raise TypeError: when parameters are of incorrect type.
    """

    IL_COMPATIBLE_BUS_TYPES = [BusType.NtoM]
    """Constant set of bus types that support interleaved memory banks"""

    def __init__(
        self,
        bus_type: BusType,
    ):
        if not type(bus_type) is BusType:
            raise TypeError(
                f"XHeep.bus_type should be of type BusType not {type(self._bus_type)}"
            )

        self._cpu = None
        self._xif: CvXIf = None
        self._bus_type: BusType = bus_type
        self._memory_ss = None
        self._debug_ss = None
        self._linker_script_config: LinkerScript = None
        self._address_map: AddressMap = None
        self._base_peripheral_domain = None
        self._user_peripheral_domain = None
        self._padring: PadRing = None
        self._interrupts: Interrupts = None
        self._extensions = {}

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
            raise TypeError(f"XHeep.cpu should be of type CPU not {type(self._cpu)}")
        self._cpu = cpu

    def cpu(self) -> CPU:
        """
        :return: the configured CPU
        :rtype: CPU
        """
        return self._cpu

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
            raise TypeError(f"XHeep.xif should be of type CvXIf not {type(xif)}")
        self._xif = xif

    def xif(self) -> CvXIf:
        """
        :return: the configured CV-X-IF
        :rtype: CvXIf
        """
        return self._xif

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
                f"XHeep.bus_type should be of type BusType not {type(self._bus_type)}"
            )
        self._bus_type = bus_type

    def bus_type(self) -> BusType:
        """
        :return: the configured bus type
        :rtype: BusType
        """
        return self._bus_type

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
                f"XHeep.memory_ss should be of type MemorySS not {type(self._memory_ss)}"
            )
        self._memory_ss = memory_ss

    def memory_ss(self) -> MemorySS:
        """
        :return: the configured memory subsystem
        :rtype: MemorySS
        """
        return self._memory_ss

    # ------------------------------------------------------------
    # Linker Script Configuration
    # ------------------------------------------------------------
    def set_linker_script_config(self, linker_script_config: LinkerScript):
        """
        Sets the linker script configuration for stack and heap sizes.

        :param LinkerScript config: The linker script configuration.
        """

        if not isinstance(linker_script_config, LinkerScript):

            raise TypeError(
                f"XHeep.linker_script_config should be of type LinkerScript not {type(linker_script_config)}"
            )
        self._linker_script_config = linker_script_config

    def linker_script(self) -> LinkerScript:
        """
        :return: the linker script configuration
        :rtype: LinkerScript
        """
        return self._linker_script_config

    def stack_size(self) -> int:
        """
        :return: the configured or inferred stack size in bytes
        :rtype: int
        """
        return self._linker_script_config.stack_size()

    def heap_size(self) -> int:
        """
        :return: the configured or inferred heap size in bytes
        :rtype: int
        """
        return self._linker_script_config.heap_size()

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
    # Peripherals
    # ------------------------------------------------------------

    def are_base_peripherals_configured(self) -> bool:
        """
        :return: `True` if the base peripherals are configured, `False` otherwise.
        :rtype: bool
        """
        return self._base_peripheral_domain is not None

    def are_user_peripherals_configured(self) -> bool:
        """
        :return: `True` if the user peripherals are configured, `False` otherwise.
        :rtype: bool
        """
        return self._user_peripheral_domain is not None

    def add_peripheral_domain(self, domain: PeripheralDomain):
        """
        Add a peripheral domain to the system. The domain should already contain all peripherals well configured. When adding a domain, a deepcopy is made to avoid side effects.

        :param PeripheralDomain domain: The domain to add.
        """
        if isinstance(domain, BasePeripheralDomain):
            self._base_peripheral_domain = deepcopy(domain)
        elif isinstance(domain, UserPeripheralDomain):
            self._user_peripheral_domain = deepcopy(domain)
        else:
            raise ValueError(
                "Domain is neither a BasePeripheralDomain nor a UserPeripheralDomain"
            )

    def get_user_peripheral_domain(self):
        """
        Returns a deepcopy of the user peripheral domain.

        :return: The user peripheral domain.
        :rtype: UserPeripheralDomain
        """
        return deepcopy(self._user_peripheral_domain)

    def get_base_peripheral_domain(self):
        """
        Returns a deepcopy of the base peripheral domain.

        :return: The base peripheral domain.
        :rtype: BasePeripheralDomain
        """
        return deepcopy(self._base_peripheral_domain)

    # ------------------------------------------------------------
    # Interrupts
    # ------------------------------------------------------------

    def set_interrupts(self, interrupts: Interrupts):
        """
        Sets the interrupts of the system.

        :param Interrupts interrupts: The interrupts to set.
        :raise TypeError: when interrupts is of incorrect type.
        """
        if not isinstance(interrupts, Interrupts):
            raise TypeError(
                f"XHeep.interrupts should be of type Interrupts not {type(interrupts)}"
            )
        self._interrupts = interrupts

    def get_interrupts(self) -> Interrupts:
        """
        :return: the configured interrupts
        :rtype: Interrupts
        """
        return self._interrupts

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
                f"xheep.get_padring() should be of type PadRing not {type(self._padring)}"
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
        Makes the system ready to be used.
        """

        if self.memory_ss():
            self.memory_ss().build()
        if self.linker_script():
            self.linker_script().build(self.memory_ss().linker_data_region_size())
        if self.address_map() and self.are_base_peripherals_configured():
            self._base_peripheral_domain.build(
                self.address_map().get_region("base_peripheral_domain").get_length()
            )
        if self.address_map() and self.are_user_peripherals_configured():
            self._user_peripheral_domain.build(
                self.address_map().get_region("user_peripheral_domain").get_length()
            )
        if self._interrupts:
            self._interrupts.build()

    def validate(self):
        """
        Does some basics checks on the configuration

        This should be called before using the XHeep object to generate the project.
        """
        if not self.cpu():
            raise RuntimeError("[MCU-GEN] ERROR: A CPU must be configured")

        if not self.memory_ss():
            raise RuntimeError("[MCU-GEN] ERROR: A memory subsystem must be configured")

        if not self.linker_script():
            raise RuntimeError(
                "[MCU-GEN] ERROR: A linker script instance must be configured"
            )

        self.memory_ss().validate()
        self.linker_script().validate(self.memory_ss().linker_data_region_size())

        if self.memory_ss().has_il_ram() and (
            self._bus_type not in self.IL_COMPATIBLE_BUS_TYPES
        ):
            raise RuntimeError(
                f"[MCU-GEN] ERROR: This system has a {self._bus_type} bus, one of {self.IL_COMPATIBLE_BUS_TYPES} is required for interleaved memory"
            )

        if not self.address_map():
            raise RuntimeError("[MCU-GEN] ERROR: An address map must be configured")
        self.address_map().validate()

        if self.are_base_peripherals_configured():
            self._base_peripheral_domain.validate(
                self.address_map().get_region("base_peripheral_domain").get_length(),
                self._bus_type,
            )
        else:
            raise RuntimeError(
                "[MCU-GEN] ERROR: Base peripheral domain must be configured"
            )
        if self.are_user_peripherals_configured():
            self._user_peripheral_domain.validate(
                self.address_map().get_region("user_peripheral_domain").get_length()
            )
        else:
            raise RuntimeError(
                "[MCU-GEN] ERROR: User peripheral domain must be configured"
            )

        # Check that if the extension interface is enabled, it is using a supported core
        if self.xif() is not None and self.cpu().get_name() in ["cv32e40p"]:
            raise RuntimeError(
                f"[MCU-GEN] ERROR: CV-X-IF enabled (xheep.set_xif()) with incompatible CPU ({self.cpu().get_name()})."
            )

        if not self._interrupts:
            raise RuntimeError("[MCU-GEN] ERROR: Interrupts must be configured")

        if not self._padring:
            raise RuntimeError("[MCU-GEN] ERROR: A padring must be configured")
        self._padring.validate()

        return True
