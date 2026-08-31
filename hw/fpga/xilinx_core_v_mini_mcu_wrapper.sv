// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// `define NO_DDR_CLK_PORTS

`ifdef FPGA_VPK180
`include "axi/typedef.svh"
`endif


module xilinx_core_v_mini_mcu_wrapper
  import xheep_obi_pkg::*;
  import xheep_reg_pkg::*;
`ifdef FPGA_VPK180
  import xheep_obi_to_axi_bridge_pkg::*;
`endif
#(
    parameter CLK_LED_COUNT_LENGTH = 27
) (

`ifdef FPGA_ZCU104
    inout logic clk_300mhz_n,
    inout logic clk_300mhz_p,
`elsif FPGA_ZCU102
    inout logic clk_125mhz_n,
    inout logic clk_125mhz_p,
`elsif FPGA_AUP_ZU3
    inout logic clk_100mhz_n,
    inout logic clk_100mhz_p,
`elsif FPGA_GENESYS2
    inout logic clk_200mhz_n,
    inout logic clk_200mhz_p,
`elsif FPGA_VPK180
    input logic lpddr4_clk1_clk_n,
    input logic lpddr4_clk1_clk_p,
    input logic lpddr4_clk3_clk_n,
    input logic lpddr4_clk3_clk_p,
    output logic [5:0] ch0_lpddr4_trip1_ca_a,
    output logic [5:0] ch0_lpddr4_trip1_ca_b,
    output logic ch0_lpddr4_trip1_ck_c_a,
    output logic ch0_lpddr4_trip1_ck_c_b,
    output logic ch0_lpddr4_trip1_ck_t_a,
    output logic ch0_lpddr4_trip1_ck_t_b,
    output logic ch0_lpddr4_trip1_cke_a,
    output logic ch0_lpddr4_trip1_cke_b,
    output logic ch0_lpddr4_trip1_cs_a,
    output logic ch0_lpddr4_trip1_cs_b,
    inout logic [1:0] ch0_lpddr4_trip1_dmi_a,
    inout logic [1:0] ch0_lpddr4_trip1_dmi_b,
    inout logic [15:0] ch0_lpddr4_trip1_dq_a,
    inout logic [15:0] ch0_lpddr4_trip1_dq_b,
    inout logic [1:0] ch0_lpddr4_trip1_dqs_c_a,
    inout logic [1:0] ch0_lpddr4_trip1_dqs_c_b,
    inout logic [1:0] ch0_lpddr4_trip1_dqs_t_a,
    inout logic [1:0] ch0_lpddr4_trip1_dqs_t_b,
    output logic ch0_lpddr4_trip1_reset_n,
    output logic [5:0] ch1_lpddr4_trip1_ca_a,
    output logic [5:0] ch1_lpddr4_trip1_ca_b,
    output logic ch1_lpddr4_trip1_ck_c_a,
    output logic ch1_lpddr4_trip1_ck_c_b,
    output logic ch1_lpddr4_trip1_ck_t_a,
    output logic ch1_lpddr4_trip1_ck_t_b,
    output logic ch1_lpddr4_trip1_cke_a,
    output logic ch1_lpddr4_trip1_cke_b,
    output logic ch1_lpddr4_trip1_cs_a,
    output logic ch1_lpddr4_trip1_cs_b,
    inout logic [1:0] ch1_lpddr4_trip1_dmi_a,
    inout logic [1:0] ch1_lpddr4_trip1_dmi_b,
    inout logic [15:0] ch1_lpddr4_trip1_dq_a,
    inout logic [15:0] ch1_lpddr4_trip1_dq_b,
    inout logic [1:0] ch1_lpddr4_trip1_dqs_c_a,
    inout logic [1:0] ch1_lpddr4_trip1_dqs_c_b,
    inout logic [1:0] ch1_lpddr4_trip1_dqs_t_a,
    inout logic [1:0] ch1_lpddr4_trip1_dqs_t_b,
    output logic ch1_lpddr4_trip1_reset_n,
`elsif FPGA_NEXYS
    inout logic clk_i,
`else
    inout logic clk_i,
`endif

`ifndef NO_DDR_CLK_PORTS
    // Serial Link DDR clock ports for PYNQ Z2 board (set in .core file)
    input  wire ddr_rcv_clk_i,
    output wire ddr_snd_clk_o,
`endif

    inout  logic rst_i,
    output logic rst_led_o,
    output logic clk_led_o,

`ifdef PS_ENABLE
`ifndef FPGA_ZCU104
`ifndef FPGA_ZCU102
`ifndef FPGA_AUP_ZU3
`ifndef FPGA_GENESYS2
`ifndef FPGA_VPK180
    inout [14:0] DDR_addr,
    inout [2:0] DDR_ba,
    inout DDR_cas_n,
    inout DDR_ck_n,
    inout DDR_ck_p,
    inout DDR_cke,
    inout DDR_cs_n,
    inout [3:0] DDR_dm,
    inout [31:0] DDR_dq,
    inout [3:0] DDR_dqs_n,
    inout [3:0] DDR_dqs_p,
    inout DDR_odt,
    inout DDR_ras_n,
    inout DDR_reset_n,
    inout DDR_we_n,
    inout FIXED_IO_ddr_vrn,
    inout FIXED_IO_ddr_vrp,
    inout [53:0] FIXED_IO_mio,
    inout FIXED_IO_ps_clk,
    inout FIXED_IO_ps_porb,
    inout FIXED_IO_ps_srstb,
`endif
`endif
`endif
`endif
`endif
`endif

`ifndef PS_ENABLE
    inout logic boot_select_i,

    inout logic jtag_tck_i,
    inout logic jtag_tms_i,
    inout logic jtag_trst_ni,
    inout logic jtag_tdi_i,
    inout logic jtag_tdo_o,

    inout logic uart_rx_i,
    inout logic uart_tx_o,
`endif

    inout logic [13:0] gpio_io,

    output logic exit_value_o,
    inout  logic exit_valid_o,

    inout logic [3:0] spi_flash_sd_io,
    inout logic spi_flash_csb_o,
    inout logic spi_flash_sck_o,

    inout logic [3:0] spi_sd_io,
    inout logic spi_csb_o,
    inout logic spi_sck_o,

    inout logic spi_slave_sck_io,
    inout logic spi_slave_cs_io,
    inout logic spi_slave_mosi_io,
    inout logic spi_slave_miso_io,

    inout logic [3:0] spi2_sd_io,
    inout logic [1:0] spi2_csb_o,
    inout logic spi2_sck_o,

    inout logic i2c_scl_io,
    inout logic i2c_sda_io,

    inout logic pdm2pcm_clk_io,
    inout logic pdm2pcm_pdm_io,

    inout logic i2s_sck_io,
    inout logic i2s_ws_io,
    inout logic i2s_sd_io

);

  wire                               clk_gen;
  logic [                      31:0] exit_value;
  wire                               rst_n;
  logic [CLK_LED_COUNT_LENGTH - 1:0] clk_count;

`ifdef PS_ENABLE
  wire       exit_valid;

  wire [1:0] ps_x_heep_i;
  wire [4:0] ps_x_heep_o;
  wire       ps_tck;
  wire       ps_tdi;
  wire       ps_tdo;
  wire       ps_tms;
  wire       ps_uart_rx;
  wire       ps_uart_tx;

`ifdef FPGA_VPK180
  localparam int unsigned DDR_AXI_ADDR_WIDTH = 64;
  localparam int unsigned DDR_AXI_DATA_WIDTH = 32;
  localparam int unsigned DDR_AXI_ID_WIDTH = 2;
  localparam int unsigned DDR_AXI_USER_WIDTH = 1;

  typedef logic [DDR_AXI_ADDR_WIDTH-1:0] ddr_axi_addr_t;
  typedef logic [DDR_AXI_DATA_WIDTH-1:0] ddr_axi_data_t;
  typedef logic [DDR_AXI_DATA_WIDTH/8-1:0] ddr_axi_strb_t;
  typedef logic [DDR_AXI_ID_WIDTH-1:0] ddr_axi_id_t;
  typedef logic [DDR_AXI_USER_WIDTH-1:0] ddr_axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(ddr_axi_aw_t, ddr_axi_addr_t, ddr_axi_id_t, ddr_axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(ddr_axi_w_t, ddr_axi_data_t, ddr_axi_strb_t, ddr_axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(ddr_axi_b_t, ddr_axi_id_t, ddr_axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ddr_axi_ar_t, ddr_axi_addr_t, ddr_axi_id_t, ddr_axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(ddr_axi_r_t, ddr_axi_data_t, ddr_axi_id_t, ddr_axi_user_t)

  `AXI_TYPEDEF_REQ_T(ddr_axi_req_t, ddr_axi_aw_t, ddr_axi_w_t, ddr_axi_ar_t)
  `AXI_TYPEDEF_RESP_T(ddr_axi_rsp_t, ddr_axi_b_t, ddr_axi_r_t)

  ddr_axi_req_t ddr_axi_req;
  ddr_axi_rsp_t ddr_axi_rsp;

  assign ddr_axi_rsp.b.user = '0;
  assign ddr_axi_rsp.r.user = '0;
`endif

`ifndef FPGA_VPK180
  (* DONT_TOUCH = "TRUE" *)wire       ps_quadspi_io_io0_io;
  (* DONT_TOUCH = "TRUE" *)wire       ps_quadspi_io_io1_io;
  (* DONT_TOUCH = "TRUE" *)wire       ps_quadspi_io_io2_io;
  (* DONT_TOUCH = "TRUE" *)wire       ps_quadspi_io_io3_io;
  wire       ps_quadspi_io_sck_io;
  wire [0:0] ps_quadspi_io_ss_io;
`endif
`endif

  // low active reset
`ifdef FPGA_NEXYS
  assign rst_n = rst_i;
`elsif FPGA_GENESYS2
  assign rst_n = rst_i;
`elsif FPGA_VPK180
`ifdef PS_ENABLE
  wire cips_rst_n;
  assign rst_n = cips_rst_n & ~rst_i;
`else
  assign rst_n = ~rst_i;
`endif
`else
  assign rst_n = !rst_i;
`endif

  // reset LED for debugging
  assign rst_led_o = rst_n;

  // counter to blink an LED
  assign clk_led_o = clk_count[CLK_LED_COUNT_LENGTH-1];

  always_ff @(posedge clk_gen or negedge rst_n) begin : clk_count_process
    if (!rst_n) begin
      clk_count <= '0;
    end else begin
      clk_count <= clk_count + 1;
    end
  end

  // eXtension Interface
  if_xif #() ext_if ();

`ifdef FPGA_ZCU104
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_300mhz_n),
      .CLK_IN1_D_0_clk_p(clk_300mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_ZCU102
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_125mhz_n),
      .CLK_IN1_D_0_clk_p(clk_125mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_AUP_ZU3
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_100mhz_n),
      .CLK_IN1_D_0_clk_p(clk_100mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_GENESYS2
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_200mhz_n),
      .CLK_IN1_D_0_clk_p(clk_200mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_VPK180
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(lpddr4_clk3_clk_n),
      .CLK_IN1_D_0_clk_p(lpddr4_clk3_clk_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_NEXYS
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .clk_100MHz(clk_i),
      .clk_out1_0(clk_gen)
  );
`else  // FPGA PYNQ-Z2
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .clk_125MHz(clk_i),
      .clk_out1_0(clk_gen)
  );
`endif

`ifdef PS_ENABLE
`ifdef FPGA_AUP_ZU3
  xilinx_ps_wizard_wrapper xilinx_ps_wizard_wrapper_i (
      .ps_gpio_i(ps_x_heep_i),
      .ps_gpio_o(ps_x_heep_o),
      .ps_tck_o(ps_tck),
      .ps_tdi_o(ps_tdi),
      .ps_tdo_i(ps_tdo),
      .ps_tms_o(ps_tms),
      .ps_uart_rx_i(ps_uart_rx),
      .ps_uart_tx_o(ps_uart_tx),
      .ps_quadspi_io_io0_io(ps_quadspi_io_io0_io),
      .ps_quadspi_io_io1_io(ps_quadspi_io_io1_io),
      .ps_quadspi_io_io2_io(ps_quadspi_io_io2_io),
      .ps_quadspi_io_io3_io(ps_quadspi_io_io3_io),
      .ps_quadspi_io_sck_io(ps_quadspi_io_sck_io),
      .ps_quadspi_io_ss_io(ps_quadspi_io_ss_io)
  );
`elsif FPGA_VPK180
  xilinx_ps_wizard_wrapper xilinx_ps_wizard_wrapper_i (
      // DDR CONNECTIONS :
      .DDR_S_AXI_araddr(ddr_axi_req.ar.addr),
      .DDR_S_AXI_arburst(ddr_axi_req.ar.burst),
      .DDR_S_AXI_arcache(ddr_axi_req.ar.cache),
      .DDR_S_AXI_arid(ddr_axi_req.ar.id),
      .DDR_S_AXI_arlen(ddr_axi_req.ar.len),
      .DDR_S_AXI_arlock(ddr_axi_req.ar.lock),
      .DDR_S_AXI_arprot(ddr_axi_req.ar.prot),
      .DDR_S_AXI_arqos(ddr_axi_req.ar.qos),
      .DDR_S_AXI_arready(ddr_axi_rsp.ar_ready),
      .DDR_S_AXI_arregion(ddr_axi_req.ar.region),
      .DDR_S_AXI_arsize(ddr_axi_req.ar.size),
      .DDR_S_AXI_arvalid(ddr_axi_req.ar_valid),
      .DDR_S_AXI_awaddr(ddr_axi_req.aw.addr),
      .DDR_S_AXI_awburst(ddr_axi_req.aw.burst),
      .DDR_S_AXI_awcache(ddr_axi_req.aw.cache),
      .DDR_S_AXI_awid(ddr_axi_req.aw.id),
      .DDR_S_AXI_awlen(ddr_axi_req.aw.len),
      .DDR_S_AXI_awlock(ddr_axi_req.aw.lock),
      .DDR_S_AXI_awprot(ddr_axi_req.aw.prot),
      .DDR_S_AXI_awqos(ddr_axi_req.aw.qos),
      .DDR_S_AXI_awready(ddr_axi_rsp.aw_ready),
      .DDR_S_AXI_awregion(ddr_axi_req.aw.region),
      .DDR_S_AXI_awsize(ddr_axi_req.aw.size),
      .DDR_S_AXI_awvalid(ddr_axi_req.aw_valid),
      .DDR_S_AXI_bid(ddr_axi_rsp.b.id),
      .DDR_S_AXI_bready(ddr_axi_req.b_ready),
      .DDR_S_AXI_bresp(ddr_axi_rsp.b.resp),
      .DDR_S_AXI_bvalid(ddr_axi_rsp.b_valid),
      .DDR_S_AXI_rdata(ddr_axi_rsp.r.data),
      .DDR_S_AXI_rid(ddr_axi_rsp.r.id),
      .DDR_S_AXI_rlast(ddr_axi_rsp.r.last),
      .DDR_S_AXI_rready(ddr_axi_req.r_ready),
      .DDR_S_AXI_rresp(ddr_axi_rsp.r.resp),
      .DDR_S_AXI_rvalid(ddr_axi_rsp.r_valid),
      .DDR_S_AXI_wdata(ddr_axi_req.w.data),
      .DDR_S_AXI_wlast(ddr_axi_req.w.last),
      .DDR_S_AXI_wready(ddr_axi_rsp.w_ready),
      .DDR_S_AXI_wstrb(ddr_axi_req.w.strb),
      .DDR_S_AXI_wvalid(ddr_axi_req.w_valid),
      .ddr_clk_i(clk_gen),
      .UART_0_rxd(ps_uart_rx),
      .UART_0_txd(ps_uart_tx),
      .ch0_lpddr4_trip1_ca_a(ch0_lpddr4_trip1_ca_a),
      .ch0_lpddr4_trip1_ca_b(ch0_lpddr4_trip1_ca_b),
      .ch0_lpddr4_trip1_ck_c_a(ch0_lpddr4_trip1_ck_c_a),
      .ch0_lpddr4_trip1_ck_c_b(ch0_lpddr4_trip1_ck_c_b),
      .ch0_lpddr4_trip1_ck_t_a(ch0_lpddr4_trip1_ck_t_a),
      .ch0_lpddr4_trip1_ck_t_b(ch0_lpddr4_trip1_ck_t_b),
      .ch0_lpddr4_trip1_cke_a(ch0_lpddr4_trip1_cke_a),
      .ch0_lpddr4_trip1_cke_b(ch0_lpddr4_trip1_cke_b),
      .ch0_lpddr4_trip1_cs_a(ch0_lpddr4_trip1_cs_a),
      .ch0_lpddr4_trip1_cs_b(ch0_lpddr4_trip1_cs_b),
      .ch0_lpddr4_trip1_dmi_a(ch0_lpddr4_trip1_dmi_a),
      .ch0_lpddr4_trip1_dmi_b(ch0_lpddr4_trip1_dmi_b),
      .ch0_lpddr4_trip1_dq_a(ch0_lpddr4_trip1_dq_a),
      .ch0_lpddr4_trip1_dq_b(ch0_lpddr4_trip1_dq_b),
      .ch0_lpddr4_trip1_dqs_c_a(ch0_lpddr4_trip1_dqs_c_a),
      .ch0_lpddr4_trip1_dqs_c_b(ch0_lpddr4_trip1_dqs_c_b),
      .ch0_lpddr4_trip1_dqs_t_a(ch0_lpddr4_trip1_dqs_t_a),
      .ch0_lpddr4_trip1_dqs_t_b(ch0_lpddr4_trip1_dqs_t_b),
      .ch0_lpddr4_trip1_reset_n(ch0_lpddr4_trip1_reset_n),
      .ch1_lpddr4_trip1_ca_a(ch1_lpddr4_trip1_ca_a),
      .ch1_lpddr4_trip1_ca_b(ch1_lpddr4_trip1_ca_b),
      .ch1_lpddr4_trip1_ck_c_a(ch1_lpddr4_trip1_ck_c_a),
      .ch1_lpddr4_trip1_ck_c_b(ch1_lpddr4_trip1_ck_c_b),
      .ch1_lpddr4_trip1_ck_t_a(ch1_lpddr4_trip1_ck_t_a),
      .ch1_lpddr4_trip1_ck_t_b(ch1_lpddr4_trip1_ck_t_b),
      .ch1_lpddr4_trip1_cke_a(ch1_lpddr4_trip1_cke_a),
      .ch1_lpddr4_trip1_cke_b(ch1_lpddr4_trip1_cke_b),
      .ch1_lpddr4_trip1_cs_a(ch1_lpddr4_trip1_cs_a),
      .ch1_lpddr4_trip1_cs_b(ch1_lpddr4_trip1_cs_b),
      .ch1_lpddr4_trip1_dmi_a(ch1_lpddr4_trip1_dmi_a),
      .ch1_lpddr4_trip1_dmi_b(ch1_lpddr4_trip1_dmi_b),
      .ch1_lpddr4_trip1_dq_a(ch1_lpddr4_trip1_dq_a),
      .ch1_lpddr4_trip1_dq_b(ch1_lpddr4_trip1_dq_b),
      .ch1_lpddr4_trip1_dqs_c_a(ch1_lpddr4_trip1_dqs_c_a),
      .ch1_lpddr4_trip1_dqs_c_b(ch1_lpddr4_trip1_dqs_c_b),
      .ch1_lpddr4_trip1_dqs_t_a(ch1_lpddr4_trip1_dqs_t_a),
      .ch1_lpddr4_trip1_dqs_t_b(ch1_lpddr4_trip1_dqs_t_b),
      .ch1_lpddr4_trip1_reset_n(ch1_lpddr4_trip1_reset_n),
      .lpddr4_clk1_clk_n(lpddr4_clk1_clk_n),
      .lpddr4_clk1_clk_p(lpddr4_clk1_clk_p),
      .pl0_resetn(cips_rst_n),
      .ps_gpio_i(ps_x_heep_i),
      .ps_gpio_o(ps_x_heep_o),
      // .ps_quadspi_io_io0_io(ps_quadspi_io_io0_io),
      // .ps_quadspi_io_io1_io(ps_quadspi_io_io1_io),
      // .ps_quadspi_io_io2_io(ps_quadspi_io_io2_io),
      // .ps_quadspi_io_io3_io(ps_quadspi_io_io3_io),
      // .ps_quadspi_io_sck_io(ps_quadspi_io_sck_io),
      // .ps_quadspi_io_ss_io(ps_quadspi_io_ss_io),
      .ps_tck_o(ps_tck),
      .ps_tdi_o(ps_tdi),
      .ps_tdo_i(ps_tdo),
      .ps_tms_o(ps_tms)
  );


  // VPK180 external DDR bus path.
  localparam int unsigned DDR_OBI_NMASTER = 2;

  xheep_obi_req_t heep_core_instr_req;
  xheep_obi_rsp_t heep_core_instr_resp;
  xheep_obi_req_t heep_core_data_req;
  xheep_obi_rsp_t heep_core_data_resp;
  xheep_obi_req_t [DDR_OBI_NMASTER-1:0] ddr_obi_master_req;
  xheep_obi_rsp_t [DDR_OBI_NMASTER-1:0] ddr_obi_master_resp;
  xheep_obi_req_t ddr_obi_req;
  xheep_obi_rsp_t ddr_obi_resp;

  assign ddr_obi_master_req[0] = heep_core_instr_req;
  assign ddr_obi_master_req[1] = heep_core_data_req;
  assign heep_core_instr_resp  = ddr_obi_master_resp[0];
  assign heep_core_data_resp   = ddr_obi_master_resp[1];

  xbar_varlat_n_to_one #(
      .XBAR_NMASTER(DDR_OBI_NMASTER),
      .obi_req_t   (xheep_obi_req_t),
      .obi_rsp_t   (xheep_obi_rsp_t)
  ) ddr_obi_xbar_i (
      .clk_i        (clk_gen),
      .rst_ni       (rst_n),
      .master_req_i (ddr_obi_master_req),
      .master_resp_o(ddr_obi_master_resp),
      .slave_req_o  (ddr_obi_req),
      .slave_resp_i (ddr_obi_resp)
  );

  xheep_obi_to_axi_bridge #(
      .AxiAddrWidth(DDR_AXI_ADDR_WIDTH),
      .AxiDataWidth(DDR_AXI_DATA_WIDTH),
      .AxiUserWidth(DDR_AXI_USER_WIDTH),
      .axi_req_t   (ddr_axi_req_t),
      .axi_rsp_t   (ddr_axi_rsp_t)
  ) obi2axi (
      .clk_i     (clk_gen),
      .rst_ni    (rst_n),
      .obi_req_i (ddr_obi_req),
      .obi_resp_o(ddr_obi_resp),
      .axi_req_o (ddr_axi_req),
      .axi_rsp_i (ddr_axi_rsp)
  );

`else
  xilinx_ps_wizard_wrapper xilinx_ps_wizard_wrapper_i (
      .DDR_addr(DDR_addr),
      .DDR_ba(DDR_ba),
      .DDR_cas_n(DDR_cas_n),
      .DDR_ck_n(DDR_ck_n),
      .DDR_ck_p(DDR_ck_p),
      .DDR_cke(DDR_cke),
      .DDR_cs_n(DDR_cs_n),
      .DDR_dm(DDR_dm),
      .DDR_dq(DDR_dq),
      .DDR_dqs_n(DDR_dqs_n),
      .DDR_dqs_p(DDR_dqs_p),
      .DDR_odt(DDR_odt),
      .DDR_ras_n(DDR_ras_n),
      .DDR_reset_n(DDR_reset_n),
      .DDR_we_n(DDR_we_n),
      .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
      .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
      .FIXED_IO_mio(FIXED_IO_mio),
      .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
      .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
      .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
      .ps_gpio_i(ps_x_heep_i),
      .ps_gpio_o(ps_x_heep_o),
      .ps_tck_o(ps_tck),
      .ps_tdi_o(ps_tdi),
      .ps_tdo_i(ps_tdo),
      .ps_tms_o(ps_tms),
      .ps_uart_rx_i(ps_uart_rx),
      .ps_uart_tx_o(ps_uart_tx),
      .ps_quadspi_io_io0_io(ps_quadspi_io_io0_io),
      .ps_quadspi_io_io1_io(ps_quadspi_io_io1_io),
      .ps_quadspi_io_io2_io(ps_quadspi_io_io2_io),
      .ps_quadspi_io_io3_io(ps_quadspi_io_io3_io),
      .ps_quadspi_io_sck_io(ps_quadspi_io_sck_io),
      .ps_quadspi_io_ss_io(ps_quadspi_io_ss_io)
  );
`endif
`endif

  x_heep_system x_heep_system_i (
      .hart_id_i('0),
      .xheep_instance_id_i('0),
      .intr_vector_ext_i('0),
      .xif_compressed_if(ext_if),
      .xif_issue_if(ext_if),
      .xif_commit_if(ext_if),
      .xif_mem_if(ext_if),
      .xif_mem_result_if(ext_if),
      .xif_result_if(ext_if),
`ifdef PS_ENABLE
`ifdef FPGA_VPK180
      .ext_xbar_master_req_i('0),
      .ext_xbar_master_resp_o(),
      .ext_core_instr_req_o(heep_core_instr_req),
      .ext_core_instr_resp_i(heep_core_instr_resp),
      .ext_core_data_req_o(heep_core_data_req),
      .ext_core_data_resp_i(heep_core_data_resp),
      .ext_debug_master_req_o(),
      .ext_debug_master_resp_i('0),
      .ext_dma_read_req_o(),
      .ext_dma_read_resp_i('0),
      .ext_dma_write_req_o(),
      .ext_dma_write_resp_i('0),
      .ext_dma_addr_req_o(),
      .ext_dma_addr_resp_i('0),
`else
      .ext_xbar_master_req_i('0),
      .ext_xbar_master_resp_o(),
      .ext_core_instr_req_o(),
      .ext_core_instr_resp_i('0),
      .ext_core_data_req_o(),
      .ext_core_data_resp_i('0),
      .ext_debug_master_req_o(),
      .ext_debug_master_resp_i('0),
      .ext_dma_read_req_o(),
      .ext_dma_read_resp_i('0),
      .ext_dma_write_req_o(),
      .ext_dma_write_resp_i('0),
      .ext_dma_addr_req_o(),
      .ext_dma_addr_resp_i('0),
`endif
`else
      .ext_xbar_master_req_i('0),
      .ext_xbar_master_resp_o(),
      .ext_core_instr_req_o(),
      .ext_core_instr_resp_i('0),
      .ext_core_data_req_o(),
      .ext_core_data_resp_i('0),
      .ext_debug_master_req_o(),
      .ext_debug_master_resp_i('0),
      .ext_dma_read_req_o(),
      .ext_dma_read_resp_i('0),
      .ext_dma_write_req_o(),
      .ext_dma_write_resp_i('0),
      .ext_dma_addr_req_o(),
      .ext_dma_addr_resp_i('0),
`endif
      .ext_peripheral_slave_req_o(),
      .ext_peripheral_slave_resp_i('0),
      .ext_ao_peripheral_req_i('0),
      .ext_ao_peripheral_resp_o(),
      .hw_fifo_req_o(),
      .hw_fifo_resp_i('0),
      .cpu_subsystem_powergate_switch_no(),
      .cpu_subsystem_powergate_switch_ack_ni('0),
      .peripheral_subsystem_powergate_switch_no(),
      .peripheral_subsystem_powergate_switch_ack_ni('0),
      .external_subsystem_powergate_switch_no(),
      .external_subsystem_powergate_switch_ack_ni('0),
      .external_subsystem_powergate_iso_no(),
      .external_subsystem_rst_no(),
      .external_ram_banks_set_retentive_no(),
      .external_subsystem_clkgate_en_no(),
      .exit_value_o(exit_value),
      .clk_i(clk_gen),
`ifdef PS_ENABLE
      .rst_ni(ps_x_heep_o[0] & rst_n),
      .boot_select_i(ps_x_heep_o[1]),
      .jtag_tck_i(ps_tck),
      .jtag_tms_i(ps_tms),
      .jtag_trst_ni(ps_x_heep_o[3]),
      .jtag_tdi_i(ps_tdi),
      .jtag_tdo_o(ps_tdo),
      .uart_rx_i(ps_uart_tx),
      .uart_tx_o(ps_uart_rx),
      .exit_valid_o(exit_valid),
`else
      .rst_ni(rst_n),
      .boot_select_i(boot_select_i),
      .jtag_tck_i(jtag_tck_i),
      .jtag_tms_i(jtag_tms_i),
      .jtag_trst_ni(jtag_trst_ni),
      .jtag_tdi_i(jtag_tdi_i),
      .jtag_tdo_o(jtag_tdo_o),
      .uart_rx_i(uart_rx_i),
      .uart_tx_o(uart_tx_o),
      .exit_valid_o(exit_valid_o),
`endif
      .gpio_0_io(gpio_io[0]),
      .gpio_1_io(gpio_io[1]),
      .gpio_2_io(gpio_io[2]),
      .gpio_3_io(gpio_io[3]),
      .gpio_4_io(gpio_io[4]),
      .gpio_5_io(gpio_io[5]),
      .gpio_6_io(gpio_io[6]),
      .gpio_7_io(gpio_io[7]),
      .gpio_8_io(gpio_io[8]),
      .gpio_9_io(gpio_io[9]),
      .gpio_10_io(gpio_io[10]),
      .gpio_11_io(gpio_io[11]),
      .gpio_12_io(gpio_io[12]),
      .gpio_13_io(gpio_io[13]),
`ifndef NO_DDR_CLK_PORTS
      .ddr_rcv_clk_i,
      .ddr_snd_clk_o,
`else
      .ddr_rcv_clk_i(1'b0),
      .ddr_snd_clk_o(),
`endif
      .spi_slave_sck_i(spi_slave_sck_io),
      .spi_slave_cs_io(spi_slave_cs_io),
      .spi_slave_miso_io(spi_slave_miso_io),
      .spi_slave_mosi_io(spi_slave_mosi_io),
      .spi_flash_sd_0_io(spi_flash_sd_io[0]),
      .spi_flash_sd_1_io(spi_flash_sd_io[1]),
      .spi_flash_sd_2_io(spi_flash_sd_io[2]),
      .spi_flash_sd_3_io(spi_flash_sd_io[3]),
      .spi_flash_cs_0_io(spi_flash_csb_o),
      .spi_flash_cs_1_io(),
      .spi_flash_sck_io(spi_flash_sck_o),
      .spi_sd_0_io(spi_sd_io[0]),
      .spi_sd_1_io(spi_sd_io[1]),
      .spi_sd_2_io(spi_sd_io[2]),
      .spi_sd_3_io(spi_sd_io[3]),
      .spi_cs_0_io(spi_csb_o),
      .spi_cs_1_io(),
      .spi_sck_io(spi_sck_o),
      .i2c_scl_io,
      .i2c_sda_io,
      .spi2_sd_0_io(spi2_sd_io[0]),
      .spi2_sd_1_io(spi2_sd_io[1]),
      .spi2_sd_2_io(spi2_sd_io[2]),
      .spi2_sd_3_io(spi2_sd_io[3]),
      .spi2_cs_0_io(spi2_csb_o[0]),
      .spi2_cs_1_io(spi2_csb_o[1]),
      .spi2_sck_io(spi2_sck_o),
      .pdm2pcm_clk_io,
      .pdm2pcm_pdm_io,
      .i2s_sck_io(i2s_sck_io),
      .i2s_ws_io(i2s_ws_io),
      .i2s_sd_io(i2s_sd_io),
      .ext_dma_slot_tx_i('0),
      .ext_dma_slot_rx_i('0),
      .ext_dma_stop_i('0),
      .intr_ext_peripheral_i('0),
      .hw_fifo_done_i('0),
      .dma_done_o()

  );

  assign exit_value_o = exit_value[0];

`ifdef PS_ENABLE
  assign ps_x_heep_i[0] = exit_valid;
  assign ps_x_heep_i[1] = exit_value[0];

  assign exit_valid_o   = exit_valid;
`ifndef FPGA_VPK180

  // QuadSPI flash mux hook
  (* DONT_TOUCH = "TRUE" *)
  LUT1 #(
      .INIT(2'b10)
  ) u_keep_ps_spi_flash_sel (
      .I0(ps_x_heep_o[4]),
      .O ()
  );

  (* DONT_TOUCH = "TRUE" *)
  LUT1 #(
      .INIT(2'b10)
  ) u_keep_ps_quadspi_sck (
      .I0(ps_quadspi_io_sck_io),
      .O ()
  );

  (* DONT_TOUCH = "TRUE" *)
  LUT1 #(
      .INIT(2'b10)
  ) u_keep_ps_quadspi_ss (
      .I0(ps_quadspi_io_ss_io[0]),
      .O ()
  );
`endif
`endif
endmodule
