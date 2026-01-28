from x_heep_gen.pads.PadRing import *
from x_heep_gen.pads.Floorplan import *
from x_heep_gen.pads.Pin import *
from x_heep_gen.pads.Pad import *

import numpy as np

PAD_QTY                     = 92
DIE_WIDTH                   = 2000
DIE_HEIGHT                  = 2000
SPACE_FROM_CORNER_CELL      = 20
PITCH_BETWEEN_IO_DEFAULT    = 65
BONDPAD_MARGIN              = 24
IOCELL_MARGIN               = 95
CORE_MARGIN                 = 160



def config() -> PadRing:
    """
    Returns the pad configuration as a PadRing object.
    This is the Python class-based equivalent of configs/pad_cfg.hjson.
    """

    fp_dim = FloorplanDimensions(   die_dimensions  = Dimension( height=DIE_WIDTH, width=DIE_HEIGHT ),
                                    bondpad_margin  = { Side.LEFT   : BONDPAD_MARGIN,
                                                        Side.BOTTOM : BONDPAD_MARGIN,
                                                        Side.RIGHT  : BONDPAD_MARGIN,
                                                        Side.TOP    : BONDPAD_MARGIN 
                                                    },
                                    iocell_margin   = { Side.LEFT   : IOCELL_MARGIN,
                                                        Side.BOTTOM : IOCELL_MARGIN,
                                                        Side.RIGHT  : IOCELL_MARGIN,
                                                        Side.TOP    : IOCELL_MARGIN 
                                                    },
                                    core_margin     = { Side.LEFT   : CORE_MARGIN,
                                                        Side.BOTTOM : CORE_MARGIN,
                                                        Side.RIGHT  : CORE_MARGIN,
                                                        Side.TOP    : CORE_MARGIN 
                                                    }
                                 )
    
    ##############################################
    # Define the library and technology's dimensions

    Cell.cell_bondpad_a     = Dimension(width=60, length=80, name="BPAD6A")
    Cell.cell_bondpad_d     = Dimension(width=60, length=80, name="BPADD")

    Cell.cell_iocell_d      = Dimension(width=60, length=80, name="PD")
    Cell.cell_iocell_clk    = Cell.cell_iocell_d
    Cell.cell_iocell_dVdd   = Dimension(width=60, length=80, name="PS1")
    Cell.cell_iocell_ioVdd  = Dimension(width=60, length=80, name="PS2")
    Cell.cell_iocell_ioPoc  = Dimension(width=60, length=80, name="PS3")
    Cell.cell_iocell_dVss   = Dimension(width=60, length=80, name="PS4")
    Cell.cell_iocell_ioVss  = Cell.cell_iocell_dVss

    Cell.cell_iocell_a      = Dimension(width=60, length=80, name="PA")
    Cell.cell_iocell_aVdd   = Dimension(width=60, length=80, name="PSA1")
    Cell.cell_iocell_aVss   = Dimension(width=60, length=80, name="PSA2")

    Cell.cell_aPrcut        = Dimension(width=30, length=80, name="PCA")
    Cell.cell_aPrcut        = Dimension(width=60, length=80, name="PCD")

    Cell.cell_aCorner       = Dimension(width=60, length=80, name="PCA")
    Cell.cell_dCorner       = Dimension(width=60, length=80, name="PCD")


    ##############################################
    # DEFINE ALL THE AVAILABLE PINS

    digital_pins = [
        (Input,     "clk",                  [1],  {"module": "cheep_top"} ),
        (Input,     "rst",                  [4],  {"module": "cheep_top", "active":"low"}),
        (Input,     "execute_from_flash",   [5],  {"module": "core_v_mini_mcu"} ),
        (Output,    "exit_valid",           [6],  {"module": "core_v_mini_mcu"} ),
        (Output,    "exit_value",           [7],  {"module": "cheep_top"} ),
        (Input,     "boot_select",          [8],  {"module": "core_v_mini_mcu"} ),
        (Output,    "vco_counter_overflow", [9],  {"module": "cheep_top"} ),
        (Output,    "lc_dir",               [10], {"module": "cheep_top"} ),
        (Output,    "lc_xing",              [11], {"module": "cheep_top"} ),
        (Output,    "dsm_clk",              [14], {"module": "cheep_top"} ),
        (Input,     "dsm_in",               [15], {"module": "cheep_top"} ),
        (Output,    "spi_flash_cs_1",       [16], {"module": "core_v_mini_mcu"} ),
        (Inout,     "spi_flash_sd_1",       [17], {"module": "core_v_mini_mcu"} ),
        (Inout,     "spi_flash_sd_0",       [18], {"module": "core_v_mini_mcu"} ),
        (Output,    "spi_flash_sck",        [19], {"module": "core_v_mini_mcu"} ),
        (Output,    "spi_flash_cs_0",       [20], {"module": "core_v_mini_mcu"} ),
        (Input,     "spi_slave_cs",         [52], {"module": "core_v_mini_mcu"} ),
        (Input,     "spi_slave_sck",        [53], {"module": "core_v_mini_mcu"} ),
        (Inout,     "spi_slave_miso",       [54], {"module": "core_v_mini_mcu"} ),
        (Input,     "spi_slave_mosi",       [55], {"module": "core_v_mini_mcu"} ),
        (Input,     "jtag_trst",            [56], {"module": "core_v_mini_mcu", "active":"low"}),
        (Input,     "jtag_tms",             [57], {"module": "core_v_mini_mcu"} ),
        (Input,     "jtag_tdi",             [58], {"module": "core_v_mini_mcu"} ),
        (Input,     "jtag_tck",             [59], {"module": "core_v_mini_mcu"} ),
        (Output,    "jtag_tdo",             [60], {"module": "core_v_mini_mcu"} ),
        (Output,    "uart_tx",              [63], {"module": "core_v_mini_mcu"} ),
        (Input,     "uart_rx",              [64], {"module": "core_v_mini_mcu"} ),
    ]

    analog_pins = [
        (Asignal,   "DSM_VIN",              [23], {"module": "analog_subsystem"}),
        (Asignal,   "DSM_VDD",              [24], {"module": "analog_subsystem"}),
        (Asignal,   "VCO_VDD",              [26], {"module": "analog_subsystem"}),
        (Asignal,   "VCO_VIN",              [27], {"module": "analog_subsystem"}),
        (Asignal,   "VCO_VN0_VDD",          [28], {"module": "analog_subsystem"}),
        (Asignal,   "VCO_VN0",              [29], {"module": "analog_subsystem"}),
        (Asignal,   "LDO_VBAT",             [30], {"module": "analog_subsystem"}),
        (Asignal,   "LDO_VOUT",             [32], {"module": "analog_subsystem"}),
        (Asignal,   "LDO_VIN",              [33], {"module": "analog_subsystem"}),
        (Asignal,   "VREF_VDD",             [36], {"module": "analog_subsystem"}),
        (Asignal,   "VREF_VOUT",            [37], {"module": "analog_subsystem"}),
        (Asignal,   "IDAC1_IOUT",           [38], {"module": "analog_subsystem"}),
        (Asignal,   "IDAC1_IIN",            [39], {"module": "analog_subsystem"}),
        (Asignal,   "IREF1_IOUT",           [40], {"module": "analog_subsystem"}),
        (Asignal,   "IREF_VDD",             [42], {"module": "analog_subsystem"}),
        (Asignal,   "IREF_IOUT",            [43], {"module": "analog_subsystem"}),
        (Asignal,   "IDAC2_IIN",            [44], {"module": "analog_subsystem"}),
        (Asignal,   "IDAC2_IOUT",           [45], {"module": "analog_subsystem"}),
        (Asignal,   "AMUX_VDD",             [47], {"module": "analog_subsystem"}),
        (Asignal,   "AMUX_VOUT",            [48], {"module": "analog_subsystem"}),
    ]

    supply_pins = [
        (DVss,      "VSS",                  [2, 12,22, 50, 61],     {"module": "cheep_top", "default":True}),
        (DVdd,      "DCORE_VDD",            [3, 21, 51],            {"module": "cheep_top"}),
        (DVddIO,    "IO_VDD",               [62],                   {"module": "cheep_top"}),
        (DVddPOC,   "IO_VDD_POC",           [13],                   {"module": "cheep_top"}),
        (AVdd,      "ACORE_VDD",            [34],                   {"module": "cheep_top"}),
        (AVss,      "ACORE_VSS",            [25, 31, 35, 41, 46],   {"module": "cheep_top"}),
    ]

    ##############################################
    # AUTOMAGICALLY ADD ALL POSSIBLE GPIOS
    # (just because we can)

    for i in range(32): digital_pins.append( (Inout,f"gpio_{i}", [],{"priority":0} ) )

    ##############################################
    # GENERATE A PIN DICT WITH ALL THESE PINS

    pins = {}
    for ps in [digital_pins, analog_pins, supply_pins]:
        pins.update({name: cls(name, pads, attr) for (cls, name, pads, attr) in ps})

    ##############################################
    # ASSIGN SOME GPIOS HERE AND THERE

    pins["gpio_0"].pads = [49]
    pins["gpio_1"].pads = [9]
    pins["gpio_2"].pads = [10]
    pins["gpio_3"].pads = [11]
    pins["gpio_4"].pads = [14]
    pins["gpio_5"].pads = [15]
    pins["gpio_6"].pads = [16]

    # Assign a gpio to the last pad just to make sure that the mcu-gen does not die
    pins["gpio_7"].pads = [PAD_QTY]


# By this point, no matter how, you should have a list[Pin] with their attributes and assigned pads
# ----------------------------------------------------------------------------------------------

    '''
    alternatively do something like:

    pad_list = 
    [
        Pad( pins=[ pinA, pinB ] ),
        Pad( pins=[ pinC ] ),
        Pad( pins=[ pinD ] ),
        Pad( pins=[ pinE, pinF ] ),
        ...
    ]

    or even: 

    pad_list = 
    {
        Side.TOP : [
            Pad( pins=[ pinA, pinB ] ),
            Pad( pins=[ pinC ] ),
            ],
        side.BOTTOM : [
            Pad( pins=[ pinD ] ),
            Pad( pins=[ pinE, pinF ] ),
            ]
        ...
    }

    or going even simpler:

    pin_mapping = 
    {
        Side.TOP : [
            [ pinA, pinB ],
            [ pinC ] ,
            ],
        side.BOTTOM : [
            [ pinD ] ,
            [ pinE, pinF ] ,
            ]
        ...
    }

    And then move around the pads in the order to make them catch that order in the global_index

    padring = PadRing(  floorplan_dimensions    = fp_dim,
                        pin_list                = pin_list,
                        pad_list                = pad_list 
                    )



    '''


    padring = PadRing(  floorplan_dimensions    = fp_dim,
                        pin_list                = list(pins.values()),
                        pad_list                = [None]*PAD_QTY 
                    )



    ##############################################
    # ASSIGN PADS TO SIDES

    assign_to_side( padring.pad_list[1                     : int(PAD_QTY/4)*1 +1], Side.LEFT )
    assign_to_side( padring.pad_list[int(PAD_QTY/4)*1 +1   : int(PAD_QTY/4)*2 +1], Side.BOTTOM )
    assign_to_side( padring.pad_list[int(PAD_QTY/4)*2 +1   : int(PAD_QTY/4)*3 +1], Side.RIGHT )
    assign_to_side( padring.pad_list[int(PAD_QTY/4)*3 +1   : int(PAD_QTY/4)*4 +1], Side.TOP )

    ##############################################
    # PLACE PHYSICAL COMPONENTS (pad ring cuts)
    # Layout indexes are counted per side,
    # starting from 0
    # clockwise (inverse wrt the global index

    prcuta_top      = Physical( name            = "PRCUTA_TOP",
                                module          = "cheep_top",
                                iocell          = cell_aPrcut,
                                bondpad         = None, 
                                side            = Side.TOP,
                                orientation     = Orientation.R0,
                                side_index      = 15.5,
                                space           = 5 )

    prcuta_bottom   = Physical( name            = "PRCUTA_BOTTOM",
                                module          = "cheep_top",
                                iocell          = cell_aPrcut,
                                bondpad         = None, 
                                side            = Side.BOTTOM,
                                orientation     = Orientation.R180,
                                side_index      = 9.5,
                                space           = 0 )

    

    padring.pad_list.append(prcuta_top)
    padring.pad_list.append(prcuta_bottom)

    ##############################################
    # PRINT A NICE DIAGRAM TO CHECK EVERYTHING IS OK

    print_pad_frame(pads[1:])
    print_pad_table(pads[1:])


    # Arbitrarily assign a fixed position to some pad
    padring.pad_list[31].iocell_center_to_ring_edge = 586

    ##############################################
    # MANUALLY SET SPACING
    for side in Side: padring.space_by_pitch(side, SPACE_FROM_CORNER_CELL, PITCH_BETWEEN_IO_DEFAULT )

    return padring
