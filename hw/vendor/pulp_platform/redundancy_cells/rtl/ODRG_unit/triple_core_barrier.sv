// Copyright 2021 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Triple Core barrier module

module triple_core_barrier #(
  parameter int unsigned SynchronizeCycles = 1
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  logic [2:0] req_i,
  output logic [2:0] gnt_o,

  output logic       request_synchronized_o
);

  logic shifted_gnt;
  logic [2:0] req_q;

  assign request_synchronized_o = &req_i;

  shift_reg #(
    .dtype( logic ),
    .Depth( SynchronizeCycles )
  ) i_shift_reg (
    .clk_i,
    .rst_ni,
    .d_i   ( &req_i      ),
    .d_o   ( shifted_gnt )
  );

  for (genvar i = 0; i < 3; i++) begin : gen_gnt
    assign gnt_o[i] = req_q[i] && shifted_gnt;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_req_ff
    if(!rst_ni) begin
      req_q <= 0;
    end else begin
      req_q <= req_i;
    end
  end

endmodule
