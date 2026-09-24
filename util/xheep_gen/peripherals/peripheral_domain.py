from typing import List, Optional
from peripherals.abstractions import Peripheral
from peripherals.base_peripherals import DMA, Power_manager, W25Q128JW_Controller
from peripherals.user_peripherals import PDM2PCM
from copy import deepcopy


class PeripheralDomain:
    """
    A peripheral domain: a group of peripherals connected to the system bus as
    an independent node. Each domain can be assigned to a power domain and can
    support clock gating, so that domains can be grouped and switched off or
    clock gated together.

    :param str name: The name of the peripheral domain. It must match the name of the address map region the domain is mapped to.
    :param str power_domain: The name of the power domain the domain belongs to. `None` means always-on. Domains sharing the same power domain name are switched on/off together.
    :param bool clock_gating: `True` if the domain supports clock gating.
    :param list[Peripheral] peripherals: The list of peripherals in the domain. There can be more than one instance of the same peripheral.
    """

    _name: str
    _start_address: Optional[int]
    _length: Optional[int]
    _power_domain: Optional[str]
    _clock_gating: bool
    _peripherals: List[
        Peripheral
    ]  # type has to be precised for filtering in validation

    def __init__(
        self,
        name: Optional[str] = None,
        power_domain: Optional[str] = None,
        clock_gating: bool = False,
        peripherals: Optional[List[Peripheral]] = None,
    ):
        """
        Initialize the peripheral domain.

        :param str name: The name of the peripheral domain. It must match the name of the address map region the domain is mapped to: the system takes the start address and the length from that region at build time.
        :param str power_domain: The name of the power domain the domain belongs to. `None` means always-on.
        :param bool clock_gating: `True` if the domain supports clock gating.
        :param list[Peripheral] peripherals: Optional initial list of peripherals.
        """
        if power_domain is not None and type(power_domain) is not str:
            raise TypeError(
                f"PeripheralDomain.power_domain should be of type str not {type(power_domain)}"
            )
        if type(clock_gating) is not bool:
            raise TypeError(
                f"PeripheralDomain.clock_gating should be of type bool not {type(clock_gating)}"
            )
        self._name = name
        self._start_address = None
        self._length = None
        self._power_domain = power_domain
        self._clock_gating = clock_gating
        self._peripherals = []
        if peripherals is not None:
            if type(peripherals) is not list:
                raise TypeError("peripherals should be of type list")
            for peripheral in peripherals:
                self.add_peripheral(peripheral)

    def get_name(self):
        """
        :return: The name of the peripheral domain.
        :rtype: str
        """
        return self._name

    def add_peripheral(self, peripheral: Peripheral):
        """
        Add a peripheral to the domain. The peripheral should be fully
        configured when added. If the peripheral has no offset, it will be
        automatically computed during build.

        :param Peripheral peripheral: The peripheral to add.
        :raise ValueError: when peripheral is not a Peripheral.
        """
        if not isinstance(peripheral, Peripheral):
            raise ValueError("Peripheral is not a Peripheral")
        self._peripherals.append(peripheral)

    def remove_peripheral(self, peripheral: Peripheral):
        """
        Remove a peripheral from the domain.

        :param Peripheral peripheral: The peripheral to remove.
        """
        if peripheral not in self._peripherals:
            print(
                f"Warning : Peripheral {peripheral.get_name()} is not in the domain {self._name}"
            )
            return
        self._peripherals.remove(peripheral)

    # ------------------------------------------------------------
    # Power / Clock-Gating Domain
    # ------------------------------------------------------------

    def set_power_domain(self, power_domain: Optional[str]):
        """
        Assign the domain to a power domain. Domains sharing the same power
        domain name are switched on/off together.

        :param str power_domain: The name of the power domain. `None` means always-on.
        :raise TypeError: when power_domain is of incorrect type.
        """
        if power_domain is not None and type(power_domain) is not str:
            raise TypeError(
                f"PeripheralDomain.power_domain should be of type str not {type(power_domain)}"
            )
        self._power_domain = power_domain

    def get_power_domain(self):
        """
        :return: The name of the power domain the domain belongs to, `None` if always-on.
        :rtype: str
        """
        return self._power_domain

    def has_power_domain(self) -> bool:
        """
        :return: `True` if the domain belongs to a switchable power domain, `False` if always-on.
        :rtype: bool
        """
        return self._power_domain is not None

    def is_always_on(self) -> bool:
        """
        :return: `True` if the domain is always-on (no switchable power domain).
        :rtype: bool
        """
        return self._power_domain is None

    def set_clock_gating(self, clock_gating: bool):
        """
        Enable or disable clock gating support for the domain.

        :param bool clock_gating: `True` if the domain supports clock gating.
        :raise TypeError: when clock_gating is of incorrect type.
        """
        if type(clock_gating) is not bool:
            raise TypeError(
                f"PeripheralDomain.clock_gating should be of type bool not {type(clock_gating)}"
            )
        self._clock_gating = clock_gating

    def has_clock_gating(self) -> bool:
        """
        :return: `True` if the domain supports clock gating.
        :rtype: bool
        """
        return self._clock_gating

    def get_start_address(self):
        """
        :return: The start address of the peripheral domain, `None` before the system resolved it from the address map.
        :rtype: int
        """
        return self._start_address

    def get_length(self):
        """
        :return: The length of the peripheral domain, `None` before the system resolved it from the address map.
        :rtype: int
        """
        return self._length

    def set_start_address(self, start_address: int):
        """
        :param int start_address: The start address of the peripheral domain.
        """
        self._start_address = start_address

    def set_length(self, length: int):
        """
        :param int length: The length of the peripheral domain in bytes.
        """
        self._length = length

    def get_peripherals(self):
        """
        :return: A copy of the list of peripherals in the domain.
        :rtype: list[Peripheral]
        """
        return (
            []
            if self._peripherals is None or len(self._peripherals) == 0
            else [deepcopy(p) for p in self._peripherals]
        )

    def get_peripheral(self, peripheral_name: str):
        """
        Get a peripheral by name. If there are multiple instances of the same peripheral, the first one is returned.

        :param str peripheral_name: The name of the peripheral to get (case sensitive).
        :return: The peripheral with the given name.
        :rtype: Peripheral
        :raise ValueError: when no peripheral with the given name is found.
        """
        for p in self._peripherals:
            if p.get_name() == peripheral_name:
                return deepcopy(p)
        raise ValueError(
            f"[MCU-GEN - PeripheralDomain] ERROR: No peripheral with name {peripheral_name} found in domain {self._name}"
        )

    def contains_peripheral(self, peripheral_name: str):
        """
        Check if the peripheral domain contains a peripheral with the given name.

        :param str peripheral_name: The name of the peripheral to check (case sensitive).
        :return: True if the peripheral domain contains a peripheral with the given name, False otherwise.
        :rtype: bool
        """
        return any(p.get_name() == peripheral_name for p in self._peripherals)

    def _resolve_address_length(self, address_length: Optional[int]) -> int:
        """
        Return the address space length to use: the one given by the caller
        or, when omitted, the one the system resolved from the address map
        region carrying the domain name.

        :param int address_length: The length given by the caller, or `None`.
        :return: The length of the address space of the peripheral domain.
        :rtype: int
        :raise RuntimeError: when no length is available.
        """
        if address_length is None:
            address_length = self._length
        if address_length is None:
            raise RuntimeError(
                f"[MCU-GEN - PeripheralDomain] ERROR: No address space length available for {self._name}"
            )
        return address_length

    def build(self, address_length: Optional[int] = None):
        """
        Build the peripheral domain. This function will compute the offset of the peripherals that have no offset.

        :param int address_length: The length of the address space of the peripheral domain. If `None`, the length given at construction is used.
        """
        address_length = self._resolve_address_length(address_length)

        # Setup

        # List of peripherals without address, sorted by length in descending order. Original index is kept to update the peripheral with the offset after placement.
        peripherals_without_address = [
            (i, p) for i, p in enumerate(self._peripherals) if p.get_address() is None
        ]
        peripherals_without_address.sort(
            key=lambda tuple: tuple[1].get_length(), reverse=True
        )

        # List of peripherals with address, sorted by address. Original index is kept to update the peripheral with the offset after placement.
        peripherals_with_address = [
            (i, p)
            for i, p in enumerate(self._peripherals)
            if p is not None and p.get_address() is not None
        ]
        peripherals_with_address.sort(key=lambda tuple: tuple[1].get_address())

        # List of free spaces of intervals of free memory space in the domain. In the beggining, there is only one free space, the whole domain.
        free_space = [[0, address_length]]

        # Number of peripherals with address
        num_peripherals_with_address = (
            0 if peripherals_with_address == None else len(peripherals_with_address)
        )

        # Number of peripherals without address
        num_peripherals_without_address = (
            0
            if peripherals_without_address == None
            else len(peripherals_without_address)
        )

        # Creating the list of intervals of free space

        # Works because peripherals_with_address is sorted by address
        # Splits the last free space into two new lists, one before the peripheral and one after
        for i in range(num_peripherals_with_address):
            # Removes last free space to split it
            last_free_space = free_space[-1]
            free_space.pop()
            current_peripheral = peripherals_with_address[i][1]

            # Checks if the peripheral domain is in free space
            if current_peripheral.get_address() < last_free_space[0]:
                if i == 0:
                    raise ValueError(
                        f"Peripheral {current_peripheral.get_name()} has an address that starts before the first free space ({current_peripheral.get_name()} starts at {hex(current_peripheral.get_address())} but first free space starts at {hex(last_free_space[0])})"
                    )
                else:
                    raise ValueError(
                        f"Peripheral {current_peripheral.get_name()} has an address that starts in {peripherals_with_address[i-1][1].get_name()} domain ({current_peripheral.get_name()} starts at {hex(current_peripheral.get_address())} but {peripherals_with_address[i-1][1].get_name()} ends at {hex(last_free_space[0])}"
                    )

            if (
                current_peripheral.get_address() + current_peripheral.get_length()
            ) > last_free_space[1]:
                raise ValueError(
                    f"Peripheral {current_peripheral.get_name()} has an address that ends after the last free space ({current_peripheral.get_name()} ends at {hex(current_peripheral.get_address() + current_peripheral.get_length())} but last free space ends at {hex(last_free_space[1])})"
                )

            # If the peripheral starts after the last free space, add it to the free space before the peripheral
            if last_free_space[0] < current_peripheral.get_address():
                free_space.append(
                    [last_free_space[0], current_peripheral.get_address()]
                )

            # If the peripheral ends before the last free space, add it to the free space after the peripheral
            if (
                current_peripheral.get_address() + current_peripheral.get_length()
            ) < last_free_space[1]:
                free_space.append(
                    [
                        current_peripheral.get_address()
                        + current_peripheral.get_length(),
                        last_free_space[1],
                    ]
                )

        # Placing peripherals in free spaces

        # Place peripherals where in the first free space where they fit, works because peripherals_without_address is sorted by length in descending order
        offsets = (
            {}
        )  # Will contain the offsets of the peripherals, and then update the peripherals with the offsets if they all fit

        for i in range(num_peripherals_without_address):
            fit = False  # Check if the peripheral fits in the free space
            current_peripheral = peripherals_without_address[i][1]
            for j in range(len(free_space)):
                if (
                    current_peripheral.get_length()
                    <= free_space[j][1] - free_space[j][0]
                ):
                    offsets[peripherals_without_address[i][0]] = free_space[j][
                        0
                    ]  # Since there can be multiple instances of the same peripheral, we must map indexes from self._peripherals instead of peripheral names (two peripherals can have the same name)

                    # Either remove space if the peripheral exactly fits the space, or shrinks the space
                    if (
                        free_space[j][0] + current_peripheral.get_length()
                        == free_space[j][1]
                    ):
                        free_space.pop(j)
                    else:
                        free_space[j][0] += current_peripheral.get_length()

                    # Ends search for free space
                    fit = True
                    break
            if not fit:
                raise ValueError(
                    f"Could not find a free space large enough for peripheral {current_peripheral.get_name()} with length {hex(current_peripheral.get_length())}"
                )

        # Setting peripherals addresses if there is enough space
        for idx, _ in peripherals_without_address:
            self._peripherals[idx].set_address(offsets[idx])

    def validate(self, address_length: Optional[int] = None):
        """
        Validate the peripheral domain.

        Checks if the peripherals do not overlap and if the peripheral domain is within the bounds.

        :param int address_length: The length of the address space of the peripheral domain. If `None`, the length given at construction is used.
        :raise RuntimeError: when peripherals overlap or are out of the domain.
        """
        address_length = self._resolve_address_length(address_length)

        # Check if the peripherals do not overlap
        if self._peripherals is None or len(self._peripherals) == 0:
            print(
                f"[MCU-GEN - PeripheralDomain] WARNING: No peripherals in {self._name}"
            )
            return

        peripherals_sorted = sorted(
            filter(lambda x: x != None, self._peripherals),
            key=lambda x: x.get_address(),
        )  # Filter out None values and sort by offset in growing order

        if len(peripherals_sorted) == 0:
            print(
                f"[MCU-GEN - PeripheralDomain] WARNING: No peripherals in {self._name}"
            )
            return

        # Check if every peripheral does not overlap with the next one (works because peripherals_sorted is sorted by address)
        for i in range(len(peripherals_sorted) - 1):
            if (
                peripherals_sorted[i].get_address() + peripherals_sorted[i].get_length()
                > peripherals_sorted[i + 1].get_address()
            ):
                raise RuntimeError(
                    f"[MCU-GEN - PeripheralDomain] ERROR: The peripheral {peripherals_sorted[i].get_name()} overflows over the domain (starts at {peripherals_sorted[i].get_address():#08X} and ends at {peripherals_sorted[i].get_address() + peripherals_sorted[i].get_length():#08X}, peripheral {peripherals_sorted[i+1].get_name()} starts at {peripherals_sorted[i+1].get_address():#08X})."
                )
            if peripherals_sorted[i].get_address() >= address_length:
                raise RuntimeError(
                    f"[MCU-GEN - PeripheralDomain] ERROR: The peripheral {peripherals_sorted[i].get_name()} is out of the domain (starts at {peripherals_sorted[i].get_address():#08X}, domain ends at {address_length:#08X})."
                )

        # Check if the last peripheral is out of the domain
        if (
            peripherals_sorted[-1].get_address() + peripherals_sorted[-1].get_length()
            > address_length
        ):
            raise RuntimeError(
                f"[MCU-GEN - PeripheralDomain] ERROR: The peripheral {peripherals_sorted[-1].get_name()} is out of the domain (starts at {peripherals_sorted[-1].get_address():#08X}, domain ends at {address_length:#08X})."
            )
        if peripherals_sorted[-1].get_address() >= address_length:
            raise RuntimeError(
                f"[MCU-GEN - PeripheralDomain] ERROR: The peripheral {peripherals_sorted[-1].get_name()} is out of the domain (starts at {peripherals_sorted[-1].get_address():#08X}, domain ends at {address_length:#08X})."
            )
