// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_err_sbr #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type                         obi_req_t   = logic,
  /// The response struct.
  parameter type                         obi_rsp_t   = logic,
  parameter type                         a_optional_t = logic,
  parameter type                         r_optional_t = logic,
  /// Numper of transactions accepted before stalling if UseRReady
  parameter int unsigned                 NumMaxTrans = 1,
  /// Data to respond with from error subordinate
  parameter logic [ObiCfg.DataWidth-1:0] RspData     = 32'hBADCAB1E
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic testmode_i,

  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  output logic [1:0] fault_o
);

  logic [3:0][1:0] hsiao_errs;
  logic [1:0][3:0] hsiao_errs_transpose;
  logic [0:0] voter_errs;
  for (genvar i = 0; i < 2; i++) begin : gen_hsiao_errs_transpose
    for (genvar j = 0; j < 4; j++) begin : gen_hsiao_errs_transpose_inner
      assign hsiao_errs_transpose[i][j] = hsiao_errs[j][i];
    end
  end
  assign fault_o[0] = |voter_errs | |hsiao_errs_transpose[0];
  assign fault_o[1] = |hsiao_errs_transpose[1];

  logic [2:0][ObiCfg.IdWidth-1:0] rid_d, rid_q;
  // logic [2:0][ObiCfg.IdWidth-1:0] rid_tmr;
  logic [2:0] fifo_full, fifo_empty, fifo_pop;

  logic [relobi_pkg::relobi_r_other_ecc_width(ObiCfg)-1:0] other_ecc_d, other_ecc_q;
  logic [2:0][relobi_pkg::relobi_r_other_ecc_width(ObiCfg)-1:0] other_ecc_tmr;
  logic [ObiCfg.DataWidth+hsiao_ecc_pkg::min_ecc(ObiCfg.DataWidth)-1:0] rdata_encoded;

  hsiao_ecc_enc #(
    .DataWidth (ObiCfg.DataWidth)
  ) i_rdata_encoder (
    .in        ( RspData ),
    .out       ( rdata_encoded )
  );

  for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
    relobi_err_sbr_tmr_part #(
      .ObiCfg(ObiCfg),
      .a_optional_t(a_optional_t),
      .r_optional_t(r_optional_t)
    ) i_tmr_part (
      .aid_i(rid_d),

      .rid_o(rid_q[i]),

      .fault_o(hsiao_errs[i][0])
    );
    assign hsiao_errs[i][1] = '0;
  end

  // bitwise_TMR_voter_fail #(
  //   .DataWidth( ObiCfg.IdWidth )
  // ) i_rid_vote (
  //   .a_i        (rid_tmr[0]),
  //   .b_i        (rid_tmr[1]),
  //   .c_i        (rid_tmr[2]),
  //   .majority_o (rid_d),
  //   .fault_detected_o(voter_errs[0])
  // );
  bitwise_TMR_voter_fail #(
    .DataWidth( relobi_pkg::relobi_r_other_ecc_width(ObiCfg) )
  ) i_other_ecc_vote (
    .a_i        (other_ecc_tmr[0]),
    .b_i        (other_ecc_tmr[1]),
    .c_i        (other_ecc_tmr[2]),
    .majority_o (other_ecc_d),
    .fault_detected_o(voter_errs[0])
  );

  always_comb begin
    obi_rsp_o.r.rdata = '0;
    obi_rsp_o.r.rdata = rdata_encoded;
    obi_rsp_o.r.rid   = rid_q;
    obi_rsp_o.r.err   = 1'b1;
    obi_rsp_o.r.r_optional = '0;
    obi_rsp_o.r.other_ecc = other_ecc_q;
    obi_rsp_o.gnt = ~fifo_full;
    obi_rsp_o.rvalid = ~fifo_empty;
  end

  if (ObiCfg.UseRReady) begin : gen_rready_fifo
    assign fifo_pop = obi_rsp_o.rvalid && obi_req_i.rready;
    rel_fifo #(
      .Depth        ( ObiCfg.UseRReady ? NumMaxTrans : 1 ),
      .FallThrough ( 1'b0                               ),
      .DataWidth   ( 3 * ObiCfg.IdWidth ),
      .TmrStatus   ( 1'b1                              ),
      .DataHasEcc  ( 1'b1                              )
    ) i_id_fifo (
      .clk_i,
      .rst_ni,
      .testmode_i,
      .flush_i   ( '0                             ),
      .full_o    ( fifo_full                      ),
      .empty_o   ( fifo_empty                     ),
      .usage_o   (),
      .data_i    ( obi_req_i.a.aid           ),
      .push_i    ( obi_req_i.req & obi_rsp_o.gnt ),
      .data_o    ( rid_d           ),
      .pop_i     ( fifo_pop                       ),
      .fault_o (hsiao_errs[3])
    );
  end else begin : gen_no_rready_fifo
    assign fifo_full  = '0;
    assign fifo_pop = '0;
    assign hsiao_errs[3] = '0;
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        rid_d <= '0;
        other_ecc_q <= '0;
        fifo_empty <= '1;
      end else begin
        rid_d <= obi_req_i.a.aid;
        other_ecc_q <= other_ecc_d;
        fifo_empty <= ~(obi_req_i.req & obi_rsp_o.gnt);
      end
    end
  end

endmodule

module relobi_err_sbr_tmr_part #(
  parameter obi_pkg::obi_cfg_t ObiCfg        = obi_pkg::ObiDefaultConfig,
  parameter type               a_optional_t  = logic,
  parameter type               r_optional_t  = logic

) (
  input  logic [2:0][ObiCfg.IdWidth    -1:0] aid_i,
  output logic [ObiCfg.IdWidth    -1:0] rid_o,

  output logic [0:0] fault_o
);

  bitwise_TMR_voter_fail #(
    .DataWidth( ObiCfg.IdWidth )
  ) i_aid_vote (
    .a_i        (aid_i[0]),
    .b_i        (aid_i[1]),
    .c_i        (aid_i[2]),
    .majority_o (rid_o),
    .fault_detected_o(fault_o[0])
  );

endmodule

`include "obi/typedef.svh"
`include "obi/assign.svh"

module relobi_err_sbr_intf #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// Numper of transactions accepted before stalling if UseRReady
  parameter int unsigned                 NumMaxTrans = 1,
  /// Data to respond with from error subordinate
  parameter logic [ObiCfg.DataWidth-1:0] RspData     = 32'hBADCAB1E
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic testmode_i,

  OBI_BUS.Subordinate sbr_port
);

  `OBI_TYPEDEF_ALL(obi, ObiCfg)

  obi_req_t obi_req;
  obi_rsp_t obi_rsp;

  `OBI_ASSIGN_TO_REQ(obi_req, sbr_port, ObiCfg)
  `OBI_ASSIGN_FROM_RSP(sbr_port, obi_rsp, ObiCfg)

  obi_err_sbr #(
    .ObiCfg      ( ObiCfg      ),
    .obi_req_t   ( obi_req_t   ),
    .obi_rsp_t   ( obi_rsp_t   ),
    .NumMaxTrans ( NumMaxTrans ),
    .RspData     ( RspData     )
  ) i_err_sbr (
    .clk_i,
    .rst_ni,
    .testmode_i,

    .obi_req_i  ( obi_req ),
    .obi_rsp_o  ( obi_rsp )
  );

endmodule
