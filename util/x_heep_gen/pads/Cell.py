from .Dimension import Dimension


class Cell:
    def __init__(self, name, width, height):
        # The name given to the cell in the PDK
        self.name = name
        # The dimensions of the cell from the PDK
        self.dimension = Dimension(width=width, height=height)


bondpad_a = Cell(name="BONDPAD_ANALOG", width=20, height=30)
bondpad_d = Cell(name="BONDPAD_DIGITAL", width=20, height=30)

iocell_d = Cell(name="IOCELL_DIGITAL", width=25, height=32)
iocell_clk = Cell(name="IOCELL_CLOCK", width=25, height=32)
iocell_dVdd = Cell(name="IOCELL_DVDD", width=25, height=32)
iocell_ioVdd = Cell(name="IOCELL_IOVDD", width=25, height=32)
iocell_ioPoc = Cell(name="IOCELL_IOPOC", width=25, height=32)
iocell_dVss = Cell(name="IOCELL_DVSS", width=25, height=32)
iocell_ioVss = Cell(name="IOCELL_IOVSS", width=25, height=32)

iocell_a = Cell(name="IOCELL_ANALOG", width=20, height=32)
iocell_aVdd = Cell(name="IOCELL_AVDD", width=20, height=32)
iocell_aVss = Cell(name="IOCELL_AVSS", width=20, height=32)

aPrcut = Cell(name="APRCUT", width=25, height=32)
aPrcut = Cell(name="DPRCUT", width=25, height=32)

aCorner = Cell(name="ACORNER", width=32, height=32)
dCorner = Cell(name="DCORNER", width=32, height=32)

bondpad_skip = Cell(name="", width=0, height=0)
pad_skip = Cell(name="", width=0, height=0)
