// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`define write_mem 8'h2
`define read_mem 8'hB
`define read_reg0 8'h7
`define write_reg0 8'h11
`define write_reg1 8'h20
`define read_reg1 8'h21
`define write_reg2 8'h30
`define read_reg2 8'h31



module spi_slave_cmd_parser (
    input  logic [7:0] cmd,
    output logic       get_addr,
    output logic       get_data,
    output logic       send_data,
    output logic       enable_cont,
    output logic       enable_regs,
    output logic       wait_dummy,
    output logic [1:0] reg_sel
);


  always_comb begin
    get_addr    = 0;
    get_data    = 0;
    send_data   = 0;
    enable_cont = 0;
    enable_regs = 1'b0;
    wait_dummy  = 0;
    reg_sel     = 2'b00;
    case (cmd)
      `write_mem: begin
        get_addr    = 1;
        get_data    = 1;
        send_data   = 0;
        enable_cont = 1'b1;
        enable_regs = 1'b0;
        wait_dummy  = 0;
        reg_sel     = 2'b00;
      end
      `read_reg0: begin
        get_addr    = 0;
        get_data    = 0;
        send_data   = 1;
        enable_cont = 0;
        enable_regs = 1'b1;
        wait_dummy  = 0;
        reg_sel     = 2'b00;
      end
      `read_mem: begin
        get_addr    = 1;
        get_data    = 0;
        send_data   = 1;
        enable_cont = 1'b1;
        enable_regs = 1'b0;
        wait_dummy  = 1;
        reg_sel     = 2'b00;
      end
      `write_reg0: begin
        get_addr    = 1'b0;
        get_data    = 1'b1;
        send_data   = 1'b0;
        enable_cont = 1'b0;
        enable_regs = 1'b1;
        wait_dummy  = 1'b0;
        reg_sel     = 2'b00;
      end
      `write_reg1: begin
        get_addr    = 1'b0;
        get_data    = 1'b1;
        send_data   = 1'b0;
        enable_cont = 1'b0;
        enable_regs = 1'b1;
        wait_dummy  = 1'b0;
        reg_sel     = 2'b01;
      end
      `read_reg1: begin
        get_addr    = 1'b0;
        get_data    = 1'b0;
        send_data   = 1'b1;
        enable_cont = 1'b0;
        enable_regs = 1'b1;
        wait_dummy  = 1'b0;
        reg_sel     = 2'b01;
      end
      `write_reg2: begin
        get_addr    = 1'b0;
        get_data    = 1'b1;
        send_data   = 1'b0;
        enable_cont = 1'b0;
        enable_regs = 1'b1;
        wait_dummy  = 1'b0;
        reg_sel     = 2'b10;
      end
      `read_reg2: begin
        get_addr    = 1'b0;
        get_data    = 1'b0;
        send_data   = 1'b1;
        enable_cont = 1'b0;
        enable_regs = 1'b1;
        wait_dummy  = 1'b0;
        reg_sel     = 2'b10;
      end
      default: begin
        get_addr    = 0;
        get_data    = 1'b0;
        send_data   = 0;
        enable_cont = 0;
        enable_regs = 1'b0;
        wait_dummy  = 0;
        reg_sel     = 2'b00;
      end
    endcase
  end

endmodule
