// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
//        Davide Schiavone <davide.schiavone@epfl.ch>, EPFL Lausanne
// Date: 06.03.2019
// Description: address decoder and response mux for full crossbar.

module addr_dec_resp_mux_varlat #(
    parameter int unsigned AggregateGnt  = 1,
    parameter int unsigned NumOut        = 32,
    parameter int unsigned ReqDataWidth  = 32,
    parameter int unsigned RespDataWidth = 32,
    parameter int unsigned LogNumOut    = NumOut > 1 ? $clog2(NumOut) : 1
) (
  input  logic                                  clk_i,
  input  logic                                  rst_ni,
  // master side
  input  logic                                  req_i,    // request from this master
  input  logic [LogNumOut-1:0]                  add_i,    // bank selection index to be decoded
  input  logic [ReqDataWidth-1:0]               data_i,   // data to be transported to slaves
  output logic                                  gnt_o,    // grant to master
  output logic                                  vld_o,    // read/write response
  output logic [RespDataWidth-1:0]              rdata_o,  // read response
  // slave side
  /* verilator lint_off UNOPTFLAT */
  output logic [NumOut-1:0]                     req_o,    // request signals after decoding
  /* verilator lint_on UNOPTFLAT */
  input  logic [NumOut-1:0]                     gnt_i,    // grants from slaves
  input  logic [NumOut-1:0]                     vld_i,    // valid response from slaves
  output logic [NumOut-1:0][ReqDataWidth-1:0]   data_o,   // data to be transported to slaves
  input  logic [NumOut-1:0][RespDataWidth-1:0]  rdata_i   // read responses from slaves
);

logic valid_inflight_d, valid_inflight_q;

////////////////////////////////////////////////////////////////////////
// degenerate case
////////////////////////////////////////////////////////////////////////
if (NumOut == unsigned'(1)) begin : gen_one_output

  assign data_o[0] = data_i;
  assign gnt_o     = gnt_i[0];
  assign rdata_o   = rdata_i[0];
  assign vld_o     = vld_i[0] & valid_inflight_q;

  // address decoder
  always_comb begin : p_addr_dec
    valid_inflight_d = valid_inflight_q;
    req_o[0] = '0;
    if (~valid_inflight_q) begin
      req_o[0] = req_i;
      valid_inflight_d = req_i & gnt_o;
    end else begin
      //we gate req_i in case there are inflights operation
      req_o[0] = '0;
      if(vld_o) begin
        valid_inflight_d = 1'b0;
        if(req_i) begin
          req_o[0] = req_i;
          valid_inflight_d = req_i & gnt_o;
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_valid_inflight
    if (!rst_ni) begin
      valid_inflight_q <= '0;
    end else begin
      valid_inflight_q <= valid_inflight_d;
    end
  end

////////////////////////////////////////////////////////////////////////
// normal case
////////////////////////////////////////////////////////////////////////
end else begin : gen_several_outputs

  // address decoder
  always_comb begin : p_addr_dec
    req_o = '0;
    valid_inflight_d = valid_inflight_q;
    gnt_o = AggregateGnt == 1 ? |gnt_i : gnt_i[add_i];
    if (~valid_inflight_q) begin
      req_o[add_i]     = req_i;
      valid_inflight_d = req_i & gnt_o;
    end else begin
      //we gate req_i in case there are inflights operation
      //however, as the gnt_o could be one, the master could change the address
      //thus if gnt_o is 1, we need to store the address, be, we, etc from the obi master
      //and propose it to the slave as soon as we get back the valid back.
      //As this bus does not support neither Outstanding or Out of order transactions
      //we need to gate the request to the slave and grant to the master until we get the valid back.
      req_o = '0;
      gnt_o = '0;
      if(vld_o) begin
        valid_inflight_d = 1'b0;
        gnt_o = AggregateGnt == 1 ? |gnt_i : gnt_i[add_i];
        if(req_i) begin
          req_o[add_i] = req_i;
          valid_inflight_d = req_i & gnt_o;
        end
      end
    end
  end

  // connect data outputs
  assign data_o = {NumOut{data_i}};

  logic [$clog2(NumOut)-1:0] bank_sel_d, bank_sel_q;

  assign rdata_o = rdata_i[bank_sel_q];
  assign vld_o = vld_i[bank_sel_q] & valid_inflight_q;
  assign bank_sel_d = add_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_valid_inflight
    if (!rst_ni) begin
      valid_inflight_q <= '0;
      bank_sel_q <= '0;
    end else begin
      valid_inflight_q <= valid_inflight_d;
      if(req_i & gnt_o)
        bank_sel_q <= bank_sel_d;
    end
  end

end


////////////////////////////////////////////////////////////////////////
// assertions
////////////////////////////////////////////////////////////////////////

`ifndef SYNTHESIS
// pragma translate_off
initial begin
  assert (NumOut > 0) else
    $fatal(1,"NumOut must be greater than 0");
end
// pragma translate_on
`endif

endmodule // addr_dec_resp_mux_varlat
