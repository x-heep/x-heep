from ..abstractions import BasePeripheral


class Power_manager(BasePeripheral):
    """
    Manages power states and clock gating for different system components.
    """

    _name = "power_manager"
