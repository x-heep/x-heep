from Cell import *
from enum import Enum

class PinType(Enum):
    DIGITAL_INPUT   = "input"
    DIGITAL_OUTPUT  = "output"
    DIGITAL_INOUT   = "inout"
    DIGITAL_SUPPLY  = "supply"
    ANALOG          = "supply"

# ToDo_padspy: select better names for this enum

class Pin:

    user_domain = ""
    module      = ""

    def __init__(
        self,
        name,
        pads        = [],
        priority    = 0,
        attributes  = {},
    ):
        self.name       = name
        self.pads       = pads
        self.priority   = priority
        self.attributes = attributes


class PinDigital(Pin):
    def __init__(self, name, attached_pads, attributes):
        super().__init__(name, attached_pads, attributes)
        self.properties = {}
        self.sv_pad_cell_name = f"u_pad_cell_{self.type.value}/pad_{self.type.value}_i"

class PinDigital(Pin):
    def __init__(self, name, pads, attr):
        self.name       = name
        self.iocell     = cell_iocell_d
        self.bondpad    = cell_bondpad_d
        self.properties = {}
        self.pads       = pads
        for key, value in attr.items(): setattr(self, key, value)
        self.sv_pad_cell_name   = f"u_pad_cell_{self.type.value}/pad_{self.type.value}_i"

class Input(PinDigital):
    def __init__(self, name, pads, attr):
        self.type = PinType.DIGITAL_INPUT
        super().__init__(name, pads, attr)

class Output(PinDigital):
    def __init__(self, name, pads, attr):
        self.type = PinType.DIGITAL_OUTPUT
        super().__init__(name, pads, attr)

class Inout(PinDigital):
    def __init__(self, name, pads, attr):
        self.type = PinType.DIGITAL_INOUT
        super().__init__(name, pads, attr)

class PinSupply(Pin):
    def __init__(self, name, pads, attr):
        self.name       = name
        self.properties = {}
        self.pads       = pads
        self.type       = PinType.DIGITAL_SUPPLY
        for key, value in attr.items(): setattr(self, key, value)
        if not hasattr(self,"sv_pad_cell_name"):
            self.sv_pad_cell_name = "u_pad_cell_supply/pad_supply_i"

class DVdd(PinSupply):
    def __init__(self, name, pads, attr):
        self.bondpad    = cell_bondpad_d
        self.iocell     = cell_iocell_dVdd
        super().__init__(name, pads, attr)

class DVddIO(PinSupply):
    def __init__(self, name, pads, attr):
        self.bondpad    = cell_bondpad_d
        self.iocell     = cell_iocell_ioVdd
        super().__init__(name, pads, attr)

class DVddPOC(PinSupply):
    def __init__(self, name, pads, attr):
        self.bondpad    = cell_bondpad_d
        self.iocell     = cell_iocell_ioPoc
        super().__init__(name, pads, attr)

class DVss(PinSupply):
    def __init__(self, name, pads, attr):
        self.bondpad    = cell_bondpad_d
        self.iocell     = cell_iocell_dVss
        super().__init__(name, pads, attr)

class PinAnalog(Pin):
    def __init__(self, name, pads, attr):
        self.name               = name
        self.properties         = {}
        self.pads               = pads
        self.type               = PinType.ANALOG
        self.driven_manually    = True
        for key, value in attr.items(): setattr(self, key, value)

class AVdd(PinAnalog):
    def __init__(self, name, pads, attr):
        self.bondpad            = cell_bondpad_a
        self.iocell             = cell_iocell_aVdd
        self.sv_pad_cell_name   = "u_sv_pad_cell_name_analog_vdd"
        super().__init__(name, pads, attr)

class AVss(PinAnalog):
    def __init__(self, name, pads, attr):
        self.bondpad            = cell_bondpad_a
        self.iocell             = cell_iocell_aVss 
        self.sv_pad_cell_name   = "u_pad_cell_analog_vss"
        super().__init__(name, pads, attr)

class Asignal(PinAnalog):
    def __init__(self, name, pads, attr):
        self.bondpad            = cell_bondpad_a
        self.iocell             = cell_iocell_a
        self.sv_pad_cell_name   = f"u_pad_cell_analog"
        super().__init__(name, pads, attr)

