from ..abstractions import UserPeripheral


class SerialLinkReceiverFifo(UserPeripheral):
    """
    Dedicated address space used by the serial link to buffer received data in a FIFO and expose it
    on request (i.e. transmitted data from SL can be read by DMA at this address). The size of the
    FIFO is configurable by parameters.
    """

    _name = "serial_link_receiver_fifo"
