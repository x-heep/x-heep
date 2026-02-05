from .cell import *
from enum import Enum


# ToDo_padspy: select better names for this enum
class PinType(Enum):
    DIGITAL_INPUT = "input"
    DIGITAL_OUTPUT = "output"
    DIGITAL_INOUT = "inout"
    DIGITAL_SUPPLY = "supply"
    ANALOG = "supply"
    PHYSICAL = "supply"


class Pin:
    DEFAULT_MODULE = "core_v_mini_mcu"

    user_domain = ""
    module = ""

    def __init__(
        self,
        name,
        module=None,
        attributes={},
    ):
        self.name = name
        self.module = module if module is not None else Pin.DEFAULT_MODULE
        self.attributes = attributes

    def __str__(self):
        return self.name

    def rtl_name(self):
        """
        Returns the RTL name of the pin including an underscore '_' as suffix. If the pin is active
        low, the suffix will be '_n' instead.
        """

        if self.attributes.get("active") == "low":
            return f"{self.name}_n"
        return f"{self.name}_"


class PinDigital(Pin):
    def __init__(self, name, module=None, attributes={}):
        self.name = name
        self.iocell = iocell_d.copy()
        self.bondpad = bondpad_d.copy()
        super().__init__(name, module, attributes=attributes)


class Input(PinDigital):
    def __init__(self, name, module=None, attributes={}):
        super().__init__(name, module, attributes=attributes)
        self.iocell.update(rtl_wrapper="u_pad_cell_input", verbose=False)


class Output(PinDigital):
    def __init__(self, name, module=None, attributes={}):
        super().__init__(name, module, attributes=attributes)
        self.iocell.update(rtl_wrapper="u_pad_cell_output", verbose=False)

class Inout(PinDigital):
    def __init__(self, name, module=None, attributes={}):
        super().__init__(name, module, attributes=attributes)
        self.iocell.update(rtl_wrapper="u_pad_cell_inout", verbose=False)


class PinSupply(Pin):
    def __init__(self, name, attributes={}):
        self.name = name
        super().__init__(name, attributes=attributes)


class DVdd(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d.copy()
        self.iocell = iocell_dVdd.copy()
        super().__init__(name, attributes=attributes)


class DVddIO(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d.copy()
        self.iocell = iocell_ioVdd.copy()
        super().__init__(name, attributes=attributes)


class DVddPOC(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d.copy()
        self.iocell = iocell_ioPoc.copy()
        super().__init__(name, attributes=attributes)


class DVss(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d.copy()
        self.iocell = iocell_dVss.copy()
        super().__init__(name, attributes=attributes)


class PinAnalog(Pin):
    def __init__(self, name, module=None, attributes={}):
        self.name = name
        super().__init__(name, module, attributes=attributes)


class AVdd(PinAnalog):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_a.copy()
        self.iocell = iocell_aVdd.copy()
        super().__init__(name, attributes=attributes)


class AVss(PinAnalog):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_a.copy()
        self.iocell = iocell_aVss.copy()
        super().__init__(name, attributes=attributes)


class Asignal(PinAnalog):
    def __init__(self, name, module=None, attributes={}):
        self.bondpad = bondpad_a.copy()
        self.iocell = iocell_a.copy()
        super().__init__(name, module, attributes=attributes)
