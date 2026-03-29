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

// CV32E40X RVFI instruction OBI interface (aligns instruction OBI signals to IF timing)
// In order to take MPU faults into account, the control signals are sampled on the core side
// of the MPU, while the transaction payloads (obi_instr.req_payload, obi_instr.resp_payload)
// are taken directly from the instruction OBI bus.
// In case of an MPU fault, the transaction payloads are undefined,
// with the exception of resp_payload.mpu_status.
//
// Contributors: Arjan Bink <arjan.bink@silabs.com>

module cv32e40x_rvfi_instr_obi import cv32e40x_pkg::*; import cv32e40x_rvfi_pkg::*;
(
  input  logic                          clk,
  input  logic                          rst_n,

  input  logic                          prefetch_valid_i,
  input  logic                          prefetch_ready_i,
  input  logic [31:0]                   prefetch_addr_i,
  input  logic                          prefetch_compressed_i,
  input  logic                          kill_if_i,
  input  mpu_status_e                   mpu_status_i,
  input logic                           prefetch_trans_valid_i,
  input logic                           prefetch_trans_ready_i,
  input logic                           prefetch_resp_valid_i,

  if_c_obi.monitor                      m_c_obi_instr_if,

  output rvfi_obi_instr_t               obi_instr                               // OBI address and response phase packet aligned to IF timing
);

  // DEPTH of the instruction buffer (at least depth of alignment buffer)
  localparam DEPTH = 4;                                                         // Needs to be power of 2 (due to used pointer arithmetic)
  localparam int unsigned PTR_WIDTH = $clog2(DEPTH);

  // FIFO
  rvfi_obi_instr_t [0:DEPTH-1]  fifo_q;                                         // FIFO with OBI address phase and response phase signals
  rvfi_obi_instr_t              fifo_req_n, fifo_resp_n;                        // FIFO with OBI address phase and response phase signals

  // Read/write pointers
  logic [PTR_WIDTH-1:0]         rptr_q, rptr_n;                                 // Pointer to FIFO entry to be read
  logic [PTR_WIDTH-1:0]         rptr_q_inc;                                     // Next read pointer (needed if instruction word is split over two entries) 
  logic [PTR_WIDTH-1:0]         wptr_req_q, wptr_req_n;                         // Pointer to FIFO (address phase) entry to be written
  logic [PTR_WIDTH-1:0]         wptr_resp_q, wptr_resp_n;                       // Pointer to FIFO (response phase) entry to be written
  logic [PTR_WIDTH:0]           cnt_q, cnt_n;                                   // Number of FIFO entries including incoming entries

  logic                         fifo_req_push;                                  // Push FIFO when transaction is accepted
  logic                         fifo_resp_push;                                 // Push FIFO when response is valid
  logic                         fifo_pop;                                       // Pop FIFO when entry has been fully used

  // Outstanding transactions
  logic [PTR_WIDTH-1:0]         outstanding_cnt_n, outstanding_cnt_q;
  logic                         outstanding_count_up;
  logic                         outstanding_count_down;

  logic                         response_valid;
  logic                         trans_accepted;

  // Use control signals from the core side of the MPU in order to take MPU faults into account
  assign response_valid = prefetch_resp_valid_i;
  assign trans_accepted = prefetch_trans_valid_i && prefetch_trans_ready_i;

  //////////////////////////////////////////////////////////////////////////////
  // Count number of outstanding transactions
  //////////////////////////////////////////////////////////////////////////////

  assign outstanding_count_up   = trans_accepted;
  assign outstanding_count_down = response_valid;

  always_comb begin
    outstanding_cnt_n = outstanding_cnt_q;

    case ({outstanding_count_up, outstanding_count_down})
      2'b00 : begin
        outstanding_cnt_n = outstanding_cnt_q;
      end
      2'b01 : begin
        outstanding_cnt_n = outstanding_cnt_q - 1'b1;
      end
      2'b10 : begin
        outstanding_cnt_n = outstanding_cnt_q + 1'b1;
      end
      2'b11 : begin
        outstanding_cnt_n = outstanding_cnt_q;
      end
    endcase
  end

  // The RVFI instruction OBI FIFO tracks reads, writes and flushes of the alignment
  // buffer. As its size is at least the size of the alignment buffer, this FIFO
  // should never overflow. As the OBI response phase is at least a cycle after
  // the address phase acceptance, the address phase FIFO push will always be
  // to a different FIFO entry than the response phase FIFO push.

  // Push OBI address phase signals into FIFO when transaction in accepted.
  // trans_accepted is based on the core side control signals from the MPU.
  // When there is no MPU fault, trans_accepted will have the same timing as
  // m_c_obi_instr_if.s_req.req, since the control signals are passed directly through the MPU,
  // and cv32e40x_instr_obi_interface will be in TRANSPARENT mode (trans_ready_o == 1'b1).
  // Upon MPU fault, req_payload will be undefined.
  assign fifo_req_push = trans_accepted;

  // Push OBI response phase signals into FIFO when response is valid.
  // response_valid is based on the core side control signal from the MPU.
  // When there is no MPU fault, response_valid will have the same timing as
  // m_c_obi_instr_if.s_rvalid.rvalid, since this signal is passed directly through cv32e40x_instr_obi_interface and the MPU.
  // Upon MPU fault, resp_payload will be undefined, with the exception of resp_payload.mpu_status
  assign fifo_resp_push = response_valid;

  // Pop FIFO when reading word or when reading upper halfword
  always_comb
  begin
    if (prefetch_compressed_i) begin
      // Only pop FIFO when using upper halfword
      fifo_pop = prefetch_valid_i && prefetch_ready_i && (prefetch_addr_i[1:0] == 2'b10);
    end else begin
      fifo_pop = prefetch_valid_i && prefetch_ready_i;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // FIFO reads/writes
  //////////////////////////////////////////////////////////////////////////////

  assign rptr_n = rptr_q + 1'b1;

  // Next address phase signals to FIFO
  always_comb
  begin
    fifo_req_n = fifo_q[wptr_req_q];
    fifo_req_n.req_payload = m_c_obi_instr_if.req_payload;
    wptr_req_n = wptr_req_q + 1'b1; 
  end

  // Next response phase signals to FIFO
  always_comb
  begin
    fifo_resp_n = fifo_q[wptr_resp_q];
    fifo_resp_n.resp_payload.bus_resp   = m_c_obi_instr_if.resp_payload;
    fifo_resp_n.resp_payload.mpu_status = mpu_status_i;
    wptr_resp_n = wptr_resp_q + 1'b1;
  end

  //////////////////////////////////////////////////////////////////////////////
  // Registers
  //////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n)
  begin
    if (rst_n == 1'b0) begin
      cnt_q                   <= 'b0;
      rptr_q                  <= 'b0;
      wptr_req_q              <= 'b0;
      wptr_resp_q             <= 'b0;
      fifo_q                  <= 'b0;
      outstanding_cnt_q       <= 'b0;
    end else begin
      // FIFO reads
      if (kill_if_i) begin
        cnt_q                 <= '0;                                    // No more entries in FIFO
        rptr_q                <= PTR_WIDTH'(wptr_resp_q + outstanding_cnt_q);   // Flush/skip existing + incoming entries (assumes rptr_q is power of 2)
      end else begin
        if (fifo_pop) begin
          rptr_q              <= rptr_n;
        end
      end

      // FIFO writes
      if (fifo_req_push) begin                                          // Will not push to same FIFO entry as response phase signals
        fifo_q[wptr_req_q]  <= fifo_req_n;
        wptr_req_q          <= wptr_req_n;
      end
      if (fifo_resp_push) begin                                         // Will not push to same FIFO entry as address phase signals
        fifo_q[wptr_resp_q] <= fifo_resp_n;
        wptr_resp_q         <= wptr_resp_n;
      end

      // Outstanding transactions
      outstanding_cnt_q     <= outstanding_cnt_n;

    end
  end

  assign rptr_q_inc = rptr_q + 1'b1;                                    // Next read pointer

  //////////////////////////////////////////////////////////////////////////////
  // Transform FIFO content into compressed / uncompressed instructions plus meta data
  //////////////////////////////////////////////////////////////////////////////

  // The FIFO can have at most 3 entries full (because the alignment buffer has that depth); so,
  // if rptr_q == wptr_resp_q, then the FIFO is empty and OBI response phase payload gets passed
  // on directly from OBI. OBI address phase payload is available earlier and will therefore always
  // be present in the FIFO.

  always_comb
  begin
    if (prefetch_compressed_i) begin
      if (prefetch_addr_i[1:0] == 2'b00) begin
        // Compressed instruction in LSBs of 1 rdata item
        obi_instr.req_payload               =  fifo_q[rptr_q].req_payload;
        obi_instr.resp_payload.bus_resp.rdata[31:16] =  16'h0;
        obi_instr.resp_payload.bus_resp.rdata[15:0]  =  (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.rdata[15:0]  : fifo_q[rptr_q].resp_payload.bus_resp.rdata[15:0];
        obi_instr.resp_payload.bus_resp.err          =  (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.err          : fifo_q[rptr_q].resp_payload.bus_resp.err;
        obi_instr.resp_payload.mpu_status            =  (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.mpu_status            : fifo_q[rptr_q].resp_payload.mpu_status;
      end else begin
        // Compressed instruction in MSBs of 1 rdata item
        obi_instr.req_payload                        = fifo_q[rptr_q].req_payload;
        obi_instr.resp_payload.bus_resp.rdata[31:16] = 16'h0;
        obi_instr.resp_payload.bus_resp.rdata[15:0]  = (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.rdata[31:16] : fifo_q[rptr_q].resp_payload.bus_resp.rdata[31:16];
        obi_instr.resp_payload.bus_resp.err          = (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.err          : fifo_q[rptr_q].resp_payload.bus_resp.err;
        obi_instr.resp_payload.mpu_status            = (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.mpu_status            : fifo_q[rptr_q].resp_payload.mpu_status;
      end
    end else begin
      if (prefetch_addr_i[1:0] == 2'b00) begin
        // Uncompressed instruction (or pointer) in 1 rdata item
        obi_instr.req_payload                        = fifo_q[rptr_q].req_payload;
        obi_instr.resp_payload.bus_resp.rdata[31:16] = (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.rdata[31:16] : fifo_q[rptr_q].resp_payload.bus_resp.rdata[31:16];
        obi_instr.resp_payload.bus_resp.rdata[15:0]  = (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.rdata[15:0]  : fifo_q[rptr_q].resp_payload.bus_resp.rdata[15:0];
        obi_instr.resp_payload.bus_resp.err          = (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.err          : fifo_q[rptr_q].resp_payload.bus_resp.err;
        obi_instr.resp_payload.mpu_status            = (rptr_q     == wptr_resp_q) ? fifo_resp_n.resp_payload.mpu_status            : fifo_q[rptr_q].resp_payload.mpu_status;
      end else begin
        // Uncompressed instruction (or pointer) in 2 rdata items
        obi_instr.req_payload                        = fifo_q[rptr_q].req_payload;
        obi_instr.resp_payload.bus_resp.rdata[31:16] = (rptr_q_inc == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.rdata[15:0]  : fifo_q[rptr_q_inc].resp_payload.bus_resp.rdata[15:0];
        obi_instr.resp_payload.bus_resp.rdata[15:0]  = fifo_q[rptr_q].resp_payload.bus_resp.rdata[31:16];
        obi_instr.resp_payload.bus_resp.err          = ((rptr_q_inc == wptr_resp_q) ? fifo_resp_n.resp_payload.bus_resp.err         : fifo_q[rptr_q_inc].resp_payload.bus_resp.err) ||
                                                       fifo_q[rptr_q].resp_payload.bus_resp.err;
        obi_instr.resp_payload.mpu_status            = (((rptr_q_inc == wptr_resp_q) ? fifo_resp_n.resp_payload.mpu_status : fifo_q[rptr_q_inc].resp_payload.mpu_status) != MPU_OK) ? MPU_RE_FAULT :
                                                       fifo_q[rptr_q].resp_payload.mpu_status;
      end
    end
  end

endmodule
