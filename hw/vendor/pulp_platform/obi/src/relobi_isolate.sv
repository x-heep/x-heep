// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_isolate #(
    /// The OBI configuration.
  parameter obi_pkg::obi_cfg_t ObiCfg       = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type               obi_req_t    = logic,
  /// The response struct.
  parameter type               obi_rsp_t    = logic,
  /// The a_chan struct for all ports.
  parameter type               obi_a_chan_t = logic,
  /// The r_chan struct for all ports.
  parameter type               obi_r_chan_t = logic,
  /// The optional a_chan struct for all ports.
  parameter type               obi_a_optional_t = logic,
  /// The optional r_chan struct for all ports.
  parameter type               obi_r_optional_t = logic,
  /// Maximum number of pending requests per channel
  parameter int unsigned       MaxPending   = 4,
  /// Gracefully terminate all incoming transactions in case of isolation by returning proper error
  /// responses.
  parameter bit                TerminateTransaction = 1'b0,
  /// Use TMR for isolate signals
  parameter bit                TmrSelect = 1'b0,
  parameter int unsigned       SelWidth  = TmrSelect ? 3 : 1
) (
  input  logic     clk_i,
  input  logic     rst_ni,

  input  obi_req_t sbr_port_req_i,
  output obi_rsp_t sbr_port_rsp_o,

  output obi_req_t mgr_port_req_o,
  input  obi_rsp_t mgr_port_rsp_i,

  input  logic [SelWidth-1:0] isolate_i,
  output logic [SelWidth-1:0] isolated_o,

  output logic fault_o
);

  // plus 1 in clog for accouning no open transaction
  localparam int unsigned CounterWidth = $clog2(MaxPending + 32'd1);
  typedef logic [CounterWidth-1:0] cnt_t;

  logic [3:0] faults;
  assign fault_o = |faults;

  obi_req_t in_req, out_req;
  obi_rsp_t in_rsp, out_rsp;

  if (TerminateTransaction) begin : gen_err_rsp
    obi_req_t err_req;
    obi_rsp_t err_rsp;
    // demux to error subordinate
    relobi_demux #(
      .ObiCfg      ( ObiCfg     ),
      .obi_req_t   ( obi_req_t  ),
      .obi_rsp_t   ( obi_rsp_t  ),
      .obi_r_chan_t( obi_r_chan_t),
      .obi_r_optional_t( obi_r_optional_t),
      .NumMgrPorts ( 2          ),
      .NumMaxTrans ( MaxPending ),
      .TmrSelect   ( TmrSelect  )
    ) i_demux (
      .clk_i                 ( clk_i  ),
      .rst_ni                ( rst_ni ),

      .sbr_port_select_i     ( isolated_o     ),
      .sbr_port_req_i        ( sbr_port_req_i ),
      .sbr_port_rsp_o        ( sbr_port_rsp_o ),

      .mgr_ports_req_o       ( { in_req, err_req } ),
      .mgr_ports_rsp_i       ( { in_rsp, err_rsp } )
    );

    relobi_err_sbr #(
      .ObiCfg      ( ObiCfg     ),
      .obi_req_t   ( obi_req_t  ),
      .obi_rsp_t   ( obi_rsp_t  ),
      .a_optional_t( obi_a_optional_t),
      .r_optional_t( obi_r_optional_t),
      .NumMaxTrans ( MaxPending )
    ) i_err_sbr (
      .clk_i       ( clk_i  ),
      .rst_ni      ( rst_ni ),
      .testmode_i  ( 1'b0   ),

      .obi_req_i   ( err_req ),
      .obi_rsp_o   ( err_rsp )
    );
  end else begin : gen_no_err_rsp
    assign in_req = sbr_port_req_i;
    assign sbr_port_rsp_o = in_rsp;
  end

  logic [2:0] rready, mgr_rready;
  logic [2:0] isolate_in, isolated_out;

  if (TmrSelect) begin : gen_tmr_isolate
    assign isolate_in = isolate_i;
    assign isolated_o = isolated_out;
    assign faults[0] = 1'b0;
  end else begin : gen_no_tmr_isolate
    assign isolate_in[0] = isolate_i;
    assign isolate_in[1] = isolate_i;
    assign isolate_in[2] = isolate_i;
    TMR_voter_fail i_isolate_vote (
      .a_i        (isolated_out[0]),
      .b_i        (isolated_out[1]),
      .c_i        (isolated_out[2]),
      .majority_o (isolated_o),
      .fault_detected_o(faults[0])
    );
  end

  if (ObiCfg.UseRReady) begin : gen_rready
    assign rready = in_rsp.rready;
    always_comb begin
      mgr_port_req_o = out_req;
      mgr_port_req_o.rready = mgr_rready;
    end
  end else begin : gen_no_rready
    assign rready = 1'b1;
    assign mgr_port_req_o = out_req;
  end

  logic [2:0][1:0] isolate_state_sync;
  logic [2:0][1:0][1:0] alt_isolate_state_sync;
  logic [2:0][CounterWidth-1:0] in_flight_sync;
  logic [2:0][1:0][CounterWidth-1:0] alt_in_flight_sync;
  for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
    for (genvar j = 0; j < 2; j++) begin : gen_alt_sync
      assign alt_isolate_state_sync[i][j] = isolate_state_sync[(i+j+1) % 3];
      assign alt_in_flight_sync[i][j] = in_flight_sync[(i+j+1) % 3];
    end
    relobi_isolate_tmr_part #(
      .CounterWidth ( CounterWidth ),
      .cnt_t        ( cnt_t        )
    ) i_tmr_part (
      .clk_i     ( clk_i     ),
      .rst_ni    ( rst_ni    ),

      .in_req_req_i     ( in_req.req[i] ),
      .in_rsp_gnt_o     ( in_rsp.gnt[i] ),
      .in_rsp_rvalid_o  ( in_rsp.rvalid[i] ),
      .out_req_req_o    ( out_req.req[i] ),
      .out_rsp_gnt_i    ( mgr_port_rsp_i.gnt[i] ),
      .out_rsp_rvalid_i ( mgr_port_rsp_i.rvalid[i] ),
      .mgr_rready_o     ( mgr_rready[i] ),
      .rready_i         ( rready[i] ),

      .isolate_i      ( isolate_in[i] ),
      .isolated_o     ( isolated_out[i] ),

      .in_flight_sync_o       ( in_flight_sync[i] ),
      .alt_in_flight_sync_i   ( alt_in_flight_sync[i] ),
      .isolate_state_sync_o   ( isolate_state_sync[i] ),
      .alt_isolate_state_sync_i( alt_isolate_state_sync[i] ),

      .fault_o        ( faults[i+1] )
    );
  end

  logic [$bits(obi_a_chan_t)-1:0] in_req_a, out_req_a;
  logic [$bits(obi_r_chan_t)-1:0] in_rsp_r, out_rsp_r;
  assign in_req_a  = in_req.a;
  assign out_req.a = obi_a_chan_t'(out_req_a);
  assign in_rsp.r  = obi_r_chan_t'(in_rsp_r);
  assign out_rsp_r = out_rsp.r;

  for (genvar i = 0; i < $bits(obi_a_chan_t); i++) begin : gen_chan_connections
    logic isolated_out_voted;
    TMR_voter_fail i_isolate_vote_tmr_part (
      .a_i        (isolated_out[0]),
      .b_i        (isolated_out[1]),
      .c_i        (isolated_out[2]),
      .majority_o (isolated_out_voted),
      .fault_detected_o(faults[4+i])
    );
    assign out_req_a[i] = isolated_out_voted ? '0 : in_req_a[i];
    if (i < $bits(obi_r_chan_t)) begin
      assign in_rsp_r[i] = isolated_out_voted ? '0 : in_rsp_r[i];
    end
  end

endmodule

module relobi_isolate_tmr_part #(
  parameter int unsigned       MaxPending = 4,
  parameter int unsigned CounterWidth = $clog2(MaxPending + 32'd1),
  parameter type cnt_t = logic[CounterWidth-1:0]
) (
  input  logic     clk_i,
  input  logic     rst_ni,

  input  logic in_req_req_i,
  output logic in_rsp_gnt_o,
  output logic in_rsp_rvalid_o,
  output logic out_req_req_o,
  input  logic out_rsp_gnt_i,
  input  logic out_rsp_rvalid_i,
  output logic mgr_rready_o,
  input  logic rready_i,

  input  logic isolate_i,
  output logic isolated_o,

  output cnt_t            in_flight_sync_o,
  input  cnt_t [1:0]      alt_in_flight_sync_i,
  output logic      [1:0] isolate_state_sync_o,
  input  logic [1:0][1:0] alt_isolate_state_sync_i,
  output logic fault_o
);

  typedef enum logic [1:0] {
    Normal,
    Hold,
    Drain,
    Isolate
  } isolate_state_e;

  isolate_state_e isolate_state_d, isolate_state_q, isolate_state_q_voted;
  cnt_t           in_flight_d, in_flight_q, in_flight_q_voted;
  logic [1:0] faults;
  assign fault_o = |faults;

  // Update counters
  always_comb begin
    in_flight_d = in_flight_q_voted;
    if (out_req_req_o && (isolate_state_q_voted == Normal)) begin
      in_flight_d++;
    end
    if (out_rsp_rvalid_i && rready_i) begin
      in_flight_d--;
    end
  end

  // Perform isolation
  always_comb begin
    isolate_state_d = isolate_state_q_voted;
    // Connect channel by default
    out_req_req_o = in_req_req_i;
    in_rsp_gnt_o = out_rsp_gnt_i;
    in_rsp_rvalid_o = out_rsp_rvalid_i;
    mgr_rready_o      = rready_i;
    unique case (isolate_state_q_voted)
      Normal: begin
        // Block if in flight transactions overflows
        if (in_flight_q_voted >= cnt_t'(MaxPending)) begin
          out_req_req_o = 1'b0;
          in_rsp_gnt_o  = 1'b0;
          if (isolate_i) begin
            isolate_state_d = Hold;
          end
        end else begin
          if (in_req_req_i && !out_rsp_gnt_i) begin
            isolate_state_d = Hold;
          end else begin
            if (isolate_i) begin
              isolate_state_d = Drain;
            end
          end
        end
      end
      Hold: begin
        out_req_req_o = 1'b1;
        if (out_rsp_gnt_i) begin
          isolate_state_d = isolate_i ? Drain : Normal;
        end
      end
      Drain: begin
        out_req_req_o = 1'b0;
        in_rsp_gnt_o  = 1'b0;
        if (in_flight_q_voted == '0) begin
          isolate_state_d = Isolate;
        end
      end
      Isolate: begin
        out_req_req_o   = 1'b0;
        in_rsp_gnt_o    = 1'b0;
        in_rsp_rvalid_o = 1'b0;
        mgr_rready_o    = 1'b0;
        if (!isolate_i) begin
          isolate_state_d = Normal;
        end
      end
      default: ;
    endcase
  end

  assign isolated_o = (isolate_state_q_voted == Isolate);

  bitwise_TMR_voter_fail #(
    .DataWidth( $bits(isolate_state_e) )
  ) i_isolate_state_vote (
    .a_i        (isolate_state_q),
    .b_i        (alt_isolate_state_sync_i[0]),
    .c_i        (alt_isolate_state_sync_i[1]),
    .majority_o (isolate_state_q_voted),
    .fault_detected_o(faults[0])
  );
  assign isolate_state_sync_o = isolate_state_q;
  bitwise_TMR_voter_fail #(
    .DataWidth( CounterWidth )
  ) i_in_flight_vote (
    .a_i        (in_flight_q),
    .b_i        (alt_in_flight_sync_i[0]),
    .c_i        (alt_in_flight_sync_i[1]),
    .majority_o (in_flight_q_voted),
    .fault_detected_o(faults[1])
  );
  assign in_flight_sync_o = in_flight_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      isolate_state_q <= Isolate;
      in_flight_q     <= '0;
    end else begin
      isolate_state_q <= isolate_state_d;
      in_flight_q     <= in_flight_d;
    end
  end

endmodule
