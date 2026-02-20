from ..abstractions import BasePeripheral


class RV_timer_ao(BasePeripheral):
    """
    RISC-V timer peripheral for system timing and scheduling.
    """

    _name = "rv_timer_ao"
