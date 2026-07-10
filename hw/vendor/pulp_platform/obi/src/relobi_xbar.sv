// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

/// An OBI crossbar interconnect.
module relobi_xbar #(
  /// The OBI configuration for the subordinate ports (input ports).
  parameter obi_pkg::obi_cfg_t SbrPortObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The OBI configuration for the manager ports (ouput ports).
  parameter obi_pkg::obi_cfg_t MgrPortObiCfg      = SbrPortObiCfg,
  /// The request struct for the subordinate ports (input ports).
  parameter type               sbr_port_obi_req_t = logic,
  /// The A channel struct for the subordinate ports (input ports).
  parameter type               sbr_port_a_chan_t  = logic,
  /// The response struct for the subordinate ports (input ports).
  parameter type               sbr_port_obi_rsp_t = logic,
  /// The R channel struct for the subordinate ports (input ports).
  parameter type               sbr_port_r_chan_t  = logic,
  /// The request struct for the manager ports (output ports).
  parameter type               mgr_port_obi_req_t = sbr_port_obi_req_t,
  /// The response struct for the manager ports (output ports).
  parameter type               mgr_port_obi_rsp_t = sbr_port_obi_rsp_t,
  /// The A channel struct for the manager port (output port).
  parameter type               mgr_port_a_chan_t  = logic,
  /// The R channel struct for the manager port (output port).
  parameter type               mgr_port_r_chan_t  = logic,
  /// The A channel optionals struct for all ports.
  parameter type               a_optional_t = logic,
  /// The R channel optionals struct for all ports.
  parameter type               r_optional_t = logic,
  /// The number of subordinate ports (input ports).
  parameter int unsigned       NumSbrPorts        = 32'd0,
  /// The number of manager ports (output ports).
  parameter int unsigned       NumMgrPorts        = 32'd0,
  /// The maximum number of outstanding transactions.
  parameter int unsigned       NumMaxTrans        = 32'd0,
  /// The number of address rules.
  parameter int unsigned       NumAddrRules       = 32'd0,
  /// The address map rule type.
  parameter type               addr_map_rule_t    = logic,
  /// Use the extended ID field (aid & rid) to route the response
  parameter bit                UseIdForRouting    = 1'b0,
  /// Connectivity matrix to disable certain paths.
  parameter bit [NumSbrPorts-1:0][NumMgrPorts-1:0] Connectivity = '1,
  /// Use TMR for addr map signal
  parameter bit                TmrMap          = 1'b1,
  parameter int unsigned       MapWidth    = TmrMap ? 3 : 1,
  parameter bit                DecodeAbort = 1'b0
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic testmode_i,

  input  sbr_port_obi_req_t [NumSbrPorts-1:0] sbr_ports_req_i,
  output sbr_port_obi_rsp_t [NumSbrPorts-1:0] sbr_ports_rsp_o,

  output mgr_port_obi_req_t [NumMgrPorts-1:0] mgr_ports_req_o,
  input  mgr_port_obi_rsp_t [NumMgrPorts-1:0] mgr_ports_rsp_i,

  input  addr_map_rule_t [MapWidth-1:0][NumAddrRules-1:0]   addr_map_i,
  input  logic [MapWidth-1:0][NumSbrPorts-1:0]              en_default_idx_i,
  input  logic [MapWidth-1:0][NumSbrPorts-1:0][$clog2(NumMgrPorts)-1:0] default_idx_i,

  output logic [1:0] fault_o
);

  logic [NumSbrPorts+NumMgrPorts-1:0][1:0] faults;
  logic [1:0][NumSbrPorts+NumMgrPorts-1:0] faults_transpose;
  for (genvar i = 0; i < NumSbrPorts+NumMgrPorts; i++) begin : gen_faults_transpose
    for (genvar j = 0; j < 2; j++) begin : gen_faults_transpose_inner
      assign faults_transpose[j][i] = faults[i][j];
    end
  end
  assign fault_o[0] = |faults_transpose[0];
  assign fault_o[1] = |faults_transpose[1];

  logic [2:0][NumSbrPorts-1:0][$clog2(NumMgrPorts)-1:0] sbr_port_select;
  logic [2:0][NumSbrPorts-1:0][MgrPortObiCfg.AddrWidth-1:0] addr_input;
  logic [2:0][NumSbrPorts-1:0] decode_abort;


  // Signals from the demuxes
  sbr_port_obi_req_t [NumSbrPorts-1:0][NumMgrPorts-1:0] sbr_reqs, sbr_reqs_aborted;
  sbr_port_obi_rsp_t [NumSbrPorts-1:0][NumMgrPorts-1:0] sbr_rsps, sbr_rsps_aborted;

  // Signals to the muxes
  sbr_port_obi_req_t [NumMgrPorts-1:0][NumSbrPorts-1:0] mgr_reqs;
  sbr_port_obi_rsp_t [NumMgrPorts-1:0][NumSbrPorts-1:0] mgr_rsps;

  // for (genvar i = 0; i < 3; i++) begin : gen_tmr_part
  //   relobi_xbar_tmr_part #(
  //     .NumSbrPorts ( NumSbrPorts                         ),
  //     .NumMgrPorts ( NumMgrPorts                         ),
  //     .AddrWidth   ( MgrPortObiCfg.AddrWidth             ),
  //     // .EccAddrWidth( MgrPortObiCfg.AddrWidth + hsiao_ecc_pkg::min_ecc(MgrPortObiCfg.AddrWidth) ),
  //     .NumAddrRules( NumAddrRules                        ),
  //     .addr_map_rule_t( addr_map_rule_t                  ),
  //     .DecodeAbort( DecodeAbort )
  //   ) i_tmr_part (
  //     .addr_i             ( addr_input[i] ),
  //     .addr_map_i         ( TmrMap ? addr_map_i[i] : addr_map_i[0] ),
  //     .en_default_idx_i   ( TmrMap ? en_default_idx_i[i] : en_default_idx_i[0] ),
  //     .default_idx_i      ( TmrMap ? default_idx_i[i] : default_idx_i[0] ),
  //     .sbr_port_select    ( sbr_port_select[i]          ),
  //     // .faults             ( faults[i*NumSbrPorts +: NumSbrPorts] ),
  //     .decode_abort_o     ( decode_abort[i]          )
  //   );
  // end

  for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_demux

    // assign addr_input[0][i] = sbr_ports_req_i[i].a.addr[0];
    // assign addr_input[1][i] = sbr_ports_req_i[i].a.addr[1];
    // assign addr_input[2][i] = sbr_ports_req_i[i].a.addr[2];

    for (genvar j = 0; j < 3; j++) begin : gen_addr_decode
      addr_decode #(
        .NoIndices ( NumMgrPorts           ),
        .NoRules   ( NumAddrRules          ),
        .addr_t    ( logic [SbrPortObiCfg.AddrWidth-1:0] ),
        .rule_t    ( addr_map_rule_t       )
      ) i_addr_decode (
        .addr_i          ( sbr_ports_req_i[i].a.addr[j]),
        .addr_map_i         ( TmrMap ? addr_map_i[j] : addr_map_i[0] ),
        .idx_o           ( sbr_port_select[j][i]  ),
        .dec_valid_o     (),
        .dec_error_o     (),
        .en_default_idx_i   ( TmrMap ? en_default_idx_i[j][i] : en_default_idx_i[0][i] ),
        .default_idx_i      ( TmrMap ? default_idx_i[j][i] : default_idx_i[0][i] )
      );
    end

    relobi_demux #(
      .ObiCfg      ( SbrPortObiCfg      ),
      .obi_req_t   ( sbr_port_obi_req_t ),
      .obi_rsp_t   ( sbr_port_obi_rsp_t ),
      .obi_r_chan_t( sbr_port_r_chan_t ),
      .obi_r_optional_t ( r_optional_t       ),
      .NumMgrPorts ( NumMgrPorts        ),
      .NumMaxTrans ( NumMaxTrans        ),
      .TmrSelect   ( 1'b1               )
    ) i_demux (
      .clk_i,
      .rst_ni,
      .sbr_port_select_i ( {sbr_port_select[2][i], sbr_port_select[1][i], sbr_port_select[0][i] } ),
      .sbr_port_req_i    ( sbr_ports_req_i[i] ),
      .sbr_port_rsp_o    ( sbr_ports_rsp_o[i] ),
      .mgr_ports_req_o   ( sbr_reqs[i]        ),
      .mgr_ports_rsp_i   ( sbr_rsps[i]        ),
      .fault_o           ( faults[i] )
    );

    for (genvar j = 0; j < NumMgrPorts; j++) begin : gen_sbr_reqs_abort_inner
      assign sbr_reqs_aborted[i][j].a = sbr_reqs[i][j].a;
      assign sbr_rsps_aborted[i][j].r = sbr_rsps[i][j].r;
      assign sbr_rsps_aborted[i][j].rvalid = sbr_rsps[i][j].rvalid;
      if (SbrPortObiCfg.UseRReady) begin : gen_rready
        assign sbr_reqs_aborted[i][j].rready = sbr_reqs[i][j].rready;
      end
      assign sbr_reqs_aborted[i][j].req[0] = sbr_reqs[i][j].req[0];// & ~decode_abort[0][i];
      assign sbr_reqs_aborted[i][j].req[1] = sbr_reqs[i][j].req[1];// & ~decode_abort[1][i];
      assign sbr_reqs_aborted[i][j].req[2] = sbr_reqs[i][j].req[2];// & ~decode_abort[2][i];
      assign sbr_rsps_aborted[i][j].gnt[0] = sbr_rsps[i][j].gnt[0];// & ~decode_abort[0][i];
      assign sbr_rsps_aborted[i][j].gnt[1] = sbr_rsps[i][j].gnt[1];// & ~decode_abort[1][i];
      assign sbr_rsps_aborted[i][j].gnt[2] = sbr_rsps[i][j].gnt[2];// & ~decode_abort[2][i];
      end

  end

  for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_interco_sbr
    for (genvar j = 0; j < NumMgrPorts; j++) begin : gen_interco_mgr
      if (Connectivity[i][j]) begin : gen_connected
        assign mgr_reqs[j][i] = sbr_reqs_aborted[i][j];
        assign sbr_rsps[i][j] = mgr_rsps[j][i];
      end else begin : gen_err_sbr
        assign mgr_reqs[j][i].req = '0;
        if (MgrPortObiCfg.UseRReady) begin : gen_rready
          assign mgr_reqs[j][i].rready = '0;
        end
        assign mgr_reqs[j][i].a   = '0;
        if (MgrPortObiCfg.Integrity) begin : gen_integrity
          assign mgr_reqs[j][i].reqpar = '1;
          if (MgrPortObiCfg.UseRReady) begin : gen_int_rready
            assign mgr_reqs[j][i].rreadypar = '1;
          end
        end
        relobi_err_sbr #(
          .ObiCfg      ( SbrPortObiCfg      ),
          .obi_req_t   ( sbr_port_obi_req_t ),
          .obi_rsp_t   ( sbr_port_obi_rsp_t ),
          .a_optional_t ( a_optional_t       ),
          .r_optional_t ( r_optional_t       ),
          .NumMaxTrans ( NumMaxTrans        ),
          .RspData     ( 32'hBADCAB1E       )
        ) i_err_sbr (
          .clk_i,
          .rst_ni,
          .testmode_i,
          .obi_req_i (sbr_reqs_aborted[i][j]),
          .obi_rsp_o (sbr_rsps[i][j]),
          .fault_o   () // TODO
        );
      end
    end
  end

  for (genvar i = 0; i < NumMgrPorts; i++) begin : gen_mux
    relobi_mux #(
      .SbrPortObiCfg      ( SbrPortObiCfg      ),
      .MgrPortObiCfg      ( MgrPortObiCfg      ),
      .sbr_port_obi_req_t ( sbr_port_obi_req_t ),
      .sbr_port_a_chan_t  ( sbr_port_a_chan_t  ),
      .sbr_port_obi_rsp_t ( sbr_port_obi_rsp_t ),
      .sbr_port_r_chan_t  ( sbr_port_r_chan_t  ),
      .mgr_port_obi_req_t ( mgr_port_obi_req_t ),
      .mgr_port_obi_rsp_t ( mgr_port_obi_rsp_t ),
      .mgr_port_a_chan_t  ( mgr_port_a_chan_t  ),
      .mgr_port_r_chan_t  ( mgr_port_r_chan_t  ),
      .a_optional_t       ( a_optional_t       ),
      .r_optional_t       ( r_optional_t       ),
      .NumSbrPorts        ( NumSbrPorts        ),
      .NumMaxTrans        ( NumMaxTrans        ),
      .UseIdForRouting    ( UseIdForRouting    )
    ) i_mux (
      .clk_i,
      .rst_ni,
      .testmode_i ( testmode_i ),
      .sbr_ports_req_i ( mgr_reqs[i]        ),
      .sbr_ports_rsp_o ( mgr_rsps[i]        ),
      .mgr_port_req_o  ( mgr_ports_req_o[i] ),
      .mgr_port_rsp_i  ( mgr_ports_rsp_i[i] ),
      .fault_o ( faults[NumSbrPorts+i] )
    );
  end

endmodule

// (* no_ungroup *)
// (* no_boundary_optimization *)
// module relobi_xbar_tmr_part #(
//   parameter int unsigned NumSbrPorts = 32'd0,
//   parameter int unsigned NumMgrPorts = 32'd0,
//   parameter int unsigned AddrWidth = 32'd0,
//   parameter int unsigned EccAddrWidth = AddrWidth + hsiao_ecc_pkg::min_ecc(AddrWidth),
//   parameter int unsigned NumAddrRules = 32'd0,
//   parameter type addr_map_rule_t = logic,
//   parameter bit DecodeAbort = 1'b1
// ) (
//   input logic [NumSbrPorts-1:0][AddrWidth-1:0] addr_i,
//   input addr_map_rule_t [NumAddrRules-1:0] addr_map_i,
//   input logic [NumSbrPorts-1:0] en_default_idx_i,
//   input logic [NumSbrPorts-1:0][$clog2(NumMgrPorts)-1:0] default_idx_i,
//   output logic [NumSbrPorts-1:0][$clog2(NumMgrPorts)-1:0] sbr_port_select,
//   // output logic [NumSbrPorts-1:0][1:0] faults,
//   output logic [NumSbrPorts-1:0] decode_abort_o
// );
//   logic [NumSbrPorts-1:0][AddrWidth-1:0] addr, addr_dec;

//   // for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_ecc_dec
//   //   hsiao_ecc_dec #(
//   //     .DataWidth ( AddrWidth )
//   //   ) i_addr_dec (
//   //     .in        ( addr_i[i] ),
//   //     .out       ( addr_dec [i]    ),
//   //     .syndrome_o(),
//   //     .err_o     (faults[i])
//   //   );
//   // end
//   // if (DecodeAbort) begin : gen_decode_abort
//   //   for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_addr
//   //     assign addr[i] = addr_i[i][AddrWidth-1:0];
//   //     assign decode_abort_o[i] = faults[i][0];// | faults[i][1];
//   //   end
//   // end else begin : gen_no_decode_abort
//     assign addr = addr_i;
//     assign decode_abort_o = '0;
//   // end


//   for (genvar i = 0; i < NumSbrPorts; i++) begin : gen_sel

//   end

// endmodule
