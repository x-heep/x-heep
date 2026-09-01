from copy import deepcopy

from bus import Bus
from cpu.cpu import CPU
from memory_ss.memory_ss import MemorySS
from peripherals.abstractions import PeripheralDomain
from system import System


class XAlp(System):
    """
    Represents the whole X-ALP system.

    An instance of this class is passed to the mako templates.

    Inherits the generic system infrastructure from :class:`System`. Unlike
    :class:`XHeep`, the configuration is bus-centric: the system starts
    from the bus (received at construction), and every component (CPU,
    memory subsystem, peripheral subsystems) is connected to it
    independently. Each peripheral subsystem is an independent bus node and
    can be grouped with others in power and clock-gating domains (see
    :class:`PeripheralDomain`).

    :param Bus bus: The bus of the system.
    :raise TypeError: when parameters are of incorrect type.
    """

    AVAILABLE_CPUS = ["cva6"]
    """Constant list of CPU names available for X-ALP."""

    AVAILABLE_PERIPHERALS = [
        "bootrom",
        "ext_peripheral",
        "fast_intr_ctrl",
        "pad_control",
        "soc_ctrl",
        "uart",
    ]
    """Constant list of peripheral names available for X-ALP."""

    MINIMUM_PERIPHERALS = [
        "soc_ctrl",
        "bootrom",
    ]
    """Constant list of peripheral names that must be present in X-ALP."""

    def __init__(self, bus: Bus):
        if not isinstance(bus, Bus):
            raise TypeError(f"XAlp.bus should be of type Bus not {type(bus)}")
        super().__init__(bus.bus_type())
        self._bus = bus

    def bus(self) -> Bus:
        """
        :return: the bus of the system
        :rtype: Bus
        """
        return self._bus

    def build(self):
        """
        Makes the system and its bus address map ready to be used.
        """
        super().build()
        self._bus.generate_address_map()
        self._bus.build_address_map()

    def get_configured_peripheral_names(self):
        """
        :return: Names of peripherals configured in subsystems or directly on the bus.
        :rtype: list[str]
        """
        names = super().get_configured_peripheral_names()
        names.extend(
            peripheral.get_name() for peripheral in self._bus.get_all_peripherals()
        )
        return names

    # ------------------------------------------------------------
    # Bus connections (bus-centric naming)
    # ------------------------------------------------------------

    def connect_cpu(self, cpu: CPU):
        """
        Connects the CPU to the bus.

        :param CPU cpu: The CPU to connect.
        :raise TypeError: when cpu is of incorrect type.
        """
        self.set_cpu(cpu)

    def connect_memory_ss(self, memory_ss: MemorySS):
        """
        Connects the memory subsystem to the bus.

        :param MemorySS memory_ss: The memory subsystem to connect.
        :raise TypeError: when memory_ss is of incorrect type.
        """
        self.set_memory_ss(memory_ss)

    def connect_peripheral_subsystem(self, subsystem: PeripheralDomain):
        """
        Connects a peripheral subsystem to the bus. The subsystem should
        already contain all peripherals well configured. When connecting a
        subsystem, a deepcopy is made to avoid side effects.

        Any number of subsystems can be connected, each one is an independent
        bus node and can be grouped with others in power / clock-gating
        domains.

        :param PeripheralDomain subsystem: The subsystem to connect.
        :raise TypeError: when subsystem is of incorrect type.
        :raise ValueError: when a subsystem with the same name is already connected.
        """
        self.add_peripheral_subsystem(subsystem)

    def disconnect_peripheral_subsystem(self, name: str):
        """
        Disconnects a peripheral subsystem from the bus.

        Note: :class:`PeripheralDomain` appends " Peripheral Domain" to the
        name given at construction, so the full name returned by
        `get_name()` must be passed (e.g. "Base Peripheral Domain").

        :param str name: The full name of the subsystem to disconnect.
        """
        self.remove_peripheral_subsystem(name)

    # ------------------------------------------------------------
    # Power / Clock-Gating Domains
    # ------------------------------------------------------------

    def get_power_domains(self):
        """
        Groups the connected peripheral subsystems by power domain.

        :return: A dictionary mapping each power domain name to the list of subsystems belonging to it. Always-on subsystems (no power domain) are not included.
        :rtype: dict[str, list[PeripheralDomain]]
        """
        domains = {}
        for ss in self._peripheral_subsystems:
            if ss.has_power_domain():
                domains.setdefault(ss.get_power_domain(), []).append(deepcopy(ss))
        return domains

    def get_always_on_subsystems(self):
        """
        :return: A deepcopy of the list of always-on peripheral subsystems (no switchable power domain).
        :rtype: list[PeripheralDomain]
        """
        return [deepcopy(ss) for ss in self._peripheral_subsystems if ss.is_always_on()]

    def get_clock_gated_subsystems(self):
        """
        :return: A deepcopy of the list of peripheral subsystems that support clock gating.
        :rtype: list[PeripheralDomain]
        """
        return [
            deepcopy(ss) for ss in self._peripheral_subsystems if ss.has_clock_gating()
        ]
