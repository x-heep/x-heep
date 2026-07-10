// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

`include "obi/assign.svh"
`include "redundancy_cells/voters.svh"

/// An OBI multiplexer.
module relobi_mux #(
  /// The configuration of the subordinate ports (input ports).
  parameter obi_pkg::obi_cfg_t SbrPortObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The configuration of the manager port (output port).
  parameter obi_pkg::obi_cfg_t MgrPortObiCfg      = SbrPortObiCfg,
  /// The request struct for the subordinate ports (input ports).
  parameter type               sbr_port_obi_req_t = logic,
  /// The A channel struct for the subordinate ports (input ports).
  parameter type               sbr_port_a_chan_t  = logic,
  /// The response struct for the subordinate ports (input ports).
  parameter type               sbr_port_obi_rsp_t = logic,
  /// The R channel struct for the subordinate ports (input ports).
  parameter type               sbr_port_r_chan_t  = logic,
  /// The request struct for the manager port (output port).
  parameter type               mgr_port_obi_req_t = sbr_port_obi_req_t,
  /// The response struct for the manager port (output port).
  parameter type               mgr_port_obi_rsp_t = sbr_port_obi_rsp_t,
  /// The A channel struct for the manager port (output port).
  parameter type               mgr_port_a_chan_t  = logic,
  /// The R channel struct for the manager port (output port).
  parameter type               mgr_port_r_chan_t  = logic,
  /// The A channel optionals struct for all ports.
  parameter type               a_optional_t = logic,
  /// The R channel optionals struct for all ports.
  parameter type               r_optional_t = logic,
  /// The number of subordinate ports (input ports).
  parameter int unsigned       NumSbrPorts        = 32'd0,
  /// The maximum number of outstanding transactions.
  parameter int unsigned       NumMaxTrans        = 32'd0,
  /// Use the extended ID field (aid & rid) to route the response
  parameter bit                UseIdForRouting    = 1'b0
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic testmode_i,

  input  sbr_port_obi_req_t [NumSbrPorts-1:0] sbr_ports_req_i,
  output sbr_port_obi_rsp_t [NumSbrPorts-1:0] sbr_ports_rsp_o,

  output mgr_port_obi_req_t                   mgr_port_req_o,
  input  mgr_port_obi_rsp_t                   mgr_port_rsp_i,

  output logic [1:0]                          fault_o
);
  if (NumSbrPorts <= 1) begin : gen_NumSbrPorts_err
    $fatal(1, "unimplemented");
  end
  if (MgrPortObiCfg.IdWidth < SbrPortObiCfg.IdWidth) begin : gen_IdWidthDecreasing_err
    $fatal(1, "relobi_mux: IdWidth not allowed to decrease");
  end
  if (MgrPortObiCfg.UseRReady   != SbrPortObiCfg.UseRReady   ||
      MgrPortObiCfg.CombGnt     != SbrPortObiCfg.CombGnt     ||
      MgrPortObiCfg.AddrWidth   != SbrPortObiCfg.DataWidth   ||
      MgrPortObiCfg.DataWidth   != SbrPortObiCfg.DataWidth   ||
      MgrPortObiCfg.Integrity   != SbrPortObiCfg.Integrity   ||
      MgrPortObiCfg.BeFull      != SbrPortObiCfg.BeFull      ||
      MgrPortObiCfg.OptionalCfg != SbrPortObiCfg.OptionalCfg   ) begin : gen_ConfigDiff_err
    $fatal(1, "relobi_mux: Configuration needs to be identical for mgr & sbr except IdWidth");
  end

  localparam int unsigned RequiredExtraIdWidth = $clog2(NumSbrPorts);

  logic [5:0][1:0] hsiao_faults;
  logic [5:0][1:0] hsiao_faults_gated;
  logic [1:0][5:0] hsiao_faults_transpose;
  logic [3:0] voter_faults;
  for (genvar i = 0; i < 6; i++) begin : gen_hsiao_faults_transpose
    for (genvar j = 0; j < 2; j++) begin : gen_hsiao_faults_transpose_inner
      assign hsiao_faults_transpose[j][i] = hsiao_faults_gated[i][j];
    end
  end
  assign fault_o[0] = |voter_faults | |hsiao_faults_transpose[0];
  assign fault_o[1] = |hsiao_faults_transpose[1];

  logic [NumSbrPorts-1:0][2:0] sbr_ports_req, sbr_ports_gnt;
  sbr_port_a_chan_t [NumSbrPorts-1:0] sbr_ports_a;

  sbr_port_a_chan_t       mgr_port_a_in_sbr;
  mgr_port_a_chan_t [2:0] mgr_port_a_tmr;
  logic [2:0][RequiredExtraIdWidth-1:0] selected_id;
  logic [2:0] mgr_port_req, fifo_full, fifo_pop;

  logic [2:0] rr_arb_mgr_port_gnt;

  logic [2:0][RequiredExtraIdWidth + hsiao_ecc_pkg::min_ecc(RequiredExtraIdWidth)-1:0]
    selected_id_tmr_three;
  logic [RequiredExtraIdWidth + hsiao_ecc_pkg::min_ecc(RequiredExtraIdWidth)-1:0]
    selected_id_tmr, response_id_encoded;

  logic [2:0][NumSbrPorts-1:0] sbr_rsp_rvalid;
  logic [2:0][NumSbrPorts-1:0] sbr_req_rready;
  logic [2:0] mgr_req_rready;

  sbr_port_r_chan_t [2:0] sbr_r_tmr;


  for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_sbr_assign
    assign sbr_ports_req[i] = sbr_ports_req_i[i].req;
    assign sbr_ports_a[i] = sbr_ports_req_i[i].a;
    assign sbr_ports_rsp_o[i].gnt = sbr_ports_gnt[i];
  end

  assign mgr_port_req_o.req = mgr_port_req & ~fifo_full;
  assign rr_arb_mgr_port_gnt = mgr_port_rsp_i.gnt & ~fifo_full;

  for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
    relobi_mux_tmr_part #(
      .SbrPortObiCfg      ( SbrPortObiCfg      ),
      .MgrPortObiCfg      ( MgrPortObiCfg      ),
      .NumSbrPorts        ( NumSbrPorts        ),
      .mgr_port_a_chan_t  ( mgr_port_a_chan_t  ),
      .mgr_port_r_chan_t  ( mgr_port_r_chan_t  ),
      .sbr_port_a_chan_t  ( sbr_port_a_chan_t  ),
      .sbr_port_r_chan_t  ( sbr_port_r_chan_t  ),
      .a_optional_t       ( a_optional_t       ),
      .r_optional_t       ( r_optional_t       ),
      .RequiredExtraIdWidth( RequiredExtraIdWidth ),
      .UseIdForRouting    ( UseIdForRouting    )
    ) i_tmr_part (
      .clk_i,
      .rst_ni,

      .mgr_port_a_in_sbr ( mgr_port_a_in_sbr ),
      .mgr_port_req      ( mgr_port_req[i]   ),
      .selected_id       ( selected_id[i]    ),
      // .mgr_port_a_tmr    ( mgr_port_a_tmr[i] ),

      .mgr_port_rsp_r    ( UseIdForRouting || MgrPortObiCfg.IdWidth != SbrPortObiCfg.IdWidth ?
                           mgr_port_rsp_i.r : '0  ),
      .mgr_port_rsp_rvalid( UseIdForRouting ? mgr_port_rsp_i.rvalid[i] : '0 ),
      .mgr_rid           ( UseIdForRouting ?
                           mgr_port_rsp_i.r.rid[i] : '0 ),
      .selected_id_tmr_three ( selected_id_tmr_three[i] ),
      .response_id_encoded( UseIdForRouting ? '0 : response_id_encoded ),
      .fifo_pop          ( UseIdForRouting ? '0 : fifo_pop[i]          ),

      .mgr_rsp_rvalid ( mgr_port_rsp_i.rvalid[i] ),
      .sbr_rsp_rvalid ( sbr_rsp_rvalid[i] ),
      .sbr_req_rready ( MgrPortObiCfg.UseRReady ? sbr_req_rready[i] : '1 ),
      .mgr_req_rready ( mgr_req_rready[i] ),

      .sbr_r_tmr      ( sbr_r_tmr[i]       ),

      .hsiao_faults      ( hsiao_faults[2*i+1:2*i]   ),
      .hsiao_faults_gated( hsiao_faults_gated[2*i+1:2*i] )
    );
  end

  rel_rr_arb_tree #(
    .NumIn     ( NumSbrPorts       ),
    .DataType  ( sbr_port_a_chan_t ),
    .AxiVldRdy ( 1'b1              ),
    .LockIn    ( 1'b1              ),
    .TmrStatus ( 1'b1              )
  ) i_rr_arb (
    .clk_i,
    .rst_ni,

    .flush_i ( 1'b0 ),
    .rr_i    ( '0 ),

    .req_i   ( sbr_ports_req       ),
    .gnt_o   ( sbr_ports_gnt       ),
    .data_i  ( sbr_ports_a         ),

    .req_o   ( mgr_port_req        ),
    .gnt_i   ( rr_arb_mgr_port_gnt ),
    .data_o  ( mgr_port_a_in_sbr   ),

    .idx_o   ( selected_id         ),

    .fault_o ( voter_faults[0] )
  );

  if (MgrPortObiCfg.IdWidth == SbrPortObiCfg.IdWidth) begin : gen_aid_identical
    assign mgr_port_req_o.a = mgr_port_a_in_sbr;
  end else begin : gen_aid_vote
    logic [2:0][MgrPortObiCfg.IdWidth-1:0] mgr_aid;
    assign mgr_port_req_o.a.addr  = mgr_port_a_in_sbr.addr;
    assign mgr_port_req_o.a.wdata = mgr_port_a_in_sbr.wdata;
    assign mgr_port_req_o.a.we    = mgr_port_a_in_sbr.we;
    assign mgr_port_req_o.a.be    = mgr_port_a_in_sbr.be;
    assign mgr_port_req_o.a.a_optional = mgr_port_a_in_sbr.a_optional;
    assign mgr_port_req_o.a.other_ecc  = mgr_port_a_in_sbr.other_ecc;

    if (MgrPortObiCfg.IdWidth >= SbrPortObiCfg.IdWidth +
                                  RequiredExtraIdWidth   ) begin : gen_aid_extend
      always_comb begin
        mgr_aid = '0;
        mgr_aid[0][SbrPortObiCfg.IdWidth + RequiredExtraIdWidth-1:0] = {selected_id[0], mgr_port_a_in_sbr.aid[0]};
        mgr_aid[1][SbrPortObiCfg.IdWidth + RequiredExtraIdWidth-1:0] = {selected_id[1], mgr_port_a_in_sbr.aid[0]};
        mgr_aid[2][SbrPortObiCfg.IdWidth + RequiredExtraIdWidth-1:0] = {selected_id[2], mgr_port_a_in_sbr.aid[0]};
      end
    end else begin : gen_aid_noextend
      always_comb begin
        mgr_aid = '0;
        mgr_aid[0][SbrPortObiCfg.IdWidth-1:0] = mgr_port_a_in_sbr.aid[0];
        mgr_aid[1][SbrPortObiCfg.IdWidth-1:0] = mgr_port_a_in_sbr.aid[0];
        mgr_aid[2][SbrPortObiCfg.IdWidth-1:0] = mgr_port_a_in_sbr.aid[0];
      end
    end
    assign mgr_port_req_o.a.aid = mgr_aid;
  end

  logic [2:0][SbrPortObiCfg.IdWidth-1:0] rsp_rid;

  if (UseIdForRouting) begin : gen_id_assign
    if (!(MgrPortObiCfg.IdWidth > 0 &&
          (MgrPortObiCfg.IdWidth >= SbrPortObiCfg.IdWidth +
                                    RequiredExtraIdWidth   ))) begin : gen_IdWidth_err
      $fatal(1, "UseIdForRouting requires MgrPort IdWidth to increase with log2(NumSbrPorts)");
    end

    assign fifo_full = 3'b0;

    assign voter_faults[2:1] = '0;
    assign selected_id_tmr = '0;

  end else begin : gen_no_id_assign

    bitwise_TMR_voter_fail #(
      .DataWidth ( RequiredExtraIdWidth + hsiao_ecc_pkg::min_ecc(RequiredExtraIdWidth) ),
      .VoterType ( 1 )
    ) i_selected_id_tmr (
      .a_i              ( selected_id_tmr_three[0] ),
      .b_i              ( selected_id_tmr_three[1] ),
      .c_i              ( selected_id_tmr_three[2] ),
      .majority_o       ( selected_id_tmr           ),
      .fault_detected_o ( voter_faults[1]           )
    );

    rel_fifo #(
      .FallThrough( 1'b0                 ),
      .DataWidth  ( RequiredExtraIdWidth + hsiao_ecc_pkg::min_ecc(RequiredExtraIdWidth) ),
      .Depth      ( NumMaxTrans          ),
      .TmrStatus  ( 1'b1                 ),
      .DataHasEcc ( 1'b1                 ),
      .StatusFF   ( 1'b0                 )
    ) i_fifo (
      .clk_i,
      .rst_ni,
      .flush_i   ('0),
      .testmode_i,

      .full_o    ( fifo_full                               ),
      .empty_o   (),
      .usage_o   (),
      .data_i    ( selected_id_tmr                         ),
      .push_i    ( mgr_port_req_o.req & mgr_port_rsp_i.gnt ),
      .data_o    ( response_id_encoded                     ),
      .pop_i     ( fifo_pop                                ),

      .fault_o (voter_faults[2])
    );

  end

  if (MgrPortObiCfg.UseRReady) begin : gen_rready_connect
      assign mgr_port_req_o.rready = mgr_req_rready;
      for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_sbr_ports_rready
        for (genvar j = 0; j < 3; j++) begin : gen_sbr_req_rready
          assign sbr_req_rready[j][i] = sbr_ports_req_i[i].rready[j];
        end
      end
  end else begin : gen_rready_tie
    assign sbr_req_rready = '1;
  end
  sbr_port_r_chan_t [NumSbrPorts-1:0] sbr_rsp_r;
  assign voter_faults[3] = '0;
  for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_sbr_r_assign
    if (MgrPortObiCfg.IdWidth == SbrPortObiCfg.IdWidth) begin : gen_rid_identical
      assign sbr_rsp_r[i].rid = mgr_port_rsp_i.r.rid;
    end else begin : gen_rid_decrease
      for (genvar j = 0; j < 3; j++) begin : gen_rid_tmr
        assign sbr_rsp_r[i].rid[j] = mgr_port_rsp_i.r.rid[j][SbrPortObiCfg.IdWidth-1:0];
      end
    end
    assign sbr_rsp_r[i].rdata = mgr_port_rsp_i.r.rdata;
    assign sbr_rsp_r[i].err = mgr_port_rsp_i.r.err;
    assign sbr_rsp_r[i].r_optional = mgr_port_rsp_i.r.r_optional;
    assign sbr_rsp_r[i].other_ecc = mgr_port_rsp_i.r.other_ecc;
  end

  for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_sbr_rsp_assign
    assign sbr_ports_rsp_o[i].r = sbr_rsp_r[i];
    assign sbr_ports_rsp_o[i].rvalid = {sbr_rsp_rvalid[2][i],
                                        sbr_rsp_rvalid[1][i],
                                        sbr_rsp_rvalid[0][i]};
  end

  if (MgrPortObiCfg.UseRReady) begin : gen_fifo_pop
    assign fifo_pop = mgr_port_rsp_i.rvalid & mgr_port_req_o.rready;
  end else begin : gen_fifo_pop
    assign fifo_pop = mgr_port_rsp_i.rvalid;
  end

endmodule

(* no_ungroup *)
(* no_boundary_optimization *)
module relobi_mux_tmr_part #(
  parameter obi_pkg::obi_cfg_t SbrPortObiCfg      = obi_pkg::ObiDefaultConfig,
  parameter obi_pkg::obi_cfg_t MgrPortObiCfg      = SbrPortObiCfg,
  parameter int unsigned NumSbrPorts = 32'd0,
  parameter type               mgr_port_a_chan_t  = logic,
  parameter type               mgr_port_r_chan_t  = logic,
  parameter type               sbr_port_a_chan_t   = logic,
  parameter type               sbr_port_r_chan_t   = logic,
  parameter type               a_optional_t       = logic,
  parameter type               r_optional_t       = logic,
  parameter int unsigned       RequiredExtraIdWidth = 0,
  parameter bit UseIdForRouting = 1'b0

) (
  input  logic clk_i,
  input  logic rst_ni,
  input  sbr_port_a_chan_t mgr_port_a_in_sbr,
  input  logic             mgr_port_req,
  input  logic [RequiredExtraIdWidth-1:0] selected_id,
  // output mgr_port_a_chan_t mgr_port_a_tmr,

  // Only if UseIdForRouting is true or Id width increases
  input  mgr_port_r_chan_t mgr_port_rsp_r,
  // Only if UseIdForRouting is true
  input  logic             mgr_port_rsp_rvalid,
  input  logic [MgrPortObiCfg.IdWidth-1:0] mgr_rid,
  // Only if UseIdForRouting is false
  output logic [RequiredExtraIdWidth+
                hsiao_ecc_pkg::min_ecc(RequiredExtraIdWidth)-1:0] selected_id_tmr_three,
  input  logic [RequiredExtraIdWidth+
                hsiao_ecc_pkg::min_ecc(RequiredExtraIdWidth)-1:0] response_id_encoded,
  input  logic fifo_pop,

  output sbr_port_r_chan_t sbr_r_tmr,

  input  logic                   mgr_rsp_rvalid,
  output logic [NumSbrPorts-1:0] sbr_rsp_rvalid,
  input  logic [NumSbrPorts-1:0] sbr_req_rready,
  output logic                   mgr_req_rready,

  output logic [1:0][1:0] hsiao_faults,
  output logic [1:0][1:0] hsiao_faults_gated
);

  logic [RequiredExtraIdWidth-1:0] response_id;

  // if (MgrPortObiCfg.IdWidth == SbrPortObiCfg.IdWidth) begin : gen_aid_identical
    // assign mgr_port_a_tmr = mgr_port_a_in_sbr;
    assign hsiao_faults[0] = '0;
    assign hsiao_faults_gated[0] = '0;
  // end else begin : gen_aid_extend
  //   logic we;
  //   logic [MgrPortObiCfg.DataWidth/8-1:0] be;
  //   logic [SbrPortObiCfg.IdWidth-1:0] sbr_aid;
  //   logic [MgrPortObiCfg.IdWidth-1:0] mgr_aid;
  //   a_optional_t a_optional;
  //   logic [relobi_pkg::relobi_a_other_ecc_width(MgrPortObiCfg)-1:0] other_ecc;
  //   relobi_a_other_decoder #(
  //     .Cfg          (SbrPortObiCfg),
  //     .a_optional_t (a_optional_t)
  //   ) i_other_decode (
  //     .we_i        (mgr_port_a_in_sbr.we),
  //     .be_i        (mgr_port_a_in_sbr.be),
  //     .aid_i       (mgr_port_a_in_sbr.aid),
  //     .a_optional_i(mgr_port_a_in_sbr.a_optional),
  //     .other_ecc_i (mgr_port_a_in_sbr.other_ecc),
  //     .we_o        (we),
  //     .be_o        (be),
  //     .aid_o       (sbr_aid),
  //     .a_optional_o(a_optional),

  //     .fault_o (hsiao_faults[0])
  //   );
  //   assign hsiao_faults_gated[0] = mgr_port_req ? hsiao_faults[0] : '0;
  //   if (MgrPortObiCfg.IdWidth >= SbrPortObiCfg.IdWidth +
  //                                 RequiredExtraIdWidth   ) begin : gen_aid_extend
  //     always_comb begin
  //       mgr_aid = '0;
  //       mgr_aid[SbrPortObiCfg.IdWidth + RequiredExtraIdWidth-1:0] = {selected_id, sbr_aid};
  //     end
  //   end else begin : gen_aid_noextend
  //     always_comb begin
  //       mgr_aid = '0;
  //       mgr_aid[SbrPortObiCfg.IdWidth-1:0] = sbr_aid;
  //     end
  //   end
  //   relobi_a_other_encoder #(
  //     .Cfg          (MgrPortObiCfg),
  //     .a_optional_t (a_optional_t)
  //   ) i_other_encode (
  //     .we_i        (we),
  //     .be_i        (be),
  //     .aid_i       (mgr_aid),
  //     .a_optional_i(a_optional),
  //     .other_ecc_o (other_ecc)
  //   );

  //   assign mgr_port_a_tmr.addr       = mgr_port_a_in_sbr.addr;
  //   assign mgr_port_a_tmr.wdata      = mgr_port_a_in_sbr.wdata;
  //   assign mgr_port_a_tmr.we         = we;
  //   assign mgr_port_a_tmr.be         = be;
  //   assign mgr_port_a_tmr.aid        = mgr_aid;
  //   assign mgr_port_a_tmr.a_optional = a_optional;
  //   assign mgr_port_a_tmr.other_ecc  = other_ecc;

  // end

  if (UseIdForRouting) begin : gen_id_assign
    // logic [MgrPortObiCfg.IdWidth-1:0] corr_rsp_rid;
    logic [SbrPortObiCfg.IdWidth-1:0] rsp_rid;
    relobi_r_other_decoder #(
      .Cfg          (MgrPortObiCfg),
      .r_optional_t (r_optional_t)
    ) i_r_other_decode (
      // .rid_i       (mgr_port_rsp_r.rid),
      .err_i       (mgr_port_rsp_r.err),
      .r_optional_i(mgr_port_rsp_r.r_optional),
      .other_ecc_i (mgr_port_rsp_r.other_ecc),
      // .rid_o       (corr_rsp_rid),
      .err_o       (),
      .r_optional_o(),
      .fault_o (hsiao_faults[1])
    );
    assign hsiao_faults_gated[1] = mgr_port_rsp_rvalid ? hsiao_faults[1] : '0;

    assign {response_id, rsp_rid} =
      mgr_rid[SbrPortObiCfg.IdWidth + RequiredExtraIdWidth-1:0];

    // TODO encode rsp_rid packet for sbrs?
  end else begin : gen_no_id_assign
    hsiao_ecc_enc #(
      .DataWidth (RequiredExtraIdWidth)
    ) i_ecc (
      .in        (selected_id),
      .out       (selected_id_tmr_three)
    );

    hsiao_ecc_dec #(
      .DataWidth (RequiredExtraIdWidth)
    ) i_ecc_dec (
      .in        (response_id_encoded),
      .out       (response_id),
      .syndrome_o(),
      .err_o     (hsiao_faults[1])
    );
    assign hsiao_faults_gated[1] = fifo_pop ? hsiao_faults[1] : '0;
  end

  always_comb begin
    sbr_rsp_rvalid = '0;
    sbr_rsp_rvalid[response_id] = mgr_rsp_rvalid;
  end
  if (MgrPortObiCfg.UseRReady) begin : gen_rready_connect
    assign mgr_req_rready = sbr_req_rready[response_id];
  end else begin : gen_rready_tie
    assign mgr_req_rready = '1;
  end


  if (MgrPortObiCfg.IdWidth == SbrPortObiCfg.IdWidth) begin : gen_rid_identical
    assign sbr_r_tmr = '0;
  end else begin : gen_rid_decrease
    // logic [MgrPortObiCfg.IdWidth-1:0] mgr_rid_tmr;
    // relobi_r_other_decoder #(
    //   .Cfg          (MgrPortObiCfg),
    //   .r_optional_t (r_optional_t)
    // ) i_r_other_decode (
    //   // .rid_i       (mgr_port_rsp_r.rid),
    //   .err_i       (mgr_port_rsp_r.err),
    //   .r_optional_i(mgr_port_rsp_r.r_optional),
    //   .other_ecc_i (mgr_port_rsp_r.other_ecc),
    //   // .rid_o       (mgr_rid_tmr),
    //   .err_o       (sbr_r_tmr.err),
    //   .r_optional_o(sbr_r_tmr.r_optional),
    //   .fault_o (hsiao_faults[2])
    // );
    // assign sbr_r_tmr.rid = mgr_rid_tmr[SbrPortObiCfg.IdWidth-1:0];
    // relobi_r_other_encoder #(
    //   .Cfg          (SbrPortObiCfg),
    //   .r_optional_t (r_optional_t)
    // ) i_r_other_encode (
    //   // .rid_i       (sbr_r_tmr.rid),
    //   .err_i       (sbr_r_tmr.err),
    //   .r_optional_i(sbr_r_tmr.r_optional),
    //   .other_ecc_o (sbr_r_tmr.other_ecc)
    // );
    assign sbr_r_tmr.rdata = mgr_port_rsp_r.rdata;
    assign sbr_r_tmr.rid[0] = mgr_port_rsp_r.rid[0][SbrPortObiCfg.IdWidth-1:0];
    assign sbr_r_tmr.rid[1] = mgr_port_rsp_r.rid[1][SbrPortObiCfg.IdWidth-1:0];
    assign sbr_r_tmr.rid[2] = mgr_port_rsp_r.rid[2][SbrPortObiCfg.IdWidth-1:0];
    assign sbr_r_tmr.err = mgr_port_rsp_r.err;
    assign sbr_r_tmr.r_optional = mgr_port_rsp_r.r_optional;
    assign sbr_r_tmr.other_ecc  = mgr_port_rsp_r.other_ecc;

  end

endmodule
