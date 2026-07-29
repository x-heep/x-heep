// Copyright 2025 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Michael Rogenmoser <michaero@iis.ee.ethz.ch

// Description: fault-tolerant logarithmic arbitration tree with round robin arbitration scheme.

`include "redundancy_cells/voters.svh"

/// The rr_arb_tree employs non-starving round robin-arbitration - i.e., the priorities
/// rotate each cycle.
///
/// ## Fair vs. unfair Arbitration
///
/// This refers to fair throughput distribution when not all inputs have active requests.
/// This module has an internal state `rr_q` which defines the highest priority input. (When
/// `ExtPrio` is `1'b1` this state is provided from the outside.) The arbitration tree will
/// choose the input with the same index as currently defined by the state if it has an active
/// request. Otherwise a *random* other active input is selected. The parameter `FairArb` is used
/// to distinguish between two methods of calculating the next state.
/// * `1'b0`: The next state is calculated by advancing the current state by one. This leads to the
///           state being calculated without the context of the active request. Leading to an
///           unfair throughput distribution if not all inputs have active requests.
/// * `1'b1`: The next state jumps to the next unserved request with higher index.
///           This is achieved by using two trailing-zero-counters (`lzc`). The upper has the masked
///           `req_i` signal with all indices which will have a higher priority in the next state.
///           The trailing zero count defines the input index with the next highest priority after
///           the current one is served. When the upper is empty the lower `lzc` provides the
///           wrapped index if there are outstanding requests with lower or same priority.
/// The implication of throughput fairness on the module timing are:
/// * The trailing zero counter (`lzc`) has a loglog relation of input to output timing. This means
///   that in this module the input to register path scales with Log(Log(`NumIn`)).
/// * The `rr_arb_tree` data multiplexing scales with Log(`NumIn`). This means that the input to output
///   timing path of this module also scales scales with Log(`NumIn`).
/// This implies that in this module the input to output path is always longer than the input to
/// register path. As the output data usually also terminates in a register the parameter `FairArb`
/// only has implications on the area. When it is `1'b0` a static plus one adder is instantiated.
/// If it is `1'b1` two `lzc`, a masking logic stage and a two input multiplexer are instantiated.
/// However these are small in respect of the data multiplexers needed, as the width of the `req_i`
/// signal is usually less as than `DataWidth`.

/// TODO: unfair arb or external priority may not be reliable!
module rel_rr_arb_tree #(
  /// Number of inputs to be arbitrated.
  parameter int unsigned NumIn      = 64,
  /// Data width of the payload in bits. Not needed if `DataType` is overwritten.
  parameter int unsigned DataWidth  = 32,
  /// Data type of the payload, can be overwritten with custom type. Only use of `DataWidth`.
  parameter type         DataType   = logic [DataWidth-1:0],
  /// The `ExtPrio` option allows to override the internal round robin counter via the
  /// `rr_i` signal. This can be useful in case multiple arbiters need to have
  /// rotating priorities that are operating in lock-step. If static priority arbitration
  /// is needed, just connect `rr_i` to '0.
  ///
  /// Set to 1'b1 to enable.
  parameter bit          ExtPrio    = 1'b0,
  /// If `AxiVldRdy` is set, the req/gnt signals are compliant with the AXI style vld/rdy
  /// handshake. Namely, upstream vld (req) must not depend on rdy (gnt), as it can be deasserted
  /// again even though vld is asserted. Enabling `AxiVldRdy` leads to a reduction of arbiter
  /// delay and area.
  ///
  /// Set to `1'b1` to treat req/gnt as vld/rdy.
  parameter bit          AxiVldRdy  = 1'b0,
  /// The `LockIn` option prevents the arbiter from changing the arbitration
  /// decision when the arbiter is disabled. I.e., the index of the first request
  /// that wins the arbitration will be locked in case the destination is not
  /// able to grant the request in the same cycle.
  ///
  /// Set to `1'b1` to enable.
  parameter bit          LockIn     = 1'b0,
  /// When set, ensures that throughput gets distributed evenly between all inputs.
  ///
  /// Set to `1'b0` to disable.
  parameter bit          FairArb    = 1'b1,
  /// IO handshake signal triplicated or not
  parameter bit          TmrStatus  = 1'b0,
  /// Have the TMR before the register, otherwise after.
  parameter bit          TmrBeforeReg = 1'b0,
  /// Dependent parameter, do **not** overwrite.
  /// Width of the arbitration priority signal and the arbitrated index.
  parameter int unsigned IdxWidth   = (NumIn > 32'd1) ? unsigned'($clog2(NumIn)) : 32'd1,
  /// Dependent parameter, do **not** overwrite.
  /// Type for defining the arbitration priority and arbitrated index signal.
  parameter type         idx_t      = logic [IdxWidth-1:0],
  /// Dependent parameter, do **not** overwrite.
  parameter int unsigned HsWidth    = TmrStatus ? 3 : 1
) (
  /// Clock, positive edge triggered.
  input  logic                clk_i,
  /// Asynchronous reset, active low.
  input  logic                rst_ni,
  /// Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
  input  logic                flush_i,
  /// External round-robin priority. Only used if `ExtPrio` is `1'b1.`
  input  idx_t                rr_i,
  /// Input requests arbitration.
  input  logic    [NumIn-1:0][HsWidth-1:0] req_i,
  /* verilator lint_off UNOPTFLAT */
  /// Input request is granted.
  output logic    [NumIn-1:0][HsWidth-1:0] gnt_o,
  /* verilator lint_on UNOPTFLAT */
  /// Input data for arbitration.
  input  DataType [NumIn-1:0] data_i,
  /// Output request is valid.
  output logic               [HsWidth-1:0] req_o,
  /// Output request is granted.
  input  logic               [HsWidth-1:0] gnt_i,
  /// Output data.
  output DataType             data_o,
  /// Index from which input the data came from.
  output idx_t               [HsWidth-1:0] idx_o,
  /// Reliability error
  output logic                             fault_o
);

  `ifndef SYNTHESIS
  `ifndef COMMON_CELLS_ASSERTS_OFF
  `ifndef VERILATOR
  `ifndef XSIM
  // Default SVA reset
  default disable iff (!rst_ni || flush_i);
  `endif
  `endif
  `endif
  `endif

  logic [8:0] tmr_errors;
  assign fault_o = |tmr_errors;

  // just pass through in this corner case
  if (NumIn == unsigned'(1)) begin : gen_pass_through
    assign req_o    = req_i[0];
    assign gnt_o[0] = gnt_i;
    assign data_o   = data_i[0];
    assign idx_o    = '0;
    assign tmr_errors = '0;
  // non-degenerate cases
  end else begin : gen_arbiter
    logic [2:0][NumIn-1:0] req_in, gnt_out;
    logic [2:0]            req_out, gnt_in;
    idx_t [2:0]            idx_out;
    idx_t [2:0][$bits(DataType)-1:0] idx_data_out;
    DataType [2**IdxWidth-1:0] data_in;
    always_comb begin
      data_in = '0;
      for (int i = 0; i < NumIn; i++) begin : gen_data_in
          data_in[i] = data_i[i];
      end
    end
    if (TmrStatus) begin : gen_req_in
      for (genvar i = 0; i < NumIn; i++) begin : gen_req_in_single
        assign req_in[0][i] = req_i[i][0];
        assign req_in[1][i] = req_i[i][1];
        assign req_in[2][i] = req_i[i][2];
        assign gnt_o[i][0] = gnt_out[0][i];
        assign gnt_o[i][1] = gnt_out[1][i];
        assign gnt_o[i][2] = gnt_out[2][i];
      end
      assign req_o = req_out;
      assign gnt_in = gnt_i;
      assign idx_o = idx_out;
      assign tmr_errors[4:0] = '0;
    end else begin : gen_req_in_triplicate
      for (genvar i = 0; i < NumIn; i++) begin : gen_req_in
        assign req_in[0][i] = req_i[i];
        assign req_in[1][i] = req_i[i];
        assign req_in[2][i] = req_i[i];
        TMR_voter_fail #(
          .VoterType(1)
        ) i_gnt_o_vote (
          .a_i(gnt_out[0][i]),
          .b_i(gnt_out[1][i]),
          .c_i(gnt_out[2][i]),
          .majority_o(gnt_o[i]),
          .fault_detected_o(tmr_errors[i])
        );
      end
        TMR_voter_fail #(
          .VoterType(1)
        ) i_req_o_vote (
          .a_i(req_out[0]),
          .b_i(req_out[1]),
          .c_i(req_out[2]),
          .majority_o(req_o),
          .fault_detected_o(tmr_errors[3])
        );
      assign gnt_in = gnt_i;
        bitwise_TMR_voter_fail #(
          .VoterType(1)
        ) i_idx_o_vote (
          .a_i(idx_out[0]),
          .b_i(idx_out[1]),
          .c_i(idx_out[2]),
          .majority_o(idx_o),
          .fault_detected_o(tmr_errors[4])
        );
    end

    localparam int unsigned NumLevels = unsigned'($clog2(NumIn));
    logic [2:0][$bits(DataType)-1:0][2**NumLevels-2:0] data_nodes_sel;

    for (genvar i = 0; i < $bits(DataType); i++) begin : gen_data_out_mux
      logic [2**NumLevels-2:0] local_sel;
      logic [2**NumLevels-2:0] data_nodes;
      logic local_fault;
      if (i == 0) assign tmr_errors[5] = local_fault;
      bitwise_TMR_voter_fail #(
        .DataWidth(2**NumLevels-1),
        .VoterType(1)
      ) i_idx_vote (
        .a_i(data_nodes_sel[0][i]),
        .b_i(data_nodes_sel[1][i]),
        .c_i(data_nodes_sel[2][i]),
        .majority_o(local_sel),
        .fault_detected_o(local_fault)
      );
      assign data_o[i] = data_nodes[0];
      // assign data_o[i] = data_in[local_index][i];
      for (genvar level = 0; unsigned'(level) < NumLevels; level++) begin : gen_levels
        for (genvar l = 0; l < 2**level; l++) begin : gen_level
          // index calcs
          localparam int unsigned Idx0 = 2**level-1+l;// current node
          localparam int unsigned Idx1 = 2**(level+1)-1+l*2;
          //////////////////////////////////////////////////////////////
          // uppermost level where data is fed in from the inputs
          if (unsigned'(level) == NumLevels-1) begin : gen_first_level
            // if two successive indices are still in the vector...
            if (unsigned'(l) * 2 < NumIn-1) begin : gen_reduce
              assign data_nodes[Idx0]  = (local_sel[Idx0]) ? data_in[l*2+1][i] : data_in[l*2][i];
            end
            // if only the first index is still in the vector...
            if (unsigned'(l) * 2 == NumIn-1) begin : gen_first
              assign data_nodes[Idx0]  = data_in[l*2][i];
            end
            // if index is out of range, fill up with zeros (will get pruned)
            if (unsigned'(l) * 2 > NumIn-1) begin : gen_out_of_range
              assign data_nodes[Idx0]  = '0;
            end
          //////////////////////////////////////////////////////////////
          // general case for other levels within the tree
          end else begin : gen_other_levels
            assign data_nodes[Idx0]  = (local_sel[Idx0]) ? data_nodes[Idx1+1] : data_nodes[Idx1];
          end
        end
      end
    end

    /* verilator lint_off UNOPTFLAT */
    // DataType [2:0] data_nodes_0;  // used to propagate the data
    /* lint_off */
    // idx_t            [2:0]      rr_q;
    // logic [NumIn-1:0][2:0]      req_d;

    // the final arbitration decision can be taken from the root of the tree
    // bitwise_TMR_voter_fail #(
    //   .DataWidth($bits(DataType)),
    //   .VoterType(1)
    // ) i_data_vote (
    //   .a_i        (data_nodes_0[0]),
    //   .b_i        (data_nodes_0[1]),
    //   .c_i        (data_nodes_0[2]),
    //   .majority_o (data_o),
    //   .fault_detected_o(tmr_errors[5])
    // );

    logic [2:0] lock_sync;
    logic [2:0][1:0] alt_lock_sync;
    logic [2:0][NumIn-1:0] req_d_sync;
    logic [2:0][1:0][NumIn-1:0] alt_req_d_sync;
    idx_t [2:0] rr_d_sync;
    idx_t [2:0][1:0] alt_rr_d_sync;

    for (genvar i = 0; i < 3; i++) begin : gen_in_rr_tmr
      for (genvar j = 0; j < 2; j++) begin: gen_sync
        assign alt_lock_sync[i][j] = lock_sync[(i+j+1) % 3];
        assign alt_req_d_sync[i][j] = req_d_sync[(i+j+1) % 3];
        assign alt_rr_d_sync[i][j] = rr_d_sync[(i+j+1) % 3];
      end
      rel_rr_arb_tree_tmr_part #(
        .NumIn        ( NumIn ),
        .DataWidth    ( DataWidth ),
        .DataType     ( DataType ),
        .ExtPrio      ( ExtPrio ),
        .AxiVldRdy    ( AxiVldRdy ),
        .LockIn       ( LockIn ),
        .FairArb      ( FairArb ),
        .TmrBeforeReg ( TmrBeforeReg ),
        .IdxWidth     ( IdxWidth ),
        .idx_t        ( idx_t )
      ) i_tmr_part (
        .clk_i            ( clk_i ),
        .rst_ni           ( rst_ni ),
        .flush_i          ( flush_i ),
        .rr_i             ( rr_i ),
        .req_in_i         ( req_in[i] ),
        .gnt_out_o        ( gnt_out[i] ),
        .req_out_o        ( req_out[i] ),
        .gnt_in_i         ( gnt_in[i] ),
        .idx_out_o        ( idx_out[i] ),
        .idx_data_out_o   ( idx_data_out[i] ),
        .alt_lock_sync_i  ( alt_lock_sync[i] ),
        .lock_sync_o      ( lock_sync[i] ),
        .alt_req_d_sync_i ( alt_req_d_sync[i] ),
        .req_d_sync_o     ( req_d_sync[i] ),
        .alt_rr_d_sync_i  ( alt_rr_d_sync[i] ),
        .rr_d_sync_o      ( rr_d_sync[i] ),
        .data_nodes_sel_o ( data_nodes_sel[i] ),
        .tmr_error_o      ( tmr_errors[6+i] )
      );
    end

    `ifndef SYNTHESIS
    `ifndef RED_CELLS_ASSERTS_OFF
    `ifndef XSIM
    initial begin : p_assert
      assert(NumIn)
        else $fatal(1, "Input must be at least one element wide.");
      assert(!(LockIn && ExtPrio))
        else $fatal(1,"Cannot use LockIn feature together with external ExtPrio.");
    end

    hot_one : assert property(
      @(posedge clk_i) disable iff (!rst_ni || flush_i) $onehot0(gnt_out[0]))
        else $fatal (1, "Grant signal must be hot1 or zero.");

    gnt0 : assert property(
      @(posedge clk_i) disable iff (!rst_ni || flush_i) |gnt_out[0] |-> gnt_i[0])
        else $fatal (1, "Grant out implies grant in.");

    gnt1 : assert property(
      @(posedge clk_i) disable iff (!rst_ni || flush_i) req_o[0] |-> gnt_i[0] |-> |gnt_out[0])
        else $fatal (1, "Req out and grant in implies grant out.");

    gnt_idx : assert property(
      @(posedge clk_i) disable iff (!rst_ni || flush_i) req_o[0] |->
                                                        gnt_i[0] |-> gnt_out[0][idx_o[0]])
        else $fatal (1, "Idx_o / gnt_o do not match.");

    req0 : assert property(
      @(posedge clk_i) disable iff (!rst_ni || flush_i) |req_i |-> req_o)
        else $fatal (1, "Req in implies req out.");

    req1 : assert property(
      @(posedge clk_i) disable iff (!rst_ni || flush_i) req_o |-> |req_i)
        else $fatal (1, "Req out implies req in.");
    `endif
    `endif
    `endif
  end

endmodule

(* no_ungroup *)
(* no_boundary_optimization *)
module rel_rr_arb_tree_tmr_part #(
  parameter int unsigned NumIn        = 64,
  parameter int unsigned DataWidth    = 32,
  parameter type         DataType     = logic [DataWidth-1:0],
  parameter bit          ExtPrio      = 1'b0,
  parameter bit          AxiVldRdy    = 1'b0,
  parameter bit          LockIn       = 1'b0,
  parameter bit          FairArb      = 1'b1,
  parameter bit          TmrBeforeReg = 1'b0,
  parameter int unsigned IdxWidth     = (NumIn > 32'd1) ? unsigned'($clog2(NumIn)) : 32'd1,
  parameter type         idx_t        = logic [IdxWidth-1:0],
  localparam int unsigned NumLevels = unsigned'($clog2(NumIn))
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  flush_i,
  input  idx_t                  rr_i,
  input  logic      [NumIn-1:0] req_in_i,
  output logic      [NumIn-1:0] gnt_out_o,
  output logic                  req_out_o,
  input  logic                  gnt_in_i,
  output idx_t                  idx_out_o,
  output idx_t [$bits(DataType)-1:0]  idx_data_out_o,
  input  logic [1:0]            alt_lock_sync_i,
  output logic                  lock_sync_o,
  input  logic [1:0][NumIn-1:0] alt_req_d_sync_i,
  output logic      [NumIn-1:0] req_d_sync_o,
  input  idx_t [1:0]            alt_rr_d_sync_i,
  output idx_t                  rr_d_sync_o,
  output logic [$bits(DataType)-1:0][2**NumLevels-2:0] data_nodes_sel_o,
  output logic                  tmr_error_o
);

  idx_t rr_q;
  logic [NumIn-1:0] req_d;

  logic [2+NumIn-1:0]    tmr_errors;
  assign tmr_error_o = |tmr_errors;

  for (genvar i = 0; i < $bits(DataType); i++) begin : gen_idx_data_out
    assign idx_data_out_o[i] = idx_out_o;
    if (i != 0)
      assign data_nodes_sel_o[i] = data_nodes_sel_o[0];
  end

  if (ExtPrio) begin : gen_ext_rr
    assign rr_q = rr_i;
    assign req_d = req_in_i;
    assign tmr_errors = '0;
    assign lock_sync_o = '0;
    assign req_d_sync_o = '0;
    assign rr_d_sync_o = '0;
  end else begin : gen_int_rr
    idx_t rr_d;

    if (LockIn) begin : gen_lock
      logic lock_d, lock_q;
      logic [NumIn-1:0] req_q;

      assign lock_d = req_out_o & ~gnt_in_i;
      assign req_d = (lock_q) ? req_q : req_in_i;

      if (TmrBeforeReg) begin : gen_lock_tmr_before_reg
        logic lock_voted;
        assign lock_sync_o = lock_d;
        TMR_voter_fail #(
          .VoterType(1)
        ) i_lock_vote (
          .a_i(lock_d),
          .b_i(alt_lock_sync_i[0]),
          .c_i(alt_lock_sync_i[1]),
          .majority_o(lock_voted),
          .fault_detected_o(tmr_errors[0])
        );
        always_ff @(posedge clk_i or negedge rst_ni) begin : p_lock_reg
          if (!rst_ni) begin
            lock_q <= '0;
          end else begin
            if (flush_i) begin
              lock_q <= '0;
            end else begin
              lock_q <= lock_voted;
            end
          end
        end
      end else begin : gen_lock_tmr_after_reg
        logic lock_next;
        assign lock_sync_o = lock_next;
        TMR_voter_fail #(
          .VoterType(1)
        ) i_lock_vote (
          .a_i(lock_next),
          .b_i(alt_lock_sync_i[0]),
          .c_i(alt_lock_sync_i[1]),
          .majority_o(lock_q),
          .fault_detected_o(tmr_errors[0])
        );
        always_ff @(posedge clk_i or negedge rst_ni) begin : p_lock_reg
          if (!rst_ni) begin
            lock_next <= '0;
          end else begin
            if (flush_i) begin
              lock_next <= '0;
            end else begin
              lock_next <= lock_d;
            end
          end
        end
      end

      `ifndef SYNTHESIS
      `ifndef RED_CELLS_ASSERTS_OFF
        lock: assert property(
          @(posedge clk_i) disable iff (!rst_ni || flush_i)
            LockIn |-> req_out_o && (!gnt_in_i && !flush_i) |=> idx_out_o == $past(idx_out_o)) else
            $fatal (1, {"Lock implies same arbiter decision in next cycle if output is not ",
                        "ready."});

        logic [NumIn-1:0] req_tmp;
        assign req_tmp = req_q & req_in_i;
        lock_req: assume property(
          @(posedge clk_i) disable iff (!rst_ni || flush_i)
              LockIn |-> lock_d |=> req_tmp == req_q) else
              $fatal (1, {"It is disallowed to deassert unserved request signals when LockIn is ",
                          "enabled."});
      `endif
      `endif

      if (TmrBeforeReg) begin : gen_req_tmr_before_reg
        logic [NumIn-1:0] req_voted;
        assign req_d_sync_o = req_d;
        for (genvar i = 0; i < NumIn; i++) begin : gen_vote_req
          TMR_voter_fail #(
            .VoterType(1)
          ) i_req_d_vote (
            .a_i(req_d[i]),
            .b_i(alt_req_d_sync_i[0][i]),
            .c_i(alt_req_d_sync_i[1][i]),
            .majority_o(req_voted[i]),
            .fault_detected_o(tmr_errors[2+i])
          );
        end
        always_ff @(posedge clk_i or negedge rst_ni) begin : p_lock_reg
          if (!rst_ni) begin
            req_q <= '0;
          end else begin
            if (flush_i) begin
              req_q <= '0;
            end else begin
              req_q <= req_voted;
            end
          end
        end
      end else begin : gen_req_tmr_after_reg
        logic [NumIn-1:0] req_next;
        assign req_d_sync_o = req_next;
        for (genvar i = 0; i < NumIn; i++) begin : gen_vote_req
          TMR_voter_fail #(
            .VoterType(1)
          ) i_req_next_vote (
            .a_i(req_next[i]),
            .b_i(alt_req_d_sync_i[0][i]),
            .c_i(alt_req_d_sync_i[1][i]),
            .majority_o(req_q[i]),
            .fault_detected_o(tmr_errors[2+i])
          );
        end
        always_ff @(posedge clk_i or negedge rst_ni) begin : p_lock_reg
          if (!rst_ni) begin
            req_next <= '0;
          end else begin
            if (flush_i) begin
              req_next <= '0;
            end else begin
              req_next <= req_d;
            end
          end
        end
      end
    end else begin : gen_no_lock
      assign req_d = req_in_i;
      assign tmr_errors[0] = '0;
      assign tmr_errors[2:NumIn+1] = '0;
      assign lock_sync_o = '0;
      assign req_d_sync_o = '0;
    end


    if (FairArb) begin : gen_fair_arb
      logic [NumIn-1:0] upper_mask,  lower_mask;
      idx_t             upper_idx,   lower_idx,   next_idx;
      logic             upper_empty, lower_empty;

      for (genvar i = 0; i < NumIn; i++) begin : gen_mask
        assign upper_mask[i] = (i >  rr_q) ? req_d[i] : 1'b0;
        assign lower_mask[i] = (i <= rr_q) ? req_d[i] : 1'b0;
      end

      lzc #(
        .WIDTH ( NumIn ),
        .MODE  ( 1'b0  )
      ) i_lzc_upper (
        .in_i    ( upper_mask  ),
        .cnt_o   ( upper_idx   ),
        .empty_o ( upper_empty )
      );

      lzc #(
        .WIDTH ( NumIn ),
        .MODE  ( 1'b0  )
      ) i_lzc_lower (
        .in_i    ( lower_mask  ),
        .cnt_o   ( lower_idx   ),
        .empty_o ( /*unused*/  )
      );

      assign next_idx = upper_empty      ? lower_idx : upper_idx;
      assign rr_d     = (gnt_in_i && req_out_o) ? next_idx  : rr_q;

    end else begin : gen_unfair_arb
      assign rr_d = (gnt_in_i && req_out_o) ?
                    ((rr_q == idx_t'(NumIn-1)) ? '0 : rr_q + 1'b1) : rr_q;
    end

    if (TmrBeforeReg) begin : gen_rr_tmr_before_reg
      idx_t rr_voted;
      assign rr_d_sync_o = rr_d;
      bitwise_TMR_voter_fail #(
        .DataWidth(IdxWidth),
        .VoterType(1)
      ) i_rr_d_vote (
        .a_i(rr_d),
        .b_i(alt_rr_d_sync_i[0]),
        .c_i(alt_rr_d_sync_i[1]),
        .majority_o(rr_voted),
        .fault_detected_o(tmr_errors[1])
      );
      always_ff @(posedge clk_i or negedge rst_ni) begin : p_rr_regs
        if (!rst_ni) begin
          rr_q <= '0;
        end else begin
          if (flush_i) begin
            rr_q <= '0;
          end else begin
            rr_q <= rr_voted;
          end
        end
      end
    end else begin : gen_rr_tmr_after_reg
      idx_t rr_next;
      assign rr_d_sync_o = rr_next;
      bitwise_TMR_voter_fail #(
        .DataWidth(IdxWidth),
        .VoterType(1)
      ) i_rr_next_vote (
        .a_i(rr_next),
        .b_i(alt_rr_d_sync_i[0]),
        .c_i(alt_rr_d_sync_i[1]),
        .majority_o(rr_q),
        .fault_detected_o(tmr_errors[1])
      );
      always_ff @(posedge clk_i or negedge rst_ni) begin : p_rr_regs
        if (!rst_ni) begin
          rr_next <= '0;
        end else begin
          if (flush_i) begin
            rr_next <= '0;
          end else begin
            rr_next <= rr_d;
          end
        end
      end
    end
  end

  /* verilator lint_off UNOPTFLAT */
  logic    [2**NumLevels-2:0] req_nodes;
  logic    [2**NumLevels-2:0] gnt_nodes;
  // DataType [2**NumLevels-2:0] data_nodes;  // used to propagate the data
  idx_t    [2**NumLevels-2:0] index_nodes; // used to propagate the indices
  /* lint_off */

  assign req_out_o = req_nodes[0];
  assign gnt_nodes[0] = gnt_in_i;
  // assign data_nodes_0 = data_nodes[0];
  assign idx_out_o = index_nodes[0];

  for (genvar level = 0; unsigned'(level) < NumLevels; level++) begin : gen_levels
    for (genvar l = 0; l < 2**level; l++) begin : gen_level
      // local select signal
      logic sel;
      // index calcs
      localparam int unsigned Idx0 = 2**level-1+l;// current node
      localparam int unsigned Idx1 = 2**(level+1)-1+l*2;
      //////////////////////////////////////////////////////////////
      // uppermost level where data is fed in from the inputs
      if (unsigned'(level) == NumLevels-1) begin : gen_first_level
        // if two successive indices are still in the vector...
        if (unsigned'(l) * 2 < NumIn-1) begin : gen_reduce
          assign req_nodes[Idx0]   = req_d[l*2] | req_d[l*2+1];

          // arbitration: round robin
          assign sel =  ~req_d[l*2] | req_d[l*2+1] & rr_q[NumLevels-1-level];

          assign index_nodes[Idx0] = idx_t'(sel);
          assign data_nodes_sel_o[0][Idx0] = sel;
          // assign data_nodes[Idx0]  = (sel) ? data_i[l*2+1] : data_i[l*2];
          assign gnt_out_o[l*2]   = gnt_nodes[Idx0] & (AxiVldRdy | req_d[l*2])  & ~sel;
          assign gnt_out_o[l*2+1] = gnt_nodes[Idx0] & (AxiVldRdy | req_d[l*2+1]) & sel;
        end
        // if only the first index is still in the vector...
        if (unsigned'(l) * 2 == NumIn-1) begin : gen_first
          assign req_nodes[Idx0]   = req_d[l*2];
          assign index_nodes[Idx0] = '0;// always zero in this case
          assign data_nodes_sel_o[0][Idx0] = 1'b0;
          // assign data_nodes[Idx0]  = data_i[l*2];
          assign gnt_out_o[l*2]      = gnt_nodes[Idx0] & (AxiVldRdy | req_d[l*2]);
        end
        // if index is out of range, fill up with zeros (will get pruned)
        if (unsigned'(l) * 2 > NumIn-1) begin : gen_out_of_range
          assign req_nodes[Idx0]   = 1'b0;
          assign index_nodes[Idx0] = idx_t'('0);
          assign data_nodes_sel_o[0][Idx0] = '0;
          // assign data_nodes[Idx0]  = DataType'('0);
        end
      //////////////////////////////////////////////////////////////
      // general case for other levels within the tree
      end else begin : gen_other_levels
        assign req_nodes[Idx0]   = req_nodes[Idx1] | req_nodes[Idx1+1];

        // arbitration: round robin
        assign sel =  ~req_nodes[Idx1] | req_nodes[Idx1+1] & rr_q[NumLevels-1-level];

        assign index_nodes[Idx0] = (sel) ?
          idx_t'({1'b1, index_nodes[Idx1+1][NumLevels-unsigned'(level)-2:0]}) :
          idx_t'({1'b0, index_nodes[Idx1][NumLevels-unsigned'(level)-2:0]});

        assign data_nodes_sel_o[0][Idx0] = sel;
        // assign data_nodes[Idx0]  = (sel) ? data_nodes[Idx1+1] : data_nodes[Idx1];
        assign gnt_nodes[Idx1]   = gnt_nodes[Idx0] & ~sel;
        assign gnt_nodes[Idx1+1] = gnt_nodes[Idx0] & sel;
      end
      //////////////////////////////////////////////////////////////
    end
  end


endmodule
