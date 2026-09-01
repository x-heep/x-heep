from ..abstractions import BasePeripheral


class Power_manager(BasePeripheral):
    """
    Manages power states and clock gating for different system components.
    """

    _name = "power_manager"

    def __init__(
        self,
        address: int = None,
        length: int = None,
        external_domains: int = 0,
        has_master_ports: bool = False,
        num_master_ports: int = None,
        has_slave_ports: bool = False,
        num_slave_ports: int = None,
        has_reg_if_ports: bool = True,
        num_reg_if_ports: int = None,
    ):
        """
        Initialize the Power_manager peripheral.

        :param int address: The virtual (in peripheral domain) memory address of the Power_manager.
        :param int length: The length of the Power_manager.
        :param int external_domains: the number of power domains external to X-HEEP.
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

        if external_domains > 32:
            raise ValueError(
                "Power_manager: external_domains must be less than 32 instead of "
                + str(external_domains)
            )

        self._external_domains = external_domains

    def get_external_domains(self):
        """
        Get the number of external domains.
        """
        return self._external_domains

    def set_external_domains(self, value: int):
        """
        Set the number of external domains.
        """
        self._external_domains = value
