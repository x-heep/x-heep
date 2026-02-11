from x_heep_gen.xheep import XHeep
from x_heep_gen.cpu.cv32e40px import cv32e40px
from x_heep_gen.cv_x_if import CvXIf
from x_heep_gen.bus_type import BusType
from x_heep_gen.memory_ss.memory_ss import MemorySS
from x_heep_gen.memory_ss.linker_section import LinkerSection
from x_heep_gen.peripherals.base_peripherals import (
    SOC_ctrl,
    Bootrom,
    SPI_flash,
    SPI_memio,
    DMA,
    Power_manager,
    RV_timer_ao,
    Fast_intr_ctrl,
    Ext_peripheral,
    Pad_control,
    GPIO_ao,
)

from x_heep_gen.peripherals.base_peripherals_domain import BasePeripheralDomain
from x_heep_gen.peripherals.user_peripherals_domain import UserPeripheralDomain

from x_heep_gen.peripherals.user_peripherals import (
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

    # Peripheral domains initialization
    base_peripheral_domain = BasePeripheralDomain()
    user_peripheral_domain = UserPeripheralDomain()

    # Base peripherals. All base peripherals must be added. They can be either added with "add_peripheral" or "add_missing_peripherals" (adds all base peripherals).
    base_peripheral_domain.add_peripheral(SOC_ctrl(0x00000000))
    base_peripheral_domain.add_peripheral(Bootrom(0x00010000))
    base_peripheral_domain.add_peripheral(SPI_flash(0x00020000, 0x00008000))
    base_peripheral_domain.add_peripheral(SPI_memio(0x00028000, 0x00008000))
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

    # User peripherals. All are optional. They must be added with "add_peripheral".
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

    return system
