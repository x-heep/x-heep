// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

package testharness_pkg;

  import addr_map_rule_pkg::*;
  import core_v_mini_mcu_pkg::*;

  localparam EXT_XBAR_NMASTER = 8;
  localparam EXT_XBAR_NSLAVE = 2;

  //master idx
  localparam logic [31:0] EXT_MASTER0_IDX = 0;
  localparam logic [31:0] EXT_MASTER1_IDX = 1;
  localparam logic [31:0] EXT_MASTER2_IDX = 2;
  localparam logic [31:0] EXT_MASTER3_IDX = 3;
  localparam logic [31:0] EXT_MASTER4_IDX = 4;
  localparam logic [31:0] EXT_MASTER5_IDX = 5;
  localparam logic [31:0] EXT_MASTER6_IDX = 6;
  localparam logic [31:0] EXT_MASTER7_IDX = 7;

  //slave mmap and idx of slow memory interleaved
  localparam logic [31:0] SLOW_MEMORY_START_ADDRESS = core_v_mini_mcu_pkg::EXT_SLAVE_START_ADDRESS;
  localparam logic [31:0] SLOW_MEMORY_SIZE = 32'h400;
  localparam logic [31:0] SLOW_MEMORY_END_ADDRESS = SLOW_MEMORY_START_ADDRESS + SLOW_MEMORY_SIZE;
  localparam logic [31:0] SLOW_MEMORY0_IDX = 32'd0;
  localparam logic [31:0] SLOW_MEMORY1_IDX = 32'd1;

  localparam addr_map_rule_t [EXT_XBAR_NSLAVE-1:0] EXT_XBAR_ADDR_RULES = '{
      '{
          idx: SLOW_MEMORY0_IDX,
          start_addr: SLOW_MEMORY_START_ADDRESS,
          end_addr: SLOW_MEMORY_END_ADDRESS
      },
      '{
          idx: SLOW_MEMORY1_IDX,
          start_addr: SLOW_MEMORY_START_ADDRESS,
          end_addr: SLOW_MEMORY_END_ADDRESS
      }
  };

  //slave encoder
  localparam EXT_NPERIPHERALS = 6;

  // Memcopy controller (external peripheral example)
  localparam logic [31:0] MEMCOPY_CTRL_START_ADDRESS = core_v_mini_mcu_pkg::EXT_PERIPHERAL_START_ADDRESS + 32'h0;
  localparam logic [31:0] MEMCOPY_CTRL_SIZE = 32'h10;
  localparam logic [31:0] MEMCOPY_CTRL_END_ADDRESS = MEMCOPY_CTRL_START_ADDRESS + MEMCOPY_CTRL_SIZE;
  localparam logic [31:0] MEMCOPY_CTRL_IDX = 32'd0;

  // External AMS Peripheral
  localparam logic [31:0] AMS_START_ADDRESS = core_v_mini_mcu_pkg::EXT_PERIPHERAL_START_ADDRESS + 32'h01000;
  localparam logic [31:0] AMS_SIZE = 32'h100;
  localparam logic [31:0] AMS_END_ADDRESS = AMS_START_ADDRESS + AMS_SIZE;
  localparam logic [31:0] AMS_IDX = 32'd1;

  // External InterFaced FIFO (IFFIFO) Peripheral
  localparam logic [31:0] IFFIFO_START_ADDRESS = core_v_mini_mcu_pkg::EXT_PERIPHERAL_START_ADDRESS + 32'h02000;
  localparam logic [31:0] IFFIFO_SIZE = 32'h100;
  localparam logic [31:0] IFFIFO_END_ADDRESS = IFFIFO_START_ADDRESS + IFFIFO_SIZE;
  localparam logic [31:0] IFFIFO_IDX = 32'd2;

  // External Simple Accelerator Peripheral
  localparam logic [31:0] SIMPLE_ACC_START_ADDRESS = core_v_mini_mcu_pkg::EXT_PERIPHERAL_START_ADDRESS + 32'h03000;
  localparam logic [31:0] SIMPLE_ACC_SIZE = 32'h100;
  localparam logic [31:0] SIMPLE_ACC_END_ADDRESS = SIMPLE_ACC_START_ADDRESS + SIMPLE_ACC_SIZE;
  localparam logic [31:0] SIMPLE_ACC_IDX = 32'd3;

  // External im2col SPC Peripheral
  localparam logic [31:0] IM2COL_SPC_START_ADDRESS = core_v_mini_mcu_pkg::EXT_PERIPHERAL_START_ADDRESS + 32'h04000;
  localparam logic [31:0] IM2COL_SPC_SIZE = 32'h100;
  localparam logic [31:0] IM2COL_SPC_END_ADDRESS = IM2COL_SPC_START_ADDRESS + IM2COL_SPC_SIZE;
  localparam logic [31:0] IM2COL_SPC_IDX = 32'd4;

  // External Digital Level Crossing Block Peripheral
  localparam logic [31:0] DLC_START_ADDRESS = core_v_mini_mcu_pkg::EXT_PERIPHERAL_START_ADDRESS + 32'h05000;
  localparam logic [31:0] DLC_SIZE = 32'h100;
  localparam logic [31:0] DLC_END_ADDRESS = DLC_START_ADDRESS + DLC_SIZE;
  localparam logic [31:0] DLC_IDX = 32'd5;

  localparam addr_map_rule_t [EXT_NPERIPHERALS-1:0] EXT_PERIPHERALS_ADDR_RULES = '{
      '{
          idx: MEMCOPY_CTRL_IDX,
          start_addr: MEMCOPY_CTRL_START_ADDRESS,
          end_addr: MEMCOPY_CTRL_END_ADDRESS
      },
      '{idx: AMS_IDX, start_addr: AMS_START_ADDRESS, end_addr: AMS_END_ADDRESS},
      '{idx: IFFIFO_IDX, start_addr: IFFIFO_START_ADDRESS, end_addr: IFFIFO_END_ADDRESS},
      '{
          idx: SIMPLE_ACC_IDX,
          start_addr: SIMPLE_ACC_START_ADDRESS,
          end_addr: SIMPLE_ACC_END_ADDRESS
      },
      '{
          idx: IM2COL_SPC_IDX,
          start_addr: IM2COL_SPC_START_ADDRESS,
          end_addr: IM2COL_SPC_END_ADDRESS
      },
      '{idx: DLC_IDX, start_addr: DLC_START_ADDRESS, end_addr: DLC_END_ADDRESS}
  };

  localparam int unsigned EXT_PERIPHERALS_PORT_SEL_WIDTH = EXT_NPERIPHERALS > 1 ? $clog2(
      EXT_NPERIPHERALS
  ) : 32'd1;

endpackage
