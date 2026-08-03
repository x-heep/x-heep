// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module debug_subsystem #(
    parameter NRHARTS = 1,
    parameter JTAG_IDCODE = 32'h10001c05,
    parameter SPI_SLAVE = 0,
    parameter type obi_req_t = xheep_obi_pkg::xheep_obi_req_t,
    parameter type obi_rsp_t = xheep_obi_pkg::xheep_obi_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    //JTAG
    input  logic jtag_tck_i,
    input  logic jtag_tms_i,
    input  logic jtag_trst_ni,
    input  logic jtag_tdi_i,
    output logic jtag_tdo_o,

    //SPI Slave
    input  logic spi_slave_sck_i,
    input  logic spi_slave_cs_i,
    output logic spi_slave_miso_o,
    output logic spi_slave_miso_oe_o,
    input  logic spi_slave_mosi_i,

    output logic debug_ndmreset_no,
    output logic [NRHARTS-1:0] debug_core_req_o,

    input  obi_req_t debug_slave_req_i,
    output obi_rsp_t debug_slave_resp_o,
    output obi_req_t debug_master_req_o,
    input  obi_rsp_t debug_master_resp_i

);

  import dm::*;

  logic [NRHARTS-1:0]    unavailable;
  dm::hartinfo_t [NRHARTS-1:0] hartinfo;
  logic dmi_rst_n;

  always_comb begin
    for (int i = 0; i < NRHARTS; i++) begin
      hartinfo[i].zero1 = '0;
      hartinfo[i].nscratch = 2;  // Debug module needs at least two scratch regs
      hartinfo[i].zero0 = '0;
      hartinfo[i].dataaccess = 1'b1;  // data registers are memory mapped in the debugger
      hartinfo[i].datasize = dm::DataCount;
      hartinfo[i].dataaddr = dm::DataAddr;
      unavailable[i] = ~(1'b1);
    end
  end

  dm::dmi_req_t  dmi_req;
  logic          dmi_req_valid;
  logic          dmi_req_ready;
  dm::dmi_resp_t dmi_resp;
  logic          dmi_resp_ready;
  logic          dmi_resp_valid;
  logic          ndmreset;

  obi_req_t dm_req, spi_slave_req;
  obi_rsp_t dm_resp, spi_slave_resp;

  obi_req_t tofifo_req;
  obi_rsp_t tofifo_resp;
  obi_req_t [2-1:0] dbg_spi_req;
  obi_rsp_t [2-1:0] dbg_spi_resp;

  assign debug_ndmreset_no = ~ndmreset;

  dmi_jtag #(
      .IdcodeValue(JTAG_IDCODE)
  ) dmi_jtag_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .testmode_i      (1'b0),
      .dmi_req_o       (dmi_req),
      .dmi_req_valid_o (dmi_req_valid),
      .dmi_req_ready_i (dmi_req_ready),
      .dmi_resp_i      (dmi_resp),
      .dmi_resp_ready_o(dmi_resp_ready),
      .dmi_resp_valid_i(dmi_resp_valid),
      .dmi_rst_no      (dmi_rst_n),
      .tck_i           (jtag_tck_i),
      .tms_i           (jtag_tms_i),
      .trst_ni         (jtag_trst_ni),
      .td_i            (jtag_tdi_i),
      .td_o            (jtag_tdo_o),
      .tdo_oe_o        ()
  );

  dm_obi_top #(
      .NrHarts(NRHARTS)
  ) dm_obi_top_i (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .testmode_i   (1'b0),
      .ndmreset_o   (ndmreset),
      .dmactive_o   (),
      .debug_req_o  (debug_core_req_o),
      .unavailable_i(unavailable),
      .hartinfo_i   (hartinfo),

      .slave_req_i   (debug_slave_req_i.req),
      .slave_gnt_o   (debug_slave_resp_o.gnt),
      .slave_we_i    (debug_slave_req_i.we),
      .slave_addr_i  (debug_slave_req_i.addr),
      .slave_be_i    (debug_slave_req_i.be),
      .slave_wdata_i (debug_slave_req_i.wdata),
      .slave_aid_i   ('0),
      .slave_rdata_o (debug_slave_resp_o.rdata),
      .slave_rvalid_o(debug_slave_resp_o.rvalid),
      .slave_rid_o   (),

      .master_req_o      (dm_req.req),
      .master_addr_o     (dm_req.addr),
      .master_we_o       (dm_req.we),
      .master_wdata_o    (dm_req.wdata),
      .master_be_o       (dm_req.be),
      .master_gnt_i      (dm_resp.gnt),
      .master_rvalid_i   (dm_resp.rvalid),
      .master_err_i      (1'b0),
      .master_other_err_i(1'b0),
      .master_rdata_i    (dm_resp.rdata),

      .dmi_rst_ni      (dmi_rst_n),
      .dmi_req_valid_i (dmi_req_valid),
      .dmi_req_ready_o (dmi_req_ready),
      .dmi_req_i       (dmi_req),
      .dmi_resp_valid_o(dmi_resp_valid),
      .dmi_resp_ready_i(dmi_resp_ready),
      .dmi_resp_o      (dmi_resp)
  );

  if (SPI_SLAVE) begin : gen_spi_slave

    obi_spi_slave obi_spi_slave_i (
        .spi_sclk_i(spi_slave_sck_i),
        .spi_cs_i(spi_slave_cs_i),
        .spi_miso_o(spi_slave_miso_o),
        .spi_mosi_i(spi_slave_mosi_i),
        .obi_clk_i(clk_i),
        .obi_rstn_i(rst_ni),
        .obi_master_req_o(spi_slave_req.req),
        .obi_master_gnt_i(spi_slave_resp.gnt),
        .obi_master_addr_o(spi_slave_req.addr),
        .obi_master_we_o(spi_slave_req.we),
        .obi_master_w_data_o(spi_slave_req.wdata),
        .obi_master_be_o(spi_slave_req.be),
        .obi_master_r_valid_i(spi_slave_resp.rvalid),
        .obi_master_r_data_i(spi_slave_resp.rdata)
    );

    assign dbg_spi_req[0]      = dm_req;
    assign dbg_spi_req[1]      = spi_slave_req;
    assign dm_resp             = dbg_spi_resp[0];
    assign spi_slave_resp      = dbg_spi_resp[1];

    // To prevent the spi slave from keeping the MISO signal high
    // when it is not its turn to speak
    assign spi_slave_miso_oe_o = ~spi_slave_cs_i;

    // 2-to-1 crossbar
    xbar_varlat_n_to_one #(
        .XBAR_NMASTER(2),
        .obi_req_t(obi_req_t),
        .obi_rsp_t(obi_rsp_t)
    ) xbar_varlat_n_to_one_i (
        .clk_i,
        .rst_ni,
        .master_req_i (dbg_spi_req),
        .master_resp_o(dbg_spi_resp),
        .slave_req_o  (tofifo_req),
        .slave_resp_i (tofifo_resp)
    );

    xheep_obi_fifo #(
        .obi_req_t(obi_req_t),
        .obi_rsp_t(obi_rsp_t)
    ) obi_fifo_i (
        .clk_i,
        .rst_ni,
        .producer_req_i (tofifo_req),
        .producer_resp_o(tofifo_resp),
        .consumer_req_o (debug_master_req_o),
        .consumer_resp_i(debug_master_resp_i)
    );
  end else begin : gen_no_spi_slave
    assign tofifo_req          = '0;
    assign tofifo_resp         = '0;
    assign dbg_spi_req[0]      = '0;
    assign dbg_spi_req[1]      = '0;
    assign dbg_spi_resp[0]     = '0;
    assign dbg_spi_resp[1]     = '0;
    assign spi_slave_req       = '0;
    assign spi_slave_resp      = '0;
    assign spi_slave_miso_o    = '0;
    assign spi_slave_miso_oe_o = '0;
    assign debug_master_req_o  = dm_req;
    assign dm_resp             = debug_master_resp_i;
  end


endmodule : debug_subsystem
