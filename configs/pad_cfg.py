from x_heep_gen.pads.pad_ring import PadRing
from x_heep_gen.pads.floorplan import FloorplanDimensions, Side
from x_heep_gen.pads.pin import Pin, Input, Output, Inout
from x_heep_gen.pads.cell import Cell
from x_heep_gen.pads.dimension import Dimension
from x_heep_gen.pads.pad import Physical, Corner

PAD_QTY = 92
DIE_WIDTH = 2000
DIE_HEIGHT = 2000
SPACE_FROM_CORNER_CELL = 20
PITCH_BETWEEN_IO_DEFAULT = 65
BONDPAD_MARGIN = 24
IOCELL_MARGIN = 95
CORE_MARGIN = 160


def config() -> PadRing:
    """
    Returns the pad configuration as a PadRing object.
    This is the Python class-based equivalent of configs/pad_cfg.hjson.
    """

    fp_dim = FloorplanDimensions(
        die_dimensions=Dimension(width=DIE_WIDTH, height=DIE_HEIGHT),
        bondpad_margin={
            Side.LEFT: BONDPAD_MARGIN,
            Side.BOTTOM: BONDPAD_MARGIN,
            Side.RIGHT: BONDPAD_MARGIN,
            Side.TOP: BONDPAD_MARGIN,
        },
        iocell_margin={
            Side.LEFT: IOCELL_MARGIN,
            Side.BOTTOM: IOCELL_MARGIN,
            Side.RIGHT: IOCELL_MARGIN,
            Side.TOP: IOCELL_MARGIN,
        },
        core_margin={
            Side.LEFT: CORE_MARGIN,
            Side.BOTTOM: CORE_MARGIN,
            Side.RIGHT: CORE_MARGIN,
            Side.TOP: CORE_MARGIN,
        },
    )

    ##############################################
    # Define the library and technology's dimensions

    Cell.bondpad_a = Cell(width=60, height=80, name="BPAD6A")
    Cell.bondpad_d = Cell(width=60, height=80, name="BPADD")

    Cell.iocell_d = Cell(width=60, height=80, name="PD")
    Cell.iocell_clk = Cell.iocell_d
    Cell.iocell_dVdd = Cell(width=60, height=80, name="PS1")
    Cell.iocell_ioVdd = Cell(width=60, height=80, name="PS2")
    Cell.iocell_ioPoc = Cell(width=60, height=80, name="PS3")
    Cell.iocell_dVss = Cell(width=60, height=80, name="PS4")
    Cell.iocell_ioVss = Cell.iocell_dVss

    Cell.iocell_a = Cell(width=60, height=80, name="PA")
    Cell.iocell_aVdd = Cell(width=60, height=80, name="PSA1")
    Cell.iocell_aVss = Cell(width=60, height=80, name="PSA2")

    Cell.aPrcut = Cell(width=30, height=80, name="PCA")
    Cell.dPrcut = Cell(width=60, height=80, name="PCD")

    Cell.aCorner = Cell(width=60, height=80, name="CA")
    Cell.dCorner = Cell(width=60, height=80, name="CD")

    ##############################################
    # DEFINE ALL THE AVAILABLE PINS

    Pin.DEFAULT_MODULE = "core_v_mini_mcu"

    """
    ToDo_padspy
    from x_heep_gen import pin_list as xheep_pins

    so we dont need to add all these manually

    """

    digital_pins = [
        Input("clk", attributes={"module": "cheep_top"}),
        Input("rst", attributes={"module": "cheep_top", "active": "low"}),
        Input("execute_from_flash"),
        Output("exit_valid"),
        Output("exit_value", attributes={"module": "cheep_top"}),
        Input("boot_select"),
        Output("vco_counter_overflow", attributes={"module": "cheep_top"}),
        Output("lc_dir", attributes={"module": "cheep_top"}),
        Output("lc_xing", attributes={"module": "cheep_top"}),
        Output("dsm_clk", attributes={"module": "cheep_top"}),
        Input("dsm_in", attributes={"module": "cheep_top"}),
        Output("spi_flash_cs_1"),
        Inout("spi_flash_sd_1"),
        Inout("spi_flash_sd_0"),
        Output("spi_flash_sck"),
        Output("spi_flash_cs_0"),
        Input("spi_slave_cs"),
        Input("spi_slave_sck"),
        Inout("spi_slave_miso"),
        Input("spi_slave_mosi"),
        Input("jtag_trst", attributes={"active": "low"}),
        Input("jtag_tms"),
        Input("jtag_tdi"),
        Input("jtag_tck"),
        Output("jtag_tdo"),
        Output("uart_tx"),
        Input("uart_rx"),
    ]

    for i in range(32):
        digital_pins.append(Inout(f"gpio_{i}", attributes={"priority": 0}))

    analog_pins = []
    supply_pins = []

    ##############################################
    # GENERATE A PIN DICT WITH ALL THESE PINS

    pin_dict = {}
    for ps in [digital_pins, analog_pins, supply_pins]:
        pin_dict.update({pin.name: pin for pin in ps})

    ##############################################
    # CREATE PHYSICAL CELLS (which do not have pins assigned)

    prcuta = Physical(
        name="PRCUTA",
        attributes={"module": "cheep_top"},
        iocell=Cell.aPrcut,
        bondpad=None,
    )
    dcorner = Corner(
        name="CORNERD",
        attributes={"module": "cheep_top"},
        iocell=Cell.dCorner,
        bondpad=None,
    )

    acorner = Corner(
        name="CORNERA",
        attributes={"module": "cheep_top"},
        iocell=Cell.aCorner,
        bondpad=None,
    )

    mapping = {
        Side.LEFT: [
            dcorner,
            ["clk"],
            ["rst"],
            ["execute_from_flash"],
            ["exit_valid"],
            ["exit_value"],
            ["boot_select"],
            ["vco_counter_overflow"],
            ["lc_dir", "gpio_1"],
            ["lc_xing", "gpio_2"],
            ["dsm_clk", "gpio_3"],
            ["dsm_in", "gpio_4"],
            ["spi_flash_cs_1"],
            ["spi_flash_sd_1"],
            ["spi_flash_sd_0"],
        ],
        Side.BOTTOM: [
            dcorner,
            ["spi_flash_sck"],
            ["spi_flash_cs_0"],
            prcuta,
        ],
        Side.RIGHT: [
            acorner,
        ],
        Side.TOP: [
            acorner,
            prcuta,
            ["gpio_0"],
            ["spi_slave_mosi"],
            ["spi_slave_miso"],
            ["spi_slave_sck"],
            ["spi_slave_cs"],
            ["jtag_tms"],
            ["jtag_tdi"],
            ["jtag_tck"],
            ["jtag_trst"],
            ["jtag_tdo"],
            ["uart_tx"],
            ["uart_rx"],
        ],
    }

    # Replace the strings for their correspinding Pin element from the pins list
    mapping = {
        side: [
            ([pin_dict[p] for p in item] if isinstance(item, list) else item)
            for item in groups
        ]
        for side, groups in mapping.items()
    }

    padring = PadRing(
        floorplan_dimensions=fp_dim,
        pin_list=list(pin_dict.values()),
        mapping=mapping,
        attributes={},  # ToDo_padspy: add global attributes if needed
    )

    ##############################################
    # PRINT A NICE DIAGRAM TO CHECK EVERYTHING IS OK

    padring.print_pad_frame()
    padring.print_pad_table()

    # Arbitrarily assign a fixed position to some pad
    padring.pad_list[31].iocell_center_to_ring_edge = 586

    ##############################################
    # MANUALLY SET SPACING
    for side in Side:
        padring.space_side_by_pitch(
            side, SPACE_FROM_CORNER_CELL, PITCH_BETWEEN_IO_DEFAULT
        )

    return padring
