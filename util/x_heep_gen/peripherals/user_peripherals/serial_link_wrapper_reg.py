from ..abstractions import UserPeripheral


class SerialLinkWrapperReg(UserPeripheral):
    """
    Dedicated address space for configuring the serial link xheep wrapper registers.
    """

    _name = "serial_link_wrapper_reg"
