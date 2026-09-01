# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Juan Sapriza, David Mallasen
# Description: Pad configuration for X-HEEP

from xheep import XHeep
from pads.pad_ring import PadRing
from pads.floorplan import Side
from pads.pin import Input, Output, Inout


def config(xheep: XHeep) -> PadRing:
    """
    Build and return the PadRing for the design, including pin definitions and pad mapping.
    For detailed documentation and usage instructions, please refer to docs/source/Configuration/PadConfiguration.md
    """

    ##############################################
    # DEFINE ALL THE AVAILABLE PINS (SIGNALS)

    digital_pins = [
        Input("clk"),
        Input("rst", module="x_heep_system", attributes={"active": "low"}),
        Input("boot_select"),
        Output("exit_valid"),
        # JTAG
        Input("jtag_tck"),
        Input("jtag_tms"),
        Input("jtag_trst", attributes={"active": "low"}),
        Input("jtag_tdi"),
        Output("jtag_tdo"),
        # UART
        Input("uart_rx"),
        Output("uart_tx"),
        # SPI Flash
        Inout("spi_flash_sck"),
        Inout("spi_flash_cs_0"),
        Inout("spi_flash_cs_1"),
        Inout("spi_flash_sd_0"),
        Inout("spi_flash_sd_1"),
        Inout("spi_flash_sd_2"),
        Inout("spi_flash_sd_3"),
        # SPI Host
        Inout("spi_sck"),
        Inout("spi_cs_0"),
        Inout("spi_cs_1"),
        Inout("spi_sd_0"),
        Inout("spi_sd_1"),
        Inout("spi_sd_2"),
        Inout("spi_sd_3"),
        # SPI Slave
        # In the debug_ss. If the debug_ss does not have an SPI slave, these pins should be removed.
        Input("spi_slave_sck"),
        Input("spi_slave_cs"),
        Inout("spi_slave_miso"),
        Input("spi_slave_mosi"),
        # PDM2PCM
        Inout("pdm2pcm_pdm"),
        Inout("pdm2pcm_clk"),
        # I2S
        Inout("i2s_sck"),
        Inout("i2s_ws"),
        Inout("i2s_sd"),
        # SPI2
        Inout("spi2_cs_0"),
        Inout("spi2_cs_1"),
        Inout("spi2_sck"),
        Inout("spi2_sd_0"),
        Inout("spi2_sd_1"),
        Inout("spi2_sd_2"),
        Inout("spi2_sd_3"),
        # I2C
        Inout("i2c_scl"),
        Inout("i2c_sda"),
        # Serial link DDR
        Input("ddr_rcv_clk"),
        Output("ddr_snd_clk"),
        Input("ddr_rcv_0"),
        Input("ddr_rcv_1"),
        Input("ddr_rcv_2"),
        Input("ddr_rcv_3"),
        Output("ddr_snd_0"),
        Output("ddr_snd_1"),
        Output("ddr_snd_2"),
        Output("ddr_snd_3"),
        # Camera
        Output("cam_pwnd"),
        Output("cam_rst"),
        Output("cam_xclk"),
        Input("cam_pclk"),
        Input("cam_vsync"),
        Input("cam_href"),
        Input("cam_data_0"),
        Input("cam_data_1"),
        Input("cam_data_2"),
        Input("cam_data_3"),
        Input("cam_data_4"),
        Input("cam_data_5"),
        Input("cam_data_6"),
        Input("cam_data_7"),
    ]

    # Add all gpios at once
    for i in range(32):
        digital_pins.append(Inout(f"gpio_{i}", attributes={"priority": 0}))

    # Generate a pin dict with all these pins
    pin_dict = {}
    for pin in digital_pins:
        pin_dict.update({pin.name: pin})

    ##############################################
    # MAP PINS TO PADS
    # And assign them sides. If you don't care about sides (i.e. just want to simulate and/or FPGA)
    # Just assign them all to the same side, like done here.
    # Multiple pins assigned to the same pad will be multiplexed.

    mapping = {
        Side.TOP: [
            ["clk"],
            ["rst"],
            ["boot_select"],
            ["jtag_tck"],
            ["jtag_tms"],
            ["jtag_trst"],
            ["jtag_tdi"],
            ["jtag_tdo"],
            ["uart_rx"],
            ["uart_tx"],
            ["exit_valid"],
            ["ddr_rcv_clk"],
            ["ddr_snd_clk"],
            ["gpio_0", "cam_pwnd"],
            ["gpio_1", "ddr_rcv_0", "cam_rst"],
            ["gpio_2", "ddr_rcv_1", "cam_xclk"],
            ["gpio_3", "ddr_rcv_2", "cam_pclk"],
            ["gpio_4", "cam_vsync"],
            ["gpio_5", "cam_href"],
            ["gpio_6", "ddr_rcv_3", "cam_data_0"],
            ["gpio_7", "ddr_snd_0", "cam_data_1"],
            ["gpio_8", "ddr_snd_1", "cam_data_2"],
            ["gpio_9", "ddr_snd_2", "cam_data_3"],
            ["gpio_10", "ddr_snd_3", "cam_data_4"],
            ["gpio_11", "cam_data_5"],
            ["gpio_12", "cam_data_6"],
            ["gpio_13", "cam_data_7"],
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

    ##############################################
    # CREATE THE PAD RING

    padring = PadRing(
        floorplan_dimensions=None,
        pin_list=list(pin_dict.values()),
        mapping=mapping,
    )

    # Check the pins attached to each pad so you can do a visual-sanity check
    padring.print_pin_summary()

    return padring
