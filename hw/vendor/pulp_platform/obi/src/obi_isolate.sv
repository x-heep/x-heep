// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module obi_isolate #(
    /// The OBI configuration.
  parameter obi_pkg::obi_cfg_t ObiCfg       = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type               obi_req_t    = logic,
  /// The response struct.
  parameter type               obi_rsp_t    = logic,
  /// Maximum number of pending requests per channel
  parameter int unsigned       MaxPending   = 4,
  /// Gracefully terminate all incoming transactions in case of isolation by returning proper error
  /// responses.
  parameter bit TerminateTransaction = 1'b0
) (
  input  logic     clk_i,
  input  logic     rst_ni,

  input  obi_req_t sbr_port_req_i,
  output obi_rsp_t sbr_port_rsp_o,

  output obi_req_t mgr_port_req_o,
  input  obi_rsp_t mgr_port_rsp_i,

  input  logic     isolate_i,
  output logic     isolated_o
);
  // plus 1 in clog for accouning no open transaction
  localparam int unsigned CounterWidth = $clog2(MaxPending + 32'd1);
  typedef logic [CounterWidth-1:0] cnt_t;


  obi_req_t in_req, out_req;
  obi_rsp_t in_rsp, out_rsp;

  if (TerminateTransaction) begin : gen_err_rsp
    obi_req_t err_req;
    obi_rsp_t err_rsp;
    // demux to error subordinate
    obi_demux #(
      .ObiCfg      ( ObiCfg     ),
      .obi_req_t   ( obi_req_t  ),
      .obi_rsp_t   ( obi_rsp_t  ),
      .NumMgrPorts ( 2          ),
      .NumMaxTrans ( MaxPending )
    ) i_demux (
      .clk_i                 ( clk_i  ),
      .rst_ni                ( rst_ni ),

      .sbr_port_select_i     ( isolated_o     ),
      .sbr_port_req_i        ( sbr_port_req_i ),
      .sbr_port_rsp_o        ( sbr_port_rsp_o ),

      .mgr_ports_req_o       ( { in_req, err_req } ),
      .mgr_ports_rsp_i       ( { in_rsp, err_rsp } )
    );

    obi_err_sbr #(
      .ObiCfg      ( ObiCfg     ),
      .obi_req_t   ( obi_req_t  ),
      .obi_rsp_t   ( obi_rsp_t  ),
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

  typedef enum logic [1:0] {
    Normal,
    Hold,
    Drain,
    Isolate
  } isolate_state_e;

  isolate_state_e isolate_state_d, isolate_state_q;
  cnt_t           in_flight_d, in_flight_q;
  logic           rready, mgr_rready;

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

  // Update counters
  always_comb begin
    in_flight_d = in_flight_q;
    if (out_req.req && (isolate_state_q == Normal)) begin
      in_flight_d++;
    end
    if (out_rsp.rvalid && rready) begin
      in_flight_d--;
    end
  end

  // Perform isolation
  always_comb begin
    isolate_state_d = isolate_state_q;
    // Connect channel by default
    out_req = in_req;
    in_rsp         = out_rsp;
    mgr_rready      = rready;
    unique case (isolate_state_q)
      Normal: begin
        // Block if in flight transactions overflows
        if (in_flight_q >= cnt_t'(MaxPending)) begin
          out_req.req = 1'b0;
          in_rsp.gnt         = 1'b0;
          if (isolate_i) begin
            isolate_state_d = Hold;
          end
        end else begin
          if (in_req.req && !out_rsp.gnt) begin
            isolate_state_d = Hold;
          end else begin
            if (isolate_i) begin
              isolate_state_d = Drain;
            end
          end
        end
      end
      Hold: begin
        out_req.req = 1'b1;
        if (out_rsp.gnt) begin
          isolate_state_d = isolate_i ? Drain : Normal;
        end
      end
      Drain: begin
        out_req.req = 1'b0;
        in_rsp.gnt         = 1'b0;
        if (in_flight_q == '0) begin
          isolate_state_d = Isolate;
        end
      end
      Isolate: begin
        out_req.req   = 1'b0;
        out_req.a     = '{default: '0};
        in_rsp.gnt    = 1'b0;
        in_rsp.rvalid = 1'b0;
        in_rsp.r      = '{default: '0};
        mgr_rready    = 1'b0;
        if (!isolate_i) begin
          isolate_state_d = Normal;
        end
      end
      default: ;
    endcase
  end

  assign isolated_o = (isolate_state_q == Isolate);

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
