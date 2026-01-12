// Copyright 2017 Embecosm Limited <www.embecosm.com>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// System bus for core-v-mini-mcu
// Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>
//              Robert Balas <balasr@student.ethz.ch>
//              Davide Schiavone <davide@openhwgroup.org>
//              Simone Machetti <simone.machetti@epfl.ch>
//              Michele Caon <michele.caon@epfl.ch>

<%
  dma = xheep.get_base_peripheral_domain().get_dma()
  memory_ss = xheep.memory_ss()
%>

module system_bus
  import obi_pkg::*;
  import addr_map_rule_pkg::*;
#(
    parameter NUM_BANKS = 2,
    parameter EXT_XBAR_NMASTER = 0,
    //do not touch these parameters
    parameter EXT_XBAR_NMASTER_RND = EXT_XBAR_NMASTER == 0 ? 1 : EXT_XBAR_NMASTER
) (
    input logic clk_i,
    input logic rst_ni,

    // Internal master ports
    input  obi_req_t  core_instr_req_i,
    output obi_resp_t core_instr_resp_o,

    input  obi_req_t  core_data_req_i,
    output obi_resp_t core_data_resp_o,

    input  obi_req_t  debug_master_req_i,
    output obi_resp_t debug_master_resp_o,

    input  obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_read_req_i,
    output obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_read_resp_o,

    input  obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_write_req_i,
    output obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_write_resp_o,

    input  obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_addr_req_i,
    output obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_addr_resp_o,

    // External master ports
    input  obi_req_t  [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_req_i,
    output obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_master_resp_o,

    // Internal slave ports
    output obi_req_t  [NUM_BANKS-1:0] ram_req_o,
    input  obi_resp_t [NUM_BANKS-1:0] ram_resp_i,

    output obi_req_t  debug_slave_req_o,
    input  obi_resp_t debug_slave_resp_i,

    output obi_req_t  ao_peripheral_slave_req_o,
    input  obi_resp_t ao_peripheral_slave_resp_i,


    output obi_req_t  peripheral_slave_req_o,
    input  obi_resp_t peripheral_slave_resp_i,

    output obi_req_t  flash_mem_slave_req_o,
    input  obi_resp_t flash_mem_slave_resp_i,

    // External slave ports
    output obi_req_t  ext_core_instr_req_o,
    input  obi_resp_t ext_core_instr_resp_i,

    output obi_req_t  ext_core_data_req_o,
    input  obi_resp_t ext_core_data_resp_i,

    output obi_req_t  ext_debug_master_req_o,
    input  obi_resp_t ext_debug_master_resp_i,

    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_read_resp_i,

    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_write_resp_i,

    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] ext_dma_addr_resp_i
);

  import core_v_mini_mcu_pkg::*;

  // Internal master ports
  obi_req_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER-1:0] int_master_req;
  obi_resp_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER-1:0] int_master_resp;

  // Internal + external master ports
  obi_req_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER+EXT_XBAR_NMASTER-1:0] master_req;
  obi_resp_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER+EXT_XBAR_NMASTER-1:0] master_resp;

  // Internal slave ports
  obi_req_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NSLAVE-1:0] int_slave_req;
  obi_resp_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NSLAVE-1:0] int_slave_resp;

  // Error slave ports  
  obi_req_t error_slave_req;
  obi_resp_t error_slave_resp;

  // Forward crossbars ports
  obi_req_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER-1:0][1:0] demux_xbar_req;
  obi_resp_t [core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER-1:0][1:0] demux_xbar_resp;

  // Dummy external master port (to prevent unused warning)
  obi_req_t [EXT_XBAR_NMASTER_RND-1:0] ext_xbar_req_unused;

  assign ext_xbar_req_unused = ext_xbar_master_req_i;

  assign error_slave_resp = '0;

  // Internal master requests
  assign int_master_req[core_v_mini_mcu_pkg::CORE_INSTR_IDX] = core_instr_req_i;
  assign int_master_req[core_v_mini_mcu_pkg::CORE_DATA_IDX] = core_data_req_i;
  assign int_master_req[core_v_mini_mcu_pkg::DEBUG_MASTER_IDX] = debug_master_req_i;

  % for i in range(dma.get_num_master_ports()):
  assign int_master_req[${3+i*3}]  = dma_read_req_i[${i}];
  assign int_master_req[${4+i*3}] = dma_write_req_i[${i}];
  assign int_master_req[${5+i*3}]  = dma_addr_req_i[${i}];
  % endfor

  // Internal + external master requests
  generate
    for (genvar i = 0; i < SYSTEM_XBAR_NMASTER; i++) begin: gen_sys_master_req_map
      assign master_req[i] = demux_xbar_req[i][DEMUX_XBAR_INT_SLAVE_IDX];
    end
    for (genvar i = 0; i < EXT_XBAR_NMASTER; i++) begin : gen_ext_master_req_map
      assign master_req[SYSTEM_XBAR_NMASTER+i] = ext_xbar_master_req_i[i];
    end
  endgenerate

  // Internal master responses
  generate
    for (genvar i = 0; i < SYSTEM_XBAR_NMASTER; i++) begin: gen_demux_master_resp_map
      assign demux_xbar_resp[i][DEMUX_XBAR_INT_SLAVE_IDX] = master_resp[i];
    end
  endgenerate
  assign core_instr_resp_o = int_master_resp[core_v_mini_mcu_pkg::CORE_INSTR_IDX];
  assign core_data_resp_o = int_master_resp[core_v_mini_mcu_pkg::CORE_DATA_IDX];
  assign debug_master_resp_o = int_master_resp[core_v_mini_mcu_pkg::DEBUG_MASTER_IDX];

  % for i in range(dma.get_num_master_ports()):
  assign dma_read_resp_o[${i}] = int_master_resp[${3+i*3}];
  assign dma_write_resp_o[${i}] = int_master_resp[${4+i*3}];
  assign dma_addr_resp_o[${i}] = int_master_resp[${5+i*3}];
  % endfor
  
  // External master responses
  if (EXT_XBAR_NMASTER == 0) begin : gen_no_ext_master_resp
    assign ext_xbar_master_resp_o = '0;
  end else begin : gen_ext_master_resp
    for (genvar i = 0; i < EXT_XBAR_NMASTER; i++) begin : gen_ext_master_resp_map
      assign ext_xbar_master_resp_o[i] = master_resp[core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER+i];
    end
  end

  // Internal slave requests
  assign error_slave_req = int_slave_req[core_v_mini_mcu_pkg::ERROR_IDX];
% for bank in memory_ss.iter_ram_banks():
  assign ram_req_o[${bank.name()}] = int_slave_req[core_v_mini_mcu_pkg::RAM${bank.name()}_IDX];
% endfor
  assign debug_slave_req_o = int_slave_req[core_v_mini_mcu_pkg::DEBUG_IDX];
  assign ao_peripheral_slave_req_o = int_slave_req[core_v_mini_mcu_pkg::AO_PERIPHERAL_IDX];
  assign peripheral_slave_req_o = int_slave_req[core_v_mini_mcu_pkg::PERIPHERAL_IDX];
  assign flash_mem_slave_req_o = int_slave_req[core_v_mini_mcu_pkg::FLASH_MEM_IDX];

  // External slave requests
  assign ext_core_instr_req_o = demux_xbar_req[CORE_INSTR_IDX][DEMUX_XBAR_EXT_SLAVE_IDX];
  assign ext_core_data_req_o = demux_xbar_req[CORE_DATA_IDX][DEMUX_XBAR_EXT_SLAVE_IDX];
  assign ext_debug_master_req_o = demux_xbar_req[DEBUG_MASTER_IDX][DEMUX_XBAR_EXT_SLAVE_IDX];

  generate
    for (genvar i = 0; i < core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS; i++) begin : gen_ext_dma_master_req_map
      assign ext_dma_read_req_o[i] = demux_xbar_req[core_v_mini_mcu_pkg::DMA_READ_P0_IDX+3*i][DEMUX_XBAR_EXT_SLAVE_IDX];
      assign ext_dma_write_req_o[i] = demux_xbar_req[core_v_mini_mcu_pkg::DMA_WRITE_P0_IDX+3*i][DEMUX_XBAR_EXT_SLAVE_IDX];
      assign ext_dma_addr_req_o[i] = demux_xbar_req[core_v_mini_mcu_pkg::DMA_ADDR_P0_IDX+3*i][DEMUX_XBAR_EXT_SLAVE_IDX];
    end
  endgenerate
  

  // Internal slave responses
  assign int_slave_resp[core_v_mini_mcu_pkg::ERROR_IDX] = error_slave_resp;
% for bank in memory_ss.iter_ram_banks():
  assign int_slave_resp[core_v_mini_mcu_pkg::RAM${bank.name()}_IDX] = ram_resp_i[${bank.name()}];
% endfor
  assign int_slave_resp[core_v_mini_mcu_pkg::DEBUG_IDX] = debug_slave_resp_i;
  assign int_slave_resp[core_v_mini_mcu_pkg::AO_PERIPHERAL_IDX] = ao_peripheral_slave_resp_i;
  assign int_slave_resp[core_v_mini_mcu_pkg::PERIPHERAL_IDX] = peripheral_slave_resp_i;
  assign int_slave_resp[core_v_mini_mcu_pkg::FLASH_MEM_IDX] = flash_mem_slave_resp_i;

  // External slave responses
  assign demux_xbar_resp[CORE_INSTR_IDX][DEMUX_XBAR_EXT_SLAVE_IDX] = ext_core_instr_resp_i;
  assign demux_xbar_resp[CORE_DATA_IDX][DEMUX_XBAR_EXT_SLAVE_IDX] = ext_core_data_resp_i;
  assign demux_xbar_resp[DEBUG_MASTER_IDX][DEMUX_XBAR_EXT_SLAVE_IDX] = ext_debug_master_resp_i;

  generate
    for (genvar i = 0; i < core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS; i++) begin : gen_ext_dma_master_resp_map
      assign demux_xbar_resp[core_v_mini_mcu_pkg::DMA_READ_P0_IDX+3*i][DEMUX_XBAR_EXT_SLAVE_IDX] = ext_dma_read_resp_i[i];
      assign demux_xbar_resp[core_v_mini_mcu_pkg::DMA_WRITE_P0_IDX+3*i][DEMUX_XBAR_EXT_SLAVE_IDX] = ext_dma_write_resp_i[i];
      assign demux_xbar_resp[core_v_mini_mcu_pkg::DMA_ADDR_P0_IDX+3*i][DEMUX_XBAR_EXT_SLAVE_IDX] = ext_dma_addr_resp_i[i];
    end
  endgenerate
  
`ifndef SYNTHESIS
  always_ff @(posedge clk_i, negedge rst_ni) begin : check_out_of_bound
    if (rst_ni) begin
      if (error_slave_req.req) begin
        $display("%t Out of bound memory access 0x%08x", $time, error_slave_req.addr);
        $stop;
      end
    end
  end

  // show writes if requested
  always_ff @(posedge clk_i, negedge rst_ni) begin : verbose_writes
    if ($test$plusargs("verbose") != 0 && core_data_req_i.req && core_data_req_i.we)
      $display("write addr=0x%08x: data=0x%08x", core_data_req_i.addr, core_data_req_i.wdata);
  end
`endif

  // 1-to-2 demux crossbars
  // ------------------------
  // These crossbars forward each master to a port on the internal crossbar or
  // to the corresponding external master port.
  generate
    for (genvar i = 0; unsigned'(i) < SYSTEM_XBAR_NMASTER; i++) begin : gen_demux_xbar
      xbar_varlat_one_to_n #(
          .XBAR_NSLAVE (32'd2), // internal crossbar + external crossbar
          .NUM_RULES   (32'd1) // only the external address space is defined
      ) demux_xbar_i (
          .clk_i        (clk_i),
          .rst_ni       (rst_ni),
          .addr_map_i   (DEMUX_XBAR_ADDR_RULES),
          .default_idx_i(DEMUX_XBAR_INT_SLAVE_IDX[0:0]),
          .master_req_i (int_master_req[i]),
          .master_resp_o(int_master_resp[i]),
          .slave_req_o  (demux_xbar_req[i]),
          .slave_resp_i (demux_xbar_resp[i])
      );
    end
  endgenerate

  // Internal system crossbar
  // ------------------------
  system_xbar #(
      .XBAR_NMASTER(core_v_mini_mcu_pkg::SYSTEM_XBAR_NMASTER + EXT_XBAR_NMASTER),
      .XBAR_NSLAVE (core_v_mini_mcu_pkg::SYSTEM_XBAR_NSLAVE)
  ) system_xbar_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .addr_map_i(core_v_mini_mcu_pkg::XBAR_ADDR_RULES),
      .default_idx_i(core_v_mini_mcu_pkg::ERROR_IDX[LOG_SYSTEM_XBAR_NSLAVE-1:0]),
      .master_req_i(master_req),
      .master_resp_o(master_resp),
      .slave_req_o(int_slave_req),
      .slave_resp_i(int_slave_resp)
  );

endmodule
