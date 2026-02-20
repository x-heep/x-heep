from ..abstractions import BasePeripheral


class SPI_memio(BasePeripheral):
    """
    Memory-mapped IO interface for SPI communication.

    Default length : 32KB
    """

    _name = "spi_memio"
    _length: int = 0x00008000
