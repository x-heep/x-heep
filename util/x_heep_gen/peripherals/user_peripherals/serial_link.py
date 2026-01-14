from ..abstractions import UserPeripheral


class serial_link(UserPeripheral):
    """
    dedicated address space for writing/reading data.
    """

    _name = "serial_link"
