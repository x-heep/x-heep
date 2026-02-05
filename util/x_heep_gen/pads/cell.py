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
        :param connections: The list of connections this cell has. For example ["vdd"].
        :param rtl_wrapper: The name of the RTL wrapper module for this cell. This is used
            to connect the cell to the rest of the design in the RTL generation process.
            For example "u_pad_cell_digital_core_vdd".
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
