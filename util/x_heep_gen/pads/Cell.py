
from Dimension import Dimension

class Cell:
    def __init__(self, name, width, height):
        # The name given to the cell in the PDK
        self.name       = name
        # The dimensions of the cell from the PDK
        self.dimension  = Dimension(width=width, height=height)


cell_bondpad_a      = Cell( name="BONDPAD_ANALOG",   width=20, length=30 )
cell_bondpad_d      = Cell( name="BONDPAD_DIGITAL",  width=20, length=30 )

cell_iocell_d       = Cell( name="IOCELL_DIGITAL", width=25, length=32 )
cell_iocell_clk     = Cell( name="IOCELL_CLOCK",   width=25, length=32 )
cell_iocell_dVdd    = Cell( name="IOCELL_DVDD",    width=25, length=32 )
cell_iocell_ioVdd   = Cell( name="IOCELL_IOVDD",   width=25, length=32 )
cell_iocell_ioPoc   = Cell( name="IOCELL_IOPOC",   width=25, length=32 )
cell_iocell_dVss    = Cell( name="IOCELL_DVSS",    width=25, length=32 )
cell_iocell_ioVss   = Cell( name="IOCELL_IOVSS",   width=25, length=32 )

cell_iocell_a       = Cell( name="IOCELL_ANALOG",  width=20, length=32 )
cell_iocell_aVdd    = Cell( name="IOCELL_AVDD",    width=20, length=32 )
cell_iocell_aVss    = Cell( name="IOCELL_AVSS",    width=20, length=32 )

cell_aPrcut         = Cell( name="APRCUT",      width=25, length=32 )
cell_aPrcut         = Cell( name="DPRCUT",      width=25, length=32 )

cell_aCorner        = Cell( name="ACORNER",     width=32, length=32 )
cell_dCorner        = Cell( name="DCORNER",     width=32, length=32 )

cell_bondpad_skip   = Cell( name = "",          width=0, length=0 )
cell_pad_skip       = Cell( name = "",          width=0, length=0 )