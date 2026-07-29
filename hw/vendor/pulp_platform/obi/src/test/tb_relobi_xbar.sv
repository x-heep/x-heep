// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

`include "obi/typedef.svh"
`include "obi/assign.svh"

module relobi_xbar_dut_wrapper #(
  parameter int unsigned NumManagers = 32'd6,
  parameter int unsigned NumSubordinates = 32'd8,
  parameter obi_pkg::obi_cfg_t MgrConfig = obi_pkg::ObiDefaultConfig,
  parameter obi_pkg::obi_cfg_t SbrConfig = obi_pkg::ObiDefaultConfig,
  parameter type rel_mgr_bus_req_t = logic,
  parameter type rel_mgr_bus_rsp_t = logic,
  parameter type rel_mgr_bus_a_chan_t = logic,
  parameter type rel_mgr_bus_r_chan_t = logic,
  parameter type rel_sbr_bus_req_t = logic,
  parameter type rel_sbr_bus_rsp_t = logic,
  parameter type rel_sbr_bus_a_chan_t = logic,
  parameter type rel_sbr_bus_r_chan_t = logic,
  parameter type mgr_bus_req_t = logic,
  parameter type mgr_bus_rsp_t = logic,
  parameter type sbr_bus_req_t = logic,
  parameter type sbr_bus_rsp_t = logic,
  parameter type mgr_bus_a_chan_t = logic,
  parameter type mgr_bus_r_chan_t = logic,
  parameter type sbr_bus_a_chan_t = logic,
  parameter type sbr_bus_r_chan_t = logic,
  parameter type mgr_a_optional_t = logic,
  parameter type mgr_r_optional_t = logic,
  parameter type sbr_a_optional_t = logic,
  parameter type sbr_r_optional_t = logic,
  parameter int unsigned NumMaxTrans = 32'd8,
  parameter int unsigned NumRules = 8,
  parameter type rule_t = logic,
  parameter rule_t [NumRules-1:0] AddrMap = '0,
  parameter bit UseIdForRouting = 1'b0,
  parameter time TestTime = 8ns,
  parameter int unsigned NumRequests = 1
) (
  input  logic clk,
  input  logic rst_n,

  // Manager ports
  input  mgr_bus_req_t [NumManagers-1:0] mgr_bus_req,
  output mgr_bus_rsp_t [NumManagers-1:0] mgr_bus_rsp,

  // Subordinate ports
  output sbr_bus_req_t [NumSubordinates-1:0] sbr_bus_req,
  input  sbr_bus_rsp_t [NumSubordinates-1:0] sbr_bus_rsp,

  input  logic [NumManagers-1:0] end_of_sim
);

  localparam int unsigned MgrBusReqBits = $bits(mgr_bus_req_t);
  localparam int unsigned MgrBusRspBits = $bits(mgr_bus_rsp_t);
  localparam int unsigned SbrBusReqBits = $bits(sbr_bus_req_t);
  localparam int unsigned SbrBusRspBits = $bits(sbr_bus_rsp_t);

  rel_mgr_bus_req_t [NumManagers-1:0] rel_mgr_bus_req, rel_mgr_bus_req_cut;
  rel_mgr_bus_rsp_t [NumManagers-1:0] rel_mgr_bus_rsp, rel_mgr_bus_rsp_cut;
  rel_sbr_bus_req_t [NumSubordinates-1:0] rel_sbr_bus_req, rel_sbr_bus_req_cut;
  rel_sbr_bus_rsp_t [NumSubordinates-1:0] rel_sbr_bus_rsp, rel_sbr_bus_rsp_cut;

  logic [1:0] xbar_fault;
  logic [NumManagers-1:0][1:0] encoder_faults;
  logic [NumManagers-1:0][1:0] enc_cut_faults;
  logic [NumSubordinates-1:0][1:0] decoder_faults;
  logic [NumSubordinates-1:0][1:0] dec_cut_faults;

  logic [NumManagers-1:0][MgrBusRspBits-1:0] mgr_bus_rsp_flat;
  for (genvar i = 0; i < NumManagers; i++) begin : gen_mgr_bus_rsp
    assign mgr_bus_rsp_flat[i] = mgr_bus_rsp[i];
  end

  logic [NumSubordinates-1:0][SbrBusReqBits-1:0] sbr_bus_req_flat;
  for (genvar i = 0; i < NumSubordinates; i++) begin : gen_sbr_bus_req
    assign sbr_bus_req_flat[i] = sbr_bus_req[i];
  end


  for (genvar i = 0; i < NumManagers; i++) begin : gen_mgr_encode
    relobi_encoder #(
      .Cfg          ( MgrConfig         ),
      .relobi_req_t ( rel_mgr_bus_req_t ),
      .relobi_rsp_t ( rel_mgr_bus_rsp_t ),
      .obi_req_t    ( mgr_bus_req_t     ),
      .obi_rsp_t    ( mgr_bus_rsp_t     ),
      .a_optional_t ( mgr_a_optional_t  ),
      .r_optional_t ( mgr_r_optional_t  )
    ) i_enc_mgr (
      .req_i (mgr_bus_req[i]),
      .rsp_o (mgr_bus_rsp[i]),

      .rel_req_o (rel_mgr_bus_req[i]),
      .rel_rsp_i (rel_mgr_bus_rsp[i]),

      .fault_o (encoder_faults[i]  )
    );
  end

  for (genvar i = 0; i < NumManagers; i++) begin : gen_mgr_cut
    relobi_cut #(
      .ObiCfg        ( MgrConfig         ),
      .obi_req_t     ( rel_mgr_bus_req_t ),
      .obi_rsp_t     ( rel_mgr_bus_rsp_t ),
      .obi_a_chan_t  ( rel_mgr_bus_a_chan_t  ),
      .obi_r_chan_t  ( rel_mgr_bus_r_chan_t  ),
      .a_optional_t ( mgr_a_optional_t  ),
      .r_optional_t ( mgr_r_optional_t  ),
      .Bypass        ( 1'b0              )
    ) i_cut_mgr (
      .clk_i          ( clk               ),
      .rst_ni         ( rst_n             ),

      .sbr_port_req_i ( rel_mgr_bus_req[i] ),
      .sbr_port_rsp_o ( rel_mgr_bus_rsp[i] ),

      .mgr_port_req_o ( rel_mgr_bus_req_cut[i] ),
      .mgr_port_rsp_i ( rel_mgr_bus_rsp_cut[i] ),

      .fault_o         ( enc_cut_faults[i] )
    );
  end

  relobi_xbar #(
    .SbrPortObiCfg   ( MgrConfig       ),
    .MgrPortObiCfg   ( SbrConfig       ),
    .sbr_port_obi_req_t ( rel_mgr_bus_req_t     ),
    .sbr_port_a_chan_t  ( rel_mgr_bus_a_chan_t  ),
    .sbr_port_obi_rsp_t ( rel_mgr_bus_rsp_t     ),
    .sbr_port_r_chan_t  ( rel_mgr_bus_r_chan_t  ),
    .mgr_port_obi_req_t ( rel_sbr_bus_req_t     ),
    .mgr_port_obi_rsp_t ( rel_sbr_bus_rsp_t     ),
    .mgr_port_a_chan_t  ( rel_sbr_bus_a_chan_t  ),
    .mgr_port_r_chan_t  ( rel_sbr_bus_r_chan_t  ),
    .a_optional_t       ( mgr_a_optional_t  ),
    .r_optional_t       ( mgr_r_optional_t  ),
    .NumSbrPorts     ( NumManagers     ),
    .NumMgrPorts     ( NumSubordinates ),
    .NumMaxTrans     ( NumMaxTrans     ),
    .NumAddrRules    ( NumRules        ),
    .addr_map_rule_t ( rule_t          ),
    .UseIdForRouting ( UseIdForRouting ),
    .TmrMap (1'b1),
    .DecodeAbort (1'b1)
  ) i_dut (
    .clk_i            ( clk     ),
    .rst_ni           ( rst_n   ),
    .testmode_i       ( 1'b0    ),

    .sbr_ports_req_i  ( rel_mgr_bus_req_cut ),
    .sbr_ports_rsp_o  ( rel_mgr_bus_rsp_cut ),

    .mgr_ports_req_o  ( rel_sbr_bus_req_cut ),
    .mgr_ports_rsp_i  ( rel_sbr_bus_rsp_cut ),

    .addr_map_i       ( {3{AddrMap}} ),
    .en_default_idx_i ( '0 ),
    .default_idx_i    ( '0 ),

    .fault_o          ( xbar_fault         )
  );

  for (genvar i = 0; i < NumSubordinates; i++) begin : gen_sbr_cut
    relobi_cut #(
      .ObiCfg        ( SbrConfig         ),
      .obi_req_t     ( rel_sbr_bus_req_t ),
      .obi_rsp_t     ( rel_sbr_bus_rsp_t ),
      .obi_a_chan_t  ( rel_sbr_bus_a_chan_t  ),
      .obi_r_chan_t  ( rel_sbr_bus_r_chan_t  ),
      .a_optional_t ( sbr_a_optional_t  ),
      .r_optional_t ( sbr_r_optional_t  ),
      .Bypass        ( 1'b0              )
    ) i_cut_sbr (
      .clk_i          ( clk               ),
      .rst_ni         ( rst_n             ),

      .sbr_port_req_i ( rel_sbr_bus_req_cut[i] ),
      .sbr_port_rsp_o ( rel_sbr_bus_rsp_cut[i] ),

      .mgr_port_req_o ( rel_sbr_bus_req[i] ),
      .mgr_port_rsp_i ( rel_sbr_bus_rsp[i] ),

      .fault_o         ( dec_cut_faults[i] )
    );
  end

  for (genvar i = 0; i < NumSubordinates; i++) begin : gen_sbr_decode
    relobi_decoder #(
      .Cfg          ( SbrConfig         ),
      .relobi_req_t ( rel_sbr_bus_req_t ),
      .relobi_rsp_t ( rel_sbr_bus_rsp_t ),
      .obi_req_t    ( sbr_bus_req_t     ),
      .obi_rsp_t    ( sbr_bus_rsp_t     ),
      .a_optional_t ( sbr_a_optional_t  ),
      .r_optional_t ( sbr_r_optional_t  )
    ) i_dec_sbr (
      .req_o (sbr_bus_req[i]),
      .rsp_i (sbr_bus_rsp[i]),

      .rel_req_i (rel_sbr_bus_req[i]),
      .rel_rsp_o (rel_sbr_bus_rsp[i]),

      .fault_o ( decoder_faults[i]  )
    );
  end

  logic interface_error;
  logic [NumSubordinates-1:0] sbr_error;
  logic [NumManagers-1:0] mgr_error;
  assign interface_error = |sbr_error | |mgr_error;

  // Collect sent requests and responses
  localparam int unsigned NumMABits = $bits(mgr_bus_a_chan_t);
  localparam int unsigned NumMRBits = $bits(mgr_bus_r_chan_t);
  localparam int unsigned NumSABits = $bits(sbr_bus_a_chan_t);
  localparam int unsigned NumSRBits = $bits(sbr_bus_r_chan_t);
  // logic [NumMABits-1:0] mgr_bus_a_chan_flat [NumManagers][NumSubordinates][$];
  logic mgr_bus_a_chan_flat_empty [NumManagers][NumSubordinates];
  logic [NumManagers-1:0][NumSubordinates-1:0] mgr_bus_a_chan_flat_pop;
  logic [NumMABits-1:0] mgr_bus_a_chan_flat_front [NumManagers][NumSubordinates];
  // logic [$clog2(NumSubordinates)-1:0] mgr_bus_rsp_idx [NumManagers][$];
  logic [$clog2(NumSubordinates)-1:0] mgr_bus_rsp_idx_front [NumManagers];
  logic [$clog2(NumSubordinates)-1:0] mgr_bus_rsp_idx_next [NumManagers];
  logic [NumManagers-1:0] mgr_bus_rsp_idx_push;
  // logic [NumSRBits-1:0] sbr_bus_r_chan_flat [NumSubordinates][$];
  logic [NumSRBits-1:0] sbr_bus_r_chan_flat_front [NumSubordinates];
  logic [NumSubordinates-1:0] sbr_bus_r_chan_flat_pop;
  logic [NumSubordinates-1:0][NumManagers-1:0] sbr_mgr_match;
  logic [NumManagers-1:0][NumSubordinates-1:0] mgr_sbr_match;

  logic [NumSubordinates-1:0] sbr_data_valid;
  logic [NumManagers-1:0] mgr_data_valid;
  for (genvar i = 0; i < NumSubordinates; i++) begin
    assign sbr_data_valid[i] = sbr_bus_req[i].req & sbr_bus_rsp[i].gnt;
    assign sbr_error[i] = sbr_bus_req[i].req & sbr_bus_rsp[i].gnt & ~(|sbr_mgr_match[i]);
  end
  for (genvar i = 0; i < NumManagers; i++) begin
    assign mgr_data_valid[i] = mgr_bus_rsp[i].rvalid;
    assign mgr_error[i] = mgr_bus_rsp[i].rvalid & ~(|mgr_sbr_match[i]);
  end

  for (genvar i = 0; i < NumManagers; i++) begin
    for (genvar j = 0; j < NumSubordinates; j++) begin
      fifo_v3 #(
        .FALL_THROUGH (1'b0),
        .DATA_WIDTH (NumMABits),
        .DEPTH (NumMaxTrans)
      ) i_fifo_mgr_a_chan (
        .clk_i (clk),
        .rst_ni (rst_n),
        .flush_i (1'b0),
        .testmode_i (1'b0),
        .full_o (),
        .empty_o (mgr_bus_a_chan_flat_empty[i][j]),
        .usage_o (),
        .data_i (mgr_bus_req[i].a),
        .push_i (mgr_bus_req[i].req && mgr_bus_rsp[i].gnt &&
                 mgr_bus_req[i].a.addr >= AddrMap[j].start_addr &&
                 mgr_bus_req[i].a.addr < AddrMap[j].end_addr),
        .data_o (mgr_bus_a_chan_flat_front[i][j]),
        .pop_i (mgr_bus_a_chan_flat_pop[i][j])
      );
    end
    fifo_v3 #(
      .FALL_THROUGH (1'b0),
      .DATA_WIDTH ($clog2(NumSubordinates)),
      .DEPTH (NumMaxTrans)
    ) i_fifo_mgr_idx (
      .clk_i (clk),
      .rst_ni (rst_n),
      .flush_i (1'b0),
      .testmode_i (1'b0),
      .full_o (),
      .empty_o (),
      .usage_o (),
      .data_i (mgr_bus_rsp_idx_next[i]),
      .push_i (mgr_bus_rsp_idx_push[i]),
      .data_o (mgr_bus_rsp_idx_front[i]),
      .pop_i (mgr_bus_rsp[i].rvalid)
    );
  end
  for (genvar i = 0; i < NumSubordinates; i++) begin
    fifo_v3 #(
      .FALL_THROUGH (1'b0),
      .DATA_WIDTH (NumSRBits),
      .DEPTH (NumMaxTrans*NumManagers)
    ) i_fifo_sbr_r_chan (
      .clk_i (clk),
      .rst_ni (rst_n),
      .flush_i (1'b0),
      .testmode_i (1'b0),
      .full_o (),
      .empty_o (),
      .usage_o (),
      .data_i (sbr_bus_rsp[i].r),
      .push_i (sbr_bus_rsp[i].rvalid),
      .data_o (sbr_bus_r_chan_flat_front[i]),
      .pop_i (sbr_bus_r_chan_flat_pop[i])
    );
  end

  always_comb begin
    for (int unsigned i = 0; i < NumSubordinates; i++) begin
      for (int unsigned j = 0; j < NumManagers; j++) begin
        if (sbr_bus_req[i].req && sbr_bus_rsp[i].gnt) begin
          if (mgr_bus_a_chan_flat_empty[j][i]) begin
            sbr_mgr_match[i][j] = 1'b0;
          end else begin
            sbr_mgr_match[i][j] = mgr_bus_a_chan_flat_front[j][i] == sbr_bus_req[i].a;
          end
        end else begin
          sbr_mgr_match[i][j] = 1'b0;
        end
      end
    end
    for (int unsigned i = 0; i < NumManagers; i++) begin
      if (mgr_bus_rsp[i].rvalid) begin
        mgr_sbr_match[i] = sbr_bus_r_chan_flat_front[mgr_bus_rsp_idx_front[i]] == mgr_bus_rsp[i].r;
      end else begin
        mgr_sbr_match[i] = '0;
      end
    end
  end

  always_comb begin
    mgr_bus_a_chan_flat_pop = '0;
    mgr_bus_rsp_idx_push = '0;
    sbr_bus_r_chan_flat_pop = '0;
    for (int unsigned i = 0; i < NumManagers; i++) begin
      for (int unsigned j = 0; j < NumSubordinates; j++) begin
        if (mgr_bus_req[i].req && mgr_bus_rsp[i].gnt &&
            mgr_bus_req[i].a.addr >= AddrMap[j].start_addr &&
            mgr_bus_req[i].a.addr < AddrMap[j].end_addr) begin
          // mgr_bus_a_chan_flat[i][j].push_back(mgr_bus_req[i].a);
          mgr_bus_rsp_idx_next[i] = j;
          mgr_bus_rsp_idx_push[i] = 1'b1;
          // mgr_bus_rsp_idx[i].push_back(j);
        end
      end
      if (mgr_bus_rsp[i].rvalid) begin
        sbr_bus_r_chan_flat_pop[mgr_bus_rsp_idx_front[i]] = 1'b1;
        // sbr_bus_r_chan_flat[mgr_bus_rsp_idx[i][0]].pop_front();
        // mgr_bus_rsp_idx[i].pop_front();
      end
    end
    for (int unsigned i = 0; i < NumSubordinates; i++) begin
      if (sbr_bus_req[i].req && sbr_bus_rsp[i].gnt) begin
        for (int unsigned j = 0; j < NumManagers; j++) begin
          if (mgr_bus_a_chan_flat_front[j][i] == sbr_bus_req[i].a) begin
            // mgr_bus_a_chan_flat[j][i].pop_front();
            mgr_bus_a_chan_flat_pop[j][i] = 1'b1;
            break;
          end
        end
      end
      // if (sbr_bus_rsp[i].rvalid) begin
      //   sbr_bus_r_chan_flat[i].push_back(sbr_bus_rsp[i].r);
      // end
    end

    // for (int unsigned i = 0; i < NumManagers; i++) begin
    //   mgr_bus_rsp_idx_front[i] = mgr_bus_rsp_idx[i][0];
    //   for (int unsigned j = 0; j < NumSubordinates; j++) begin
    //     mgr_bus_a_chan_flat_empty[i][j] = (mgr_bus_a_chan_flat[i][j].size() == 0);
    //     mgr_bus_a_chan_flat_front[i][j] = mgr_bus_a_chan_flat[i][j][0];
    //   end
    // end
    // for (int unsigned i = 0; i < NumSubordinates; i++) begin
    //   sbr_bus_r_chan_flat_front[i] = sbr_bus_r_chan_flat[i][0];
    // end
  end

  // Fault indication
  logic corrected_fault;
  logic uncorrectable_fault;
  always_comb begin
    corrected_fault = xbar_fault[0];
    uncorrectable_fault = xbar_fault[1];

    for (int unsigned i = 0; i < NumManagers; i++) begin
      corrected_fault |= encoder_faults[i][0] | enc_cut_faults[i][0];
      uncorrectable_fault |= encoder_faults[i][1] | enc_cut_faults[i][1];
    end
    for (int unsigned i = 0; i < NumSubordinates; i++) begin
      corrected_fault |= decoder_faults[i][0] | dec_cut_faults[i][0];
      uncorrectable_fault |= decoder_faults[i][1]  | dec_cut_faults[i][1];
    end
  end

  always @(posedge clk) begin
    #(TestTime);
    if (rst_n == 1'b1) begin
      if (uncorrectable_fault) begin
        $display("Uncorrectable fault detected in the crossbar at %t.", $time);
      end else if (corrected_fault) begin
        $display("Corrected fault detected in the crossbar at %t.", $time);
      end
    end
  end

  `ifdef TARGET_ZOIX
  `include "strobe.sv"
  `endif

endmodule

module tb_relobi_xbar;
  import obi_pkg::*;

  localparam int unsigned NumManagers = 32'd6;
  localparam int unsigned NumSubordinates = 32'd8;
  localparam bit          UseIdForRouting = 1'b0;

  localparam int unsigned NumMaxTrans = 32'd8;
  localparam int unsigned AddrWidth = 32;
  localparam int unsigned DataWidth = 32;
  localparam int unsigned MgrIdWidth = 5;
  localparam int unsigned SbrIdWidth = MgrIdWidth;
  localparam int unsigned AUserWidth = 4;
  localparam int unsigned WUserWidth = 2;
  localparam int unsigned RUserWidth = 3;

  // TODO CHK!

  localparam int unsigned NumRequests = 32'd1000;

  localparam time CyclTime = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  localparam obi_pkg::obi_cfg_t MgrConfig = '{
    UseRReady:      1'b0,
    CombGnt:        1'b0,
    AddrWidth: AddrWidth,
    DataWidth: DataWidth,
    IdWidth:  MgrIdWidth,
    Integrity:      1'b0,
    BeFull:         1'b1,
    OptionalCfg: '{
      UseAtop:          1'b1,
      UseMemtype:       1'b1,
      UseProt:          1'b1,
      UseDbg:           1'b1,
      AUserWidth: AUserWidth,
      WUserWidth: WUserWidth,
      RUserWidth: RUserWidth,
      MidWidth:            0,
      AChkWidth:           0,
      RChkWidth:           0
    }
  };

  typedef struct packed {
    logic [ AUserWidth-1:0] auser;
    logic [ WUserWidth-1:0] wuser;
    obi_pkg::atop_t         atop;
    obi_pkg::memtype_t      memtype;
    obi_pkg::prot_t         prot;
    logic                   dbg;
  } mgr_a_optional_t;
  typedef struct packed {
    logic [RUserWidth-1:0] ruser;
    logic                  exokay;
  } mgr_r_optional_t;
  typedef obi_test::obi_rand_manager #(
    .ObiCfg           ( MgrConfig ),
    .obi_a_optional_t ( mgr_a_optional_t ),
    .obi_r_optional_t ( mgr_r_optional_t ),
    .TA ( ApplTime ),
    .TT ( TestTime ),
    .MinAddr (32'h0000_0000),
    .MaxAddr (32'h0001_1000)
  ) rand_manager_t;

  localparam obi_pkg::obi_cfg_t SbrConfig = '{
    UseRReady:      1'b0,
    CombGnt:        1'b0,
    AddrWidth: AddrWidth,
    DataWidth: DataWidth,
    IdWidth:  SbrIdWidth,
    Integrity:      1'b0,
    BeFull:         1'b1,
    OptionalCfg: '{
      UseAtop:          1'b1,
      UseMemtype:       1'b1,
      UseProt:          1'b1,
      UseDbg:           1'b1,
      AUserWidth: AUserWidth,
      WUserWidth: WUserWidth,
      RUserWidth: RUserWidth,
      MidWidth:            0,
      AChkWidth:           0,
      RChkWidth:           0
    }
  };

  typedef mgr_a_optional_t sbr_a_optional_t;
  typedef mgr_r_optional_t sbr_r_optional_t;

  typedef obi_test::obi_rand_subordinate #(
    .ObiCfg ( SbrConfig ),
    .obi_a_optional_t ( sbr_a_optional_t ),
    .obi_r_optional_t ( sbr_r_optional_t ),
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) rand_subordinate_t;

  localparam int unsigned NumRules = 8;
  typedef struct packed {
    int unsigned idx;
    logic [AddrWidth-1:0] start_addr;
    logic [AddrWidth:0] end_addr;
  } rule_t;

  localparam rule_t [NumRules-1:0] AddrMap = '{
    '{idx: 32'd7, start_addr: 32'h0001_0000, end_addr: 32'h0001_1000},
    '{idx: 32'd6, start_addr: 32'h0000_9000, end_addr: 32'h0001_0000},
    '{idx: 32'd5, start_addr: 32'h0000_8000, end_addr: 32'h0000_9000},
    '{idx: 32'd4, start_addr: 32'h0000_7000, end_addr: 32'h0000_8000},
    '{idx: 32'd3, start_addr: 32'h0000_6300, end_addr: 32'h0000_7000},
    '{idx: 32'd2, start_addr: 32'h0000_4000, end_addr: 32'h0000_6300},
    '{idx: 32'd1, start_addr: 32'h0000_3000, end_addr: 32'h0000_4000},
    '{idx: 32'd0, start_addr: 32'h0000_0000, end_addr: 32'h0000_3000}
  };

  logic clk, rst_n;
  logic [NumManagers-1:0] end_of_sim;

  OBI_BUS_DV #(
    .OBI_CFG          ( MgrConfig ),
    .obi_a_optional_t ( mgr_a_optional_t ),
    .obi_r_optional_t ( mgr_r_optional_t )
  ) mgr_bus_dv [NumManagers] (
    .clk_i  ( clk   ),
    .rst_ni ( rst_n )
  );
  OBI_BUS #(
    .OBI_CFG          ( MgrConfig ),
    .obi_a_optional_t ( mgr_a_optional_t ),
    .obi_r_optional_t ( mgr_r_optional_t )
  ) mgr_bus [NumManagers] ();

  for (genvar i = 0; i < NumManagers; i++) begin : gen_mgr_drivers
    initial begin
      automatic rand_manager_t obi_rand_manager = new ( mgr_bus_dv[i], $sformatf("MGR_%0d",i));
      automatic logic [  MgrConfig.DataWidth-1:0] r_rdata    = '0;
      automatic logic [    MgrConfig.IdWidth-1:0] r_rid      = '0;
      automatic logic                             r_err      = '0;
      automatic mgr_r_optional_t                  r_optional = '0;
      end_of_sim[i] <= 1'b0;
      obi_rand_manager.reset();
      @(posedge rst_n);
      obi_rand_manager.write(32'h0000_1100, 4'hF, 32'hDEAD_BEEF, 2,
                             '{auser: '0,
                               wuser: '0,
                               atop: '0,
                               memtype: obi_pkg::memtype_t'('0),
                               prot: obi_pkg::prot_t'('0),
                               dbg: '0}, r_rdata, r_rid, r_err, r_optional);
      obi_rand_manager.read(32'h0000_e100, 2, '{auser: '0,
                                                wuser: '0,
                                                atop: '0,
                                                memtype: obi_pkg::memtype_t'('0),
                                                prot: obi_pkg::prot_t'('0),
                                                dbg: '0}, r_rdata, r_rid, r_err, r_optional);
      obi_rand_manager.run(NumRequests);
      end_of_sim[i] <= 1'b1;
    end

    `OBI_ASSIGN(mgr_bus[i], mgr_bus_dv[i], MgrConfig, MgrConfig)
  end

  OBI_BUS_DV #(
    .OBI_CFG          ( SbrConfig ),
    .obi_a_optional_t ( sbr_a_optional_t ),
    .obi_r_optional_t ( sbr_r_optional_t )
  ) sbr_bus_dv [NumSubordinates] (
    .clk_i  ( clk   ),
    .rst_ni ( rst_n )
  );
  OBI_BUS #(
    .OBI_CFG          ( SbrConfig ),
    .obi_a_optional_t ( sbr_a_optional_t ),
    .obi_r_optional_t ( sbr_r_optional_t )
  ) sbr_bus [NumSubordinates] ();

  for (genvar i = 0; i < NumSubordinates; i++) begin : gen_sbr_drivers
    initial begin
      automatic rand_subordinate_t obi_rand_subordinate =
        new ( sbr_bus_dv[i], $sformatf("SBR_%0d",i));
      obi_rand_subordinate.reset();
      @(posedge rst_n);
      obi_rand_subordinate.run();
    end

    `OBI_ASSIGN(sbr_bus_dv[i], sbr_bus[i], SbrConfig, SbrConfig)
  end

  clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
  ) i_clk_gen (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
  );

  // DUT
  `OBI_TYPEDEF_ALL_DEFAULT_WITH_OPTIONAL(mgr_bus, MgrConfig, mgr_a_optional_t, mgr_r_optional_t)
  `OBI_TYPEDEF_ALL_DEFAULT_WITH_OPTIONAL(sbr_bus, SbrConfig, sbr_a_optional_t, sbr_r_optional_t)
  `RELOBI_TYPEDEF_ALL_WITH_OPTIONAL(rel_mgr_bus, MgrConfig, mgr_a_optional_t, mgr_r_optional_t)
  `RELOBI_TYPEDEF_ALL_WITH_OPTIONAL(rel_sbr_bus, SbrConfig, sbr_a_optional_t, sbr_r_optional_t)
  mgr_bus_req_t [NumManagers-1:0] mgr_bus_req;
  mgr_bus_rsp_t [NumManagers-1:0] mgr_bus_rsp;
  sbr_bus_req_t [NumSubordinates-1:0] sbr_bus_req;
  sbr_bus_rsp_t [NumSubordinates-1:0] sbr_bus_rsp;

  for (genvar i = 0; i < NumManagers; i++) begin : gen_mgr_encode
    `OBI_ASSIGN_TO_REQ(mgr_bus_req[i], mgr_bus[i], MgrConfig)
    `OBI_ASSIGN_FROM_RSP(mgr_bus[i], mgr_bus_rsp[i], MgrConfig)
  end

  relobi_xbar_dut_wrapper #(
    .NumManagers(NumManagers),
    .NumSubordinates(NumSubordinates),
    .MgrConfig(MgrConfig),
    .SbrConfig(SbrConfig),
    .rel_mgr_bus_req_t(rel_mgr_bus_req_t),
    .rel_mgr_bus_rsp_t(rel_mgr_bus_rsp_t),
    .rel_mgr_bus_a_chan_t(rel_mgr_bus_a_chan_t),
    .rel_mgr_bus_r_chan_t(rel_mgr_bus_r_chan_t),
    .rel_sbr_bus_req_t(rel_sbr_bus_req_t),
    .rel_sbr_bus_rsp_t(rel_sbr_bus_rsp_t),
    .rel_sbr_bus_a_chan_t(rel_sbr_bus_a_chan_t),
    .rel_sbr_bus_r_chan_t(rel_sbr_bus_r_chan_t),
    .mgr_bus_req_t(mgr_bus_req_t),
    .mgr_bus_rsp_t(mgr_bus_rsp_t),
    .sbr_bus_req_t(sbr_bus_req_t),
    .sbr_bus_rsp_t(sbr_bus_rsp_t),
    .mgr_bus_a_chan_t(mgr_bus_a_chan_t),
    .mgr_bus_r_chan_t(mgr_bus_r_chan_t),
    .sbr_bus_a_chan_t(sbr_bus_a_chan_t),
    .sbr_bus_r_chan_t(sbr_bus_r_chan_t),
    .mgr_a_optional_t(mgr_a_optional_t),
    .mgr_r_optional_t(mgr_r_optional_t),
    .sbr_a_optional_t(sbr_a_optional_t),
    .sbr_r_optional_t(sbr_r_optional_t),
    .NumMaxTrans(NumMaxTrans),
    .NumRules(NumRules),
    .rule_t(rule_t),
    .AddrMap(AddrMap),
    .UseIdForRouting(UseIdForRouting),
    .TestTime(TestTime),
    .NumRequests(NumRequests)
  ) i_dut_wrapper (
    .clk,
    .rst_n,

    // Manager ports
    .mgr_bus_req,
    .mgr_bus_rsp,

    // Subordinate ports
    .sbr_bus_req,
    .sbr_bus_rsp,

    .end_of_sim(end_of_sim)
  );

  for (genvar i = 0; i < NumSubordinates; i++) begin : gen_sbr_decode
    `OBI_ASSIGN_FROM_REQ(sbr_bus[i], sbr_bus_req[i], SbrConfig)
    `OBI_ASSIGN_TO_RSP(sbr_bus_rsp[i], sbr_bus[i], SbrConfig)
  end

  initial begin
    wait(&end_of_sim);
    repeat (1000) @(posedge clk);
    $display("Simulation stopped as all Masters transferred their data, Success.",);
    $finish();
  end

endmodule
