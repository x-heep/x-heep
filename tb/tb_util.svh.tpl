// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
    memory_ss = xheep.memory_ss()
%>

`ifndef SYNTHESIS
// Task for loading 'mem' with SystemVerilog system task $readmemh()
export "DPI-C" task tb_readHEX;
export "DPI-C" task tb_loadHEX;
% for bank in memory_ss.iter_ram_banks():
export "DPI-C" task tb_writetoSram${bank.name()};
% endfor
export "DPI-C" task tb_getMemSize;
export "DPI-C" task tb_set_exit_loop;
export "DPI-C" task load_flash_hex;

import core_v_mini_mcu_pkg::*;
% if xheep.reliability.memory_ecc:
import hsiao_ecc_pkg::*;
% endif

task tb_getMemSize;
  output int mem_size;
  mem_size  = core_v_mini_mcu_pkg::MEM_SIZE;
endtask

task tb_readHEX;
  input string file;
  output logic [7:0] stimuli[core_v_mini_mcu_pkg::MEM_SIZE];
  $readmemh(file, stimuli);
endtask

% if xheep.reliability.memory_ecc:
function automatic logic [38:0] tb_encode_sram_word;
  input logic [31:0] data;
  localparam int unsigned DataWidth = 32;
  localparam int unsigned ProtWidth = hsiao_ecc_pkg::min_ecc(DataWidth);
  localparam bit [hsiao_ecc_pkg::MaxParityWidth-1:0][hsiao_ecc_pkg::MaxTotalWidth-1:0] HsiaoCodes =
      hsiao_ecc_pkg::hsiao_matrix(DataWidth, ProtWidth);

  tb_encode_sram_word[DataWidth-1:0] = data;
  for (int unsigned i = 0; i < ProtWidth; i++) begin
    tb_encode_sram_word[DataWidth+i] = ^(data & HsiaoCodes[i][DataWidth-1:0]);
  end
endfunction

% endif
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

    while(!x_heep_system_i.core_v_mini_mcu_i.debug_subsystem_i.dm_obi_top_i.master_gnt_i)
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
% for bank in memory_ss.iter_ram_banks():
  for (i=${bank.start_address()}; i < ${bank.end_address()}; i = i + 4) begin
    if (((i/4) & ${2**bank.il_level()-1}) == ${bank.il_offset()}) begin
      w_addr = ((i/4) >> ${bank.il_level()}) % ${bank.size()//4};
      tb_writetoSram${bank.name()}(w_addr, stimuli[i+3], stimuli[i+2],
                                          stimuli[i+1], stimuli[i]);
    end
  end
% endfor

`endif

endtask

% for bank in memory_ss.iter_ram_banks():
task tb_writetoSram${bank.name()};
  input int addr;
  input [7:0] val3;
  input [7:0] val2;
  input [7:0] val1;
  input [7:0] val0;
`ifdef VCS
% if (not xheep.reliability.bus_redundant and xheep.reliability.memory_ecc):
  force x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ecc_sram_${bank.name()}_i.ram_i.tc_ram_i.sram[addr] = tb_encode_sram_word({val3, val2, val1, val0});
  release x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ecc_sram_${bank.name()}_i.ram_i.tc_ram_i.sram[addr];
% else:
  force x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram${bank.name()}_i.tc_ram_i.sram[addr] =
% if xheep.reliability.bus_redundant and xheep.reliability.memory_ecc:
      tb_encode_sram_word({val3, val2, val1, val0});
% else:
      {
    val3, val2, val1, val0
  };
% endif
  release x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram${bank.name()}_i.tc_ram_i.sram[addr];
% endif
`else
  // TODO: change this here + add ecc_sram_xheep_wrapper to core file
% if (not xheep.reliability.bus_redundant and xheep.reliability.memory_ecc):
  x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ecc_sram_${bank.name()}_i.ram_i.tc_ram_i.sram[addr] = tb_encode_sram_word({val3, val2, val1, val0});
% else:
  x_heep_system_i.core_v_mini_mcu_i.memory_subsystem_i.ram${bank.name()}_i.tc_ram_i.sram[addr] =
% if xheep.reliability.bus_redundant and xheep.reliability.memory_ecc:
      tb_encode_sram_word({val3, val2, val1, val0});
% else:
      {
    val3, val2, val1, val0
  };
% endif
% endif
`endif
endtask

% endfor

task tb_set_exit_loop;
`ifdef VCS
  force x_heep_system_i.core_v_mini_mcu_i.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0] = 1'b1;
  release x_heep_system_i.core_v_mini_mcu_i.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0];
`else
  x_heep_system_i.core_v_mini_mcu_i.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0] = 1'b1;
`endif
endtask
`endif

task load_flash_hex;
    input string firmware_file;
    int i;
    for (i=0;i<=16*1024*1024;i=i+1)
        gen_USE_EXTERNAL_DEVICE_EXAMPLE.flash_boot_i.memory[i] = 8'h00;
    $readmemh(firmware_file, gen_USE_EXTERNAL_DEVICE_EXAMPLE.flash_boot_i.memory);
endtask
