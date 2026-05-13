from ..abstractions import BasePeripheral
import math


class DMA(BasePeripheral):
    """
    Direct Memory Access controller for efficient data transfer between memory and peripherals.


    :param int ch_length: The length of each channel in the DMA.
    :param int length: The length of the DMA.
    :param int num_channels: The number of channels in the DMA.
    :param int num_master_ports: The number of master ports in the DMA.
    :param int num_channels_per_master_port: The number of channels per master port in the DMA.
    """

    _name = "dma"

    def __init__(
        self,
        address: int = None,
        length: int = None,
        ch_length: int = 0x100,
        num_channels: int = 0x1,
        num_master_ports: int = 0x1,
        num_channels_per_master_port: int = 0x1,
        fifo_depth: int = 0x4,
        addr_mode: str = "yes",
        subaddr_mode: str = "yes",
        hw_fifo_mode: str = "yes",
        zero_padding: str = "yes",
        is_included: str = "yes",
    ):
        """
        Initialize the DMA peripheral.

        :param int address: The virtual (in peripheral domain) memory address of the dma.
        :param int length: The length of the DMA.
        :param int ch_length: The length of each channel in the DMA.
        :param int num_channels: The number of channels in the DMA.
        :param int num_master_ports: The number of master ports in the DMA.
        :param int num_channels_per_master_port: The number of channels per master port in the DMA.
        """
        super().__init__(address, length)
        self._ch_length = ch_length
        self._num_channels = num_channels
        self._num_master_ports = num_master_ports
        self._num_channels_per_master_port = num_channels_per_master_port
        self._fifo_depth = fifo_depth
        self._addr_mode = 0 if addr_mode == "no" else 1
        self._subaddr_mode = 0 if subaddr_mode == "no" else 1
        self._hw_fifo_mode = 0 if hw_fifo_mode == "no" else 1
        self._zero_padding = 0 if zero_padding == "no" else 1
        self._is_included = 0 if is_included == "no" else 1

    def get_is_included(self):
        """
        Get whether the DMA is included.
        """
        return self._is_included

    def set_ch_length(self, value: int):
        """
        Set the length of each channel in the DMA.
        """
        self._ch_length = value

    def get_ch_length(self):
        """
        Get the length of each channel in the DMA.
        """
        return self._ch_length

    def set_num_channels(self, value: int):
        """
        Set the number of channels in the DMA.
        """
        self._num_channels = value

    def get_num_channels(self):
        """
        Get the number of channels in the DMA.
        """
        return self._num_channels

    def set_num_master_ports(self, value: int):
        """
        Set the number of master ports in the DMA.
        """
        self._num_master_ports = value

    def get_num_master_ports(self):
        """
        Get the number of master ports in the DMA.
        """
        return self._num_master_ports

    def set_num_channels_per_master_port(self, value: int):
        """
        Set the number of channels per master port in the DMA.
        """
        self._num_channels_per_master_port = value

    def get_num_channels_per_master_port(self):
        """
        Get the number of channels per master port in the DMA.
        """
        return self._num_channels_per_master_port

    def get_fifo_depth(self):
        """
        Get the depth of the DMA FIFO.
        """
        return self._fifo_depth

    def set_fifo_depth(self, value: int):
        """
        Set the depth of the DMA FIFO.
        """
        self._fifo_depth = value

    def set_addr_mode(self, value: str):
        """
        Set the address mode of the DMA.
        """
        if value not in ["yes", "no"]:
            raise ValueError("Invalid address mode. Must be 'yes' or 'no'.")

        if value == "yes":
            self._addr_mode = 1
        else:
            self._addr_mode = 0

    def get_addr_mode(self):
        """
        Get the address mode of the DMA.
        """
        return self._addr_mode

    def set_subaddr_mode(self, value: str):
        """
        Set the subaddress mode of the DMA.
        """
        if value not in ["yes", "no"]:
            raise ValueError("Invalid subaddress mode. Must be 'yes' or 'no'.")

        if value == "yes":
            self._subaddr_mode = 1
        else:
            self._subaddr_mode = 0

    def get_subaddr_mode(self):
        """
        Get the subaddress mode of the DMA.
        """
        return self._subaddr_mode

    def set_hw_fifo_mode(self, value: str):
        """
        Set the hardware FIFO mode of the DMA.
        """
        if value not in ["yes", "no"]:
            raise ValueError("Invalid hardware FIFO mode. Must be 'yes' or 'no'.")

        if value == "yes":
            self._hw_fifo_mode = 1
        else:
            self._hw_fifo_mode = 0

    def get_hw_fifo_mode(self):
        """
        Get the hardware FIFO mode of the DMA.
        """
        return self._hw_fifo_mode

    def set_zero_padding(self, value: str):
        """
        Set the zero padding mode of the DMA.
        """
        if value not in ["yes", "no"]:
            raise ValueError("Invalid zero padding mode. Must be 'yes' or 'no'.")

        if value == "yes":
            self._zero_padding = 1
        else:
            self._zero_padding = 0

    def get_zero_padding(self):
        """
        Get the zero padding mode of the DMA.
        """
        return self._zero_padding

    def get_xbar_array(self):
        """
        Get the DMA xbar array.
        """
        if self.get_num_master_ports() > 1:
            # Computation of full_masters_xbars
            temp_full_masters_xbars = math.floor(
                self.get_num_channels() / self.get_num_channels_per_master_port()
            )
            if (
                temp_full_masters_xbars < self.get_num_master_ports()
                and temp_full_masters_xbars * self.get_num_channels_per_master_port()
                == self.get_num_channels()
            ):
                full_masters_xbars = temp_full_masters_xbars - 1
            else:
                full_masters_xbars = temp_full_masters_xbars
            last = self.get_num_channels_per_master_port() * full_masters_xbars

            # Array initialization
            array_xbar_gen = [0] * self.get_num_master_ports()

            # Computation of the number of xbar channels for each master port
            for i in range(self.get_num_master_ports()):
                if i < full_masters_xbars:
                    array_xbar_gen[i] = self.get_num_channels_per_master_port()
                else:
                    array_xbar_gen[i] = min(
                        self.get_num_channels() - last,
                        self.get_num_channels()
                        - last
                        - (self.get_num_master_ports() - i - 1),
                    )
                    last = last + array_xbar_gen[i]

            if sum(array_xbar_gen) != self.get_num_channels() or 0 in array_xbar_gen:
                exit("Error in the DMA xbar generation: wrong parameters")

            return ", ".join(map(str, array_xbar_gen))
        else:
            if self.get_num_channels_per_master_port() != self.get_num_channels():
                exit(
                    "With 1 master port, the number of DMA channels per master port has to be equal to the number of DMA channels"
                )
            return "default: 1"

    def validate(self):
        """
        Checks if the DMA peripheral is valid (number of channels between 0 and 256, master ports
        between 0 and number of channels, channels per master port between 0 and number of channels,
        number of channels per master port is not 0 if number of channels is not 1).
        """
        if self.get_num_channels() > 256 or self.get_num_channels() == 0:
            raise RuntimeError(
                "[MCU-GEN - DMA] ERROR: Number of DMA channels has to be between 0 and 256, excluded"
            )

        if (
            self.get_num_master_ports() > self.get_num_channels()
            or self.get_num_master_ports() == 0
        ):
            raise RuntimeError(
                f"[MCU-GEN - DMA] ERROR: Number of DMA master ports has to be between 0 and "
                f"{self.get_num_channels()}, 0 excluded"
            )

        if (
            self.get_num_channels_per_master_port() > self.get_num_channels()
            and self.get_num_channels() != 1
        ) or self.get_num_channels_per_master_port() == 0:
            raise RuntimeError(
                f"[MCU-GEN - DMA] ERROR: Number of DMA channels per system bus master ports has to be between 0 and "
                f"{self.get_num_channels()}, 0 excluded"
            )
