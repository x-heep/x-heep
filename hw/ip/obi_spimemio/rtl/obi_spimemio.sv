/*
*  Copyright 2022 EPFL Christoph Müller <christoph.mueller@epfl.ch>
*  Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
*  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
*/

module obi_spimemio #(
    // NOTE: OBI and register data types below must have the same data and
    // address width.
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic,
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input  logic clk_i,
    input  logic rst_ni,
    output logic flash_csb_o,
    output logic flash_clk_o,

    output logic flash_io0_oe_o,
    output logic flash_io1_oe_o,
    output logic flash_io2_oe_o,
    output logic flash_io3_oe_o,

    output logic flash_io0_do_o,
    output logic flash_io1_do_o,
    output logic flash_io2_do_o,
    output logic flash_io3_do_o,

    input logic flash_io0_di_i,
    input logic flash_io1_di_i,
    input logic flash_io2_di_i,
    input logic flash_io3_di_i,

    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    input  obi_req_t spimemio_req_i,
    output obi_rsp_t spimemio_resp_o
);

  import picorv32_pkg::*;
  import obi_spimemio_reg_pkg::*;

  picorv32_req_t  picorv32_req;
  picorv32_resp_t picorv32_resp;

  reg_rsp_t reg_rsp_reg, reg_rsp_spimem;

  logic [31:0] cfgreg_do;
  logic cfgreg_we, cfgreg_rd;

  obi_spimemio_reg2hw_t reg2hw;

  obi_to_picorv32 #(
      .obi_req_t(obi_req_t),
      .obi_rsp_t(obi_rsp_t)
  ) obi_to_picorv32_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .picorv32_req_o(picorv32_req),
      .picorv32_resp_i(picorv32_resp),
      .obi_req_i(spimemio_req_i),
      .obi_resp_o(spimemio_resp_o)
  );

  obi_spimemio_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) obi_spimemio_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_i,
      .reg_rsp_o(reg_rsp_reg),
      .reg2hw,
      .devmode_i(1'b1)
  );

  assign cfgreg_we = reg_req_i.valid & reg_req_i.write && reg_req_i.addr[obi_spimemio_reg_pkg::BlockAw-1:0] == OBI_SPIMEMIO_CFG_SPIMEM_OFFSET;
  assign cfgreg_rd = reg_req_i.valid & ~reg_req_i.write && reg_req_i.addr[obi_spimemio_reg_pkg::BlockAw-1:0] == OBI_SPIMEMIO_CFG_SPIMEM_OFFSET;

  always_comb begin
    reg_rsp_spimem.rdata = cfgreg_do;
    reg_rsp_spimem.error = 1'b0;
    reg_rsp_spimem.ready = 1'b1;

    if (cfgreg_rd) begin
      reg_rsp_o = reg_rsp_spimem;
    end else begin
      reg_rsp_o = reg_rsp_reg;
    end
  end

  spimemio spimemio_i (
      .clk(clk_i),
      .resetn(rst_ni),
      .start_spi_i(reg2hw.start_spimem.q),
      .valid(picorv32_req.valid),
      .ready(picorv32_resp.ready),
      .addr({picorv32_req.addr[23:2], 2'b00}),
      .rdata(picorv32_resp.rdata),

      .flash_csb(flash_csb_o),
      .flash_clk(flash_clk_o),

      .flash_io0_oe(flash_io0_oe_o),
      .flash_io1_oe(flash_io1_oe_o),
      .flash_io2_oe(flash_io2_oe_o),
      .flash_io3_oe(flash_io3_oe_o),

      .flash_io0_do(flash_io0_do_o),
      .flash_io1_do(flash_io1_do_o),
      .flash_io2_do(flash_io2_do_o),
      .flash_io3_do(flash_io3_do_o),

      .flash_io0_di(flash_io0_di_i),
      .flash_io1_di(flash_io1_di_i),
      .flash_io2_di(flash_io2_di_i),
      .flash_io3_di(flash_io3_di_i),

      .cfgreg_we({4{cfgreg_we}}),
      .cfgreg_di(reg_req_i.wdata),
      .cfgreg_do(cfgreg_do)
  );

endmodule
