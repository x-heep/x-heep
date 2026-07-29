// Copyright 2025 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Michael Rogenmoser <michaero@iis.ee.ethz.ch>

`include "redundancy_cells/voters.svh"

module rel_fifo #(
  /// fifo is in fall-through mode
  parameter bit          FallThrough = 1'b0,
  /// default data width if the fifo is of type logic
  parameter int unsigned DataWidth   = 32,
  /// depth can be arbitrary from 0 to 2**32
  parameter int unsigned Depth       = 8,
  /// Status and control signals are triplicated
  parameter bit          TmrStatus   = 1'b0,
  /// Input data has ECC (setting to 0 will add ecc encoders and decoders and assume simple logic vector, currently unimplemented)
  parameter bit          DataHasEcc  = 1'b1,
  /// Use dedicated registers for status_cnt_q (better timing, higher area, likely to be optimized away, currently unimplemented)
  parameter bit          StatusFF    = 1'b0,
  // DO NOT OVERWRITE THESE PARAMETERS
  parameter int unsigned AddrDepth   = cf_math_pkg::idx_width(Depth),
  parameter int unsigned HsWidth     = TmrStatus ? 3 : 1
)(
  /// Clock
  input  logic                 clk_i,
  /// Asynchronous reset active low
  input  logic                 rst_ni,
  /// flush the queue
  input  logic [  HsWidth-1:0] flush_i,
  /// test_mode to bypass clock gating
  input  logic                 testmode_i,
  /// status flags:
  /// queue is full
  output logic [  HsWidth-1:0] full_o,
  /// queue is empty
  output logic [  HsWidth-1:0] empty_o,
  /// fill pointer (unprotected, use full_o or empty_o)
  output logic [AddrDepth-1:0] usage_o,
  /// as long as the queue is not full we can push new data
  /// data to push into the queue
  input  logic [DataWidth-1:0] data_i,
  /// data is valid and can be pushed to the queue
  input  logic [  HsWidth-1:0] push_i,
  /// as long as the queue is not empty we can pop new elements
  /// output data
  output logic [DataWidth-1:0] data_o,
  /// pop head from queue
  input  logic [  HsWidth-1:0] pop_i,
  /// tmr fault output signal
  output logic                 fault_o
);
  // local parameter
  // FIFO depth - handle the case of pass-through, synthesizer will do constant propagation
  localparam int unsigned FifoDepth = (Depth > 0) ? Depth : 1;

  // TODO: DataHasEcc ? data_t : logic [hsiao_pkg::min_ecc(DataWidth)+DataWidth-1:0];
  localparam int unsigned EccDataWidth = DataWidth;

  logic [9:0] tmr_faults;
  logic [FifoDepth-1:0][EccDataWidth-1:0] data_tmr_faults;
  assign fault_o = |tmr_faults;

  // clock gating control
  logic [2:0][FifoDepth-1:0][EccDataWidth-1:0] gate_clock;
  // pointer to the read and write section of the queue
  logic [2:0][AddrDepth:0] read_pointer_n,
                           read_pointer_q,
                           write_pointer_n,
                           write_pointer_q,
                           status_cnt_n,
                           status_cnt_q;
  logic [2:0] full, empty, push, pop, flush;

  logic [EccDataWidth-1:0] data_in;
  logic [EccDataWidth-1:0] data_out;

  // actual memory
  logic [FifoDepth-1:0][EccDataWidth-1:0] mem_q;

  if (!DataHasEcc) begin : gen_ecc_encode
    $error("unimplemented");
    // TODO ecc encoding of data_i into data_in
    // TODO ecc decoding of data_out into data_o
  end else begin : gen_ecc_passthrough
    assign data_in = data_i;
    assign data_o = data_out;
  end

  logic [2:0][AddrDepth:0] read_pointer_n_sync,
                           write_pointer_n_sync;
  logic [2:0][1:0][AddrDepth:0] alt_read_pointer_n_sync,
                                alt_write_pointer_n_sync;

  logic [2:0][EccDataWidth-1:0][AddrDepth:0] read_pointer_next;
  logic [2:0][EccDataWidth-1:0] use_fallthrough;

  logic [EccDataWidth-1:0] data_out_faults;
  assign tmr_faults[0] = |data_out_faults;

  for (genvar i = 0; i < EccDataWidth; i++) begin : gen_data_out_mux
    logic [AddrDepth:0] read_pointer_next_local;
    logic use_fallthrough_local;
    logic [1:0] local_faults;
    assign data_out_faults[i] = |local_faults;
    bitwise_TMR_voter_fail #(
      .DataWidth(AddrDepth+1)
    ) i_read_pointer_next_vote (
      .a_i(read_pointer_next[0][i]),
      .b_i(read_pointer_next[1][i]),
      .c_i(read_pointer_next[2][i]),
      .majority_o(read_pointer_next_local),
      .fault_detected_o(local_faults[0])
    );
    TMR_voter_fail #(
      .VoterType(1)
    ) i_use_fallthrough_vote (
      .a_i(use_fallthrough[0][i]),
      .b_i(use_fallthrough[1][i]),
      .c_i(use_fallthrough[2][i]),
      .majority_o(use_fallthrough_local),
      .fault_detected_o(local_faults[1])
    );
    assign data_out[i] = use_fallthrough_local ?
                         data_in[i] : mem_q[read_pointer_next_local[AddrDepth-1:0]][i];
  end

  if (TmrStatus) begin : gen_tmr_status
    assign full_o = full;
    assign empty_o = empty;
    assign push = push_i;
    assign pop = pop_i;
    assign flush = flush_i;
    assign tmr_faults[1] = '0;
    assign tmr_faults[2] = '0;
  end else begin : gen_voted_status
    assign push = {push_i, push_i, push_i};
    assign pop = {pop_i, pop_i, pop_i};
    assign flush = {flush_i, flush_i, flush_i};
    TMR_voter_fail #(
      .VoterType(1)
    ) i_full_tmr_vote (
      .a_i(full[0]),
      .b_i(full[1]),
      .c_i(full[2]),
      .majority_o(full_o),
      .fault_detected_o(tmr_faults[1])
    );
    TMR_voter_fail #(
      .VoterType(1)
    ) i_empty_tmr_vote (
      .a_i(empty[0]),
      .b_i(empty[1]),
      .c_i(empty[2]),
      .majority_o(empty_o),
      .fault_detected_o(tmr_faults[2])
    );
  end

  for (genvar i = 0; i < 3; i++) begin : gen_tmr_parts
    for (genvar j = 0; j < 2; j++) begin : gen_alt_sync
      assign alt_read_pointer_n_sync[i][j]  = read_pointer_n_sync[(i+j+1) % 3];
      assign alt_write_pointer_n_sync[i][j] = write_pointer_n_sync[(i+j+1) % 3];
    end
    rel_fifo_tmr_part #(
      .FallThrough(FallThrough),
      .EccDataWidth(EccDataWidth),
      .Depth(Depth),
      .FifoDepth(FifoDepth),
      .AddrDepth(AddrDepth),
      .StatusFF(StatusFF)
    ) i_tmr_part (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .flush_i(flush[i]),
      .full_o(full[i]),
      .empty_o(empty[i]),
      .push_i(push[i]),
      .pop_i(pop[i]),
      .gate_clock_o(gate_clock[i]),
      .read_pointer_next_multi_o(read_pointer_next[i]),
      .use_fallthrough_o(use_fallthrough[i]),
      .status_cnt_q_o(status_cnt_q[i]),
      .read_pointer_q_o(read_pointer_q[i]),
      .write_pointer_q_o(write_pointer_q[i]),
      .status_cnt_n_o(status_cnt_n[i]),
      .read_pointer_n_o(read_pointer_n[i]),
      .write_pointer_n_o(write_pointer_n[i]),
      .alt_read_pointer_n_sync_i(alt_read_pointer_n_sync[i]),
      .read_pointer_n_sync_o(read_pointer_n_sync[i]),
      .alt_write_pointer_n_sync_i(alt_write_pointer_n_sync[i]),
      .write_pointer_n_sync_o(write_pointer_n_sync[i]),
      .tmr_faults_o(tmr_faults[5+(2*i):4+(2*i)])
    );
  end

  assign usage_o = status_cnt_q[0][AddrDepth-1:0];

  assign tmr_faults[3] = |data_tmr_faults;

  for (genvar i = 0; i < FifoDepth; i++) begin : gen_mem_ffs_depth
    for (genvar j = 0; j < EccDataWidth; j++) begin : gen_mem_ffs
      logic gate_clock_local;
      TMR_voter_fail #(
        .VoterType(1)
      ) i_gate_clock_vote (
        .a_i(gate_clock[0][i][j]),
        .b_i(gate_clock[1][i][j]),
        .c_i(gate_clock[2][i][j]),
        .majority_o(gate_clock_local),
        .fault_detected_o(data_tmr_faults[i][j])
      );
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
          mem_q[i][j] <= '0;
        end else if (!gate_clock_local) begin
          mem_q[i][j] <= data_in[j];
        end
      end
    end
  end

// pragma translate_off
`ifndef VERILATOR
`ifndef RED_CELLS_ASSERTS_OFF
  initial begin
    assert (Depth > 0)             else $error("Depth must be greater than 0.");
  end

  full_write : assert property(
    @(posedge clk_i) disable iff (~rst_ni) (full_o |-> ~push_i))
    else $fatal (1, "Trying to push new data although the FIFO is full.");

  empty_read : assert property(
    @(posedge clk_i) disable iff (~rst_ni) (empty_o |-> ~pop_i))
    else $fatal (1, "Trying to pop data although the FIFO is empty.");
`endif
`endif
// pragma translate_on

endmodule

(* no_ungroup *)
(* no_boundary_optimization *)
module rel_fifo_tmr_part #(
  parameter bit          FallThrough = 1'b0,
  parameter int unsigned EccDataWidth = 39,
  parameter int unsigned Depth       = 8,
  parameter int unsigned FifoDepth   = 8,
  parameter int unsigned AddrDepth = 8,
  parameter bit          StatusFF   = 1'b0
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic flush_i,
  output logic full_o,
  output logic empty_o,
  input  logic push_i,
  input  logic pop_i,
  output logic [FifoDepth-1:0][EccDataWidth-1:0] gate_clock_o,
  output logic [EccDataWidth-1:0][AddrDepth:0] read_pointer_next_multi_o,
  output logic [EccDataWidth-1:0] use_fallthrough_o,
  output logic [AddrDepth:0] status_cnt_q_o,
  output logic [AddrDepth:0] read_pointer_q_o,
  output logic [AddrDepth:0] write_pointer_q_o,
  output logic [AddrDepth:0] status_cnt_n_o,
  output logic [AddrDepth:0] read_pointer_n_o,
  output logic [AddrDepth:0] write_pointer_n_o,
  input  logic [1:0][AddrDepth:0] alt_read_pointer_n_sync_i,
  output logic      [AddrDepth:0] read_pointer_n_sync_o,
  input  logic [1:0][AddrDepth:0] alt_write_pointer_n_sync_i,
  output logic      [AddrDepth:0] write_pointer_n_sync_o,
  output logic [1:0] tmr_faults_o
);

  logic [AddrDepth:0] read_pointer_next, write_pointer_next;

  for (genvar i = 0; i < EccDataWidth; i++) begin : gen_read_write_next
    assign read_pointer_next_multi_o[i]  = read_pointer_next;
    assign use_fallthrough_o[i] = FallThrough &&
                                  (read_pointer_next == write_pointer_next) &&
                                  push_i;
  end

  if (StatusFF) begin : gen_status_ff
    $error("unimplemented");
    // logic [2:0][AddrDepth:0] status_cnt_d;

    // always_comb begin
    //   if ()
    // end

    // always_ff @(posedge clk_i or negedge rst_ni) begin : proc_status_cnt
    //   if(!rst_ni) begin
    //     status_cnt_q_o <= '0;
    //   end else begin
    //     status_cnt_q_o <= status_cnt_d;
    //   end
    // end
  end else begin : gen_status_calc
    assign status_cnt_q_o = write_pointer_q_o - read_pointer_q_o;
  end

  if (Depth == 0) begin : gen_pass_through
    assign empty_o = push_i;
    assign full_o = pop_i;
  end else begin : gen_fifo
    if (StatusFF) begin : gen_full_empty_from_status
      assign full_o  = (status_cnt_q_o == FifoDepth[AddrDepth:0]);
      assign empty_o = (status_cnt_q_o == 0) & ~(FallThrough & push_i);
    end else begin : gen_full_empty_calc
      assign full_o  = (write_pointer_q_o[AddrDepth-1:0] == read_pointer_q_o[AddrDepth-1:0] &
                          write_pointer_q_o[AddrDepth]     != read_pointer_q_o[AddrDepth]);
      assign empty_o = (write_pointer_q_o                == read_pointer_q_o) &
                          ~(FallThrough & push_i);
    end
  end

  // read and write queue logic
  always_comb begin : read_write_comb
    // default assignment
    read_pointer_n_o  = read_pointer_q_o;
    write_pointer_n_o = write_pointer_q_o;
    status_cnt_n_o    = status_cnt_q_o;
    gate_clock_o      = {FifoDepth{{EccDataWidth{1'b1}}}};

    // push a new element to the queue
    if (push_i && ~full_o) begin
      // un-gate the clock, we want to write something
      gate_clock_o[write_pointer_q_o[AddrDepth-1:0]] = {EccDataWidth{1'b0}};
      // increment the write counter
      // this is dead code when DEPTH is a power of two
      if (write_pointer_q_o[AddrDepth-1:0] == FifoDepth[AddrDepth-1:0] - 1) begin
          write_pointer_n_o[AddrDepth-1:0] = '0;
          write_pointer_n_o[AddrDepth] = ~write_pointer_q_o[AddrDepth];
      end else begin
          write_pointer_n_o = write_pointer_q_o + 1;
      end
      if (StatusFF) begin
        // increment the overall counter
        status_cnt_n_o    = status_cnt_q_o + 1;
      end
    end

    // pop an element from the queue
    if (pop_i && ~empty_o) begin
      // read from the queue is a default assignment
      // but increment the read pointer...
      // this is dead code when DEPTH is a power of two
      if (read_pointer_q_o[AddrDepth-1:0] == FifoDepth[AddrDepth-1:0] - 1) begin
          read_pointer_n_o[AddrDepth-1:0] = '0;
          read_pointer_n_o[AddrDepth] = ~read_pointer_q_o[AddrDepth];
      end else begin
          read_pointer_n_o = read_pointer_q_o + 1;
      end
      // ... and decrement the overall count
      if (StatusFF) begin
        status_cnt_n_o   = status_cnt_q_o - 1;
      end
    end

    // keep the count pointer stable if we push and pop at the same time
    if (StatusFF) begin
      if (push_i && pop_i &&  ~full_o && ~empty_o)
        status_cnt_n_o   = status_cnt_q_o;
    end

    // FIFO is in pass through mode -> do not change the pointers
    if (FallThrough && (write_pointer_next == read_pointer_next) && push_i) begin
      if (pop_i) begin
        status_cnt_n_o = status_cnt_q_o;
        read_pointer_n_o = read_pointer_q_o;
        write_pointer_n_o = write_pointer_q_o;
      end
    end
  end

    assign read_pointer_n_sync_o  = read_pointer_next;
    assign write_pointer_n_sync_o = write_pointer_next;
    bitwise_TMR_voter_fail #(
      .DataWidth(AddrDepth+1)
    ) i_read_pointer_vote (
      .a_i(read_pointer_next),
      .b_i(alt_read_pointer_n_sync_i[0]),
      .c_i(alt_read_pointer_n_sync_i[1]),
      .majority_o(read_pointer_q_o),
      .fault_detected_o(tmr_faults_o[0])
    );
    bitwise_TMR_voter_fail #(
      .DataWidth(AddrDepth+1)
    ) i_write_pointer_vote (
      .a_i(write_pointer_next),
      .b_i(alt_write_pointer_n_sync_i[0]),
      .c_i(alt_write_pointer_n_sync_i[1]),
      .majority_o(write_pointer_q_o),
      .fault_detected_o(tmr_faults_o[1])
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if(!rst_ni) begin
        read_pointer_next  <= '0;
        write_pointer_next <= '0;
      end else begin
        if (flush_i) begin
          read_pointer_next  <= '0;
          write_pointer_next <= '0;
        end else begin
          read_pointer_next  <= read_pointer_n_o;
          write_pointer_next <= write_pointer_n_o;
        end
      end
    end
endmodule
