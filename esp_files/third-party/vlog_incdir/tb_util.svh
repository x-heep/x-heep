// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

`ifndef SYNTHESIS
// Task for loading 'mem' with SystemVerilog system task $readmemh()
export "DPI-C" task tb_readHEX;
export "DPI-C" task tb_loadHEX;
export "DPI-C" task tb_writetoSram0;
export "DPI-C" task tb_writetoSram1;
export "DPI-C" task tb_getMemSize;
export "DPI-C" task tb_set_exit_loop;

import core_v_mini_mcu_pkg::*;

task tb_getMemSize;
  output int mem_size;
  mem_size = core_v_mini_mcu_pkg::MEM_SIZE;
endtask

task tb_readHEX;
  input string file;
  output logic [7:0] stimuli[core_v_mini_mcu_pkg::MEM_SIZE];
  $readmemh(file, stimuli);
endtask

task tb_loadHEX;
  input string file;
  //whether to use debug to write to memories
  logic [7:0] stimuli[core_v_mini_mcu_pkg::MEM_SIZE];
  int i, stimuli_base, w_addr, NumBytes;
  logic [31:0] addr;

  tb_readHEX(file, stimuli);
  tb_getMemSize(NumBytes);

`ifndef VERILATOR
  for (i = 0; i < NumBytes; i = i + 4) begin

    @(posedge x_heep_system_i.core_v_mini_mcu_i.clk_i);
    addr = i;
    #1;
    // write to memory
    force x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_req_o = 1'b1;
    force x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_addr_o = addr;
    force x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_we_o = 1'b1;
    force x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_be_o = 4'b1111;
    force x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_wdata_o = {
      stimuli[i+3], stimuli[i+2], stimuli[i+1], stimuli[i]
    };

    while (!x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_gnt_i)
    @(posedge x_heep_system_i.core_v_mini_mcu_i.clk_i);

    #1;
    force x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_req_o = 1'b0;

    wait (x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_rvalid_i);

    #1;

  end

  release x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_req_o;
  release x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_addr_o;
  release x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_we_o;
  release x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_be_o;
  release x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_wdata_o;

`else
  for (i = 0; i < 32768; i = i + 4) begin
    if (((i / 4) & 0) == 0) begin
      w_addr = ((i / 4) >> 0) % 8192;
      tb_writetoSram0(w_addr, stimuli[i+3], stimuli[i+2], stimuli[i+1], stimuli[i]);
    end
  end
  for (i = 32768; i < 65536; i = i + 4) begin
    if (((i / 4) & 0) == 0) begin
      w_addr = ((i / 4) >> 0) % 8192;
      tb_writetoSram1(w_addr, stimuli[i+3], stimuli[i+2], stimuli[i+1], stimuli[i]);
    end
  end

`endif

endtask

task tb_writetoSram0;
  input int addr;
  input [7:0] val3;
  input [7:0] val2;
  input [7:0] val1;
  input [7:0] val0;
`ifdef VCS
  force x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram0_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
  release x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram0_i.tc_ram_i.sram[addr];
`else
  x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram0_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
`endif
endtask

task tb_writetoSram1;
  input int addr;
  input [7:0] val3;
  input [7:0] val2;
  input [7:0] val1;
  input [7:0] val0;
`ifdef VCS
  force x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram1_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
  release x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram1_i.tc_ram_i.sram[addr];
`else
  x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram1_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
`endif
endtask


task tb_set_exit_loop;
`ifdef VCS
  force x_heep_system_i.core_v_mini_mcu_i.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0] = 1'b1;
  release x_heep_system_i.core_v_mini_mcu_i.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0];
`else
  x_heep_system_i.core_v_mini_mcu_i.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0] = 1'b1;
`endif
endtask
`endif
