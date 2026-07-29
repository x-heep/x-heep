// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module obi_cut #(
    /// The OBI configuration.
  parameter obi_pkg::obi_cfg_t ObiCfg       = obi_pkg::ObiDefaultConfig,
  /// The obi A channel struct.
  parameter type               obi_a_chan_t = logic,
  /// The obi R channel struct.
  parameter type               obi_r_chan_t = logic,
  /// The request struct.
  parameter type               obi_req_t    = logic,
  /// The response struct.
  parameter type               obi_rsp_t    = logic,
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
  input  obi_rsp_t mgr_port_rsp_i
);

  spill_register #(
    .T      ( obi_a_chan_t ),
    .Bypass ( BypassReq    )
  ) i_reg_a (
    .clk_i,
    .rst_ni,
    .valid_i ( sbr_port_req_i.req ),
    .ready_o ( sbr_port_rsp_o.gnt ),
    .data_i  ( sbr_port_req_i.a   ),
    .valid_o ( mgr_port_req_o.req ),
    .ready_i ( mgr_port_rsp_i.gnt ),
    .data_o  ( mgr_port_req_o.a   )
  );

  if (ObiCfg.UseRReady) begin : gen_use_rready
    spill_register #(
      .T      ( obi_r_chan_t ),
      .Bypass ( BypassRsp    )
    ) i_req_r (
      .clk_i,
      .rst_ni,
      .valid_i ( mgr_port_rsp_i.rvalid ),
      .ready_o ( mgr_port_req_o.rready ),
      .data_i  ( mgr_port_rsp_i.r      ),
      .valid_o ( sbr_port_rsp_o.rvalid ),
      .ready_i ( sbr_port_req_i.rready ),
      .data_o  ( sbr_port_rsp_o.r      )
    );
  end else begin : gen_no_use_rready
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
