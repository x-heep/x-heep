from x_heep_gen.pads.pad_ring import PadRing
from x_heep_gen.pads.floorplan import Side
from x_heep_gen.pads.pin import Pin, Input, Output, Inout
''' OPTIONAL - for cheeps
from x_heep_gen.pads.floorplan import FloorplanDimensions
from x_heep_gen.pads.cell import Cell
from x_heep_gen.pads.dimension import Dimension
from x_heep_gen.pads.pad import Physical, Corner
'''

def config() -> PadRing:
    """
    Returns the pad configuration as a PadRing object.
    This is the Python class-based equivalent of configs/pad_cfg.hjson.
    """

    ''' OPTIONAL - for cheeps

    # Define the floorplan dimensions

    DIE_WIDTH = 2000
    DIE_HEIGHT = 2000
    SPACE_FROM_CORNER_CELL = 20
    PITCH_BETWEEN_IO_DEFAULT = 65
    BONDPAD_MARGIN = 24
    IOCELL_MARGIN = 95
    CORE_MARGIN = 160

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

    # Define the library and technology's dimensions

    Cell.bondpad_a = Cell(width=60, height=80, name="BPADA")
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

    '''

    ##############################################
    # DEFINE ALL THE AVAILABLE PINS

    Pin.DEFAULT_MODULE = "core_v_mini_mcu"

    """
    ToDo_padspy
    from x_heep_gen import pin_list as xheep_pins

    so we dont need to add all these manually

    """

    digital_pins = [
        Input("clk"),
        Input("rst", attributes={"module": "x_heep_system", "active": "low"}),
        Input("boot_select"),
        Input("execute_from_flash"),
        Output("exit_valid"),
        Output("exit_value", attributes={"module": "x_heep_system"}),

        Input("jtag_tck"),
        Input("jtag_tms"),
        Input("jtag_trst", attributes={"active": "low"}),
        Input("jtag_tdi"),
        Output("jtag_tdo"),

        Input("uart_rx"),
        Output("uart_tx"),
        
        Inout("spi_flash_sck"),
        Inout("spi_flash_cs_0"),
        Inout("spi_flash_cs_1"),
        Inout("spi_flash_sd_0"),
        Inout("spi_flash_sd_1"),
        Inout("spi_flash_sd_2"),
        Inout("spi_flash_sd_3"),

        Inout("spi_sck"),
        Inout("spi_cs_0"),
        Inout("spi_cs_1"),
        Inout("spi_sd_0"),
        Inout("spi_sd_1"),
        Inout("spi_sd_2"),
        Inout("spi_sd_3"),
    
        Inout("spi2_cs_0"),
        Inout("spi2_cs_1"),
        Inout("spi2_sck"),
        Inout("spi2_sd_0"),
        Inout("spi2_sd_1"),
        Inout("spi2_sd_2"),
        Inout("spi2_sd_3"),

        Input("spi_slave_sck"),
        Input("spi_slave_cs"),
        Inout("spi_slave_miso"),
        Input("spi_slave_mosi"),

        Inout("pdm2pcm_pdm"),
        Inout("pdm2pcm_clk"),

        Inout("i2s_sck"),
        Inout("i2s_ws"),
        Inout("i2s_sd"),
        
        Inout("i2c_scl"),
        Inout("i2c_sda"),
    ]

    # Add all gpios at once, because we are lazy :P
    for i in range(32): digital_pins.append(Inout(f"gpio_{i}", attributes={"priority": 0}))

    analog_pins = []
    supply_pins = []

    ##############################################
    # GENERATE A PIN DICT WITH ALL THESE PINS
    # Feel free to generate this dictionary directly, no need to go through the list before,
    # we did it like this just for our convenience. 
    # pin_dict = {
    #   "clk" : Input("clk"),
    #   . . . 
    #  }

    pin_dict = {}
    for ps in [digital_pins, analog_pins, supply_pins]:
        pin_dict.update({pin.name: pin for pin in ps})

    ''' OPTIONAL - for cheeps
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
    ''' 
    
    ##############################################
    # MAP PINS TO PADS
    # And assign them sides.
    # If you don't care about sides (i.e. just want to simulate)
    # Just assign them all to the same side. 

    mapping = {
        Side.LEFT: [
            ''' OPTIONAL - for cheeps
            # You should add one of these at the start of each side. 
            # Make it an analog corner if needed. 
            dcorner,
            '''
            ["clk"],
            ["rst"],
            ["boot_select"],
            ["execute_from_flash"],
            ["jtag_tck"],
            ["jtag_tms"],
            ["jtag_trst"],
            ["jtag_tdi"],
            ["jtag_tdo"],
            ["uart_rx"],
            ["uart_tx"],
            ["exit_valid"],
            ["exit_value"],
            ["gpio_0"],
            ["gpio_1"],
        ],
        Side.BOTTOM: [
            ["gpio_0"],
            ["gpio_1"],
            ["gpio_2"],
            ["gpio_3"],
            ["gpio_4"],
            ["gpio_5"],
            ["gpio_6"],
            ["gpio_7"],
            ["gpio_8"],
            ["gpio_9"],
            ["gpio_10"],
            ["gpio_11"],
            ["gpio_12"],
            ["gpio_13"],
        ],
        Side.RIGHT: [
            ["spi_flash_sck"],
            ["spi_flash_cs_0"],
            ["spi_flash_cs_1"],
            ["spi_flash_sd_0"],
            ["spi_flash_sd_1"],
            ["spi_flash_sd_2"],
            ["spi_flash_sd_3"],
            ["spi_sck"],
            ["spi_cs_0"],
            ["spi_cs_1"],
            ["spi_sd_0"],
            ["spi_sd_1"],
            ["spi_sd_2"],
            ["spi_sd_3"],
            ["spi_slave_sck", "gpio_14"],
            ["spi_slave_cs", "gpio_15"],
            ["spi_slave_miso", "gpio_16"],
        ],
        Side.TOP: [
            ["spi_slave_mosi", "gpio_17"],
            ["pdm2pcm_pdm", "gpio_18"],
            ["pdm2pcm_clk", "gpio_19"],
            ["i2s_sck", "gpio_20"],
            ["i2s_ws", "gpio_21"],
            ["i2s_sd", "gpio_22"],
            ["spi2_cs_0", "gpio_23"],
            ["spi2_cs_1", "gpio_24"],
            ["spi2_sck", "gpio_25"],
            ["spi2_sd_0", "gpio_26"],
            ["spi2_sd_1", "gpio_27"],
            ["spi2_sd_2", "gpio_28"],
            ["spi2_sd_3", "gpio_29"],
            ["i2c_scl", "gpio_31"],
            ["i2c_sda", "gpio_30"],
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
        floorplan_dimensions=None,
        pin_list=list(pin_dict.values()),
        mapping=mapping,
        attributes={},  # ToDo_padspy: add global attributes if needed
    )

    ##############################################
    # PRINT A NICE DIAGRAM TO CHECK EVERYTHING IS OK

    padring.print_pad_frame()
    padring.print_pad_table()

    ''' OPTIONAL - for cheeps 
    # Arbitrarily assign a fixed position to some pad
    padring.pad_list[31].iocell_center_to_ring_edge = 586

    # Set the spacing between the pads
    for side in Side:
        padring.space_side_by_pitch(
            side, SPACE_FROM_CORNER_CELL, PITCH_BETWEEN_IO_DEFAULT
        )
    '''

    return padring
