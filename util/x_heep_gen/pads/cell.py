from .dimension import Dimension
import copy


class Cell:
    """
    Represents a cell in the padring. This can be for example a bondpad, an iocell or a corner cell.
    """

    def __init__(
        self,
        name: str,
        width: float,
        height: float,
        connections: list = None,
        rtl_wrapper="",
    ):
        """
        Constructor for Cell.

        :param name: The name of the cell in the PDK.
        :param width: The width of the cell from the LEF file of the PDK.
        :param height: The height of the cell from the LEF file of the PDK.
        :param connections: The list of connections this cell has. For example ["vdd"]. The cell
            (the one that comes from the PDK) has pins. e.g. when we set a pad as
            input/output/inout, what we do is fix some fo those to 1 or 0, and connect the others to
            the signal. Same goes for analog or supply pins (although most of them simply have a
            single pin). These connection names do not necessarily match the pin name that we use,
            which we force to be a synonym of the signal that will be connected. The pins defined in
            the cell (that we dubbed "connections" not to mix them up with the "pins" of the cheep),
            are thus a property of the cell (not the pad) and vary from PDK to PDK. These are used
            while instantiating the cell on the RTL).
        :param rtl_wrapper: The name of the RTL wrapper module for this cell. For example
            "u_pad_cell_digital_core_vdd". The cell (the one that comes from the PDK) is wrapped
            around an RTL module so that we can have a single point where the cell name should be
            consistent with what we include in the cheep.io (i.e. if we claim that we will use
            a cell on the cheep_pads.py, that will be added on the cheep.io, and thus it will be
            instantiated on the floorplan. We need to make sure that the instance of the pad that is
            instantiated on the RTL refers to the same cell, so on the cheeps we have a folder
            hw/asic/rtl/... where we create wrappers for the PDK cells, and the name of the cell
            instantiated inside the wrapper must match the name used on the cheep.io). The
            rtl_wrapper is simply the name that we give to that wrapper of the cell.
        """
        self.name = name
        self.dimension = Dimension(width=width, height=height)
        self.connections = [] if connections is None else connections
        self.rtl_wrapper = rtl_wrapper

    def update(self, **kwargs):
        """
        Update the attributes of the cell.

        :param kwargs: Key-value pairs of attributes to update. The "verbose" key can be used to
            enable verbose output.
        :return: The updated cell instance (self).
        """
        verbose = kwargs.pop("verbose", False)
        # kwargs is already a dictionary of everything passed
        for key, value in kwargs.items():
            if verbose:
                print(
                    f"Updating {self.name}: {key} from {getattr(self, key)} to {value}"
                )
            setattr(self, key, value)
        return self

    def copy(self):
        """
        Return a deep copy of the cell.
        """
        return copy.deepcopy(self)


# =====================================
# Predefined cells
# =====================================

bondpad_a = Cell(name="BONDPAD_ANALOG", width=20, height=30)
bondpad_d = Cell(name="BONDPAD_DIGITAL", width=20, height=30)

iocell_d = Cell(
    name="IOCELL_DIGITAL", width=25, height=32
)  # No need to declare connections, they are handled manually in the padring template
iocell_clk = Cell(name="IOCELL_CLOCK", width=25, height=32)
iocell_dVdd = Cell(
    name="IOCELL_DVDD",
    width=25,
    height=32,
    rtl_wrapper="u_pad_cell_digital_core_vdd",
    connections=["vdd"],
)
iocell_ioVdd = Cell(
    name="IOCELL_IOVDD",
    width=25,
    height=32,
    rtl_wrapper="u_pad_cell_digital_io_vdd",
    connections=["vdd"],
)
iocell_ioPoc = Cell(
    name="IOCELL_IOPOC",
    width=25,
    height=32,
    rtl_wrapper="u_pad_cell_digital_poc_vdd",
    connections=["vdd"],
)
iocell_dVss = Cell(
    name="IOCELL_DVSS",
    width=25,
    height=32,
    rtl_wrapper="u_pad_cell_digital_core_vss",
    connections=["vss"],
)
iocell_ioVss = Cell(
    name="IOCELL_IOVSS",
    width=25,
    height=32,
    rtl_wrapper="u_pad_cell_digital_io_vdd",
    connections=["vss"],
)

iocell_a = Cell(
    name="IOCELL_ANALOG",
    width=20,
    height=32,
    rtl_wrapper="u_pad_cell_analog",
    connections=["io"],
)
iocell_aVdd = Cell(
    name="IOCELL_AVDD",
    width=20,
    height=32,
    rtl_wrapper="u_pad_cell_analog_vdd",
    connections=["vdd"],
)
iocell_aVss = Cell(
    name="IOCELL_AVSS",
    width=20,
    height=32,
    rtl_wrapper="u_pad_cell_analog_vss",
    connections=["vss"],
)

aPrcut = Cell(name="APRCUT", width=25, height=32, rtl_wrapper="u_pad_cell_analog_vss")
dPrcut = Cell(name="DPRCUT", width=25, height=32, rtl_wrapper="u_pad_cell_analog_vss")

aCorner = Cell(name="ACORNER", width=32, height=32)
dCorner = Cell(name="DCORNER", width=32, height=32)

bondpad_skip = Cell(name="", width=0, height=0)
pad_skip = Cell(name="", width=0, height=0)
