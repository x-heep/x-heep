// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module spi_slave_dc_fifo #(
    parameter DATA_WIDTH   = 32
) (
    input logic clk_a,
    input logic rstn_a,
    input logic [DATA_WIDTH-1:0] data_a,
    input logic valid_a,
    output logic ready_a,
    input logic clk_b,
    input logic rstn_b,
    output logic [DATA_WIDTH-1:0] data_b,
    output logic valid_b,
    input logic ready_b
);

  typedef logic [DATA_WIDTH-1:0] data_t;

  cdc_fifo_gray #(
      .WIDTH(32),
      .T(data_t),
      .LOG_DEPTH(4),
      .SYNC_STAGES(2)
  ) i_cdc_fifo_gray (

      .src_rst_ni (rstn_a),
      .src_clk_i  (clk_a),
      .src_data_i (data_a),
      .src_valid_i(valid_a),
      .src_ready_o(ready_a),

      .dst_rst_ni (rstn_b),
      .dst_clk_i  (clk_b),
      .dst_data_o (data_b),
      .dst_valid_o(valid_b),
      .dst_ready_i(ready_b)

  );

endmodule
