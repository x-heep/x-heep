/*
*  Copyright 2022 EPFL Christoph Müller <christoph.mueller@epfl.ch>
*  Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
*  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
*/

module obi_to_picorv32 #(
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input  obi_req_t obi_req_i,
    output obi_rsp_t obi_resp_o,

    output picorv32_pkg::picorv32_req_t  picorv32_req_o,
    input  picorv32_pkg::picorv32_resp_t picorv32_resp_i

);
  // Package with type definitions
  import picorv32_pkg::*;

  typedef enum logic [3:0] {
    READ_MEM = 4'b0000,
    WRITE_WORD = 4'b1111,
    WRITE_HALFWORD_1 = 4'b1100,
    WRITE_HALFWORD_0 = 4'b0011,
    WRITE_BYTE_3 = 4'b1000,
    WRITE_BYTE_2 = 4'b0100,
    WRITE_BYTE_1 = 4'b0010,
    WRITE_BYTE_0 = 4'b0001
  } picorv_request_e;

  enum logic [1:0] {
    IDLE,
    READ,
    WRITE,
    GIVE_VALID
  }
      state, state_next;


  logic [31:0] addr_buf, addr_buf_next, rdata_buf, rdata_buf_next;


  always_ff @(posedge clk_i or negedge rst_ni) begin : ram_valid_q
    if (!rst_ni) begin
      state <= IDLE;
      addr_buf <= '0;
      rdata_buf <= '0;
    end else begin
      state <= state_next;
      addr_buf <= addr_buf_next;
      rdata_buf <= rdata_buf_next;
    end
  end


  always_comb begin : fsm
    // default values
    addr_buf_next = addr_buf;
    state_next = state;
    picorv32_req_o.valid = 1'b0;
    picorv32_req_o.addr = '0;
    picorv32_req_o.wdata = '0;
    picorv32_req_o.wstrb = READ_MEM;
    obi_resp_o.gnt = 1'b0;
    obi_resp_o.rvalid = 1'b0;
    obi_resp_o.rdata = rdata_buf;
    rdata_buf_next = picorv32_resp_i.rdata;
    // fsm
    case (state)
      IDLE: begin
        if (obi_req_i.req) begin
          if (obi_req_i.we == 1'b1) begin
            state_next = WRITE;
            obi_resp_o.gnt = 1'b1;
          end else begin
            state_next = READ;
            addr_buf_next = obi_req_i.addr;
            obi_resp_o.gnt = 1'b1;
          end
        end
      end
      READ: begin
        picorv32_req_o.addr  = addr_buf;
        picorv32_req_o.valid = 1'b1;
        if (picorv32_resp_i.ready) begin
          state_next = GIVE_VALID;
        end
        // Todo: add contineous read w/o idle
      end
      WRITE: begin
        state_next = IDLE;
        obi_resp_o.rvalid = 1'b1;
        // Todo: add write.
      end
      GIVE_VALID: begin
        state_next = IDLE;
        obi_resp_o.rvalid = 1'b1;
      end

      default: begin
        state_next = IDLE;
      end

    endcase

  end

endmodule
