from x_heep_gen.pads.PadDef import (
    Dimension, Layout, PadMapping, PadActive, Orientation,
    Input, Output, Inout, DVss, DVdd, DVddIO, DVddPOC, DVss, AVdd, AVss, Asignal, Physical,
    assign_to_side, print_pad_table, generate_padlist, print_pad_frame, space_by_pitch
)
import x_heep_gen.pads.PadDef as PadDef
from x_heep_gen.pads.PadRing import PadRing

import numpy as np

PAD_QTY = 92
WIDTH   = 2000
HEIGHT  = 2000


def config() -> PadRing:
    """
    Returns the pad configuration as a PadRing object.
    This is the Python class-based equivalent of configs/pad_cfg.hjson.
    """


    ##############################################
    # Define the library and technology's dimensions

    PadDef.bp_a         = Dimension(width=60, length=80, name="BPAD6A")
    PadDef.bp_d         = Dimension(width=60, length=80, name="BPADD")

    PadDef.pad_d        = Dimension(width=60, length=80, name="PD")
    PadDef.pad_clk      = PadDef.pad_d
    PadDef.pad_dVdd     = Dimension(width=60, length=80, name="PS1")
    PadDef.pad_ioVdd    = Dimension(width=60, length=80, name="PS2")
    PadDef.pad_ioPoc    = Dimension(width=60, length=80, name="PS3")
    PadDef.pad_dVss     = Dimension(width=60, length=80, name="PS4")
    PadDef.pad_ioVss    = PadDef.pad_dVss

    PadDef.pad_a        = Dimension(width=60, length=80, name="PA")
    PadDef.pad_aVdd     = Dimension(width=60, length=80, name="PSA1")
    PadDef.pad_aVss     = Dimension(width=60, length=80, name="PSA2")

    PadDef.aPrcut       = Dimension(width=30, length=80, name="PCA")
    PadDef.aPrcut       = Dimension(width=60, length=80, name="PCD")

    PadDef.aCorner      = Dimension(width=60, length=80, name="PCA")
    PadDef.dCorner      = Dimension(width=60, length=80, name="PCD")


    ##############################################
    # DEFINE ALL THE AVAILABLE PINS

    digital_pins = [
        (Input,     "clk",                  [1],  {"driven_manually": True} ),
        (Input,     "rst",                  [4],  {"active":PadActive.LOW.value, "driven_manually": True}),
        (Input,     "execute_from_flash",   [5],  {} ),
        (Output,    "exit_valid",           [6],  {} ),
        (Output,    "exit_value",           [7],  {"driven_manually": True} ),
        (Input,     "boot_select",          [8],  {} ),
        (Output,    "vco_counter_overflow", [9],  {"driven_manually": True} ),
        (Output,    "lc_dir",               [10], {"driven_manually": True} ),
        (Output,    "lc_xing",              [11], {"driven_manually": True} ),
        (Output,    "dsm_clk",              [14], {"driven_manually": True} ),
        (Input,     "dsm_in",               [15], {"driven_manually": True} ),
        (Output,    "spi_flash_cs_1",       [16], {} ),
        (Inout,     "spi_flash_sd_1",       [17], {} ),
        (Inout,     "spi_flash_sd_0",       [18], {} ),
        (Output,    "spi_flash_sck",        [19], {} ),
        (Output,    "spi_flash_cs_0",       [20], {} ),
        (Input,     "spi_slave_cs",         [52], {} ),
        (Input,     "spi_slave_sck",        [53], {} ),
        (Inout,     "spi_slave_miso",       [54], {} ),
        (Input,     "spi_slave_mosi",       [55], {} ),
        (Input,     "jtag_trst",            [56], {"active":PadActive.LOW.value}),
        (Input,     "jtag_tms",             [57], {} ),
        (Input,     "jtag_tdi",             [58], {} ),
        (Input,     "jtag_tck",             [59], {} ),
        (Output,    "jtag_tdo",             [60], {} ),
        (Output,    "uart_tx",              [63], {} ),
        (Input,     "uart_rx",              [64], {} ),
    ]

    analog_pins = [
        (Asignal,   "DSM_VIN",              [23], {}),
        (Asignal,   "DSM_VDD",              [24], {}),
        (Asignal,   "VCO_VDD",              [26], {}),
        (Asignal,   "VCO_VIN",              [27], {}),
        (Asignal,   "VCO_VN0_VDD",          [28], {}),
        (Asignal,   "VCO_VN0",              [29], {}),
        (Asignal,   "LDO_VBAT",             [30], {}),
        (Asignal,   "LDO_VOUT",             [32], {}),
        (Asignal,   "LDO_VIN",              [33], {}),
        (Asignal,   "VREF_VDD",             [36], {}),
        (Asignal,   "VREF_VOUT",            [37], {}),
        (Asignal,   "IDAC1_IOUT",           [38], {}),
        (Asignal,   "IDAC1_IIN",            [39], {}),
        (Asignal,   "IREF1_IOUT",           [40], {}),
        (Asignal,   "IREF_VDD",             [42], {}),
        (Asignal,   "IREF_IOUT",            [43], {}),
        (Asignal,   "IDAC2_IIN",            [44], {}),
        (Asignal,   "IDAC2_IOUT",           [45], {}),
        (Asignal,   "AMUX_VDD",             [47], {}),
        (Asignal,   "AMUX_VOUT",            [48], {}),
    ]

    supply_pins = [
        (DVss,      "VSS",                  [2, 12,22, 50, 61],     {"default":True}),
        (DVdd,      "DCORE_VDD",            [3, 21, 51],            {}),
        (DVddIO,    "IO_VDD",               [62],                   {}),
        (DVddPOC,   "IO_VDD_POC",           [13],                   {}),
        (AVdd,      "ACORE_VDD",            [34],                   {}),
        (AVss,      "ACORE_VSS",            [25, 31, 35, 41, 46],   {}),
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

    ##############################################
    # GENERATE A LIST OF ALL POSSIBLE PADS
    # These do not include physical blocks yet
    default_pin = next(pin for pin in pins.values() if hasattr(pin,"default"))
    pads = generate_padlist(pins, PAD_QTY, default_pin=default_pin)

    ##############################################
    # ASSIGN PADS TO SIDES

    assign_to_side( pads[1                     : int(PAD_QTY/4)*1 +1], PadMapping.LEFT )
    assign_to_side( pads[int(PAD_QTY/4)*1 +1   : int(PAD_QTY/4)*2 +1], PadMapping.BOTTOM )
    assign_to_side( pads[int(PAD_QTY/4)*2 +1   : int(PAD_QTY/4)*3 +1], PadMapping.RIGHT )
    assign_to_side( pads[int(PAD_QTY/4)*3 +1   : int(PAD_QTY/4)*4 +1], PadMapping.TOP )

    ##############################################
    # PLACE PHYSICAL COMPONENTS (pad ring cuts)
    # Layout indexes are counted per side,
    # starting from 0
    # clockwise (inverse wrt the global index

    prcuta_top      = Physical( name            ="PRCUTA_TOP",
                                layout          = Layout(bond_pad=PadDef.bp_skip, cell_pad=PadDef.aPrcut),
                                side            = PadMapping.TOP,
                                orient          = Orientation.R0,
                                layout_index    = 15.5,
                                space           = 5 )

    prcuta_bottom   = Physical( name            = "PRCUTA_BOTTOM",
                                layout          = Layout(bond_pad=PadDef.bp_skip, cell_pad=PadDef.aPrcut),
                                side            = PadMapping.BOTTOM,
                                orient          = Orientation.R180,
                                layout_index    = 9.5,
                                space           = 0 )

    pads.append(prcuta_top)
    pads.append(prcuta_bottom)

    ##############################################
    # PRINT A NICE DIAGRAM TO CHECK EVERYTHING IS OK

    print_pad_frame(pads[1:])
    print_pad_table(pads[1:])

    ##############################################
    # DIMENSIONS

    pad_group = PadGroup(
        name                =   "cheep_top",
        physical_properties =   {"io_to_core_offset": 30},
        pad_edge_offset     =   100,    # Ignored
        bondpad_edge_offset =   29,     # Ignored
        bp_spacing          =   15,     # Ignored
        cell_spacing        =   None,   # Ignored
        fp_dim              =   Dimension(width=WIDTH, length=HEIGHT),

    )


    ##############################################
    # MANUALLY SET MARGINS
    # There are four rings, each has an offset
    # 1: sealring
    # 2: CDU
    # 3: bondpads
    # 4: pads
    # For each ring, there is a side
    ring_margin_default = [0, 0, 12.2, 24, 95]
    ring_margins = {
        "top":      ring_margin_default.copy(),
        "bottom":   ring_margin_default.copy(),
        "left":     ring_margin_default.copy(),
        "right":    ring_margin_default.copy(),
    }

    ##############################################
    # MANUALLY SET OFFSETS

    SPACE_FROM_CORNER_CELL      = 20
    PITCH_BETWEEN_IO_DEFAULT    = 65

    # Arbitrarily assign a fixed position to some pad
    pads[31].pc_center_from_ring = 586

    for side in ["left", "bottom", "right","top"]:
        side_margins    = ring_margins[side]
        side_pads       = [ pad for pad in pads[1:] if pad.mapping.value == side ]
        space_by_pitch( side_pads, side_margins, SPACE_FROM_CORNER_CELL, PITCH_BETWEEN_IO_DEFAULT )

    ##############################################
    # ADD PADS TO PAD GROUP
    # and prepare them to be received by the mcu-gen

    pads = pads[1:]
    pads.sort(key=lambda x: x.global_index)

    from copy import deepcopy
    backup = deepcopy(pads)

    [pad_group.add_pad(pad) for pad in pads]



    padring = PadRing(pad_group)
    padring.build()

    padring.customPadList = backup
    padring.ring_margins = ring_margins

    return padring
