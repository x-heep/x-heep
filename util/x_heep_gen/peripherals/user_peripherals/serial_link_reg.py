from ..abstractions import UserPeripheral


class SerialLinkReg(UserPeripheral):
    """
    dedicated address space for configuring serial link IP registers.
    """

    _name = "serial_link_reg"
