from ..abstractions import UserPeripheral


class PDM2PCM(UserPeripheral):
    """
    Pulse-density modulation to pulse-code modulation converter.

    :param bool cic_only: True to enable CIC only mode, False to enable other modes. By default, CIC only mode is enabled.

    """

    _name = "pdm2pcm"

    def __init__(self, address: int = None, length: int = None, cic_only: bool = True):
        """
        Initialize the PDM2PCM peripheral.

        :param int address: The virtual (in peripheral domain) memory address of the pdm2pcm.
        :param int length: The length of the pdm2pcm.
        :param bool cic_only: True to enable CIC only mode, False to enable other modes. By default, CIC only mode is enabled.
        """
        super().__init__(address, length)
        self._cic_only = cic_only

    def get_cic_mode(self):
        """
        Get the CIC mode of the PDM2PCM peripheral.

        :return: True if CIC only mode is enabled, False otherwise.
        """
        return self._cic_only
