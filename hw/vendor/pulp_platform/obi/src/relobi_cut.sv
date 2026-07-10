// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_cut #(
  /// The OBI configuration.
  parameter obi_pkg::obi_cfg_t ObiCfg       = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type               obi_req_t    = logic,
  /// The response struct.
  parameter type               obi_rsp_t    = logic,
  /// The obi A channel struct.
  parameter type               obi_a_chan_t = logic,
  /// The obi R channel struct.
  parameter type               obi_r_chan_t = logic,
  /// Optional type for the A channel.
  parameter type               a_optional_t = logic,
  /// Optional type for the R channel.
  parameter type               r_optional_t = logic,
  /// Bypass enable, can be individually overridden!
  parameter bit                Bypass       = 1'b0,
  /// Bypass enable for Request side.
  parameter bit                BypassReq    = Bypass,
  /// Bypass enable for Response side.
  parameter bit                BypassRsp    = Bypass
) (
  input  logic     clk_i,
  input  logic     rst_ni,

  input  obi_req_t sbr_port_req_i,
  output obi_rsp_t sbr_port_rsp_o,

  output obi_req_t mgr_port_req_o,
  input  obi_rsp_t mgr_port_rsp_i,
  output logic [1:0] fault_o
);

  logic [1:0] faults;
  logic [1:0] corrector_faults;
  assign fault_o[0] = |faults | corrector_faults[0];
  assign fault_o[1] = corrector_faults[1];

  obi_req_t corrector_req, corrected_req;
  obi_rsp_t corrector_rsp, corrected_rsp;
  assign corrector_req.req = '0;
  if (ObiCfg.UseRReady) begin : gen_corrector_req_rready
    assign corrector_req.rready = '0;
  end
  assign corrector_rsp.rvalid = '0;
  assign corrector_rsp.gnt = '0;

  relobi_corrector #(
    .Cfg           ( ObiCfg ),
    .relobi_req_t  ( obi_req_t ),
    .relobi_rsp_t  ( obi_rsp_t ),
    .a_optional_t  ( a_optional_t ),
    .r_optional_t  ( r_optional_t )
  ) i_relobi_corrector (
    .req_i (corrector_req),
    .rsp_i (corrector_rsp),
    .req_o (corrected_req),
    .rsp_o (corrected_rsp),
    .fault_o (corrector_faults)
  );

  rel_spill_register #(
    .T      ( obi_a_chan_t ),
    .Bypass ( BypassReq    ),
    .TmrHandshake ( 1'b1 ),
    .DataCorrector ( 1'b1 )
  ) i_reg_a (
    .clk_i,
    .rst_ni,
    .valid_i ( sbr_port_req_i.req ),
    .ready_o ( sbr_port_rsp_o.gnt ),
    .data_i  ( sbr_port_req_i.a   ),
    .valid_o ( mgr_port_req_o.req ),
    .ready_i ( mgr_port_rsp_i.gnt ),
    .data_o  ( mgr_port_req_o.a   ),
    .fault_o ( faults[0]          ),
    .data_corrector_o ( corrector_req.a ),
    .data_corrected_i ( corrected_req.a )
  );

  if (ObiCfg.UseRReady) begin : gen_use_rready
    rel_spill_register #(
      .T      ( obi_r_chan_t ),
      .Bypass ( BypassRsp    ),
      .TmrHandshake ( 1'b1 ),
      .DataCorrector ( 1'b1 )
    ) i_reg_r (
      .clk_i,
      .rst_ni,
      .valid_i ( mgr_port_rsp_i.rvalid ),
      .ready_o ( mgr_port_req_o.rready ),
      .data_i  ( mgr_port_rsp_i.r      ),
      .valid_o ( sbr_port_rsp_o.rvalid ),
      .ready_i ( sbr_port_req_i.rready ),
      .data_o  ( sbr_port_rsp_o.r      ),
      .fault_o ( faults[1]             ),
      .data_corrector_o ( corrector_rsp.r ),
      .data_corrected_i ( corrected_rsp.r )
    );
  end else begin : gen_no_use_rready
    assign faults[1] = 1'b0;
    assign corrector_rsp.r = '0;
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        sbr_port_rsp_o.rvalid <= 1'b0;
        sbr_port_rsp_o.r      <= '0;
      end else begin
        sbr_port_rsp_o.rvalid <= mgr_port_rsp_i.rvalid;
        sbr_port_rsp_o.r      <= mgr_port_rsp_i.r;
      end
    end
  end

endmodule
