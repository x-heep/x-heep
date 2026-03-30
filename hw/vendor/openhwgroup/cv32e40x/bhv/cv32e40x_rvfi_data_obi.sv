// Copyright (c) 2022 OpenHW Group
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0

// CV32E40X RVFI data OBI interface (aligns data OBI signals to WB timing)
// Note that due to complications added by the write buffer (specifically the fact that
// instructions can retire before a transaction leaves the write buffer), this module
// monitors transactions going in to the write buffer.
// Future improvements of this module may include monitoring the OBI signals directly,
// and have special handling of buffered writes.
//
// Contributors: Arjan Bink <arjan.bink@silabs.com>

module cv32e40x_rvfi_data_obi import cv32e40x_pkg::*; import cv32e40x_rvfi_pkg::*;
(
  input logic           clk,
  input logic           rst_n,
  input obi_data_req_t  buffer_trans_i,
  input logic           buffer_trans_valid_i,
  output obi_data_req_t lsu_data_trans_o,
  output logic          lsu_data_trans_valid_o
);

  // Intermediate rotate signal, as direct part-select not supported in all tools
  logic [63:0] buffer_trans_wdata_ror;

  // Rotate right
  assign buffer_trans_wdata_ror = {buffer_trans_i.wdata, buffer_trans_i.wdata} >> (8*buffer_trans_i.addr[1:0]);

  // Feed valid through
  assign lsu_data_trans_valid_o = buffer_trans_valid_i;

  always_comb begin
    lsu_data_trans_o = buffer_trans_i;

    // Align Memory write data
    lsu_data_trans_o.wdata = buffer_trans_wdata_ror;
  end

endmodule
