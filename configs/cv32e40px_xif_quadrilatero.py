from xheep import XHeep
from address_map.address_map import AddressMap
from address_map.address_region import AddressRegion
from cpu.cv32e40px import cv32e40px
from cv_x_if import CvXIf
from bus_type import BusType
from debug_ss.debug_ss import DebugSS
from memory_ss.memory_ss import MemorySS
from memory_ss.linker_section import LinkerSection
from peripherals.base_peripherals import (
    SOC_ctrl,
    Bootrom,
    SPI_flash,
    DMA,
    Power_manager,
    RV_timer_ao,
    Fast_intr_ctrl,
    Ext_peripheral,
    Pad_control,
    GPIO_ao,
)

from peripherals.base_peripherals_domain import BasePeripheralDomain
from peripherals.user_peripherals_domain import UserPeripheralDomain

from peripherals.user_peripherals import (
    RV_plic,
    SPI_host,
    GPIO,
    I2C,
    RV_timer,
    SPI2,
    PDM2PCM,
    I2S,
    UART,
)

from linker_script.linker_script import LinkerScript
from interrupts.interrupts import Interrupts


def config():
    system = XHeep(BusType.NtoM)
    system.set_cpu(cv32e40px())

    system.set_xif(
        CvXIf(
            x_num_rs=2,  # cv32e40px supports 3 but quadrilatero has only 2
            x_id_width=4,
            x_mem_width=32,
            x_rfr_width=32,
            x_rfw_width=32,
            x_misa=0x0,
            x_ecs_xs=0x0,
        )
    )

    memory_ss = MemorySS()
    memory_ss.add_ram_banks([32] * 2)
    memory_ss.add_ram_banks_il(4, 16, "data_interleaved")
    memory_ss.add_linker_section(LinkerSection.by_size("code", 0, 0x000008000))
    memory_ss.add_linker_section(LinkerSection("data", 0x000008000, None))
    system.set_memory_ss(memory_ss)

    system.set_linker_script_config(LinkerScript(stack_size=0x800, heap_size=0x800))

    system.set_debug_ss(DebugSS(has_spi_slave=1))

    address_map = AddressMap()
    address_map.add_region(
        AddressRegion("debug", start_address=0x10000000, length=0x00100000)
    )
    address_map.add_region(
        AddressRegion(
            "base_peripheral_domain", start_address=0x20000000, length=0x00100000
        )
    )
    address_map.add_region(
        AddressRegion(
            "user_peripheral_domain", start_address=0x30000000, length=0x00100000
        )
    )
    address_map.add_region(
        AddressRegion("flash_mem", start_address=0x40000000, length=0x01000000)
    )
    address_map.add_region(
        AddressRegion("serial_link", start_address=0x50000000, length=0x01000000)
    )
    address_map.add_region(
        AddressRegion("ext_slaves", start_address=0xF0000000, length=0x01000000)
    )
    system.set_address_map(address_map)

    # Peripheral domains initialization
    base_peripheral_domain = BasePeripheralDomain()
    user_peripheral_domain = UserPeripheralDomain()

    # Base peripherals. All base peripherals must be added.
    base_peripheral_domain.add_peripheral(SOC_ctrl(0x00000000))
    base_peripheral_domain.add_peripheral(Bootrom(0x00010000))
    base_peripheral_domain.add_peripheral(SPI_flash(0x00020000, 0x00008000))
    base_peripheral_domain.add_peripheral(
        DMA(
            address=0x30000,
            length=0x10000,
            num_channels=4,
            num_master_ports=2,
            num_channels_per_master_port=2,
        )
    )
    base_peripheral_domain.add_peripheral(Power_manager(0x00040000))
    base_peripheral_domain.add_peripheral(RV_timer_ao(0x00050000))
    base_peripheral_domain.add_peripheral(Fast_intr_ctrl(0x00060000))
    base_peripheral_domain.add_peripheral(Ext_peripheral(0x00070000))
    base_peripheral_domain.add_peripheral(Pad_control(0x00080000))
    base_peripheral_domain.add_peripheral(GPIO_ao(0x00090000))

    # User peripherals. All are optional.
    user_peripheral_domain.add_peripheral(RV_plic(0x00000000))
    user_peripheral_domain.add_peripheral(UART(0x00080000))

    # Add the peripheral domains to the system
    system.add_peripheral_domain(base_peripheral_domain)
    system.add_peripheral_domain(user_peripheral_domain)

    # X-HEEP testharness extension
    # Here we enable the "ZFINX" RISC-V extension for the FPU
    testharness_extension = {
        "FPU_SS_ZFINX": 0,
        "QUADRILATERO": 1,  # Enables Matrix custom RISC-V extensions. Admitted values: 1|0.
    }
    system.add_extension("testharness", testharness_extension)

    interrupts = Interrupts()
    interrupts.add_interrupt("null_intr", 0)
    interrupts.add_interrupt("uart_intr_tx_watermark", 1)
    interrupts.add_interrupt("uart_intr_rx_watermark", 2)
    interrupts.add_interrupt("uart_intr_tx_empty", 3)
    interrupts.add_interrupt("uart_intr_rx_overflow", 4)
    interrupts.add_interrupt("uart_intr_rx_frame_err", 5)
    interrupts.add_interrupt("uart_intr_rx_break_err", 6)
    interrupts.add_interrupt("uart_intr_rx_timeout", 7)
    interrupts.add_interrupt("uart_intr_rx_parity_err", 8)
    interrupts.add_interrupt("gpio_intr_8", 9)
    interrupts.add_interrupt("gpio_intr_9", 10)
    interrupts.add_interrupt("gpio_intr_10", 11)
    interrupts.add_interrupt("gpio_intr_11", 12)
    interrupts.add_interrupt("gpio_intr_12", 13)
    interrupts.add_interrupt("gpio_intr_13", 14)
    interrupts.add_interrupt("gpio_intr_14", 15)
    interrupts.add_interrupt("gpio_intr_15", 16)
    interrupts.add_interrupt("gpio_intr_16", 17)
    interrupts.add_interrupt("gpio_intr_17", 18)
    interrupts.add_interrupt("gpio_intr_18", 19)
    interrupts.add_interrupt("gpio_intr_19", 20)
    interrupts.add_interrupt("gpio_intr_20", 21)
    interrupts.add_interrupt("gpio_intr_21", 22)
    interrupts.add_interrupt("gpio_intr_22", 23)
    interrupts.add_interrupt("gpio_intr_23", 24)
    interrupts.add_interrupt("gpio_intr_24", 25)
    interrupts.add_interrupt("gpio_intr_25", 26)
    interrupts.add_interrupt("gpio_intr_26", 27)
    interrupts.add_interrupt("gpio_intr_27", 28)
    interrupts.add_interrupt("gpio_intr_28", 29)
    interrupts.add_interrupt("gpio_intr_29", 30)
    interrupts.add_interrupt("gpio_intr_30", 31)
    interrupts.add_interrupt("gpio_intr_31", 32)
    interrupts.add_interrupt("intr_fmt_watermark", 33)
    interrupts.add_interrupt("intr_rx_watermark", 34)
    interrupts.add_interrupt("intr_fmt_overflow", 35)
    interrupts.add_interrupt("intr_rx_overflow", 36)
    interrupts.add_interrupt("intr_nak", 37)
    interrupts.add_interrupt("intr_scl_interference", 38)
    interrupts.add_interrupt("intr_sda_interference", 39)
    interrupts.add_interrupt("intr_stretch_timeout", 40)
    interrupts.add_interrupt("intr_sda_unstable", 41)
    interrupts.add_interrupt("intr_trans_complete", 42)
    interrupts.add_interrupt("intr_tx_empty", 43)
    interrupts.add_interrupt("intr_tx_nonempty", 44)
    interrupts.add_interrupt("intr_tx_overflow", 45)
    interrupts.add_interrupt("intr_acq_overflow", 46)
    interrupts.add_interrupt("intr_ack_stop", 47)
    interrupts.add_interrupt("intr_host_timeout", 48)
    interrupts.add_interrupt("spi2_intr_event", 49)
    interrupts.add_interrupt("i2s_intr_event", 50)
    interrupts.add_interrupt("w25q128jw_controller_intr_event", 51)
    system.set_interrupts(interrupts)

    return system
