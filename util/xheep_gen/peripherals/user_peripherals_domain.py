# User Peripherals
from .abstractions import UserPeripheral, PeripheralDomain

from .user_peripherals import PDM2PCM

# User Peripherals Classes


# Domain Class
class UserPeripheralDomain(PeripheralDomain):
    """
    Domain for user peripherals. All user peripherals must be added.

    Start address : 0x30000000
    Length :        0x00100000
    """

    def __init__(self, start_address: int = 0x30000000, length: int = 0x00100000):
        """
        Initialize the user peripheral domain.
        Start address : 0x30000000
        Length :       0x00100000

        At the beginning, there is no base peripheral. All non-added peripherals will be added during build().
        """
        super().__init__(
            name="User",
            start_address=start_address,
            length=length,
        )

    def get_pdm2pcm(self):
        """
        Get the PDM2PCM peripheral. Assumes only one PDM2PCM peripheral is added. If multiple PDM2PCM peripherals are added, only the first added one will be returned.

        :return: The PDM2PCM peripheral.
        """
        for peripheral in self._peripherals:
            if isinstance(peripheral, PDM2PCM):
                return peripheral
        return None

    def add_peripheral(self, peripheral: UserPeripheral):
        """
        Add a peripheral to the domain if it is a UserPeripheral. If not, raise an error.

        :param UserPeripheral peripheral: The peripheral to add.
        """
        if not isinstance(peripheral, UserPeripheral):
            raise ValueError("Peripheral is not a UserPeripheral")
        self._peripherals.append(peripheral)

    def remove_peripheral(self, peripheral: UserPeripheral):
        """
        Remove a peripheral from the domain if it is a UserPeripheral.

        :param UserPeripheral peripheral: The peripheral to remove.
        """
        if peripheral not in self._peripherals:
            print(
                f"Warning : Peripheral {peripheral.get_name()} is not in the domain {self._name}"
            )
        self._peripherals.remove(peripheral)
