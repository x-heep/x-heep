# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): marinPh, David Mallasén
# Description: X-HEEP System configuration.

from copy import deepcopy

from bus_type import BusType
from system import System
from cpu.cpu import CPU
from peripherals.abstractions import PeripheralDomain
from peripherals.base_peripherals_domain import BasePeripheralDomain
from peripherals.user_peripherals_domain import UserPeripheralDomain
from linker_script.linker_script import LinkerScript
from interrupts.interrupts import Interrupts


class XHeep(System):
    """
    Represents the whole X-HEEP system.

    An instance of this class is passed to the mako templates.

    :param BusType bus_type: The bus type chosen for this mcu.
    :raise TypeError: when parameters are of incorrect type.
    """

    IL_COMPATIBLE_BUS_TYPES = [BusType.NtoM]
    """Constant set of bus types that support interleaved memory banks"""

    AVAILABLE_CPUS = ["cv32e20", "cv32e40p", "cv32e40px", "cv32e40x"]
    """Constant list of CPU names available for X-HEEP."""

    def __init__(
        self,
        bus_type: BusType,
    ):
        super().__init__(bus_type)
        self._linker_script_config: LinkerScript = None
        self._interrupts: Interrupts = None

    # ------------------------------------------------------------
    # Peripheral Domains
    # ------------------------------------------------------------

    def add_peripheral_domain(self, domain: PeripheralDomain):
        """
        Add a peripheral domain to the system. The domain should already contain all peripherals well configured. When adding a domain, a deepcopy is made to avoid side effects.

        X-HEEP holds at most one base and one user peripheral domain, so a
        domain replaces the one of the same kind if it is already present.

        :param PeripheralDomain domain: The domain to add.
        :raise ValueError: when the domain is neither a base nor a user peripheral domain.
        """
        if not isinstance(domain, (BasePeripheralDomain, UserPeripheralDomain)):
            raise ValueError(
                "Domain is neither a BasePeripheralDomain nor a UserPeripheralDomain"
            )
        existing = self._find_peripheral_subsystem(type(domain))
        if existing is not None:
            self.remove_peripheral_subsystem(existing.get_name())
        self.add_peripheral_subsystem(domain)

    # ------------------------------------------------------------
    # CPU
    # ------------------------------------------------------------

    # ------------------------------------------------------------
    # CORE-V eXtension Interface (CV-X-IF)
    # ------------------------------------------------------------

    # ------------------------------------------------------------
    # Bus
    # ------------------------------------------------------------

    # ------------------------------------------------------------
    # Memory
    # ------------------------------------------------------------

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

    # ------------------------------------------------------------
    # Address Map
    # ------------------------------------------------------------

    # ------------------------------------------------------------
    # Peripherals
    # ------------------------------------------------------------

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

    # ------------------------------------------------------------
    # Extensions
    # ------------------------------------------------------------

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
            self._find_peripheral_subsystem(BasePeripheralDomain).build(
                self.address_map().get_region("base_peripheral_domain").get_length()
            )
        if self.address_map() and self.are_user_peripherals_configured():
            self._find_peripheral_subsystem(UserPeripheralDomain).build(
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
        if self.cpu().get_name() not in self.get_available_cpus():
            raise RuntimeError(
                f"[MCU-GEN] ERROR: CPU {self.cpu().get_name()} is not available for XHeep. Available CPUs: {', '.join(self.get_available_cpus())}"
            )

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
            self._find_peripheral_subsystem(BasePeripheralDomain).validate(
                self.address_map().get_region("base_peripheral_domain").get_length(),
                self._bus_type,
            )
        else:
            raise RuntimeError(
                "[MCU-GEN] ERROR: Base peripheral domain must be configured"
            )
        if self.are_user_peripherals_configured():
            self._find_peripheral_subsystem(UserPeripheralDomain).validate(
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
