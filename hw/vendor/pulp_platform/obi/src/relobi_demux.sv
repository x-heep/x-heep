// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module relobi_demux #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct for all ports.
  parameter type               obi_req_t   = logic,
  /// The response struct for all ports.
  parameter type               obi_rsp_t   = logic,
  /// The r_chan struct for all ports.
  parameter type               obi_r_chan_t = logic,
  /// The optional r_chan struct for all ports.
  parameter type               obi_r_optional_t = logic,
  /// The number of manager ports.
  parameter int unsigned       NumMgrPorts = 32'd0,
  /// The maximum number of outstanding transactions.
  parameter int unsigned       NumMaxTrans = 32'd0,
  /// Use TMR for select signal
  parameter bit                TmrSelect   = 1'b1,
  /// The type of the port select signal.
  parameter type               select_t    = logic [$clog2(NumMgrPorts)-1:0],
  parameter int unsigned       SelWidth    = TmrSelect ? 3 : 1
) (
  input  logic                       clk_i,
  input  logic                       rst_ni,

  input  select_t  [   SelWidth-1:0] sbr_port_select_i,
  input  obi_req_t                   sbr_port_req_i,
  output obi_rsp_t                   sbr_port_rsp_o,

  output obi_req_t [NumMgrPorts-1:0] mgr_ports_req_o,
  input  obi_rsp_t [NumMgrPorts-1:0] mgr_ports_rsp_i,

  output logic [1:0]                 fault_o
);

  if (ObiCfg.Integrity) begin : gen_integrity_err
    $fatal(1, "unimplemented");
  end

  logic [6:0] faults;
  assign fault_o[0] = |faults;
  assign fault_o[1] = 1'b0; // reserved for future use

  // stall requests to ensure in-order behavior (could be handled differently with rready)
  localparam int unsigned CounterWidth = cf_math_pkg::idx_width(NumMaxTrans);

  // Internals TMR'd

  logic [2:0][NumMgrPorts-1:0] mgr_ports_req;

  obi_r_chan_t [NumMgrPorts-1:0] mgr_ports_rsp_r;
  logic [2:0][NumMgrPorts-1:0] mgr_ports_rsp_rvalid;
  logic [2:0][NumMgrPorts-1:0] mgr_ports_gnt;
  obi_r_chan_t [2:0] sbr_port_rsp_r;
  logic [2:0] sbr_port_rready;

  for (genvar i = 0; i < NumMgrPorts; i++) begin : gen_mgr_rsp
    assign mgr_ports_rsp_r[i]   = mgr_ports_rsp_i[i].r;
    for (genvar j = 0; j < 3; j++) begin : gen_mgr_rsp_valid
      assign mgr_ports_rsp_rvalid[j][i] = mgr_ports_rsp_i[i].rvalid[j];
      assign mgr_ports_gnt[j][i] = mgr_ports_rsp_i[i].gnt[j];
    end
  end

  select_t [2:0] select_d_sync;
  select_t [2:0][1:0] alt_select_d_sync;
  logic [2:0][CounterWidth:0] counter_d_sync;
  logic [2:0][1:0][CounterWidth:0] alt_counter_d_sync;
  for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
    for (genvar j = 0; j < 2; j++) begin : gen_alt_sync
      assign alt_select_d_sync[i][j] = select_d_sync[(i+j+1) % 3];
      assign alt_counter_d_sync[i][j] = counter_d_sync[(i+j+1) % 3];
    end
    relobi_demux_tmr_part #(
      .NumMgrPorts   (NumMgrPorts),
      .CounterWidth  (CounterWidth),
      .select_t      (select_t),
      .obi_r_chan_t  (obi_r_chan_t),
      .TmrBeforeReg  (1'b0)
    ) i_tmr_part (
      .clk_i                (clk_i),
      .rst_ni               (rst_ni),
      .select_i             (TmrSelect ? sbr_port_select_i[i] : sbr_port_select_i[0]),
      .sbr_port_req         (sbr_port_req_i.req[i]),
      .sbr_port_gnt         (sbr_port_rsp_o.gnt[i]),
      .mgr_ports_req        (mgr_ports_req[i]),
      .mgr_ports_gnt        (mgr_ports_gnt[i]),
      .mgr_ports_rsp_r      (mgr_ports_rsp_r),
      .mgr_ports_rsp_rvalid (mgr_ports_rsp_rvalid[i]),
      .sbr_port_rsp_r       (sbr_port_rsp_r[i]),
      .sbr_port_rsp_rvalid  (sbr_port_rsp_o.rvalid[i]),
      .sbr_port_rready      (sbr_port_rready[i]),
      .select_d_sync        (select_d_sync[i]),
      .counter_d_sync       (counter_d_sync[i]),
      .alt_select_d_sync    (alt_select_d_sync[i]),
      .alt_counter_d_sync   (alt_counter_d_sync[i]),
      .fault_o              (faults[2*i+1:2*i])
    );
  end

  for (genvar i = 0; i < NumMgrPorts; i++) begin : gen_mgr_req
    assign mgr_ports_req_o[i].req[0] = mgr_ports_req[0][i];
    assign mgr_ports_req_o[i].req[1] = mgr_ports_req[1][i];
    assign mgr_ports_req_o[i].req[2] = mgr_ports_req[2][i];
    assign mgr_ports_req_o[i].a   = sbr_port_req_i.a;
  end

  relobi_tmr_r #(
    .ObiCfg      (ObiCfg),
    .obi_r_chan_t(obi_r_chan_t),
    .r_optional_t (obi_r_optional_t)
  ) i_r_vote (
    .three_r_i(sbr_port_rsp_r),
    .voted_r_o(sbr_port_rsp_o.r),
    .fault_o (faults[6])
  );

  if (ObiCfg.UseRReady) begin : gen_rready
    assign sbr_port_rready = sbr_port_req_i.rready;
    for (genvar i = 0; i < NumMgrPorts; i++) begin : gen_rready
      assign mgr_ports_req_o[i].rready = sbr_port_req_i.rready;
    end
  end else begin : gen_no_rready
    assign sbr_port_rready = 3'b111;
  end

endmodule

(* no_ungroup *)
(* no_boundary_optimization *)
module relobi_demux_tmr_part #(
  parameter int unsigned NumMgrPorts = 32'd0,
  parameter int unsigned CounterWidth = 7,
  parameter type select_t = logic [$clog2(NumMgrPorts)-1:0],
  parameter type obi_r_chan_t = logic,
  parameter bit TmrBeforeReg = 1'b0
) (
  input  logic                          clk_i,
  input  logic                          rst_ni,
  input  select_t                       select_i,
  input  logic                          sbr_port_req,
  output logic                          sbr_port_gnt,
  output logic        [NumMgrPorts-1:0] mgr_ports_req,
  input  logic        [NumMgrPorts-1:0] mgr_ports_gnt,
  input  obi_r_chan_t [NumMgrPorts-1:0] mgr_ports_rsp_r,
  input  logic        [NumMgrPorts-1:0] mgr_ports_rsp_rvalid,
  output obi_r_chan_t                   sbr_port_rsp_r,
  output logic                          sbr_port_rsp_rvalid,
  input  logic                          sbr_port_rready,
  output select_t                      select_d_sync,
  output logic [CounterWidth:0]        counter_d_sync,
  input  select_t [1:0]                alt_select_d_sync,
  input  logic [1:0][CounterWidth:0]   alt_counter_d_sync,
  output logic                    [1:0] fault_o
);


  logic  cnt_up, cnt_down, overflow;
  logic [CounterWidth-1:0] in_flight;

  select_t select_d, select_q;
  logic [CounterWidth:0] counter_d, counter_q;

  always_comb begin : proc_req
    select_d = select_q;
    cnt_up = 1'b0;
    for (int j = 0; j < NumMgrPorts; j++) begin
      mgr_ports_req[j] = 1'b0;
    end
    sbr_port_gnt = 1'b0;
    if (!overflow) begin
      if (select_i == select_q ||
          in_flight == '0) begin
        mgr_ports_req[select_i] = sbr_port_req;
        sbr_port_gnt             = mgr_ports_gnt[select_i];
      end
    end

    if (mgr_ports_req[select_i] && mgr_ports_gnt[select_i]) begin
      select_d = select_i;
      cnt_up = 1'b1;
    end
  end

  assign sbr_port_rsp_r = mgr_ports_rsp_r[select_q];
  assign sbr_port_rsp_rvalid = mgr_ports_rsp_rvalid[select_q];

  // Could be voted, but with only one error source (either select_q or rvalid) should suffice
  assign cnt_down = mgr_ports_rsp_rvalid[select_q] && sbr_port_rready;

  assign overflow = counter_q[CounterWidth];
  assign in_flight = counter_q[CounterWidth-1:0];

  always_comb begin
    counter_d = counter_q;

    if (cnt_up & ~cnt_down) begin
      counter_d = counter_q + {{CounterWidth-1{1'b0}}, 1'b1};
    end else if (cnt_down & ~cnt_up) begin
      counter_d = counter_q - {{CounterWidth-1{1'b0}}, 1'b1};
    end
  end

  if (TmrBeforeReg) begin : gen_tmr_before_reg
    select_t select_d_voted;
    logic [CounterWidth:0] counter_d_voted;
    assign select_d_sync = select_d;
    assign counter_d_sync = counter_d;
    bitwise_TMR_voter_fail #(
      .DataWidth( $clog2(NumMgrPorts) )
    ) i_select_vote (
      .a_i        (select_d),
      .b_i        (alt_select_d_sync[0]),
      .c_i        (alt_select_d_sync[1]),
      .majority_o (select_d_voted),
      .fault_detected_o (fault_o[0])
    );
    bitwise_TMR_voter_fail #(
      .DataWidth( CounterWidth+1 )
    ) i_counter_vote (
      .a_i        (counter_d),
      .b_i        (alt_counter_d_sync[0]),
      .c_i        (alt_counter_d_sync[1]),
      .majority_o (counter_d_voted),
      .fault_detected_o (fault_o[1])
    );
    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_select
      if(!rst_ni) begin
        counter_q <= '0;
        select_q <= '0;
      end else begin
        counter_q <= counter_d_voted;
        select_q <= select_d_voted;
      end
    end
  end else begin : gen_tmr_after_reg
    select_t select_d_next;
    logic [CounterWidth:0] counter_d_next;
    assign select_d_sync = select_d_next;
    assign counter_d_sync = counter_d_next;
    bitwise_TMR_voter_fail #(
      .DataWidth( $clog2(NumMgrPorts) )
    ) i_select_vote (
      .a_i        (select_d_next),
      .b_i        (alt_select_d_sync[0]),
      .c_i        (alt_select_d_sync[1]),
      .majority_o (select_q),
      .fault_detected_o (fault_o[0])
    );
    bitwise_TMR_voter_fail #(
      .DataWidth( CounterWidth+1 )
    ) i_counter_vote (
      .a_i        (counter_d_next),
      .b_i        (alt_counter_d_sync[0]),
      .c_i        (alt_counter_d_sync[1]),
      .majority_o (counter_q),
      .fault_detected_o (fault_o[1])
    );
    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_select
      if(!rst_ni) begin
        counter_d_next <= '0;
        select_d_next <= '0;
      end else begin
        counter_d_next <= counter_d;
        select_d_next <= select_d;
      end
    end

  end



endmodule
