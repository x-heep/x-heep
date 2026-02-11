from ..abstractions import UserPeripheral


class SerialLink(UserPeripheral):
    """
    dedicated address space for writing/reading data.
    """

    _name = "serial_link"
