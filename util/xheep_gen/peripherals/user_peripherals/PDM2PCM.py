from ..abstractions import UserPeripheral


class PDM2PCM(UserPeripheral):
    """
    Pulse-density modulation to pulse-code modulation converter.

    :param bool cic_only: True to enable CIC only mode, False to enable other modes. By default, CIC only mode is enabled.

    """

    _name = "pdm2pcm"

    def __init__(
        self,
        address: int = None,
        length: int = None,
        cic_only: bool = True,
        has_master_ports: bool = False,
        num_master_ports: int = None,
        has_slave_ports: bool = False,
        num_slave_ports: int = None,
        has_reg_if_ports: bool = True,
        num_reg_if_ports: int = None,
    ):
        """
        Initialize the PDM2PCM peripheral.

        :param int address: The virtual (in peripheral domain) memory address of the pdm2pcm.
        :param int length: The length of the pdm2pcm.
        :param bool cic_only: True to enable CIC only mode, False to enable other modes. By default, CIC only mode is enabled.
        """
        super().__init__(
            address,
            length,
            has_master_ports=has_master_ports,
            num_master_ports=num_master_ports,
            has_slave_ports=has_slave_ports,
            num_slave_ports=num_slave_ports,
            has_reg_if_ports=has_reg_if_ports,
            num_reg_if_ports=num_reg_if_ports,
        )
        self._cic_only = cic_only

    def get_cic_mode(self):
        """
        Get the CIC mode of the PDM2PCM peripheral.

        :return: True if CIC only mode is enabled, False otherwise.
        """
        return self._cic_only
