from x_heep_gen.xheep import XHeep
from x_heep_gen.cpu.cpu import CPU
from x_heep_gen.bus_type import BusType
from x_heep_gen.memory_ss.memory_ss import MemorySS
from x_heep_gen.memory_ss.linker_section import LinkerSection
from x_heep_gen.peripherals.base_peripherals_domain import BasePeripheralDomain
from x_heep_gen.peripherals.user_peripherals_domain import UserPeripheralDomain
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
    # Usual system, with every peripheral except PDM2PCM

    system = XHeep(BusType.NtoM)
    system.set_cpu(CPU("cv32e20"))

    memory_ss = MemorySS()
    memory_ss.add_ram_banks([32] * 2)
    memory_ss.add_ram_banks_il(2, 64, "data_interleaved")
    memory_ss.add_linker_section(LinkerSection.by_size("code", 0, 0x00000C800))
    memory_ss.add_linker_section(LinkerSection("data", 0x00000C800, None))
    system.set_memory_ss(memory_ss)

    # Peripheral domains initialization
    base_peripheral_domain = BasePeripheralDomain()
    user_peripheral_domain = UserPeripheralDomain()

    # Base peripherals. All base peripherals must be added. They can be either added with "add_peripheral" or "add_missing_peripherals" (adds all base peripherals).
    base_peripheral_domain.add_missing_peripherals()

    # User peripherals. All are optional. They must be added with "add_peripheral".
    user_peripheral_domain.add_peripheral(RV_plic(0x00000000))
    user_peripheral_domain.add_peripheral(SPI_host(0x00010000))
    user_peripheral_domain.add_peripheral(GPIO(0x00020000))
    user_peripheral_domain.add_peripheral(I2C(0x00030000))
    user_peripheral_domain.add_peripheral(RV_timer(0x00040000))
    user_peripheral_domain.add_peripheral(SPI2(0x00050000))
    user_peripheral_domain.add_peripheral(UART(0x00080000))
    user_peripheral_domain.add_peripheral(
        I2S()
    )  # If no address is provided, the peripheral will be automatically added where there is space.

    # Add the peripheral domains to the system
    system.add_peripheral_domain(base_peripheral_domain)
    system.add_peripheral_domain(user_peripheral_domain)

    return system
