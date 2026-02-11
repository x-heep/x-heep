from ..abstractions import UserPeripheral


class SerialLink(UserPeripheral):
    """
    Dedicated address space for writing/reading data.
    """

    _name = "serial_link"
