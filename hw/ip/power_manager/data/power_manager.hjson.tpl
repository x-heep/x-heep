// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

<%
    memory_ss = xheep.memory_ss()
    external_domains = xheep.get_base_peripheral_domain().get_power_manager().get_external_domains()
%>

{ name: "power_manager",
  clock_primary: "clk_i",
  bus_interfaces: [
    { protocol: "reg_iface", direction: "device" }
  ],
  regwidth: "32",
  registers: [
    { name:     "WAKEUP_STATE",
      desc:     "Wake-up state of the system",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "WAKEUP_STATE", desc: "Wake-up state Reg, used by BOOTROM" }
      ]
    }

    { name:     "RESTORE_ADDRESS",
      desc:     "Restore address value",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "31:0", name: "RESTORE_ADDRESS", desc: "Restore address Reg, used by BOOTROM" }
      ]
    }

    { name:     "GLOBAL_POINTER",
      desc:     "Global Pointer value",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "31:0", name: "GLOBAL_POINTER", desc: "Global Reg, used by power manager HAL" }
      ]
    }

    { name:     "EN_WAIT_FOR_INTR",
      desc:     "Enable wait for interrupt",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "31:0", name: "EN_WAIT_FOR_INTR", desc: "Enable wait for interrupt" }
      ]
    }

    { name:     "INTR_STATE",
      desc:     "Interrupt state",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "31:0", name: "INTR_STATE", desc: "Interrupt state Reg" }
      ]
    }

    { name:     "POWER_GATE_CORE",
      desc:     "Used to power gate core",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "POWER_GATE_CORE", desc: "Power Gate Core Reg" }
      ]
    }

    { name:     "POWER_GATE_CORE_ACK",
      desc:     "Used by the core switch to ack the power manager",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hrw",
      fields: [
        { bits: "0", name: "POWER_GATE_CORE_ACK", desc: "Power Gate Core Ack Reg" }
      ]
    }

    { name:     "CPU_RESET_ASSERT_COUNTER",
      desc:     "Counter before resetting the CPU domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "15:0", name: "CPU_RESET_ASSERT_COUNTER", desc: "CPU counter before resetting" }
      ]
    }

    { name:     "CPU_RESET_DEASSERT_COUNTER",
      desc:     "Counter before unreset the CPU domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "15:0", name: "CPU_RESET_DEASSERT_COUNTER", desc: "CPU counter before unresetting" }
      ]
    }

    { name:     "CPU_SWITCH_OFF_COUNTER",
      desc:     "Counter before switching off the CPU domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "15:0", name: "CPU_SWITCH_OFF_COUNTER", desc: "CPU counter before switching off" }
      ]
    }

    { name:     "CPU_SWITCH_ON_COUNTER",
      desc:     "Counter before switching on the CPU domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "15:0", name: "CPU_SWITCH_ON_COUNTER", desc: "CPU counter before switching on" }
      ]
    }

    { name:     "CPU_WAIT_ACK_SWITCH_ON_COUNTER",
      desc:     "Bit to set whether to further wait for the ACK from the core switch after the counter expired",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "CPU_WAIT_ACK_SWITCH_ON_COUNTER", desc: "wait for CPU switch ack before switching on" }
      ]
    }

    { name:     "CPU_ISO_OFF_COUNTER",
      desc:     "Counter before setting off the isolation of the CPU domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "15:0", name: "CPU_ISO_OFF_COUNTER", desc: "CPU counter before setting off isolation" }
      ]
    }

    { name:     "CPU_ISO_ON_COUNTER",
      desc:     "Counter before setting on the isolation of the CPU domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "15:0", name: "CPU_ISO_ON_COUNTER", desc: "CPU counter before setting on isolation" }
      ]
    }

    { name:     "CPU_COUNTERS_STOP",
      desc:     "Bits to stop the counters keeping the done_o signal high",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "CPU_RESET_ASSERT_STOP_BIT_COUNTER", desc: "Stop the CPU_RESET_ASSERT_COUNTER counter" }
        { bits: "1", name: "CPU_RESET_DEASSERT_STOP_BIT_COUNTER", desc: "Stop the CPU_RESET_DEASSERT_COUNTER counter" }
        { bits: "2", name: "CPU_SWITCH_OFF_STOP_BIT_COUNTER", desc: "Stop the CPU_SWITCH_OFF_COUNTER counter" }
        { bits: "3", name: "CPU_SWITCH_ON_STOP_BIT_COUNTER", desc: "Stop the CPU_SWITCH_ON_COUNTER counter" }
        { bits: "4", name: "CPU_ISO_OFF_STOP_BIT_COUNTER", desc: "Stop the CPU_ISO_OFF_COUNTER counter" }
        { bits: "5", name: "CPU_ISO_ON_STOP_BIT_COUNTER", desc: "Stop the CPU_ISO_ON_COUNTER counter" }
      ]
    }

    { name:     "POWER_GATE_PERIPH_ACK",
      desc:     "Used by the periph switch to ack the power manager",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hrw",
      fields: [
        { bits: "0", name: "POWER_GATE_PERIPH_ACK", desc: "Power Gate Periph Ack Reg" }
      ]
    }

    { name:     "PERIPH_RESET",
      desc:     "Reset the PERIPH domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "PERIPH_RESET", desc: "Reset PERIPH domain" }
      ]
    }

    { name:     "PERIPH_SWITCH",
      desc:     "Switch off the PERIPH domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "PERIPH_SWITCH", desc: "Switch off PERIPH domain" }
      ]
    }

    { name:     "PERIPH_WAIT_ACK_SWITCH_ON",
      desc:     "Wait for the PERIPH domain switch ack",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "PERIPH_WAIT_ACK_SWITCH_ON", desc: "Wait PERIPH domain switch ack" }
      ]
    }

    { name:     "PERIPH_ISO",
      desc:     "Set on the isolation of the PERIPH domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "PERIPH_ISO", desc: "Set on isolation of PERIPH domain" }
      ]
    }

    { name:     "PERIPH_CLK_GATE",
      desc:     "Clock-gates the PERIPH domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "PERIPH_CLK_GATE", desc: "Clock-gates the PERIPH domain" }
      ]
    }

% for channel in range(xheep.get_base_peripheral_domain().get_dma().get_num_channels()):
    { name:     "DMA_CH${channel}_CLK_GATE",
      desc:     "Clock-gates the DMA CH${channel}",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "DMA_CH${channel}_CLK_GATE", desc: "Clock-gates the DMA CH${channel}" }
      ]
    }
% endfor

% for bank in memory_ss.iter_ram_banks():
    { name:     "RAM_${bank.name()}_CLK_GATE",
      desc:     "Clock-gates the RAM_${bank.name()} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "RAM_${bank.name()}_CLK_GATE", desc: "Clock-gates the RAM_${bank.name()} domain" }
      ]
    }

    { name:     "POWER_GATE_RAM_BLOCK_${bank.name()}_ACK",
      desc:     "Used by the ram ${bank.name()} switch to ack the power manager",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hrw",
      fields: [
        { bits: "0", name: "POWER_GATE_RAM_BLOCK_${bank.name()}_ACK", desc: "Power Gate Ram Block ${bank.name()} Ack Reg" }
      ]
    }

    { name:     "RAM_${bank.name()}_SWITCH",
      desc:     "Switch off the RAM_${bank.name()} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "RAM_${bank.name()}_SWITCH", desc: "Switch off RAM_${bank.name()} domain" }
      ]
    }

    { name:     "RAM_${bank.name()}_WAIT_ACK_SWITCH_ON",
      desc:     "Wait for the RAM_${bank.name()} domain switch ack",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "RAM_${bank.name()}_WAIT_ACK_SWITCH_ON", desc: "Wait RAM_${bank.name()} domain switch ack" }
      ]
    }

    { name:     "RAM_${bank.name()}_ISO",
      desc:     "Set on the isolation of the RAM_${bank.name()} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "RAM_${bank.name()}_ISO", desc: "Set on isolation of RAM_${bank.name()} domain" }
      ]
    }

    { name:     "RAM_${bank.name()}_RETENTIVE",
      desc:     "Set on retentive mode for the RAM_${bank.name()} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "RAM_${bank.name()}_RETENTIVE", desc: "Set on retentive mode for RAM_${bank.name()} domain" }
      ]
    }

% endfor
% for ext in range(external_domains):
    { name:     "EXTERNAL_${ext}_CLK_GATE",
      desc:     "Clock-gates the EXTERNAL_${ext} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "EXTERNAL_${ext}_CLK_GATE", desc: "Clock-gates the EXTERNAL_${ext} domain" }
      ]
    }

    { name:     "POWER_GATE_EXTERNAL_${ext}_ACK",
      desc:     "Used by the external ${ext} switch to ack the power manager",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hrw",
      fields: [
        { bits: "0", name: "POWER_GATE_EXTERNAL_${ext}_ACK", desc: "Power Gate External ${ext} Ack Reg" }
      ]
    }

    { name:     "EXTERNAL_${ext}_RESET",
      desc:     "Reset the EXTERNAL_${ext} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "EXTERNAL_${ext}_RESET", desc: "Reset EXTERNAL_${ext} domain" }
      ]
    }

    { name:     "EXTERNAL_${ext}_SWITCH",
      desc:     "Switch off the EXTERNAL_${ext} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "EXTERNAL_${ext}_SWITCH", desc: "Switch off EXTERNAL_${ext} domain" }
      ]
    }

    { name:     "EXTERNAL_${ext}_WAIT_ACK_SWITCH_ON",
      desc:     "Wait for the EXTERNAL_${ext} domain switch ack",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "EXTERNAL_${ext}_WAIT_ACK_SWITCH_ON", desc: "Wait EXTERNAL_${ext} domain switch ack" }
      ]
    }

    { name:     "EXTERNAL_${ext}_ISO",
      desc:     "Set on the isolation of the EXTERNAL_${ext} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "EXTERNAL_${ext}_ISO", desc: "Set on isolation of EXTERNAL_${ext} domain" }
      ]
    }

    { name:     "EXTERNAL_RAM_${ext}_RETENTIVE",
      desc:     "Set on retentive mode for external RAM_${ext} domain",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "EXTERNAL_RAM_${ext}_RETENTIVE", desc: "Set on retentive mode of external RAM_${ext} domain" }
      ]
    }

% endfor
    { name:     "MONITOR_POWER_GATE_CORE",
      desc:     "Used to monitor the signals to power gate core",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hwo",
      fields: [
        { bits: "2:0", name: "MONITOR_POWER_GATE_CORE", desc: "Monitor Signals Power Gate Core Reg" }
      ]
    }

    { name:     "MONITOR_POWER_GATE_PERIPH",
      desc:     "Used to monitor the signals to power gate periph",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hwo",
      fields: [
        { bits: "2:0", name: "MONITOR_POWER_GATE_PERIPH", desc: "Monitor Signals Power Gate Periph Reg" }
      ]
    }

% for bank in memory_ss.iter_ram_banks():
    { name:     "MONITOR_POWER_GATE_RAM_BLOCK_${bank.name()}",
      desc:     "Used to monitor the signals to power gate ram block ${bank.name()}",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hwo",
      fields: [
        { bits: "1:0", name: "MONITOR_POWER_GATE_RAM_BLOCK_${bank.name()}", desc: "Monitor Signals Power Gate Ram Block ${bank.name()} Reg" }
      ]
    }

% endfor
% for ext in range(external_domains):
    { name:     "MONITOR_POWER_GATE_EXTERNAL_${ext}",
      desc:     "Used to monitor the signals to power gate external ${ext}",
      resval:   "0x00000000"
      swaccess: "ro",
      hwaccess: "hwo",
      fields: [
        { bits: "2:0", name: "MONITOR_POWER_GATE_EXTERNAL_${ext}", desc: "Monitor Signals Power Gate External ${ext} Reg" }
      ]
    }

% endfor
    { name:     "MASTER_CPU_FORCE_SWITCH_OFF",
      desc:     "Used to force core switch off",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "MASTER_CPU_FORCE_SWITCH_OFF", desc: "Force Core Switch Off Reg, used by JTAG" }
      ]
    }

    { name:     "MASTER_CPU_FORCE_SWITCH_ON",
      desc:     "Used to force core switch on",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "MASTER_CPU_FORCE_SWITCH_ON", desc: "Force Core Switch On Reg, used by JTAG" }
      ]
    }

    { name:     "MASTER_CPU_FORCE_RESET_ASSERT",
      desc:     "Used to force core reset assert",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "MASTER_CPU_FORCE_RESET_ASSERT", desc: "Force Core Reset Assert Reg, used by JTAG" }
      ]
    }

    { name:     "MASTER_CPU_FORCE_RESET_DEASSERT",
      desc:     "Used to force core reset deassert",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "MASTER_CPU_FORCE_RESET_DEASSERT", desc: "Force Core Reset Deassert Reg, used by JTAG" }
      ]
    }

    { name:     "MASTER_CPU_FORCE_ISO_OFF",
      desc:     "Used to force core iso off",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "MASTER_CPU_FORCE_ISO_OFF", desc: "Force Core Iso Off Reg, used by JTAG" }
      ]
    }

    { name:     "MASTER_CPU_FORCE_ISO_ON",
      desc:     "Used to force core iso on",
      resval:   "0x00000000"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0", name: "MASTER_CPU_FORCE_ISO_ON", desc: "Force Core Iso On Reg, used by JTAG" }
      ]
    }

   ]
}
