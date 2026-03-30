// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Manuel Eggimann <meggimann@iis.ee.ethz.ch>

module serial_link_channel_allocator
 import serial_link_pkg::*;
 #(
  parameter type phy_data_t = serial_link_pkg::phy_data_t,
  parameter int          NumChannels = 1,
  parameter int unsigned FlushCounterWidth = 8, // Number of bits for the
                                // internal counter for the auto-flush feature.
                                // 8 bits should be sufficient in most circumstances
  localparam int         Log2Channels = $clog2(NumChannels)
)(
  input logic                         clk_i,
  input logic                         rst_ni,

  //---------------------- Configuration ----------------------
  input logic                         cfg_tx_clear_i,
  input logic [NumChannels-1:0]       cfg_tx_channel_en_i,
  input logic                         cfg_tx_bypass_en_i,
  input logic                         cfg_tx_auto_flush_en_i,
  input logic                         cfg_tx_flush_trigger_i,
  input logic [FlushCounterWidth-1:0] cfg_tx_auto_flush_count_i,
  input logic                         cfg_rx_clear_i,
  input logic [NumChannels-1:0]       cfg_rx_channel_en_i,
  input logic                         cfg_rx_auto_flush_en_i,
  // count*T_clk <! T_tx_clk, otherwise, data jumbling can occur
  input logic [FlushCounterWidth-1:0] cfg_rx_auto_flush_count_i,
  input logic                         cfg_rx_bypass_en_i,
  input logic                         cfg_rx_sync_en_i,

  //----------------------- TX Channels -----------------------
  // From/To Data Link Layer
  input                               phy_data_t [NumChannels-1:0] data_out_i,
  input logic [NumChannels-1:0]       data_out_valid_i,
  output logic                        data_out_ready_o,
  // To/From Phy
  output                              phy_data_t [NumChannels-1:0] data_out_o,
  output logic [NumChannels-1:0]      data_out_valid_o,
  input logic [NumChannels-1:0]       data_out_ready_i,
  //----------------------- RX Channels -----------------------
  // To/From Data Link Layer
  output                              phy_data_t [NumChannels-1:0] data_in_o,
  output logic [NumChannels-1:0]      data_in_valid_o,
  input logic [NumChannels-1:0]       data_in_ready_i,
  // From/To Phy
  input                               phy_data_t [NumChannels-1:0] data_in_i,
  input logic [NumChannels-1:0]       data_in_valid_i,
  output logic [NumChannels-1:0]      data_in_ready_o
);

  //----------------------- TX Channels -----------------------
  phy_data_t[NumChannels-1:0]    s_tx_chopper2spreader_data;
  logic                          s_tx_chopper2data_link_ready;
  logic                          s_tx_data_link2chopper_valid;
  logic
[NumChannels-1:0]        s_tx_chopper2spreader_valid;
  logic                          s_tx_spreader2chopper_ready;
  phy_data_t[NumChannels-1:0]    s_tx_spreader2phy_data;
  logic [NumChannels-1:0]        s_tx_spreader2phy_valid;
  logic                          s_tx_phy2spreader_ready;

  // Popcount to count number of enabled channels
  logic [Log2Channels-1:0]       s_enabeled_channels_count;
  always_comb begin
    s_enabeled_channels_count = '0;
    foreach(cfg_tx_channel_en_i[i]) begin
      s_enabeled_channels_count += cfg_tx_channel_en_i[i];
    end
  end

  assign s_tx_data_link2chopper_valid = |data_out_valid_i && !cfg_tx_bypass_en_i;

  stream_chopper #(
    .element_t ( phy_data_t  ),
    .Width     ( NumChannels ),
    .FlushCounterWidth(FlushCounterWidth)
  ) i_tx_chopper(
    .clk_i,
    .rst_ni,
    .clear_i                ( cfg_tx_clear_i               ),
    .bypass_en_i            ( cfg_tx_bypass_en_i           ),
    .flush_i                ( cfg_tx_flush_trigger_i       ),
    .cfg_auto_flush_en_i    ( cfg_tx_auto_flush_en_i       ),
    .cfg_auto_flush_count_i ( cfg_tx_auto_flush_count_i    ),
    .cfg_chopsize_i         ( s_enabeled_channels_count    ),
    .data_i                 ( data_out_i                   ),
    .valid_i                ( s_tx_data_link2chopper_valid ),
    .ready_o                ( s_tx_chopper2data_link_ready ),
    .data_o                 ( s_tx_chopper2spreader_data   ),
    .valid_o                ( s_tx_chopper2spreader_valid  ),
    .ready_i                ( s_tx_spreader2chopper_ready  )
  );

  channel_spread_sfr #(
    .element_t ( phy_data_t  ),
    .Width     ( NumChannels )
  ) i_tx_spreader(
    .clk_i,
    .rst_ni,
    .clear_i          ( cfg_tx_clear_i              ),
    .cfg_channel_en_i ( cfg_tx_channel_en_i         ),
    .data_i           ( s_tx_chopper2spreader_data  ),
    .valid_i          ( s_tx_chopper2spreader_valid ),
    .ready_o          ( s_tx_spreader2chopper_ready ),
    .data_o           ( s_tx_spreader2phy_data      ),
    .valid_o          ( s_tx_spreader2phy_valid     ),
    .ready_i          ( s_tx_phy2spreader_ready     )
  );

  // Synchronization Barrier and Bypass Mux
  // Wait until all enabled channels are ready before asserting upstream read
  // and possibly bypass the allocator all together
  assign data_out_o = (cfg_tx_bypass_en_i)? data_out_i : s_tx_spreader2phy_data;
  assign data_out_valid_o = (cfg_tx_bypass_en_i)? data_out_valid_i: s_tx_spreader2phy_valid;
  assign s_tx_phy2spreader_ready = (cfg_tx_bypass_en_i)? 1'b0 :
    ((data_out_ready_i & data_out_valid_o) == data_out_valid_o);
  assign data_out_ready_o = (cfg_tx_bypass_en_i)? (data_out_ready_i == data_out_valid_o) :
    s_tx_chopper2data_link_ready;

  //----------------------- RX Channels -----------------------
  typedef struct packed {
    phy_data_t [NumChannels-1:0] data;
    logic [NumChannels-1:0]      valid;
  } slice_payload_t;

  logic                       s_rx_phy2recv_barrier_valid;
  logic                       s_rx_recv_barrier2phy_ready;

  phy_data_t[NumChannels-1:0] s_rx_recv_barrier2despreader_data;
  logic [NumChannels-1:0]     s_rx_recv_barrier2despreader_valid;
  logic                       s_rx_despreader2recv_barrier_ready;

  slice_payload_t         s_rx_despreader2slice_payload;
  logic                   s_rx_despreader2slice_valid;
  logic                   s_rx_slice2despreader_ready;

  slice_payload_t         s_rx_slice2dechopper_payload;
  logic                   s_rx_slice2dechopper_valid;
  logic                   s_rx_dechopper2slice_ready;

  phy_data_t[NumChannels-1:0] s_rx_dechopper2data_link_data;
  logic                       s_rx_dechopper2data_link_valid;
  logic                       s_rx_data_link2dechopper_ready;

  slice_payload_t           s_rx_recv_barrier_payload_in, s_rx_recv_barrier_payload_out;
  logic                     s_rx_recv_barrier_valid_in;
  logic                     s_rx_recv_barrier_ready_out;
  logic                     s_rx_recv_barrier_valid_out;
  logic                     s_rx_recv_barrier_ready_in;

  assign s_rx_recv_barrier_payload_in.data = data_in_i;

  // This fifo buffers incoming data. It not only prevents overflows in case of
  // back pressure (the depth should be dimensioned according to the number of
  // credits in credit-based flow control schemes) is also acts as a
  // synchronization barrier for the independing RX channels. It only has a
  // single valid signal and the valid status of the individual channels is
  // packed into the FIFO's payload. That way we prevent issues when new packets
  // arrive when a partial packet (not all channels valid e.g. due to
  // auto-flushing) is already stalled. Without the synchronization FIFO, parts
  // of the late arriving packet would be accidently merged into the earlier partial
  // packet if it wasn't for this FIFO acting as the sync barrier.
  stream_register #(
    .T            ( slice_payload_t   )
  ) i_rx_recv_barrier (
    .clk_i,
    .rst_ni,
    .clr_i      ( cfg_rx_clear_i           ),
    .testmode_i ( 1'b0                     ),
    .data_i     ( s_rx_recv_barrier_payload_in     ),
    .valid_i    ( s_rx_recv_barrier_valid_in  ),
    .ready_o    ( s_rx_recv_barrier_ready_out ),
    .data_o     ( s_rx_recv_barrier_payload_out    ),
    .valid_o    ( s_rx_recv_barrier_valid_out ),
    .ready_i    ( s_rx_recv_barrier_ready_in  )
  );

  assign s_rx_recv_barrier2despreader_valid = (s_rx_recv_barrier_valid_out && !cfg_rx_bypass_en_i)?
     s_rx_recv_barrier_payload_out.valid: '0;
  assign s_rx_recv_barrier2despreader_data = s_rx_recv_barrier_payload_out.data;

  channel_despread_sfr #(
    .element_t ( phy_data_t  ),
    .Width     ( NumChannels )
  ) i_rx_despreader (
    .clk_i,
    .rst_ni,
    .clear_i             ( cfg_rx_clear_i                      ),
    .valid_i             ( s_rx_recv_barrier2despreader_valid     ),
    .ready_o             ( s_rx_despreader2recv_barrier_ready     ),
    .data_i              ( s_rx_recv_barrier2despreader_data      ),
    .valid_o             ( s_rx_despreader2slice_payload.valid ),
    .ready_i             ( s_rx_slice2despreader_ready         ),
    .data_o              ( s_rx_despreader2slice_payload.data  )
  );

  // Insert pipeline slice in order to decouple latency of dechopper and
  // despreader. Since the despreader generates <NumChannels> individual valid
  // signals, we pack them into the slice data payload and use the or'ed
  // combination as the valid signal. The valid signals are already synchronized
  // at that stage so we can do it like this.

  assign s_rx_despreader2slice_valid = |s_rx_despreader2slice_payload.valid;

  spill_register #(
    .T(slice_payload_t),
    .Bypass(1'b0)
  ) i_rx_decoupling_slice (
    .clk_i,
    .rst_ni,
    .valid_i ( s_rx_despreader2slice_valid   ),
    .ready_o ( s_rx_slice2despreader_ready   ),
    .data_i  ( s_rx_despreader2slice_payload ),
    .valid_o ( s_rx_slice2dechopper_valid    ),
    .ready_i ( s_rx_dechopper2slice_ready    ),
    .data_o  ( s_rx_slice2dechopper_payload  )
  );


  stream_dechopper #(
    .element_t         ( phy_data_t        ),
    .Width             ( NumChannels       ),
    .FlushCounterWidth ( FlushCounterWidth )
  ) i_rx_dechopper(
    .clk_i,
    .rst_ni,
    .clear_i     ( cfg_rx_clear_i                                                     ),
    .bypass_en_i ( cfg_rx_bypass_en_i                                                 ),
    .valid_i     ( s_rx_slice2dechopper_valid? s_rx_slice2dechopper_payload.valid: '0 ),
    .ready_o     ( s_rx_dechopper2slice_ready                                         ),
    .data_i      ( s_rx_slice2dechopper_payload.data                                  ),
    .valid_o     ( s_rx_dechopper2data_link_valid                                     ),
    .ready_i     ( s_rx_data_link2dechopper_ready                                     ),
    .data_o      ( s_rx_dechopper2data_link_data                                      )
  );

  // Output assignments and bypass mux
  always_comb begin
    data_in_o               = '0;
    data_in_valid_o         = '0;
    data_in_ready_o         = '0;
    s_rx_recv_barrier_ready_in = 1'b0;

    if (cfg_rx_bypass_en_i) begin
      // In bypass mode we need to distinguish between enabled and disabled
      // synchronization. If sync is disabled, we not only bypass the channel
      // allocator but also the receive FIFO that performs synchronization.
      if (cfg_rx_sync_en_i) begin
        data_in_ready_o         = s_rx_recv_barrier_ready_out? s_rx_recv_barrier_payload_in.valid
                                                              : '0;
        data_in_o               = s_rx_recv_barrier_payload_out.data;
        data_in_valid_o         = s_rx_recv_barrier_valid_out? s_rx_recv_barrier_payload_out.valid
                                                              : '0;
        s_rx_recv_barrier_ready_in = |data_in_ready_i;
      end else begin
        data_in_ready_o = data_in_ready_i & cfg_rx_channel_en_i;
        data_in_o       = data_in_i;
        data_in_valid_o = data_in_valid_i & cfg_rx_channel_en_i;
      end
    end else begin
      data_in_ready_o         = s_rx_recv_barrier_ready_out? s_rx_recv_barrier_payload_in.valid: '0;
      data_in_o               = s_rx_dechopper2data_link_data;
      data_in_valid_o         = '{default: s_rx_dechopper2data_link_valid};
      s_rx_recv_barrier_ready_in = s_rx_despreader2recv_barrier_ready;
    end
  end

  // If we are not in bypass mode, the data_link layer is guaranteed to always
  // assert either all or none of the ready signals. We can just check the first
  // one to save logic/pressure on critical path.
  assign s_rx_data_link2dechopper_ready = (cfg_rx_bypass_en_i)? 1'b0: data_in_ready_i[0];

  // Partial phy valid synchronization logic
  // The TX side sends on all channels using the same synchronous clock (divided
  // by a constant integer ratio). The only reason, why valid bits from
  // different channels would not arrive in the same cycle is due to the CDC
  // crossing from source clock to RX clock which could skew some of the
  // channels by at most 1 clock cycle. A naive implementation would just wait
  // until all RX channels which are enabled have their valid signals asserted,
  // however, the TX chopper makes use of a feature called auto-flush. If we
  // send e.g. a SINGLE 4 byte word over a 4x8bit channel with on channel being
  // disabled, the TX side of the channel allocator would normally send the
  // first 3 bytes and wait indefinitely for more TX data to arrive to assemble
  // the next 3 byte link layer packet to send. However in the case where we
  // send only one packet, this additional data will never arrive and the
  // network layer packet is never fully transmitted. Therefore, the TX side has
  // an auto-flush feature that automatically flushes the FIFO sending partially
  // full (in this case 1 byte) packets if no additional data arrives for a
  // configurable number of clock cycles. Therefore, the RX side must be
  // correctly synchronize the arriving channels even though there might be less
  // than cfg_rx_channel_en valid signals asserted because the TX side flushed
  // its output and sent a partial packet. The logic for RX valid
  // synchronization thus uses a small FSM that waits at most
  // cfg_rx_auto_flush_count_i cycles after some RX valid toggling before
  // forwarding the valid to the RX datapath. In theory a config
  // cfg_rx_auto_flush_count_i = 1 should always be enough. For testability
  // purposes and to be on the save side, we make it configurable.
  //
  logic                       s_rx_fullword_valid;

  typedef enum logic[0:0] {WAIT_RX, PARTIAL_RX} rx_sync_state_e;
  rx_sync_state_e rx_sync_state_d, rx_sync_state_q;
  logic [FlushCounterWidth-1:0] rx_sync_auto_flush_counter_d, rx_sync_auto_flush_counter_q;

  assign s_rx_fullword_valid = (cfg_rx_channel_en_i & data_in_valid_i) == cfg_rx_channel_en_i;
  always_comb begin
    s_rx_recv_barrier_valid_in      = 1'b0;
    s_rx_recv_barrier_payload_in.valid   = '0;
    rx_sync_state_d              = rx_sync_state_q;
    rx_sync_auto_flush_counter_d = rx_sync_auto_flush_counter_q;

    // Check synchronous clear signal
    if (cfg_rx_clear_i) begin
      rx_sync_state_d = WAIT_RX;
      rx_sync_auto_flush_counter_d = '0;
    end else if (cfg_rx_sync_en_i) begin
      // Check which sync state we are in:
      case (rx_sync_state_q)
        WAIT_RX: begin
          // Check if we received a complete word
          if (s_rx_fullword_valid) begin
            // Yes we did. All the enabled channels are valid.
            // Push a new item into the pipeline register
            s_rx_recv_barrier_valid_in     = 1'b1;
            s_rx_recv_barrier_payload_in.valid  = data_in_valid_i & cfg_rx_channel_en_i;

            // Did some enabled channels become valid and is the auto flush feature
            // enabled?
          end else if (((data_in_valid_i & cfg_rx_channel_en_i) != '0) && cfg_rx_auto_flush_en_i)
          begin
            // We received a partial word. Switch to the PARTIAL_RX state to wait
            // for cfg_rx_auto_flush_count_i cycles for some more data to arrive
              rx_sync_state_d                                     = PARTIAL_RX;
              rx_sync_auto_flush_counter_d                        = 0;
          end
        end

        PARTIAL_RX: begin
          // Check if the auto-flush counter expired
          if ((rx_sync_auto_flush_counter_q == cfg_rx_auto_flush_count_i)
              || !cfg_rx_auto_flush_en_i || s_rx_fullword_valid)
          begin
            // Auto flush counter expired
            // Now we forward the valid signal to the RX datapath. If there was skew
            // between the different channels, it should be resolved by now (assumes
            // at most one RX clock cycle of skew). There should in theory never
            // be any backpressure towards the PHY since the RX FIFO should be
            // dimensioned to hold as many elements as there are credits in the
            // credit-based flow control system.
            s_rx_recv_barrier_valid_in      = 1'b1;
            s_rx_recv_barrier_payload_in.valid   = data_in_valid_i & cfg_rx_channel_en_i;
            if (s_rx_recv_barrier_ready_out) begin
              rx_sync_auto_flush_counter_d = '0;
              rx_sync_state_d              = WAIT_RX;
            end
          end else begin
            rx_sync_auto_flush_counter_d = rx_sync_auto_flush_counter_q+1;
          end
        end

        default: begin
          rx_sync_state_d = WAIT_RX;
        end
      endcase
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      rx_sync_state_q              <= WAIT_RX;
      rx_sync_auto_flush_counter_q <= '0;
    end else begin
      rx_sync_state_q              <= rx_sync_state_d;
      rx_sync_auto_flush_counter_q <= rx_sync_auto_flush_counter_d;
    end
  end

endmodule
