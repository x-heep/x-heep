import warnings

from bus_type import BusType
from copy import deepcopy
from typing import List, Optional

from peripherals.abstractions import Peripheral, PeripheralDomain


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


class AxiMaster:
    """
    An AXI master endpoint on the bus (e.g. CPU, debug module, external master).

    Masters carry no address; they are enumerated to assign crossbar master
    indices.

    :param str name: The name of the master.
    """

    def __init__(self, name: str):
        if type(name) is not str or name == "":
            raise ValueError("AxiMaster name should be a non-empty string")
        self._name = name

    def get_name(self) -> str:
        """:return: the name of the master."""
        return self._name


class BusSlave:
    """
    A non-peripheral AXI slave window on the bus (e.g. MEM, DEBUG_MODULE,
    EXT_SLAVE).

    Exposes the same name/address accessors as peripherals and peripheral
    subsystems so the address generator can treat every AXI slave uniformly.

    :param str name: The name of the slave window.
    :param int base: The start address of the window.
    :param int size: The size of the window in bytes.
    """

    def __init__(self, name: str, base=None, size=None):
        if type(name) is not str or name == "":
            raise ValueError("BusSlave name should be a non-empty string")
        if base is not None and type(base) is not int:
            raise ValueError("BusSlave base should be a positive integer")
        if size is not None and type(size) is not int:
            raise ValueError("BusSlave size should be a strictly positive integer")
        self._name = name
        self._start_address = base
        self._length = size

    def get_name(self) -> str:
        """:return: the name of the slave window."""
        return self._name

    def get_start_address(self) -> int:
        """:return: the start address of the slave window."""
        return self._start_address

    def get_length(self) -> int:
        """:return: the size of the slave window in bytes."""
        return self._length

    def set_start_address(self, base: int):
        """:param int base: The start address of the window."""
        self._start_address = base

    def set_length(self, size: int):
        """:param int size: The size of the window in bytes."""
        self._length = size


#: Default window size used when an AXI slave is added without an explicit size.
DEFAULT_SLAVE_SIZE = 0x1000


class Bus:
    """
    Represents a system bus.

    In bus-centric systems (see :class:`XAlp`) the bus is created first and
    every component (CPU, memory subsystem, peripheral subsystems) is then
    connected to it.

    :param BusType bus_type: The type of the bus.
    :raise TypeError: when parameters are of incorrect type.
    """

    def __init__(
        self,
        bus_type: Optional[BusType] = None,
        peripherals: Optional[List[Peripheral]] = None,
        domains: Optional[List[PeripheralDomain]] = None,
    ):
        if bus_type is not None and not type(bus_type) is BusType:
            raise TypeError(
                f"Bus.bus_type should be of type BusType not {type(bus_type)}"
            )
        self._bus_type = bus_type
        self._peripherals = []
        self._domains = []
        self._masters: List[AxiMaster] = []
        self._slaves: list = []

        if domains is not None:
            if peripherals is not None:
                raise ValueError(
                    "Bus should be configured with either peripherals or domains, not both"
                )
            self.set_domains(domains)
        elif peripherals is not None:
            self._set_peripherals_or_domains(peripherals)

    def bus_type(self) -> Optional[BusType]:
        """
        :return: the type of the bus
        :rtype: BusType
        """
        return self._bus_type

    # ------------------------------------------------------------
    # Peripherals / Domains
    # ------------------------------------------------------------

    def _set_peripherals_or_domains(self, entries):
        if type(entries) is not list:
            raise TypeError("Bus peripherals or domains should be of type list")
        if all(isinstance(entry, PeripheralDomain) for entry in entries):
            self.set_domains(entries)
        elif all(isinstance(entry, Peripheral) for entry in entries):
            self.set_peripherals(entries)
        else:
            raise TypeError(
                "Bus entries should be either all Peripheral instances or all PeripheralDomain instances"
            )

    def set_peripherals(self, peripherals: List[Peripheral]):
        """
        Configure the bus with a flat list of peripherals. This represents a
        single bus address space.

        :param list[Peripheral] peripherals: Peripherals connected to the bus.
        """
        if type(peripherals) is not list:
            raise TypeError("Bus.peripherals should be of type list")
        if not all(isinstance(peripheral, Peripheral) for peripheral in peripherals):
            raise TypeError("Bus.peripherals should contain only Peripheral objects")
        self._peripherals = [deepcopy(peripheral) for peripheral in peripherals]
        self._domains = []

    def add_peripheral(self, peripheral: Peripheral):
        """
        Add a peripheral to a flat bus address space.
        """
        if not isinstance(peripheral, Peripheral):
            raise TypeError("Bus peripheral should be of type Peripheral")
        if self._domains:
            raise ValueError(
                "Cannot add a flat peripheral to a bus configured with domains"
            )
        self._peripherals.append(deepcopy(peripheral))

    def get_peripherals(self):
        """
        :return: A copy of the flat peripheral list.
        :rtype: list[Peripheral]
        """
        return [deepcopy(peripheral) for peripheral in self._peripherals]

    def set_domains(self, domains: List[PeripheralDomain]):
        """
        Configure the bus with a list of peripheral domains.

        :param list[PeripheralDomain] domains: Peripheral domains connected to the bus.
        """
        if type(domains) is not list:
            raise TypeError("Bus.domains should be of type list")
        if not all(isinstance(domain, PeripheralDomain) for domain in domains):
            raise TypeError("Bus.domains should contain only PeripheralDomain objects")
        self._domains = [deepcopy(domain) for domain in domains]
        self._peripherals = []

    def add_domain(self, domain: PeripheralDomain):
        """
        Add a peripheral domain to the bus.
        """
        if not isinstance(domain, PeripheralDomain):
            raise TypeError("Bus domain should be of type PeripheralDomain")
        if self._peripherals:
            raise ValueError("Cannot add a domain to a bus configured with peripherals")
        self._domains.append(deepcopy(domain))

    def get_domains(self):
        """
        :return: A copy of the peripheral domains connected to the bus.
        :rtype: list[PeripheralDomain]
        """
        return [deepcopy(domain) for domain in self._domains]

    def get_all_peripherals(self):
        """
        :return: A copy of all peripherals connected directly or through domains.
        :rtype: list[Peripheral]
        """
        if self._domains:
            peripherals = []
            for domain in self._domains:
                peripherals.extend(domain.get_peripherals())
        else:
            peripherals = self.get_peripherals()
        # Peripherals living inside AXI-slave peripheral subsystems.
        for slave in self._slaves:
            if isinstance(slave, PeripheralDomain):
                peripherals.extend(slave.get_peripherals())
        return peripherals

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
        Add an AXI slave to the bus. A slave is either a :class:`BusSlave`
        (a plain address window such as MEM / DEBUG_MODULE / EXT_SLAVE) or a
        :class:`PeripheralDomain` (a peripheral subsystem whose register-interface
        peripherals become REG slaves nested in its window).

        :param slave: The slave node to add.
        :raise TypeError: when slave is of incorrect type.
        """
        if not isinstance(slave, (BusSlave, PeripheralDomain)):
            raise TypeError(
                "Bus slave should be a BusSlave or a PeripheralDomain (peripheral subsystem)"
            )
        if slave.get_length() is None:
            warnings.warn(
                f"The length of {slave.get_name()} is not set, a default value of "
                f"{hex(DEFAULT_SLAVE_SIZE)} will be used."
            )
        self._slaves.append(slave)

    def get_slaves(self):
        """:return: The ordered list of AXI slave nodes."""
        return list(self._slaves)

    def build_address_map(self, start_address: int = 0):
        """
        Build the AXI slave windows and their nested register sub-buses, then
        validate that the AXI slave windows do not overlap.

        Slaves are placed in the order they were added. A slave with no explicit
        size gets :data:`DEFAULT_SLAVE_SIZE`. A slave with no explicit base is
        placed at the next free address after the previous slave (starting from
        ``start_address``); a slave with an explicit base must not start before
        that next free address. Peripheral subsystem slaves are then built so
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
        slaves = sorted(self._slaves, key=lambda s: s.get_start_address())
        for current, nxt in zip(slaves, slaves[1:]):
            current_end = current.get_start_address() + current.get_length()
            if current_end > nxt.get_start_address():
                raise ValueError(
                    f"AXI slave {current.get_name()} (ends at {hex(current_end)}) "
                    f"overlaps {nxt.get_name()} (starts at {hex(nxt.get_start_address())})"
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
        :return: Ordered AXI slave windows as ``{name, macro, idx, base, size, end}``.
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

    def get_reg_slaves(self):
        """
        :return: Register-interface slaves nested in peripheral subsystem AXI
            windows, as ``{name, macro, idx, base, size, end}`` with absolute
            addresses (subsystem base + peripheral offset).
        :rtype: list[dict]
        """
        result = []
        idx = 0
        for slave in self._slaves:
            if not isinstance(slave, PeripheralDomain):
                continue
            sub_base = slave.get_start_address()
            for peripheral in slave.get_peripherals():
                if not peripheral.has_reg_if_ports():
                    continue
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

    # ------------------------------------------------------------
    # Address Map
    # ------------------------------------------------------------

    def generate_address_map(self, start_address: int = 0):
        """
        Automatically assign missing peripheral addresses and return the bus
        address map.

        Flat peripherals are placed sequentially in the bus address space.
        Domain-backed peripherals are placed by each domain and reported with
        absolute addresses (`domain.start_address + peripheral.offset`).

        :param int start_address: First address used for flat peripherals.
        :return: Address map entries.
        :rtype: list[dict]
        """
        if type(start_address) is not int or start_address < 0:
            raise ValueError("start_address should be a positive integer")

        if self._domains:
            for domain in self._domains:
                domain.build()
            return self.get_address_map()

        next_address = start_address
        for peripheral in self._peripherals:
            address = peripheral.get_address()
            if address is None:
                peripheral.set_address(next_address)
                address = next_address
            if address < next_address:
                raise ValueError(
                    f"Peripheral {peripheral.get_name()} starts at {hex(address)}, before the next free bus address {hex(next_address)}"
                )
            next_address = address + peripheral.get_size_bytes()

        self._validate_flat_address_map()
        return self.get_address_map()

    def get_address_map(self):
        """
        :return: The current address map.
        :rtype: list[dict]
        """
        if self._domains:
            address_map = []
            for domain in self._domains:
                for peripheral in domain.get_peripherals():
                    if peripheral.get_address() is None:
                        continue
                    address_map.append(
                        {
                            "domain": domain.get_name(),
                            "name": peripheral.get_name(),
                            "address": domain.get_start_address()
                            + peripheral.get_address(),
                            "offset": peripheral.get_address(),
                            "size": peripheral.get_size_bytes(),
                        }
                    )
            return sorted(address_map, key=lambda entry: entry["address"])

        return sorted(
            [
                {
                    "domain": None,
                    "name": peripheral.get_name(),
                    "address": peripheral.get_address(),
                    "offset": peripheral.get_address(),
                    "size": peripheral.get_size_bytes(),
                }
                for peripheral in self._peripherals
                if peripheral.get_address() is not None
            ],
            key=lambda entry: entry["address"],
        )

    def _validate_flat_address_map(self):
        peripherals = sorted(
            self._peripherals,
            key=lambda peripheral: peripheral.get_address(),
        )
        for current, next_peripheral in zip(peripherals, peripherals[1:]):
            current_end = current.get_address() + current.get_size_bytes()
            if current_end > next_peripheral.get_address():
                raise ValueError(
                    f"Peripheral {current.get_name()} overflows over {next_peripheral.get_name()}"
                )
