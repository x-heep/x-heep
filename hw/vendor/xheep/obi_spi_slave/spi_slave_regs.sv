// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module spi_slave_regs #(
    parameter REG_SIZE = 8,
    parameter DUMMY_CYCLES = 32
) (
    input  logic                sclk,
    input  logic                rstn,
    input  logic [REG_SIZE-1:0] wr_data,
    input  logic [         1:0] wr_addr,
    input  logic                wr_data_valid,
    output logic [REG_SIZE-1:0] rd_data,
    input  logic [         1:0] rd_addr,
    output logic [         7:0] dummy_cycles,
    output logic [        15:0] wrap_length
);

  logic [REG_SIZE-1:0] reg0;  // number of dummy cycles
  logic [REG_SIZE-1:0] reg1;  // wrap length, low
  logic [REG_SIZE-1:0] reg2;  // wrap length, high

  assign dummy_cycles = reg0;
  assign wrap_length  = {reg2, reg1};

  always_comb begin
    rd_data = reg0;
    case (rd_addr)
      2'b00: rd_data = reg0;
      2'b01: rd_data = reg1;
      2'b10: rd_data = reg2;
      default: begin
      end
    endcase
  end

  always @(posedge sclk or negedge rstn) begin
    if (rstn == 0) begin
      reg0 <= DUMMY_CYCLES;
      reg1 <= 'h0;
      reg2 <= 'h0;
    end else begin
      if (wr_data_valid) begin
        case (wr_addr)
          2'b00: reg0 <= wr_data;
          2'b01: reg1 <= wr_data;
          2'b10: reg2 <= wr_data;
          default: begin
          end
        endcase
      end
    end
  end
endmodule
