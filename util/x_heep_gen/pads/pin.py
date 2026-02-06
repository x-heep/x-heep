from .cell import *
from enum import Enum


class Pin:
    """
    Represents a pin (signal) in the system that can be assigned to a pad.
    """

    # Default module to which the pin will be attached to. See Pin.module.
    DEFAULT_MODULE = "core_v_mini_mcu"

    def __init__(
        self,
        name: str,
        module: str = None,
        attributes: dict = None,
    ):
        """
        Constructor for Pin.

        :param name: The name of the signal (without _i, _n, or similar RTL suffixes).
        :param module: The module to which the pin belongs. This represent where in the CHEEP is the
            pin connected to. Does it come directly from the border? Does it come from an external
            peripheral? Does it come from inside core_v_mini_mcu? By default, it will be assigned to
            "core_v_mini_mcu".
        :param attributes: Additional attributes of the pin as key-value pairs. Useful attributes
            can be:
            - {"active": "low"} to indicate that this pin is active low
            - {"priority": 1} to give priority to this pins when the pad is multiplexed. The higher
                the value, the higher the priority (i.e. the pin with the highest priority will be
                the default one).
        """
        self.name = name
        self.module = Pin.DEFAULT_MODULE if module is None else module
        self.attributes = {} if attributes is None else attributes

        # IO cell and bondpad assigned to this pin
        self.iocell: Cell = None
        self.bondpad: Cell = None

    def __str__(self):
        return self.name

    def rtl_name(self) -> str:
        """
        Returns the RTL name of the pin including an underscore '_' as suffix. If the pin is active
        low, the suffix will be '_n' instead.
        """

        if self.attributes.get("active") == "low":
            return f"{self.name}_n"
        return f"{self.name}_"


class PinDigital(Pin):
    """
    Represents a generic digital pin.

    This class will have the digital bondpad and iocell assigned.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell = iocell_d.copy()
        self.bondpad = bondpad_d.copy()


class Input(PinDigital):
    """
    Represents a digital input pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell.rtl_wrapper = "u_pad_cell_input"


class Output(PinDigital):
    """
    Represents a digital output pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell.rtl_wrapper = "u_pad_cell_output"


class Inout(PinDigital):
    """
    Represents a digital inout pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell.rtl_wrapper = "u_pad_cell_inout"


class PinSupply(Pin):
    """
    Represents a generic supply pin.
    """

    def __init__(self, name, attributes=None):
        super().__init__(name, attributes=attributes)


class DVdd(PinSupply):
    """
    Represents a digital Vdd supply pin.
    """

    def __init__(self, name, attributes=None):
        super().__init__(name, attributes)
        self.iocell = iocell_dVdd.copy()
        self.bondpad = bondpad_d.copy()


class DVddIO(PinSupply):
    """
    Represents a digital I/O Vdd supply pin.
    """

    def __init__(self, name, attributes=None):
        super().__init__(name, attributes)
        self.iocell = iocell_ioVdd.copy()
        self.bondpad = bondpad_d.copy()


class DVddPOC(PinSupply):
    """
    Represents a digital Power-On-Circuit Vdd supply pin.
    """

    def __init__(self, name, attributes=None):
        super().__init__(name, attributes)
        self.iocell = iocell_ioPoc.copy()
        self.bondpad = bondpad_d.copy()


class DVss(PinSupply):
    """
    Represents a digital Vss supply pin.
    """

    def __init__(self, name, attributes=None):
        super().__init__(name, attributes)
        self.iocell = iocell_dVss.copy()
        self.bondpad = bondpad_d.copy()


class PinAnalog(Pin):
    """
    Represents a generic analog pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)


class AVdd(PinAnalog):
    """
    Represents an analog Vdd supply pin.
    """

    def __init__(self, name, attributes=None):
        super().__init__(name, attributes=attributes)
        self.iocell = iocell_aVdd.copy()
        self.bondpad = bondpad_a.copy()


class AVss(PinAnalog):
    """
    Represents an analog Vss supply pin.
    """

    def __init__(self, name, attributes=None):
        super().__init__(name, attributes=attributes)
        self.iocell = iocell_aVss.copy()
        self.bondpad = bondpad_a.copy()


class Asignal(PinAnalog):
    """
    Represents a generic analog signal pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell = iocell_a.copy()
        self.bondpad = bondpad_a.copy()
