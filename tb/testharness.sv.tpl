// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

`ifdef USE_UPF
import UPF::*;
`endif

<%
  cpu = xheep.cpu()
%>

module testharness #(
    parameter bit FPU_SS_ZFINX                = 1,
    parameter bit QUADRILATERO                = 0,
    parameter bit JTAG_DPI                    = 0,
    parameter bit USE_EXTERNAL_DEVICE_EXAMPLE = 1,
    parameter     CLK_FREQUENCY               = 'd100_000  //KHz
) (
`ifdef VERILATOR
    input  wire         clk_i,
    input  wire         rst_ni,
    input  wire         boot_select_i,
    input  wire         execute_from_flash_i,
    output wire         exit_valid_o,
`else  // VERILATOR
    inout  wire         clk_i,
    inout  wire         rst_ni,
    inout  wire         boot_select_i,
    inout  wire         execute_from_flash_i,
    inout  wire         exit_valid_o,
`endif  // VERILATOR
    output logic [31:0] exit_value_o,

`ifdef SIM_SYSTEMC
    output logic        ext_systemc_req_req_o,
    output logic        ext_systemc_req_we_o,
    output logic [ 3:0] ext_systemc_req_be_o,
    output logic [31:0] ext_systemc_req_addr_o,
    output logic [31:0] ext_systemc_req_wdata_o,

    input  logic        ext_systemc_resp_gnt_i,
    input  logic        ext_systemc_resp_rvalid_i,
    input  logic [31:0] ext_systemc_resp_rdata_i,
`endif
    input  wire         jtag_tck_i,
    input  wire         jtag_tms_i,
    input  wire         jtag_trst_ni,
    input  wire         jtag_tdi_i,
    output wire         jtag_tdo_o
);


  `include "tb_util.svh"

  import obi_pkg::*;
  import reg_pkg::*;
  import fifo_pkg::*;
  import testharness_pkg::*;
  import addr_map_rule_pkg::*;
  import core_v_mini_mcu_pkg::*;

  localparam AO_SPC_NUM = 1;
  localparam AO_SPC_NUM_RND = AO_SPC_NUM == 0 ? 0 : AO_SPC_NUM - 1;
  localparam SWITCH_ACK_LATENCY = 15;
  localparam EXT_XBAR_NMASTER_RND = USE_EXTERNAL_DEVICE_EXAMPLE ? testharness_pkg::EXT_XBAR_NMASTER : 1;
  localparam HEEP_EXT_XBAR_NMASTER = USE_EXTERNAL_DEVICE_EXAMPLE ? testharness_pkg::EXT_XBAR_NMASTER : 0;

  localparam int unsigned LOG_EXT_XBAR_NSLAVE = EXT_XBAR_NSLAVE > 32'd1 ? $clog2(
      EXT_XBAR_NSLAVE
  ) : 32'd1;

  localparam EXT_DOMAINS_RND = core_v_mini_mcu_pkg::EXTERNAL_DOMAINS == 0 ? 1 : core_v_mini_mcu_pkg::EXTERNAL_DOMAINS;
  localparam NEXT_INT_RND = core_v_mini_mcu_pkg::NEXT_INT == 0 ? 1 : core_v_mini_mcu_pkg::NEXT_INT;

  // Internal signals
  // ----------------
  // Global pins
  wire clk;
  wire rst_n;
  wire boot_select;
  wire execute_from_flash;
  wire exit_valid;

  // UART
  wire uart_rx;
  wire uart_tx;
  logic sim_jtag_enable = (JTAG_DPI == 1);

  // JTAG
  wire sim_jtag_tck;
  wire sim_jtag_tms;
  wire sim_jtag_tdi;
  wire sim_jtag_tdo;
  wire sim_jtag_trstn;
  wire mux_jtag_tck;
  wire mux_jtag_tms;
  wire mux_jtag_tdi;
  wire mux_jtag_tdo;
  wire mux_jtag_trstn;
  wire [31:0] gpio;

  // SPI
  wire [3:0] spi_flash_sd_io;
  wire [1:0] spi_flash_csb;
  wire spi_flash_sck;

  wire [3:0] spi_sd_io;
  wire [1:0] spi_csb;
  wire spi_sck;

  logic iffifo_in_ready, iffifo_out_valid;
  logic iffifo_int_o;

  // Im2col SPC interrupt signal
  logic im2col_spc_done_int_o;

  // dLC done signal
  logic dlc_done;
  logic dlc_xing_o;
  logic dlc_dir_o;

  // External DMA slots
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_tx;
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_rx;

  assign ext_dma_slot_tx[0] = iffifo_in_ready;
  assign ext_dma_slot_rx[0] = iffifo_out_valid;
  if (core_v_mini_mcu_pkg::DMA_CH_NUM > 1) begin : gen_dma_slot_tx
    assign ext_dma_slot_tx[core_v_mini_mcu_pkg::DMA_CH_NUM-1:1] = '0;
    assign ext_dma_slot_rx[core_v_mini_mcu_pkg::DMA_CH_NUM-1:1] = '0;
  end

  // External xbar master/slave and peripheral ports
  logic [EXT_PERIPHERALS_PORT_SEL_WIDTH-1:0] ext_periph_select;
  obi_req_t [EXT_XBAR_NMASTER_RND-1:0] ext_master_req;
  obi_req_t [EXT_XBAR_NMASTER_RND-1:0] heep_slave_req;
  obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] ext_master_resp;
  obi_resp_t [EXT_XBAR_NMASTER_RND-1:0] heep_slave_resp;
  obi_req_t heep_core_instr_req;
  obi_resp_t heep_core_instr_resp;
  obi_req_t heep_core_data_req;
  obi_resp_t heep_core_data_resp;
  obi_req_t heep_debug_master_req;
  obi_resp_t heep_debug_master_resp;
  obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_read_req;
  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_read_resp;
  obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_write_req;
  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_write_resp;
  obi_req_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_addr_req;
  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] heep_dma_addr_resp;
  obi_req_t [EXT_XBAR_NSLAVE-1:0] ext_slave_req;
  obi_resp_t [EXT_XBAR_NSLAVE-1:0] ext_slave_resp;
  reg_req_t periph_slave_req;
  reg_rsp_t periph_slave_rsp;

  fifo_req_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_req;
  fifo_resp_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_resp;

  reg_pkg::reg_req_t [testharness_pkg::EXT_NPERIPHERALS-1:0] ext_periph_slv_req;
  reg_pkg::reg_rsp_t [testharness_pkg::EXT_NPERIPHERALS-1:0] ext_periph_slv_rsp;

  // External interrupts
  logic [NEXT_INT_RND-1:0] intr_vector_ext;
  logic memcopy_intr;

  // External subsystems
  logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_switch_n;
  logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY:0];
  logic [EXT_DOMAINS_RND-1:0] cpu_subsystem_powergate_switch_n;
  logic [EXT_DOMAINS_RND-1:0] cpu_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY:0];
  logic [EXT_DOMAINS_RND-1:0] peripheral_subsystem_powergate_switch_n;
  logic [EXT_DOMAINS_RND-1:0] peripheral_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY:0];
  logic [EXT_DOMAINS_RND-1:0] external_subsystem_powergate_iso_n;
  logic [EXT_DOMAINS_RND-1:0] external_subsystem_rst_n;
  logic [EXT_DOMAINS_RND-1:0] external_ram_banks_set_retentive_n;
  logic [EXT_DOMAINS_RND-1:0] external_subsystem_clkgate_en_n;

  // eXtension Interface
  if_xif #(
      .X_NUM_RS(fpu_ss_pkg::X_NUM_RS),
      .X_ID_WIDTH(fpu_ss_pkg::X_ID_WIDTH),
      .X_MEM_WIDTH(fpu_ss_pkg::X_MEM_WIDTH),
      .X_RFR_WIDTH(fpu_ss_pkg::X_RFR_WIDTH),
      .X_RFW_WIDTH(fpu_ss_pkg::X_RFW_WIDTH),
      .X_MISA(fpu_ss_pkg::X_MISA)
  ) ext_if ();

  // External SPC interface signals
  reg_req_t [AO_SPC_NUM_RND:0] ext_ao_peripheral_req;
  reg_rsp_t [AO_SPC_NUM_RND:0] ext_ao_peripheral_resp;

  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_busy;

  always_comb begin
    // All interrupt lines set to zero by default
    for (int i = 0; i < core_v_mini_mcu_pkg::NEXT_INT; i++) begin
      intr_vector_ext[i] = 1'b0;
    end
    // Re-assign the interrupt lines used here
    intr_vector_ext[0] = memcopy_intr;
    intr_vector_ext[1] = iffifo_int_o;
    intr_vector_ext[2] = im2col_spc_done_int_o;
  end

  //log parameters
  initial begin
    $display("%t: the parameter FPU_SS_ZFINX is %x", $time, FPU_SS_ZFINX);
    $display("%t: the parameter QUADRILATERO is %x", $time, QUADRILATERO);
    $display("%t: the parameter JTAG_DPI is %x", $time, JTAG_DPI);
    $display("%t: the parameter EXT_DOMAINS is %x", $time, core_v_mini_mcu_pkg::EXTERNAL_DOMAINS);
    $display("%t: the parameter USE_EXTERNAL_DEVICE_EXAMPLE is %x", $time,
             USE_EXTERNAL_DEVICE_EXAMPLE);
    $display("%t: the parameter CLK_FREQUENCY is %d KHz", $time, CLK_FREQUENCY);
  end

`ifdef USE_UPF
  initial begin
    $display("%t: All Power Supply ON", $time);
    supply_on("VDD", 1.2);
    supply_on("VSS", 0);
  end
`endif

  // -------------
  // X-HEEP SYSTEM
  // -------------
  // Inout pins assignments
  // NOTE: These assignments are needed to avoid a Verilator 5.X error triggered when directly
  // connecting primary input/output ports to inout ports of internal modules. It should be safe
  // to remove this workaround once support for Verilator 4.X is dropped and proper handling of
  // primary inout ports is implemented in the C++ testbench.
  // See https://verilator.org/guide/latest/languages.html#tri-inout for details.
  assign clk = clk_i;
  assign rst_n = rst_ni;
  assign boot_select = boot_select_i;
  assign execute_from_flash = execute_from_flash_i;
  assign exit_valid_o = exit_valid;

  // X-HEEP system instance
  x_heep_system #(
      .EXT_XBAR_NMASTER(HEEP_EXT_XBAR_NMASTER),
      .AO_SPC_NUM(AO_SPC_NUM)
  ) x_heep_system_i (
      .clk_i(clk),
      .rst_ni(rst_n),
      .hart_id_i('0),
      .xheep_instance_id_i('0),
      .jtag_tck_i(mux_jtag_tck),
      .jtag_tms_i(mux_jtag_tms),
      .jtag_trst_ni(mux_jtag_trstn),
      .jtag_tdi_i(mux_jtag_tdi),
      .jtag_tdo_o(mux_jtag_tdo),
      .boot_select_i(boot_select),
      .execute_from_flash_i(execute_from_flash),
      .exit_valid_o(exit_valid),
      .uart_rx_i(uart_rx),
      .uart_tx_o(uart_tx),
      .gpio_0_io(gpio[0]),
      .gpio_1_io(gpio[1]),
      .gpio_2_io(gpio[2]),
      .gpio_3_io(gpio[3]),
      .gpio_4_io(gpio[4]),
      .gpio_5_io(gpio[5]),
      .gpio_6_io(gpio[6]),
      .gpio_7_io(gpio[7]),
      .gpio_8_io(gpio[8]),
      .gpio_9_io(gpio[9]),
      .gpio_10_io(gpio[10]),
      .gpio_11_io(gpio[11]),
      .gpio_12_io(gpio[12]),
      .gpio_13_io(gpio[13]),
      .spi_slave_sck_io(spi_sck),
      .spi_slave_cs_io(spi_csb[0]),
      .spi_slave_miso_io(spi_sd_io[1]),
      .spi_slave_mosi_io(spi_sd_io[0]),
      .spi_flash_sck_io(spi_flash_sck),
      .spi_flash_cs_0_io(spi_flash_csb[0]),
      .spi_flash_cs_1_io(spi_flash_csb[1]),
      .spi_flash_sd_0_io(spi_flash_sd_io[0]),
      .spi_flash_sd_1_io(spi_flash_sd_io[1]),
      .spi_flash_sd_2_io(spi_flash_sd_io[2]),
      .spi_flash_sd_3_io(spi_flash_sd_io[3]),
      .spi_sck_io(spi_sck),
      .spi_cs_0_io(spi_csb[0]),
      .spi_cs_1_io(spi_csb[1]),
      .spi_sd_0_io(spi_sd_io[0]),
      .spi_sd_1_io(spi_sd_io[1]),
      .spi_sd_2_io(spi_sd_io[2]),
      .spi_sd_3_io(spi_sd_io[3]),
      .pdm2pcm_pdm_io(gpio[18]),
      .pdm2pcm_clk_io(gpio[19]),
      .i2s_sck_io(gpio[20]),
      .i2s_ws_io(gpio[21]),
      .i2s_sd_io(gpio[22]),
      .spi2_cs_0_io(gpio[23]),
      .spi2_cs_1_io(gpio[24]),
      .spi2_sck_io(gpio[25]),
      .spi2_sd_0_io(gpio[26]),
      .spi2_sd_1_io(gpio[27]),
      .spi2_sd_2_io(gpio[28]),
      .spi2_sd_3_io(gpio[29]),
      .i2c_scl_io(gpio[31]),
      .i2c_sda_io(gpio[30]),
      .exit_value_o,
      .intr_vector_ext_i(intr_vector_ext),
      .xif_compressed_if(ext_if),
      .xif_issue_if(ext_if),
      .xif_commit_if(ext_if),
      .xif_mem_if(ext_if),
      .xif_mem_result_if(ext_if),
      .xif_result_if(ext_if),
      .ext_xbar_master_req_i(heep_slave_req),
      .ext_xbar_master_resp_o(heep_slave_resp),
      .ext_core_instr_req_o(heep_core_instr_req),
      .ext_core_instr_resp_i(heep_core_instr_resp),
      .ext_core_data_req_o(heep_core_data_req),
      .ext_core_data_resp_i(heep_core_data_resp),
      .ext_debug_master_req_o(heep_debug_master_req),
      .ext_debug_master_resp_i(heep_debug_master_resp),
      .ext_dma_read_req_o(heep_dma_read_req),
      .ext_dma_read_resp_i(heep_dma_read_resp),
      .ext_dma_write_req_o(heep_dma_write_req),
      .ext_dma_write_resp_i(heep_dma_write_resp),
      .ext_dma_addr_req_o(heep_dma_addr_req),
      .ext_dma_addr_resp_i(heep_dma_addr_resp),
      .hw_fifo_req_o(hw_fifo_req),
      .hw_fifo_resp_i(hw_fifo_resp),
      .ext_ao_peripheral_req_i(ext_ao_peripheral_req),
      .ext_ao_peripheral_resp_o(ext_ao_peripheral_resp),
      .ext_peripheral_slave_req_o(periph_slave_req),
      .ext_peripheral_slave_resp_i(periph_slave_rsp),
      .cpu_subsystem_powergate_switch_no(cpu_subsystem_powergate_switch_n),
      .cpu_subsystem_powergate_switch_ack_ni(cpu_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY]),
      .peripheral_subsystem_powergate_switch_no(peripheral_subsystem_powergate_switch_n),
      .peripheral_subsystem_powergate_switch_ack_ni(peripheral_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY]),
      .external_subsystem_powergate_switch_no(external_subsystem_powergate_switch_n),
      .external_subsystem_powergate_switch_ack_ni(external_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY]),
      .external_subsystem_powergate_iso_no(external_subsystem_powergate_iso_n),
      .external_subsystem_rst_no(external_subsystem_rst_n),
      .external_ram_banks_set_retentive_no(external_ram_banks_set_retentive_n),
      .external_subsystem_clkgate_en_no(external_subsystem_clkgate_en_n),
      .ext_dma_slot_tx_i(ext_dma_slot_tx),
      .ext_dma_slot_rx_i(ext_dma_slot_rx),
      .ext_dma_stop_i('0),
      .intr_ext_peripheral_i(gpio[31]),
      .hw_fifo_done_i({{(core_v_mini_mcu_pkg::DMA_CH_NUM - 1) {1'b0}}, dlc_done}),
      .dma_done_o(dma_busy)
  );

  // Testbench external bus
  // ----------------------
  // The external bus connects the external peripherals among them and to
  // the corresponding X-HEEP slave port (to the internal system bus).
  ext_bus #(
      .EXT_XBAR_NMASTER(EXT_XBAR_NMASTER),
      .EXT_XBAR_NSLAVE (EXT_XBAR_NSLAVE)
  ) ext_bus_i (
      .clk_i                   (clk_i),
      .rst_ni                  (rst_ni),
      .addr_map_i              (EXT_XBAR_ADDR_RULES),
      .default_idx_i           (SLOW_MEMORY0_IDX[LOG_EXT_XBAR_NSLAVE-1:0]),
      .heep_core_instr_req_i   (heep_core_instr_req),
      .heep_core_instr_resp_o  (heep_core_instr_resp),
      .heep_core_data_req_i    (heep_core_data_req),
      .heep_core_data_resp_o   (heep_core_data_resp),
      .heep_debug_master_req_i (heep_debug_master_req),
      .heep_debug_master_resp_o(heep_debug_master_resp),
      .heep_dma_read_req_i     (heep_dma_read_req),
      .heep_dma_read_resp_o    (heep_dma_read_resp),
      .heep_dma_write_req_i    (heep_dma_write_req),
      .heep_dma_write_resp_o   (heep_dma_write_resp),
      .heep_dma_addr_req_i     (heep_dma_addr_req),
      .heep_dma_addr_resp_o    (heep_dma_addr_resp),
      .ext_master_req_i        (ext_master_req),
      .ext_master_resp_o       (ext_master_resp),
      .heep_slave_req_o        (heep_slave_req),
      .heep_slave_resp_i       (heep_slave_resp),
      .ext_slave_req_o         (ext_slave_req),
      .ext_slave_resp_i        (ext_slave_resp)
  );

  // Power switch emulation
  // ----------------------
  always_ff @(posedge clk_i) begin : blockName
    for (int unsigned i = 0; i <= SWITCH_ACK_LATENCY; i++) begin
      if (i == 0) begin
        external_subsystem_powergate_switch_ack_n[0] <= external_subsystem_powergate_switch_n;
        cpu_subsystem_powergate_switch_ack_n[0] <= cpu_subsystem_powergate_switch_n;
        peripheral_subsystem_powergate_switch_ack_n[0] <= peripheral_subsystem_powergate_switch_n;
      end else begin
        external_subsystem_powergate_switch_ack_n[i] <= external_subsystem_powergate_switch_ack_n[i-1];
        cpu_subsystem_powergate_switch_ack_n[i] <= cpu_subsystem_powergate_switch_ack_n[i-1];
        peripheral_subsystem_powergate_switch_ack_n[i] <= peripheral_subsystem_powergate_switch_ack_n[i-1];
      end
    end
  end

  uartdpi #(
      .BAUD(CLK_FREQUENCY * 1000 / 20),  // close to maximum baud rate (/16)
      .FREQ(CLK_FREQUENCY * 1000),  //Hz
      .NAME("uart0")
  ) i_uart0 (
      .clk_i,
      .rst_ni,
      .tx_o(uart_rx),
      .rx_i(uart_tx)
  );

  // jtag calls from dpi
  SimJTAG #(
      .TICK_DELAY(1),
      .PORT      (4567)
  ) i_sim_jtag (
      .clock(clk_i),
      .reset(~rst_ni),
      .enable(sim_jtag_enable),
      .init_done(rst_ni),
      .jtag_TCK(sim_jtag_tck),
      .jtag_TMS(sim_jtag_tms),
      .jtag_TDI(sim_jtag_tdi),
      .jtag_TRSTn(sim_jtag_trstn),
      .jtag_TDO_data(sim_jtag_tdo),
      .jtag_TDO_driven(1'b1),
      .exit()
  );

  assign mux_jtag_tck   = JTAG_DPI ? sim_jtag_tck : jtag_tck_i;
  assign mux_jtag_tms   = JTAG_DPI ? sim_jtag_tms : jtag_tms_i;
  assign mux_jtag_tdi   = JTAG_DPI ? sim_jtag_tdi : jtag_tdi_i;
  assign mux_jtag_trstn = JTAG_DPI ? sim_jtag_trstn : jtag_trst_ni;

  assign sim_jtag_tdo   = JTAG_DPI ? mux_jtag_tdo : '0;
  assign jtag_tdo_o     = !JTAG_DPI ? mux_jtag_tdo : '0;

  // External xbar slave example port
  obi_req_t  [EXT_XBAR_NSLAVE-1:0] slow_ram_slave_req;
  obi_resp_t [EXT_XBAR_NSLAVE-1:0] slow_ram_slave_resp;

`ifndef SIM_SYSTEMC

  assign slow_ram_slave_req[SLOW_MEMORY0_IDX] = ext_slave_req[SLOW_MEMORY0_IDX];
  assign ext_slave_resp[SLOW_MEMORY0_IDX]     = slow_ram_slave_resp[SLOW_MEMORY0_IDX];

  assign slow_ram_slave_req[SLOW_MEMORY1_IDX] = ext_slave_req[SLOW_MEMORY1_IDX];
  assign ext_slave_resp[SLOW_MEMORY1_IDX]     = slow_ram_slave_resp[SLOW_MEMORY1_IDX];

`else

  obi_req_t  ext_systemc_req;
  obi_resp_t ext_systemc_resp;

  assign ext_systemc_req_req_o            = ext_systemc_req.req;
  assign ext_systemc_req_we_o             = ext_systemc_req.we;
  assign ext_systemc_req_be_o             = ext_systemc_req.be;
  assign ext_systemc_req_addr_o           = ext_systemc_req.addr;
  assign ext_systemc_req_wdata_o          = ext_systemc_req.wdata;

  assign ext_systemc_resp.gnt             = ext_systemc_resp_gnt_i;
  assign ext_systemc_resp.rvalid          = ext_systemc_resp_rvalid_i;
  assign ext_systemc_resp.rdata           = ext_systemc_resp_rdata_i;

  assign ext_systemc_req                  = ext_slave_req[SLOW_MEMORY0_IDX];
  assign ext_slave_resp[SLOW_MEMORY0_IDX] = ext_systemc_resp;
`endif

  generate
    if (USE_EXTERNAL_DEVICE_EXAMPLE) begin : gen_USE_EXTERNAL_DEVICE_EXAMPLE

`ifndef SIM_SYSTEMC

      // External xbar slave memory example
      slow_memory #(
          .NumWords (8192),
          .DataWidth(32'd32)
      ) slow_ram0_i (
          .clk_i,
          .rst_ni,
          .req_i(slow_ram_slave_req[SLOW_MEMORY0_IDX].req),
          .we_i(slow_ram_slave_req[SLOW_MEMORY0_IDX].we),
          .addr_i(slow_ram_slave_req[SLOW_MEMORY0_IDX].addr[15:2]),
          .wdata_i(slow_ram_slave_req[SLOW_MEMORY0_IDX].wdata),
          .be_i(slow_ram_slave_req[SLOW_MEMORY0_IDX].be),
          // output ports
          .gnt_o(slow_ram_slave_resp[SLOW_MEMORY0_IDX].gnt),
          .rdata_o(slow_ram_slave_resp[SLOW_MEMORY0_IDX].rdata),
          .rvalid_o(slow_ram_slave_resp[SLOW_MEMORY0_IDX].rvalid)
      );

      slow_memory #(
          .NumWords (8192),
          .DataWidth(32'd32)
      ) slow_ram1_i (
          .clk_i,
          .rst_ni,
          .req_i(slow_ram_slave_req[SLOW_MEMORY1_IDX].req),
          .we_i(slow_ram_slave_req[SLOW_MEMORY1_IDX].we),
          .addr_i(slow_ram_slave_req[SLOW_MEMORY1_IDX].addr[15:2]),
          .wdata_i(slow_ram_slave_req[SLOW_MEMORY1_IDX].wdata),
          .be_i(slow_ram_slave_req[SLOW_MEMORY1_IDX].be),
          // output ports
          .gnt_o(slow_ram_slave_resp[SLOW_MEMORY1_IDX].gnt),
          .rdata_o(slow_ram_slave_resp[SLOW_MEMORY1_IDX].rdata),
          .rvalid_o(slow_ram_slave_resp[SLOW_MEMORY1_IDX].rvalid)
      );
`endif

      parameter DMA_TRIGGER_SLOT_NUM = 4;

      // External peripheral example with master port to access memory
      dma #(
          .reg_req_t (reg_pkg::reg_req_t),
          .reg_rsp_t (reg_pkg::reg_rsp_t),
          .obi_req_t (obi_pkg::obi_req_t),
          .obi_resp_t(obi_pkg::obi_resp_t),
          .SLOT_NUM  (DMA_TRIGGER_SLOT_NUM)
      ) dma_i (
          .clk_i,
          .rst_ni,
          .clk_gate_en_ni('1),
          .ext_dma_stop_i('0),
          .hw_fifo_done_i('0),
          .reg_req_i(ext_periph_slv_req[testharness_pkg::MEMCOPY_CTRL_IDX]),
          .reg_rsp_o(ext_periph_slv_rsp[testharness_pkg::MEMCOPY_CTRL_IDX]),
          .dma_read_req_o(ext_master_req[testharness_pkg::EXT_MASTER0_IDX]),
          .dma_read_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER0_IDX]),
          .dma_write_req_o(ext_master_req[testharness_pkg::EXT_MASTER1_IDX]),
          .dma_write_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER1_IDX]),
          .hw_fifo_req_o(),
          .hw_fifo_resp_i(),
          .dma_addr_req_o(),
          .dma_addr_resp_i('0),
          .trigger_slot_i('0),
          .dma_done_intr_o(memcopy_intr),
          .dma_window_intr_o(),
          .dma_done_o()
      );

      dlc dlc_i (
          .clk_i(clk_i),
          .rst_ni(rst_ni),
          .dlc_done_o(dlc_done),
          .reg_req_i(ext_periph_slv_req[testharness_pkg::DLC_IDX]),
          .reg_rsp_o(ext_periph_slv_rsp[testharness_pkg::DLC_IDX]),
          .hw_fifo_req_i(hw_fifo_req[0]),
          .hw_fifo_resp_o(hw_fifo_resp[0]),
          .dlc_xing_o,
          .dlc_dir_o
      );

      simple_accelerator #(
          .reg_req_t (reg_pkg::reg_req_t),
          .reg_rsp_t (reg_pkg::reg_rsp_t),
          .obi_req_t (obi_pkg::obi_req_t),
          .obi_resp_t(obi_pkg::obi_resp_t)
      ) simple_accelerator_i (
          .clk_i,
          .rst_ni,
          .reg_req_i(ext_periph_slv_req[testharness_pkg::SIMPLE_ACC_IDX]),
          .reg_rsp_o(ext_periph_slv_rsp[testharness_pkg::SIMPLE_ACC_IDX]),
          .acc_read_ch0_req_o(ext_master_req[testharness_pkg::EXT_MASTER2_IDX]),
          .acc_read_ch0_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER2_IDX]),
          .acc_write_ch0_req_o(ext_master_req[testharness_pkg::EXT_MASTER3_IDX]),
          .acc_write_ch0_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER3_IDX])
      );

      im2col_spc im2col_spc_i (
          .clk_i,
          .rst_ni,

          .aopb2im2col_resp_i(ext_ao_peripheral_resp[0]),
          .im2col2aopb_req_o (ext_ao_peripheral_req[0]),

          .reg_req_i(ext_periph_slv_req[testharness_pkg::IM2COL_SPC_IDX]),
          .reg_rsp_o(ext_periph_slv_rsp[testharness_pkg::IM2COL_SPC_IDX]),

          .dma_done_i(dma_busy),
          .im2col_spc_done_int_o(im2col_spc_done_int_o)
      );

      // AMS external peripheral
      ams #(
          .reg_req_t(reg_pkg::reg_req_t),
          .reg_rsp_t(reg_pkg::reg_rsp_t)
      ) ams_i (
          .clk_i,
          .rst_ni,
          .reg_req_i(ext_periph_slv_req[testharness_pkg::AMS_IDX]),
          .reg_rsp_o(ext_periph_slv_rsp[testharness_pkg::AMS_IDX])
      );

      // InterFaced FIFO (IFFIFO) external peripheral
      iffifo #(
          .reg_req_t(reg_pkg::reg_req_t),
          .reg_rsp_t(reg_pkg::reg_rsp_t)
      ) iffifo_i (
          .clk_i,
          .rst_ni,
          .reg_req_i(ext_periph_slv_req[testharness_pkg::IFFIFO_IDX]),
          .reg_rsp_o(ext_periph_slv_rsp[testharness_pkg::IFFIFO_IDX]),
          // DMA slots
          .iffifo_in_ready_o(iffifo_in_ready),
          .iffifo_out_valid_o(iffifo_out_valid),
          // Interrupt lines
          .iffifo_int_o(iffifo_int_o)
      );

      addr_decode #(
          .NoIndices(testharness_pkg::EXT_NPERIPHERALS),
          .NoRules(testharness_pkg::EXT_NPERIPHERALS),
          .addr_t(logic [31:0]),
          .rule_t(addr_map_rule_pkg::addr_map_rule_t)
      ) i_addr_decode_soc_regbus_ext_periphs (
          .addr_i(periph_slave_req.addr),
          .addr_map_i(testharness_pkg::EXT_PERIPHERALS_ADDR_RULES),
          .idx_o(ext_periph_select),
          .dec_valid_o(),
          .dec_error_o(),
          .en_default_idx_i(1'b0),
          .default_idx_i('0)
      );

      reg_demux #(
          .NoPorts(testharness_pkg::EXT_NPERIPHERALS),
          .req_t  (reg_pkg::reg_req_t),
          .rsp_t  (reg_pkg::reg_rsp_t)
      ) reg_demux_i (
          .clk_i,
          .rst_ni,
          .in_select_i(ext_periph_select),
          .in_req_i(periph_slave_req),
          .in_rsp_o(periph_slave_rsp),
          .out_req_o(ext_periph_slv_req),
          .out_rsp_i(ext_periph_slv_rsp)
      );

      // GPIO counter example
      gpio_cnt #(
          .CntMax(32'd2048)
      ) gpio_cnt_i (
          .clk_i,
          .rst_ni,
          .gpio_i(gpio[30]),
          .gpio_o(gpio[31])
      );

      pdm2pcm_dummy pdm2pcm_dummy_i (
          .clk_i,
          .rst_ni,
          .pdm_data_o(gpio[18]),
          .pdm_clk_i (gpio[19])
      );

      // I2s "microphone"/rx example
      i2s_microphone i2s_microphone_i (
          .rst_ni(rst_ni),
          .i2s_sck_i(gpio[20]),
          .i2s_ws_i(gpio[21]),
          .i2s_sd_o(gpio[22])
      );

      // Flash used for booting (execute from flash or copy from flash)
      spiflash flash_boot_i (
          .csb(spi_flash_csb[0]),
          .clk(spi_flash_sck),
          .io0(spi_flash_sd_io[0]),  // MOSI
          .io1(spi_flash_sd_io[1]),  // MISO
          .io2(spi_flash_sd_io[2]),
          .io3(spi_flash_sd_io[3])
      );

      if ((core_v_mini_mcu_pkg::CpuType == cv32e40x || core_v_mini_mcu_pkg::CpuType == cv32e40px || (FPU_SS_ZFINX && core_v_mini_mcu_pkg::CpuType == cv32e20)) && ${cpu.get_sv_str("cv_x_if") if cpu.is_defined("cv_x_if") else "0"} && (QUADRILATERO == 0)) begin: gen_fpu_ss_wrapper
        fpu_ss_wrapper #(
            .PULP_ZFINX(FPU_SS_ZFINX),
            .INPUT_BUFFER_DEPTH(1),
            .OUT_OF_ORDER(0),
            .FORWARDING(1),
            .FPU_FEATURES(fpu_ss_pkg::FPU_FEATURES),
            .FPU_IMPLEMENTATION(fpu_ss_pkg::FPU_IMPLEMENTATION)
        ) fpu_ss_wrapper_i (
            // Clock and reset
            .clk_i,
            .rst_ni,

            // eXtension Interface
            .xif_compressed_if(ext_if),
            .xif_issue_if(ext_if),
            .xif_commit_if(ext_if),
            .xif_mem_if(ext_if),
            .xif_mem_result_if(ext_if),
            .xif_result_if(ext_if)
        );
      end
      if ((core_v_mini_mcu_pkg::CpuType == cv32e40x || core_v_mini_mcu_pkg::CpuType == cv32e40px || core_v_mini_mcu_pkg::CpuType == cv32e20) && ${cpu.get_sv_str("cv_x_if") if cpu.is_defined("cv_x_if") else "0"} && (QUADRILATERO != 0)) begin: gen_quadrilatero_wrapper
        quadrilatero_wrapper #(
            .MATRIX_FPU(0)
        ) quadrilatero_wrapper_i (
            .clk_i,
            .rst_ni,
            // eXtension Interface
            .xif_compressed_if      (ext_if),
            .xif_issue_if           (ext_if),
            .xif_commit_if          (ext_if),
            .xif_mem_if             (ext_if),
            .xif_mem_result_if      (ext_if),
            .xif_result_if          (ext_if),
            // OBI signals 
            .quadrilatero_ch0_req_o (ext_master_req[testharness_pkg::EXT_MASTER4_IDX]),
            .quadrilatero_ch0_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER4_IDX]),
            .quadrilatero_ch1_req_o (ext_master_req[testharness_pkg::EXT_MASTER5_IDX]),
            .quadrilatero_ch1_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER5_IDX]),
            .quadrilatero_ch2_req_o (ext_master_req[testharness_pkg::EXT_MASTER6_IDX]),
            .quadrilatero_ch2_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER6_IDX]),
            .quadrilatero_ch3_req_o (ext_master_req[testharness_pkg::EXT_MASTER7_IDX]),
            .quadrilatero_ch3_resp_i(ext_master_resp[testharness_pkg::EXT_MASTER7_IDX])
        );
      end else begin : gen_no_quadrilatero_wrapper

        // Tie-off unused Quadrilatero master ports
        assign ext_master_req[testharness_pkg::EXT_MASTER4_IDX] = '0;
        assign ext_master_req[testharness_pkg::EXT_MASTER5_IDX] = '0;
        assign ext_master_req[testharness_pkg::EXT_MASTER6_IDX] = '0;
        assign ext_master_req[testharness_pkg::EXT_MASTER7_IDX] = '0;

      end

    end else begin : gen_DONT_USE_EXTERNAL_DEVICE_EXAMPLE
      assign slow_ram_slave_resp[0].gnt = '0;
      assign slow_ram_slave_resp[0].rdata = '0;
      assign slow_ram_slave_resp[0].rvalid = '0;
      assign slow_ram_slave_resp[1].gnt = '0;
      assign slow_ram_slave_resp[1].rdata = '0;
      assign slow_ram_slave_resp[1].rvalid = '0;

      assign ext_periph_slv_req = '0;
      assign ext_periph_slv_rsp = '0;

      assign ext_master_req[testharness_pkg::EXT_MASTER0_IDX].req = '0;
      assign ext_master_req[testharness_pkg::EXT_MASTER0_IDX].we = '0;
      assign ext_master_req[testharness_pkg::EXT_MASTER0_IDX].be = '0;
      assign ext_master_req[testharness_pkg::EXT_MASTER0_IDX].addr = '0;
      assign ext_master_req[testharness_pkg::EXT_MASTER0_IDX].wdata = '0;

      assign memcopy_intr = '0;
      assign iffifo_int_o = '0;
      assign periph_slave_rsp = '0;
      assign im2col_spc_done_int_o = '0;

    end
  endgenerate

endmodule  // testharness
