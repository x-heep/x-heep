# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import hjson

from peripherals.base_peripherals_domain import BasePeripheralDomain
from peripherals.user_peripherals_domain import UserPeripheralDomain
from peripherals.base_peripherals import (
    SOC_ctrl,
    Bootrom,
    SPI_flash,
    SPI_memio,
    W25Q128JW_Controller,
    DMA,
    Power_manager,
    RV_timer_ao,
    Fast_intr_ctrl,
    Ext_peripheral,
    Pad_control,
    GPIO_ao,
)
from .user_peripherals import (
    RV_plic,
    SPI_host,
    GPIO,
    I2C,
    RV_timer,
    SPI2,
    PDM2PCM,
    I2S,
    UART,
    SerialLinkReg,
    SerialLinkReceiverFifo,
    SerialLinkWrapperReg,
)


def load_peripherals_config(system, config: hjson.OrderedDict):
    """
    Load peripheral configurations from HJSON and add them to the system.

    :param System system: The system to which peripherals will be added
    :param hjson.OrderedDict config: The HJSON configuration dictionary
    """

    # Define peripheral factory maps
    # Base peripherals are always-on peripherals in the AO (Always On) domain
    base_peripheral_factories = {
        "soc_ctrl": lambda o, l: SOC_ctrl(o, l),
        "bootrom": lambda o, l: Bootrom(o, l),
        "spi_flash": lambda o, l: SPI_flash(o, l),
        "spi_memio": lambda o, l: SPI_memio(o, l),
        "w25q128jw_controller": lambda o, l: W25Q128JW_Controller(o, l),
        "dma": _create_dma_peripheral,  # Special handling for complex DMA config
        "power_manager": lambda o, l: Power_manager(o, l),
        "rv_timer_ao": lambda o, l: RV_timer_ao(o, l),
        "fast_intr_ctrl": lambda o, l: Fast_intr_ctrl(o, l),
        "ext_peripheral": lambda o, l: Ext_peripheral(o, l),
        "pad_control": lambda o, l: Pad_control(o, l),
        "gpio_ao": lambda o, l: GPIO_ao(o, l),
    }

    # User peripherals are peripherals in the user-controllable domain
    user_peripheral_factories = {
        "rv_plic": lambda o, l: RV_plic(o, l),
        "spi_host": lambda o, l: SPI_host(o, l),
        "gpio": lambda o, l: GPIO(o, l),
        "i2c": lambda o, l: I2C(o, l),
        "rv_timer": lambda o, l: RV_timer(o, l),
        "spi2": lambda o, l: SPI2(o, l),
        "pdm2pcm": lambda o, l: PDM2PCM(o, l),
        "i2s": lambda o, l: I2S(o, l),
        "uart": lambda o, l: UART(o, l),
        "serial_link_reg": lambda o, l: SerialLinkReg(o, l),
        "serial_link_receiver_fifo": lambda o, l: SerialLinkReceiverFifo(o, l),
        "serial_link_wrapper_mux": lambda o, l: SerialLinkWrapperReg(o, l),
    }

    for name, fields in config.items():
        # Base Peripherals (Always-On Domain)
        if name == "ao_peripherals":
            _load_domain_peripherals(
                system=system,
                fields=fields,
                domain_type="base",
                peripheral_factory_map=base_peripheral_factories,
                domain_constructor=BasePeripheralDomain,
                are_configured_check=system.are_base_peripherals_configured,
                get_domain_attr=lambda: system._base_peripheral_domain,
            )

        # User Peripherals (User Domain)
        elif name == "peripherals":
            _load_domain_peripherals(
                system=system,
                fields=fields,
                domain_type="user",
                peripheral_factory_map=user_peripheral_factories,
                domain_constructor=UserPeripheralDomain,
                are_configured_check=system.are_user_peripherals_configured,
                get_domain_attr=lambda: system._user_peripheral_domain,
            )


def _create_dma_peripheral(peripheral_config, offset, length):
    """
    Create DMA peripheral with its complex configuration.

    DMA peripherals require special handling because they have extensive
    configuration parameters beyond just memory offset and length. This
    factory function encapsulates all DMA-specific configuration logic.

    Configuration Parameters:
    -------------------------
    - is_included: Whether DMA is enabled (default: "yes")
    - addr_mode_en: Enable address mode (yes/no)
    - subaddr_mode_en: Enable subaddress mode (yes/no)
    - hw_fifo_mode_en: Enable hardware FIFO mode (yes/no)
    - zero_padding_en: Enable zero padding (yes/no)
    - ch_length: Length of each DMA channel (hex string)
    - num_channels: Number of DMA channels (hex string)
    - num_master_ports: Number of master ports (hex string)
    - num_channels_per_master_port: Channels per master port (hex string)
    - fifo_depth: Depth of FIFO buffer (hex string)

    When DMA is not included (is_included="no"), minimal default values
    are used to ensure the system can still be generated with a stubbed
    DMA peripheral.

    :param dict peripheral_config: DMA configuration dictionary
    :param int offset: Memory address offset for DMA peripheral
    :param int length: Memory length allocated to DMA peripheral
    :return: Configured DMA peripheral instance
    :rtype: DMA
    :raises ValueError: If mode parameters are not "yes" or "no"
    """
    try:
        dma_is_included = (
            "yes" if peripheral_config.get("is_included", "yes") == "yes" else "no"
        )
    except (KeyError, AttributeError):
        dma_is_included = "yes"

    if dma_is_included == "yes":
        addr_mode_en = peripheral_config["addr_mode_en"]
        subaddr_mode_en = peripheral_config["subaddr_mode_en"]
        hw_fifo_mode_en = peripheral_config["hw_fifo_mode_en"]
        zero_padding_en = peripheral_config["zero_padding_en"]

        # Validate yes/no values
        for param_name, param_value in [
            ("addr_mode_en", addr_mode_en),
            ("subaddr_mode_en", subaddr_mode_en),
            ("hw_fifo_mode_en", hw_fifo_mode_en),
            ("zero_padding_en", zero_padding_en),
        ]:
            if param_value not in ["no", "yes"]:
                raise ValueError(f"{param_name} should be no or yes")

        ch_length = int(peripheral_config["ch_length"], 16)
        num_channels = int(peripheral_config["num_channels"], 16)
        num_master_ports = int(peripheral_config["num_master_ports"], 16)
        num_channels_per_master_port = int(
            peripheral_config["num_channels_per_master_port"], 16
        )
        fifo_depth = int(peripheral_config["fifo_depth"], 16)
    else:
        # Use minimal defaults when DMA is not included
        addr_mode_en = "no"
        subaddr_mode_en = "no"
        hw_fifo_mode_en = "no"
        zero_padding_en = "no"
        ch_length = int("0x100", 16)
        num_channels = int("0x1", 16)
        num_master_ports = int("0x1", 16)
        num_channels_per_master_port = int("0x1", 16)
        fifo_depth = int("0x4", 16)

    return DMA(
        is_included=dma_is_included,
        address=offset,
        length=length,
        ch_length=ch_length,
        num_channels=num_channels,
        num_master_ports=num_master_ports,
        num_channels_per_master_port=num_channels_per_master_port,
        fifo_depth=fifo_depth,
        addr_mode=addr_mode_en,
        subaddr_mode=subaddr_mode_en,
        hw_fifo_mode=hw_fifo_mode_en,
        zero_padding=zero_padding_en,
    )


def _load_domain_peripherals(
    system,
    fields,
    domain_type,
    peripheral_factory_map,
    domain_constructor,
    are_configured_check,
    get_domain_attr,
):
    """
    Load peripherals for a specific domain (base or user) from configuration.

    :param System system: The system to which peripherals will be added
    :param dict fields: The configuration fields for the peripheral domain
    :param str domain_type: The type of domain ("base" or "user")
    :param dict peripheral_factory_map: Mapping of peripheral names to factory functions for this domain
    :param function domain_constructor: Constructor function for the peripheral domain
    :param function are_configured_check: Function to check if the domain is already configured
    :param function get_domain_attr: Function to get the existing domain attribute from the system
    """

    # Create peripheral domain if not already configured
    domain = (
        domain_constructor(int(fields["address"], 16), int(fields["length"], 16))
        if not are_configured_check()
        else None
    )

    if domain is None:
        return

    # Iterate over all peripherals and create corresponding objects
    for peripheral_name, peripheral_config in fields.items():
        if peripheral_name in ["address", "length"]:
            continue

        # Skip if peripheral was already added by python configuration
        if are_configured_check() and get_domain_attr().contains_peripheral(
            peripheral_name
        ):
            continue

        # Check if peripheral should be included
        try:
            is_included = peripheral_config.get("is_included", "yes")
            # Special case for base peripherals: DMA is always included
            if (
                domain_type == "base"
                and peripheral_name != "dma"
                and is_included == "no"
            ):
                continue
            # For user peripherals, skip if not included
            if domain_type == "user" and is_included == "no":
                continue
        except (KeyError, AttributeError):
            pass

        # Create peripheral instance
        peripheral = _create_peripheral_from_config(
            peripheral_name, peripheral_config, peripheral_factory_map
        )

        # Add peripheral to domain
        domain.add_peripheral(peripheral)

    # All peripherals in configuration file have been added
    system.add_peripheral_domain(domain)


def _create_peripheral_from_config(
    peripheral_name, peripheral_config, peripheral_factory_map
):
    """
    Create a peripheral instance from its configuration.

    This function takes a peripheral name, its configuration dictionary, and a mapping of peripheral
    names to factory functions. It extracts the necessary parameters from the configuration and uses
    the appropriate factory function to create and return a peripheral instance.

    :param str peripheral_name: Name of the peripheral to create
    :param dict peripheral_config: Configuration dictionary for the peripheral
    :param dict peripheral_factory_map: Mapping of peripheral names to factory functions
    :return: Configured peripheral instance
    """

    offset = int(peripheral_config["offset"], 16)
    length = int(peripheral_config["length"], 16)

    if peripheral_name not in peripheral_factory_map:
        raise ValueError(f"Peripheral {peripheral_name} does not exist.")

    factory = peripheral_factory_map[peripheral_name]

    # Special handling for DMA (has complex configuration)
    if peripheral_name == "dma":
        return factory(peripheral_config, offset, length)
    else:
        return factory(offset, length)
