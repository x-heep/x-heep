// Copyright (c) 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module sram_wrapper #(
    parameter int unsigned NumWords = 32'd1024,  // Number of Words in data array
    parameter int unsigned DataWidth = 32'd32,  // Data signal width
    // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
    parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1
) (
    input logic clk_i,
    input logic rst_ni,
    // input ports
    input logic req_i,
    input logic we_i,
    input logic [AddrWidth-1:0] addr_i,
    input logic [31:0] wdata_i,
    input logic [3:0] be_i,
    // power manager signals that goes to the ASIC macros
    input logic pwrgate_ni,
    output logic pwrgate_ack_no,
    input logic set_retentive_ni,
    // output ports
    output logic [31:0] rdata_o
);

assign pwrgate_ack_no = pwrgate_ni;

  // Force block RAM inference on Xilinx (Virtex-7)
  (* ram_style = "block" *)
  logic [DataWidth-1:0] mem[0:NumWords-1];

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      rdata_o <= '0;
    end else begin
      // Write with byte enables
      if (req_i && we_i) begin
        for (int b = 0; b < 4; b++) begin
          if (be_i[b]) begin
            mem[addr_i][8*b+:8] <= wdata_i[8*b+:8];
          end
        end
      end

      // 1-cycle synchronous read (matches X-HEEP expectation)
      if (req_i && !we_i) begin
        rdata_o <= mem[addr_i];
      end
    end
  end

endmodule
