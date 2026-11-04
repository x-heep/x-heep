// Copyright (c) 2026 X-HEEP contributors
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
    input logic [DataWidth-1:0] wdata_i,
    input logic [DataWidth/8-1:0] be_i,
    // power manager signals that goes to the ASIC macros
    input logic pwrgate_ni,
    output logic pwrgate_ack_no,
    input logic set_retentive_ni,
    // output ports
    output logic [DataWidth-1:0] rdata_o
);

  assign pwrgate_ack_no = pwrgate_ni;


  if (NumWords == 32'd8192) begin
    logic [7:0] wea_membllk_0;
    logic [2*DataWidth-1:0] wdata_memblk_0;
    logic [2*DataWidth-1:0] rdata_memblk_0;
    logic addr_i0_reg_memblk_0;


    assign wea_membllk_0 = addr_i[0] ? {{{4{req_i & we_i}} & be_i}, 4'b0} : {4'b0, {{4{req_i & we_i}} & be_i}};
    assign wdata_memblk_0 = addr_i[0] ? {wdata_i, 32'b0} : {32'b0, wdata_i};

    always_ff @(posedge clk_i) begin
      if (req_i) addr_i0_reg_memblk_0 <= addr_i[0];
    end

    xilinx_mem_gen_8192 tc_ram_i (
        .clka (clk_i),
        .ena  (req_i),
        .wea  (wea_membllk_0),
        .addra(addr_i[AddrWidth-1:1]),
        .dina (wdata_memblk_0),
        // output ports
        .douta(rdata_memblk_0)
    );

    assign rdata_o = addr_i0_reg_memblk_0 ? rdata_memblk_0[2*DataWidth-1 : DataWidth] : rdata_memblk_0[DataWidth-1:0];
  end else if (NumWords == 32'd4096) begin  // for w25q128jw cache
    xilinx_mem_gen_llc_cache tc_ram_i (
        .clka (clk_i),
        .ena  (req_i),
        .wea  ({4{req_i & we_i}} & be_i),
        .addra(addr_i),
        .dina (wdata_i),
        // output ports
        .douta(rdata_o)
    );
  end else begin : gen_inferred_ram
    // Accelerator memories can have sizes without a generated Xilinx IP.
    $warning(
        "sram_wrapper: no Xilinx memory IP for NumWords = %0d: falling back to an inferred block RAM",
        NumWords
    );

    logic [DataWidth-1:0] mem_q[NumWords];

    always_ff @(posedge clk_i) begin
      if (req_i) begin
        if (we_i) begin
          for (int unsigned i = 0; i < DataWidth / 8; i++) begin
            if (be_i[i]) mem_q[addr_i][i*8+:8] <= wdata_i[i*8+:8];
          end
        end else begin
          rdata_o <= mem_q[addr_i];
        end
      end
    end
  end
endmodule
