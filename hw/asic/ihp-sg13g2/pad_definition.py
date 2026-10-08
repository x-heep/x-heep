# from x_heep_gen.pads import cell
# from x_heep_gen.pads.pin import *
# from x_heep_gen.pads.pad import *
from pads import cell
from pads.pin import *
from pads.pad import *

# =====================================
# PDK Cells and bondpad
# =====================================
# Power cells
pwrcell_vdd    = Cell( width=80, height=180, name="sg13g2_IOPadVdd", rtl_wrapper="pad_cell_vdd")
pwrcell_vss    = Cell( width=80, height=180, name="sg13g2_IOPadVss", rtl_wrapper="pad_cell_vss")
pwrcell_iovdd  = Cell( width=80, height=180, name="sg13g2_IOPadIOVdd", rtl_wrapper="pad_cell_iovdd")
pwrcell_iovss  = Cell( width=80, height=180, name="sg13g2_IOPadIOVss", rtl_wrapper="pad_cell_iovss")

# Bondpad: only one in IHP-SG13G2
bondpad_all = Cell( width=70, height=70, name="bondpad_70x70_novias")

# TODO: Corner and fillers

# Update the standard cells to match the dimensions and cell name from the PDK
cell.iocell_a.update( dimension=Dimension(width=80, height=180), name="sg13g2_IOPadAnalog" )
cell.iocell_d.update( dimension=Dimension(width=80, height=180) ) # No name as this bondpad is used for input, output and inout pins
cell.bondpad_a.update( dimension=bondpad_all.dimension, name=bondpad_all.name )
cell.bondpad_d.update( dimension=bondpad_all.dimension, name=bondpad_all.name )

# =====================================
# Custom pin classes
# =====================================
class PinPower(Pin):
    """
    Represents a power pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell = pwrcell_vdd.copy()
        self.bondpad = bondpad_all.copy()


class PinVdd(PinPower):
    """
    Represents a VDD/VPWR power pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell = pwrcell_vdd.copy()


class PinVss(PinPower):
    """
    Represents a VSS/VGND power pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell = pwrcell_vss.copy()


class PinIoVdd(PinPower):
    """
    Represents a IOVDD power pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell = pwrcell_iovdd.copy()


class PinIoVss(PinPower):
    """
    Represents a IOVSS power pin.
    """

    def __init__(self, name, module=None, attributes=None):
        super().__init__(name, module, attributes)
        self.iocell = pwrcell_iovss.copy()
