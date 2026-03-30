// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

// Implements the Network layer of the Serial Link
// Translates from the AXI to the AXIStream interface and vice-versa
module serial_link_network #(
    parameter type axi_req_t  = logic,
    parameter type axi_rsp_t  = logic,
    parameter type axis_req_t = logic,
    parameter type axis_rsp_t = logic,
    parameter type aw_chan_t  = logic,
    parameter type w_chan_t   = logic,
    parameter type b_chan_t   = logic,
    parameter type ar_chan_t  = logic,
    parameter type r_chan_t   = logic,
    parameter type payload_t  = logic,
    // For credit-based control flow
    parameter int NumCredits  = -1,
    // Force send out credits belonging to the other side
    // after ForceSendThresh is reached
    localparam int ForceSendThresh  = NumCredits - 4
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  input  axi_req_t  axi_in_req_i,
  output axi_rsp_t  axi_in_rsp_o,
  output axi_req_t  axi_out_req_o,
  input  axi_rsp_t  axi_out_rsp_i,
  output axis_req_t axis_out_req_o,
  input  axis_rsp_t axis_out_rsp_i,
  input  axis_req_t axis_in_req_i,
  output axis_rsp_t axis_in_rsp_o
);

  import serial_link_pkg::*;

  typedef enum logic [1:0] {
    Idle = 'b00,
    ArPend = 'b01,
    AwPend = 'b10,
    ArAwPend = 'b11
  } commiter_state_e;

  logic entropy_q, entropy_d;
  commiter_state_e commiter_state_q, commiter_state_d;

  payload_t payload_out, payload_in;

  credit_t credits_out_q, credits_out_d;
  credit_t credits_to_send_q, credits_to_send_d;
  logic credit_to_send_force;

  logic aw_gnt, w_gnt, b_gnt, ar_gnt, r_gnt;

  logic axis_reg_valid_out, axis_reg_ready_out;
  logic axis_reg_valid_in, axis_reg_ready_in;
  payload_t axis_reg_data_in, axis_reg_data_out;

  always_comb begin : commiter
    aw_gnt  = 1'b0;
    w_gnt   = 1'b0;
    b_gnt   = 1'b0;
    ar_gnt  = 1'b0;
    r_gnt   = 1'b0;
    commiter_state_d = commiter_state_q;

    // Priorities:
    // 1) B responses are always granted as they can be sent along other req/rsp
    // 2) AR/AW beats have priority unless there is already a same request in flight
    // 3) R/W beats have lowest priority unless there already is an AR/AW beat in flight.
    //    Additionally, W are not granted before the coresponding AW
    unique case(commiter_state_q)
      Idle: begin
        if (axi_in_req_i.aw_valid) begin
          aw_gnt = (axi_in_req_i.ar_valid)? entropy_q : 1'b1;
        end
        if (axi_in_req_i.ar_valid) begin
          ar_gnt = (axi_in_req_i.aw_valid)? ~entropy_q : 1'b1;
        end

        // Only r responses can be served in this state
        if (!ar_gnt & !aw_gnt) begin
          r_gnt = axi_out_rsp_i.r_valid;
        end

        if (aw_gnt & axi_in_rsp_o.aw_ready) commiter_state_d = AwPend;
        if (ar_gnt & axi_in_rsp_o.ar_ready) commiter_state_d = ArPend;
      end

      AwPend: begin
        if (axi_in_req_i.ar_valid) begin
          // We can no longer grant AW request but we can still grant AR requests
          ar_gnt = 1'b1;
        end else begin
          // Otherwise we grant R/W beats
          // Deciding between R/W requests with entropy prevents starvation
          if (axi_out_rsp_i.r_valid) begin
            r_gnt = (axi_in_req_i.w_valid)? entropy_q : 1'b1;
          end
          if (axi_in_req_i.w_valid) begin
            w_gnt = (axi_out_rsp_i.r_valid)? ~entropy_q : 1'b1;
          end
        end

        // Once last W is granted we can terminate AW burst and/or accepted a AR beat
        if (axi_in_req_i.w_valid & axi_in_rsp_o.w_ready & axi_in_req_i.w.last) begin
          commiter_state_d = (ar_gnt & axi_in_rsp_o.ar_ready)? ArPend : Idle;
        end else begin
          commiter_state_d = (ar_gnt & axi_in_rsp_o.ar_ready)? ArAwPend : AwPend;
        end
      end

      ArPend: begin
        if (axi_in_req_i.aw_valid) begin
          // We can no longer grant AR request but we can still grant AW requests
          aw_gnt = 1'b1;
        end else begin
          // Otherwise we grant R/W beats
          // Deciding between R/W requests with entropy prevents starvation
          if (axi_out_rsp_i.r_valid) begin
            r_gnt = (axi_in_req_i.w_valid)? entropy_q : 1'b1;
          end
          if (axi_in_req_i.w_valid) begin
            w_gnt = (axi_out_rsp_i.r_valid)? ~entropy_q : 1'b1;
          end
        end

        // Once last R response is out we can terminate AR burst and/or accepted a AW beat
        if (axi_in_rsp_o.r_valid & axi_in_req_i.r_ready & axi_in_rsp_o.r.last) begin
          commiter_state_d = (aw_gnt & axi_in_rsp_o.aw_ready)? AwPend : Idle;
        end else begin
          commiter_state_d = (aw_gnt & axi_in_rsp_o.aw_ready)? ArAwPend : ArPend;
        end
      end

      ArAwPend: begin
        // Only R/W are accepted
        if (axi_out_rsp_i.r_valid) begin
          r_gnt = (axi_in_req_i.w_valid)? entropy_q : 1'b1;
        end
        if (axi_in_req_i.w_valid) begin
          w_gnt = (axi_out_rsp_i.r_valid)? ~entropy_q : 1'b1;
        end

        // Check for last R/W packet
        if (axi_in_rsp_o.r_valid & axi_in_req_i.r_ready & axi_in_rsp_o.r.last) begin
          commiter_state_d[0] = 1'b0; // AwPend or Idle
        end
        if (axi_in_req_i.w_valid & axi_in_rsp_o.w_ready & axi_in_req_i.w.last) begin
          commiter_state_d[1] = 1'b0; // ArPend or Idle
        end
      end

      default:;
    endcase


    // Always serve B responses
    b_gnt = axi_out_rsp_i.b_valid;
  end

  `FF(commiter_state_q, commiter_state_d, Idle)

  always_comb begin : sender
    payload_out = '0;
    payload_out.credit = credits_to_send_q;

    if (aw_gnt) begin
      payload_out.axi_ch = axi_in_req_i.aw;
      payload_out.hdr = TagAW;
    end else if (w_gnt) begin
      payload_out.axi_ch = axi_in_req_i.w;
      payload_out.hdr = TagW;
    end else if (ar_gnt) begin
      payload_out.axi_ch = axi_in_req_i.ar;
      payload_out.hdr = TagAR;
    end else if (r_gnt) begin
      payload_out.axi_ch = axi_out_rsp_i.r;
      payload_out.hdr = TagR;
    end

    if (b_gnt) begin
      payload_out.b_valid = 1'b1;
      payload_out.b = axi_out_rsp_i.b;
    end

    // There are three reasons to send out a packet:
    // 1) Send out an AXI beat (!TagIdle)
    // 2) Return a B response (b_valid)
    // 3) Send an empty packet with credits (credits_to_send_force)
    axis_reg_valid_in = (payload_out.hdr != TagIdle) | payload_out.b_valid | credit_to_send_force;

    // There is a potential deadlock situation, when the last credit on the local side
    // is consumed and all the credits from the other side are currently in-flight.
    // To prevent this situation, the last credit is only consumed if credit is also sent back
    if (credits_out_q == 0) begin
      axis_reg_valid_in = 1'b0;
    end else if (credits_out_q == 1 && credits_to_send_q == 0) begin
      axis_reg_valid_in = 1'b0;
    end

    // Send responses if request was sent
    axi_in_rsp_o.aw_ready = aw_gnt & axis_reg_ready_in & axis_reg_valid_in;
    axi_in_rsp_o.w_ready  = w_gnt & axis_reg_ready_in & axis_reg_valid_in;
    axi_out_req_o.b_ready = b_gnt & axis_reg_ready_in & axis_reg_valid_in;
    axi_in_rsp_o.ar_ready = ar_gnt & axis_reg_ready_in & axis_reg_valid_in;
    axi_out_req_o.r_ready = r_gnt & axis_reg_ready_in & axis_reg_valid_in;
  end

  // assign axis_reg_valid_in = ((payload_out.hdr != TagIdle) | payload_out.b_valid |
                              // credit_to_send_force) & (credits_out_q != 0);
  assign axis_reg_data_in = payload_out;
  assign axis_out_req_o.tvalid = axis_reg_valid_out;
  assign axis_out_req_o.t.data = axis_reg_data_out;
  assign axis_reg_ready_out = axis_out_rsp_i.tready;

  stream_fifo #(
    .DEPTH  ( 2           ),
    .T      (  payload_t  )
  ) i_axis_out_reg (
    .clk_i      ( clk_i               ),
    .rst_ni     ( rst_ni              ),
    .flush_i    ( 1'b0                ),
    .testmode_i ( 1'b0                ),
    .usage_o    (                     ),
    .valid_i    ( axis_reg_valid_in   ),
    .ready_o    ( axis_reg_ready_in   ),
    .data_i     ( axis_reg_data_in    ),
    .valid_o    ( axis_reg_valid_out  ),
    .ready_i    ( axis_reg_ready_out  ),
    .data_o     ( axis_reg_data_out   )
  );

  logic axi_ch_sent_q, axi_ch_sent_d;
  logic b_sent_q, b_sent_d;
  logic ar_sent_q, ar_sent_d;
  logic aw_sent_q, aw_sent_d;
  logic w_sent_q, w_sent_d;
  logic r_sent_q, r_sent_d;
  logic two_ch_packet, credit_only_packet;

  typedef enum logic { Normal, Sync } unpack_state_e;

  unpack_state_e unpack_state_q, unpack_state_d;

  assign aw_sent_d  = axi_out_req_o.aw_valid & axi_out_rsp_i.aw_ready |
                      ((unpack_state_q == Sync) & aw_sent_q);
  assign w_sent_d   = axi_out_req_o.w_valid & axi_out_rsp_i.w_ready |
                      ((unpack_state_q == Sync) & w_sent_q);
  assign ar_sent_d  = axi_out_req_o.ar_valid & axi_out_rsp_i.ar_ready |
                      ((unpack_state_q == Sync) & ar_sent_q);
  assign r_sent_d   = axi_in_rsp_o.r_valid & axi_in_req_i.r_ready |
                      ((unpack_state_q == Sync) & r_sent_q);
  assign b_sent_d   = axi_in_rsp_o.b_valid & axi_in_req_i.b_ready |
                      ((unpack_state_q == Sync) & b_sent_q);
  assign axi_ch_sent_d = aw_sent_d | w_sent_d | ar_sent_d | r_sent_d;

  assign payload_in = payload_t'(axis_in_req_i.t.data);
  assign two_ch_packet = (payload_in.hdr != TagIdle) & payload_in.b_valid;
  assign credit_only_packet = (payload_in.hdr == TagIdle) & ~payload_in.b_valid;

  always_comb begin : unpacker
    axi_out_req_o.aw_valid = 1'b0;
    axi_out_req_o.w_valid = 1'b0;
    axi_out_req_o.ar_valid = 1'b0;
    axi_in_rsp_o.r_valid = 1'b0;
    axi_in_rsp_o.b_valid = 1'b0;

    axis_in_rsp_o = '0;

    axi_out_req_o.aw = aw_chan_t'(payload_in.axi_ch);
    axi_out_req_o.w = w_chan_t'(payload_in.axi_ch);
    axi_in_rsp_o.b = b_chan_t'(payload_in.b);
    axi_out_req_o.ar = ar_chan_t'(payload_in.axi_ch);
    axi_in_rsp_o.r = r_chan_t'(payload_in.axi_ch);

    unpack_state_d = unpack_state_q;

    // The incoming payload can pack a AW,W,AR,R + an additional B channel
    // Both channels have to be accepted, if only one of them is accepted
    // at a time we have to synch
    unique case (unpack_state_q)

      Normal: begin
        if (axis_in_req_i.tvalid) begin
          axi_out_req_o.aw_valid = (payload_in.hdr == TagAW);
          axi_out_req_o.w_valid = (payload_in.hdr == TagW);
          axi_out_req_o.ar_valid = (payload_in.hdr == TagAR);
          axi_in_rsp_o.r_valid = (payload_in.hdr == TagR);
          axi_in_rsp_o.b_valid = payload_in.b_valid;

          // If there is a AXI channel + B response,
          // check if only one of them was accepted
          if (two_ch_packet) begin
            // I only one was able to send -> need to synchronize
            if (axi_ch_sent_d ^ b_sent_d) begin
              unpack_state_d = Sync;
            // if both were able to send -> accept payload
            end else if (axi_ch_sent_d & b_sent_d) begin
              axis_in_rsp_o.tready = 1'b1;
            end
          end else if (credit_only_packet) begin
            axis_in_rsp_o.tready = 1'b1;
          end else begin
            // accept payload if either one of them was able to send
            if (axi_ch_sent_d | b_sent_d) begin
              axis_in_rsp_o.tready = 1'b1;
            end
          end
        end
      end

      Sync: begin
        // If AXI channel was not sent yet, raise AXI request
        axi_out_req_o.aw_valid = (payload_in.hdr == TagAW) & ~axi_ch_sent_q;
        axi_out_req_o.w_valid = (payload_in.hdr == TagW) & ~axi_ch_sent_q;
        axi_out_req_o.ar_valid = (payload_in.hdr == TagAR) & ~axi_ch_sent_q;
        axi_in_rsp_o.r_valid = (payload_in.hdr == TagR) & ~axi_ch_sent_q;
        // Same for B response
        axi_in_rsp_o.b_valid = payload_in.b_valid & ~b_sent_q;

        // Once both AXI and B channel has been sent out, we can go
        // back to the Normal mode and accept payload
        if (axi_ch_sent_d & b_sent_d) begin
          axis_in_rsp_o.tready = 1'b1;
          unpack_state_d = Normal;
        end
      end

      default:;
    endcase
  end

  assign entropy_d = entropy_q + (axis_out_req_o.tvalid & axis_out_rsp_i.tready);
  `FF(entropy_q, entropy_d, '0)
  `FF(aw_sent_q, aw_sent_d, '0)
  `FF(w_sent_q, w_sent_d, '0)
  `FF(ar_sent_q, ar_sent_d, '0)
  `FF(r_sent_q, r_sent_d, '0)
  `FF(b_sent_q, b_sent_d, '0)
  `FF(axi_ch_sent_q, axi_ch_sent_d, '0)
  `FF(unpack_state_q, unpack_state_d, Normal)


  //////////////////////
  //   FLOW CONTROL   //
  //////////////////////

  // Flow control is theoretically part of the data link layer.
  // However it is much simpler to implement it here where we have
  // simple Handshake interfaces

  always_comb begin
    credits_out_d = credits_out_q;
    credits_to_send_d = credits_to_send_q;
    credit_to_send_force = 1'b0;

    // Send empty packets with credits if there are too many
    // credits to send but no AXI request transaction
    if (credits_to_send_q >= ForceSendThresh) begin
      credit_to_send_force = 1'b1;
    end

    // The order of the two if blocks matter!
    if (axis_reg_valid_in & axis_reg_ready_in) begin
      credits_out_d--;
      credits_to_send_d = 0;
    end

    if (axis_in_req_i.tvalid & axis_in_rsp_o.tready) begin
      credits_out_d += payload_in.credit;
      credits_to_send_d++;
    end
  end

  `FF(credits_out_q, credits_out_d, NumCredits)
  `FF(credits_to_send_q, credits_to_send_d, 0)

  ////////////////////
  //   ASSERTIONS   //
  ////////////////////
  `ASSERT(AxiComitterAw, axi_in_req_i.w_valid & axi_in_rsp_o.w_ready & axi_in_req_i.w.last
          |=> $fell(commiter_state_q[1]))
  `ASSERT(AxiComitterAr, axi_in_rsp_o.r_valid & axi_in_req_i.r_ready & axi_in_rsp_o.r.last
          |=> $fell(commiter_state_q[0]))
  `ASSERT(AxisStable, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> $stable(axis_out_req_o.t))
  `ASSERT(AxisHandshake, axis_out_req_o.tvalid & !axis_out_rsp_i.tready |=> axis_out_req_o.tvalid)
  `ASSERT_INIT(ForceSendTh, ForceSendThresh > 0)
  `ASSERT(MaxCredits, credits_out_q <= NumCredits)
  `ASSERT(MaxSendCredits, credits_to_send_q <= NumCredits)

endmodule
