// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


<%
  user_peripheral_domain = xheep.get_user_peripheral_domain()
  base_peripheral_domain = xheep.get_base_peripheral_domain()
  dma = base_peripheral_domain.get_dma()
%>

{ name: "soc_ctrl"
  clock_primary: "clk_i"
  bus_interfaces: [
    { protocol: "reg_iface", direction: "device" }
  ]
  regwidth: "32"
  registers: [
    { name:     "EXIT_VALID"
      desc:     "Exit Valid - Used to write exit valid bit"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "0", name: "EXIT_VALID", desc: "Exit Valid Reg" }
      ]
    }
    { name:     "EXIT_VALUE"
      desc:     "Exit Value - Used to write exit value register"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "31:0", name: "EXIT_VALUE", desc: "Exit Value Reg" }
      ]
    }
    { name:     "BOOT_SELECT"
      desc:     "Boot Select Value - Used to decide whether to boot from JTAG or FLASH"
      swaccess: "ro"
      hwaccess: "hrw"
      fields: [
        { bits: "0", name: "BOOT_SELECT", desc: "Boot Select Reg" }
      ]
    }
    { name:     "BOOT_EXIT_LOOP"
      desc:     "Boot Exit Loop Value - Set externally (e.g. JTAG, TESTBENCH, or another MASTER) to make the CPU jump to the main function entry"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "0", name: "BOOT_EXIT_LOOP", desc: "Boot Exit Reg" }
      ]
    }
    { name:     "BOOT_ADDRESS"
      desc:     "Boot Address Value - Used in the boot rom or power-on-reset functions"
      resval:   "0x00000180"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "31:0", name: "BOOT_ADDRESS", desc: "Boot Address Reg" }
      ]
    }
    { name:     "SYSTEM_FREQUENCY_HZ"
      desc:     "System Frequency Value - Used to know and set at which frequency the system is running (in Hz)"
      resval:   "0x1"
      swaccess: "rw"
      hwaccess: "none"
      fields: [
        { bits: "31:0", name: "SYSTEM_FREQUENCY_HZ", desc: "Contains the value in Hz of the frequency the system is running" }
      ]
    }
    { name:     "XHEEP_ID"
      desc:     "In case of multiple X-HEEP instances, it tells you the X-HEEP instance id"
      swaccess: "ro"
      hwaccess: "none"
      fields: [
        { bits: "31:0", name: "XHEEP_ID", desc: "X-HEEP instance id" }
      ]
    }
    { name:     "XHEEP_AO_PERIPHERAL_CONFIG"
      desc:     "Tells you about the ao_peripheral config"
      swaccess: "ro"
      hwaccess: "none"
      fields: [
        { bits: "0", name: "SPI_FLASH", desc: "X-HEEP has SPI_FLASH", resval: "${'0x1' if base_peripheral_domain.contains_peripheral("spi_flash") else '0x0'}" }
        { bits: "1", name: "DMA", desc: "X-HEEP has DMA", resval: "${'0x1' if dma.get_is_included() else '0x0'}" }
        { bits: "2", name: "PAD_CONTROL", desc: "X-HEEP has PAD_CONTROL", resval: "${'0x1' if base_peripheral_domain.contains_peripheral("pad_control") else '0x0'}" }
        { bits: "3", name: "GPIO_AO", desc: "X-HEEP has GPIO_AO", resval: "${'0x1' if base_peripheral_domain.contains_peripheral("gpio_ao") else '0x0'}" }
      ]
    }
    { name:     "XHEEP_PERIPHERAL_CONFIG"
      desc:     "Tells you about the peripheral config"
      swaccess: "ro"
      hwaccess: "none"
      fields: [
        { bits: "0", name: "RV_PLIC", desc: "X-HEEP has RV_PLIC", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("rv_plic") else '0x0'}" }
        { bits: "1", name: "SPI_HOST", desc: "X-HEEP has SPI_HOST", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("spi_host") else '0x0'}" }
        { bits: "2", name: "GPIO", desc: "X-HEEP has GPIO", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("gpio") else '0x0'}" }
        { bits: "3", name: "I2C", desc: "X-HEEP has I2C", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("i2c") else '0x0'}" }
        { bits: "4", name: "RV_TIMER", desc: "X-HEEP has RV_TIMER", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("rv_timer") else '0x0'}" }
        { bits: "5", name: "SPI2", desc: "X-HEEP has SPI2", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("spi2") else '0x0'}" }
        { bits: "6", name: "PDM2PCM", desc: "X-HEEP has PDM2PCM", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("pdm2pcm") else '0x0'}" }
        { bits: "7", name: "I2S", desc: "X-HEEP has I2S", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("i2s") else '0x0'}" }
        { bits: "8", name: "UART", desc: "X-HEEP has UART", resval: "${'0x1' if user_peripheral_domain.contains_peripheral("uart") else '0x0'}" }
      ]
    }
   ]
}
