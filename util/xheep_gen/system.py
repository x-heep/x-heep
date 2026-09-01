from copy import deepcopy
from typing import List

from bus_type import BusType
from cpu.cpu import CPU
from cv_x_if import CvXIf
from memory_ss.memory_ss import MemorySS
from peripherals.abstractions import PeripheralDomain
from peripherals.base_peripherals_domain import BasePeripheralDomain
from peripherals.user_peripherals_domain import UserPeripheralDomain
from pads.pad_ring import PadRing


class System:
    """
    Generic representation of a generated system.

    Holds the parts shared by every system flavor (X-HEEP, X-ALP, ...):
    bus type, CPU, CORE-V eXtension Interface, memory subsystem, peripheral
    subsystems, pad ring and user-defined extensions. Concrete systems
    (e.g. :class:`XHeep`, :class:`XAlp`) inherit from this class and add
    their specific components and configuration style.

    Peripherals are organized in peripheral subsystems (see
    :class:`PeripheralDomain`): each subsystem is an independent group of
    peripherals with its own address range. Any number of subsystems can be
    added to the system.

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

    def __init__(
        self,
        bus_type: BusType,
    ):
        if not type(bus_type) is BusType:
            raise TypeError(
                f"{type(self).__name__}.bus_type should be of type BusType not {type(bus_type)}"
            )

        self._bus_type: BusType = bus_type

        self._cpu = None
        self._xif: CvXIf = None

        self._memory_ss = None

        self._peripheral_subsystems: List[PeripheralDomain] = []

        self._peripherals: List = []

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
    # Peripheral Subsystems
    # ------------------------------------------------------------

    def get_peripherals(self):
        """
        :return: List of all peripherals configured in the system.
        :rtype: list[Peripheral]
        """
        return [deepcopy(peripheral) for peripheral in self._peripherals]

    def add_peripheral_subsystem(self, subsystem: PeripheralDomain):
        """
        Add a peripheral subsystem to the system. The subsystem should
        already contain all peripherals well configured. When adding a
        subsystem, a deepcopy is made to avoid side effects.

        :param PeripheralDomain subsystem: The subsystem to add.
        :raise TypeError: when subsystem is of incorrect type.
        :raise ValueError: when a subsystem with the same name is already present.
        """
        if not isinstance(subsystem, PeripheralDomain):
            raise TypeError(
                f"{type(self).__name__} peripheral subsystems should be of type PeripheralDomain not {type(subsystem)}"
            )
        if any(
            ss.get_name() == subsystem.get_name() for ss in self._peripheral_subsystems
        ):
            raise ValueError(
                f"A peripheral subsystem named {subsystem.get_name()} is already present in the system"
            )
        self._peripheral_subsystems.append(deepcopy(subsystem))
        for peripheral in subsystem.get_peripherals():
            self._peripherals.append(deepcopy(peripheral))

    def remove_peripheral_subsystem(self, name: str):
        """
        Remove a peripheral subsystem from the system.

        Note: :class:`PeripheralDomain` appends " Peripheral Domain" to the
        name given at construction, so the full name returned by
        `get_name()` must be passed (e.g. "Base Peripheral Domain").

        :param str name: The full name of the subsystem to remove.
        """
        for ss in self._peripheral_subsystems:
            if ss.get_name() == name:
                self._peripheral_subsystems.remove(ss)
                return
        print(f"Warning : Peripheral subsystem {name} is not in the system")

    def get_peripheral_subsystem(self, name: str):
        """
        Returns a deepcopy of the peripheral subsystem with the given name.

        Note: :class:`PeripheralDomain` appends " Peripheral Domain" to the
        name given at construction, so the full name returned by
        `get_name()` must be passed (e.g. "Base Peripheral Domain").

        :param str name: The full name of the subsystem.
        :return: The peripheral subsystem, `None` if not found.
        :rtype: PeripheralDomain
        """
        for ss in self._peripheral_subsystems:
            if ss.get_name() == name:
                return deepcopy(ss)
        return None

    def get_peripheral_subsystems(self):
        """
        Returns a deepcopy of the list of all peripheral subsystems.

        :return: The peripheral subsystems.
        :rtype: list[PeripheralDomain]
        """
        return [deepcopy(ss) for ss in self._peripheral_subsystems]

    def get_available_peripherals(self):
        """
        :return: Peripheral names available for this system flavor.
        :rtype: list[str]
        """
        return list(self.AVAILABLE_PERIPHERALS)

    def get_minimum_peripherals(self):
        """
        :return: Peripheral names that must be present.
        :rtype: list[str]
        """
        return list(self.MINIMUM_PERIPHERALS)

    def get_configured_peripheral_names(self):
        """
        :return: Names of peripherals configured in the system.
        :rtype: list[str]
        """
        names = []
        for ss in self._peripheral_subsystems:
            names.extend(peripheral.get_name() for peripheral in ss.get_peripherals())
        return names

    def get_base_peripheral_domain(self):
        """
        Returns a deepcopy of the base peripheral domain (convenience
        accessor, first subsystem of type BasePeripheralDomain).

        :return: The base peripheral domain, `None` if not present.
        :rtype: BasePeripheralDomain
        """
        for ss in self._peripheral_subsystems:
            if isinstance(ss, BasePeripheralDomain):
                return deepcopy(ss)
        return None

    def get_user_peripheral_domain(self):
        """
        Returns a deepcopy of the user peripheral domain (convenience
        accessor, first subsystem of type UserPeripheralDomain).

        :return: The user peripheral domain, `None` if not present.
        :rtype: UserPeripheralDomain
        """
        for ss in self._peripheral_subsystems:
            if isinstance(ss, UserPeripheralDomain):
                return deepcopy(ss)
        return None

    def are_base_peripherals_configured(self) -> bool:
        """
        :return: `True` if the base peripherals are configured, `False` otherwise.
        :rtype: bool
        """
        return any(
            isinstance(ss, BasePeripheralDomain) for ss in self._peripheral_subsystems
        )

    def are_user_peripherals_configured(self) -> bool:
        """
        :return: `True` if the user peripherals are configured, `False` otherwise.
        :rtype: bool
        """
        return any(
            isinstance(ss, UserPeripheralDomain) for ss in self._peripheral_subsystems
        )

    def are_peripherals_configured(self) -> bool:
        """
        :return: `True` if both base and user peripherals are configured, `False` otherwise.
        :rtype: bool
        """
        return (
            self.are_base_peripherals_configured()
            and self.are_user_peripherals_configured()
        )

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
        every peripheral subsystem.
        """
        if self.memory_ss():
            self.memory_ss().build()
        for ss in self._peripheral_subsystems:
            ss.build()

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

        if not self.memory_ss():
            raise RuntimeError("[MCU-GEN] ERROR: A memory subsystem must be configured")
        self.memory_ss().validate()

        if self.memory_ss().has_il_ram() and (
            self._bus_type not in self.IL_COMPATIBLE_BUS_TYPES
        ):
            raise RuntimeError(
                f"[MCU-GEN] ERROR: This system has a {self._bus_type} bus, one of {self.IL_COMPATIBLE_BUS_TYPES} is required for interleaved memory"
            )

        self._validate_peripheral_availability()

        # Check that each peripheral subsystem is valid
        for ss in self._peripheral_subsystems:
            ss.validate()

        # Check that peripheral subsystems do not overlap
        subsystems_sorted = sorted(
            self._peripheral_subsystems, key=lambda ss: ss.get_start_address()
        )
        for current, next_ss in zip(subsystems_sorted, subsystems_sorted[1:]):
            if current.get_start_address() == next_ss.get_start_address():
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: The peripheral subsystems {current.get_name()} and {next_ss.get_name()} should not start at the same address (current address is {current.get_start_address():#08X})."
                )
            if (
                current.get_start_address() + current.get_length()
                > next_ss.get_start_address()
            ):
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: The peripheral subsystem {current.get_name()} (ends at {current.get_start_address() + current.get_length():#08X}) overflows over {next_ss.get_name()} (starts at {next_ss.get_start_address():#08X})."
                )

        # Check that all subsystems start above the protected low address range
        for ss in self._peripheral_subsystems:
            if ss.get_start_address() < 0x10000:  # from mcu_gen.py
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: Peripheral subsystem start address must be greater than 0x10000, current address of {ss.get_name()} is {ss.get_start_address():#08X}."
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

        available_peripherals = self.get_available_peripherals()
        if available_peripherals:
            unsupported = sorted(
                set(configured_peripherals) - set(available_peripherals)
            )
            if unsupported:
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: Unsupported peripherals for {type(self).__name__}: {', '.join(unsupported)}"
                )

        minimum_peripherals = self.get_minimum_peripherals()
        if minimum_peripherals:
            missing = sorted(set(minimum_peripherals) - set(configured_peripherals))
            if missing:
                raise RuntimeError(
                    f"[MCU-GEN] ERROR: Missing minimum peripherals for {type(self).__name__}: {', '.join(missing)}"
                )
