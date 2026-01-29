from .cell import *
from enum import Enum


class PinType(Enum):
    DIGITAL_INPUT = "input"
    DIGITAL_OUTPUT = "output"
    DIGITAL_INOUT = "inout"
    DIGITAL_SUPPLY = "supply"
    ANALOG = "supply"
    PHYSICAL = "supply"


# ToDo_padspy: select better names for this enum

DEFAULT_MODULE = "core_v_mini_mcu"


class Pin:

    user_domain = ""
    module = ""

    def __init__(
        self,
        name,
        attributes={},
    ):
        self.name = name
        self.priority = 0
        self.attributes = attributes

    def rtl_name(self):
        """
        Returns the RTL name of the pin, which, for example, may have a suffix if the attributes
        specify that it is active low.
        """

        if self.attributes.get("active") == False:
            return f"{self.name}_n"
        return self.name


class PinDigital(Pin):
    def __init__(self, name, attributes={}):
        self.name = name
        self.iocell = iocell_d
        self.bondpad = bondpad_d
        self.sv_pad_cell_name = f"u_pad_cell_{self.type.value}/pad_{self.type.value}_i"
        super().__init__(name, attributes)


class Input(PinDigital):
    def __init__(self, name, attributes={}):
        self.type = PinType.DIGITAL_INPUT
        super().__init__(name, attributes)


class Output(PinDigital):
    def __init__(self, name, attributes={}):
        self.type = PinType.DIGITAL_OUTPUT
        super().__init__(name, attributes)


class Inout(PinDigital):
    def __init__(self, name, attributes={}):
        self.type = PinType.DIGITAL_INOUT
        super().__init__(name, attributes)


class PinSupply(Pin):
    def __init__(self, name, attributes={}):
        self.name = name
        self.properties = {}
        self.type = PinType.DIGITAL_SUPPLY
        if not hasattr(self, "sv_pad_cell_name"):
            self.sv_pad_cell_name = "u_pad_cell_supply/pad_supply_i"
        super().__init__(name, attributes)


class DVdd(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d
        self.iocell = iocell_dVdd
        super().__init__(name, attributes)


class DVddIO(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d
        self.iocell = iocell_ioVdd
        super().__init__(name, attributes)


class DVddPOC(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d
        self.iocell = iocell_ioPoc
        super().__init__(name, attributes)


class DVss(PinSupply):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_d
        self.iocell = iocell_dVss
        super().__init__(name, attributes)


class PinAnalog(Pin):
    def __init__(self, name, attributes={}):
        self.name = name
        self.properties = {}
        self.type = PinType.ANALOG
        self.driven_manually = True
        super().__init__(name, attributes)


class AVdd(PinAnalog):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_a
        self.iocell = iocell_aVdd
        self.sv_pad_cell_name = "u_pad_cell_analog_vdd"
        super().__init__(name, attributes)


class AVss(PinAnalog):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_a
        self.iocell = iocell_aVss
        self.sv_pad_cell_name = "u_pad_cell_analog_vss"
        super().__init__(name, attributes)


class Asignal(PinAnalog):
    def __init__(self, name, attributes={}):
        self.bondpad = bondpad_a
        self.iocell = iocell_a
        self.sv_pad_cell_name = f"u_pad_cell_analog"
        super().__init__(name, attributes)
