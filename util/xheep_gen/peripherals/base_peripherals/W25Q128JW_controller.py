from bus_type import BusType
from ..abstractions import BasePeripheral


class W25Q128JW_Controller(BasePeripheral):
    """
    W25Q128JW controller.
    """

    _name = "w25q128jw_controller"

    def __init__(self, address: int = None, length: int = None, cache: str = "no"):
        """
        Initialize the W25Q128JW controller peripheral.

        :param int address: The virtual (in peripheral domain) memory address of the W25Q128JW controller.
        :param int length: The length of the W25Q128JW controller.
        :param str cache: Whether the cache is enabled. Can be "no" or "yes". Default is "no".
        """
        super().__init__(address, length)

        self._cache = 0 if cache == "no" else 1

    def get_cache(self):
        """
        Get whether the cache is enabled.
        """

        return self._cache

    def validate(self, bus_type: BusType = None):
        """
        Validate the W25Q128JW controller peripheral. Cache needs NtoM bus type to be enabled.

        :param BusType bus_type: The bus type of the peripheral domain.
        """
        if self._cache and bus_type != BusType.NtoM:
            raise ValueError(
                "[MCU-GEN - W25Q128JW_Controller] ERROR: Cache parameter can only be enabled for NtoM bus type"
            )
