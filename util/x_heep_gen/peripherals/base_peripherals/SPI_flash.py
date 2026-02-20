from ..abstractions import BasePeripheral


class SPI_flash(BasePeripheral):
    """
    Interface for external SPI flash memory access.

    Default length : 32KB
    """

    _name = "spi_flash"
    _length: int = 0x00008000
