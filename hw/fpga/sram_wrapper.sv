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


  if (NumWords == 32'd8192) begin
    xilinx_mem_gen_8192 tc_ram_i (
        .clka (clk_i),
        .ena  (req_i),
        .wea  ({4{req_i & we_i}} & be_i),
        .addra(addr_i),
        .dina (wdata_i),
        // output ports
        .douta(rdata_o)
    );
  end else begin
    $error("Bank size not generated.");
  end
endmodule
