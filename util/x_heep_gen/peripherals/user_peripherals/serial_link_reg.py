from ..abstractions import UserPeripheral


class serial_link_reg(UserPeripheral):
    """
    dedicated address space for configuring serial link IP registers.
    """

    _name = "serial_link_reg"
