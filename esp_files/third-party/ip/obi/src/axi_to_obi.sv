// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

module axi_to_obi #(
  /// The configuration of the OBI port (input port).
  parameter obi_pkg::obi_cfg_t ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct of the OBI port
  parameter type               obi_req_t = logic,
  /// The response struct of the OBI port
  parameter type               obi_rsp_t = logic,
  /// The A struct of the OBI port
  parameter type               obi_a_chan_t = logic,
  /// The R struct of the OBI port
  parameter type               obi_r_chan_t = logic,
  /// AXI Address Width
  parameter int unsigned       AxiAddrWidth = ObiCfg.AddrWidth,
  /// AXI Data Width
  parameter int unsigned       AxiDataWidth = ObiCfg.DataWidth,
  /// AXI ID Width
  parameter int unsigned       AxiIdWidth   = 0,
  /// AXI User Width
  parameter int unsigned       AxiUserWidth = 0,

  parameter int unsigned       MaxTrans = 0,
  /// The request struct of the AXI port
  parameter type               axi_req_t = logic,
  /// The response struct of the AXI port
  parameter type               axi_rsp_t = logic,
  // Dependent Parameters, *DO NOT OVERWRITE*
  parameter int unsigned       NumBanks = AxiDataWidth/ObiCfg.DataWidth,
  parameter int unsigned       AUserWidthAdjusted = ObiCfg.OptionalCfg.AUserWidth ?
                                                    ObiCfg.OptionalCfg.AUserWidth : 1,
  parameter int unsigned       WUserWidthAdjusted = ObiCfg.OptionalCfg.WUserWidth ?
                                                    ObiCfg.OptionalCfg.WUserWidth : 1,
  parameter int unsigned       RUserWidthAdjusted = ObiCfg.OptionalCfg.RUserWidth ?
                                                    ObiCfg.OptionalCfg.RUserWidth : 1
) (
  input  logic     clk_i,
  input  logic     rst_ni,
  input  logic     testmode_i,

  input  axi_req_t axi_req_i,
  output axi_rsp_t axi_rsp_o,

  output obi_req_t obi_req_o,
  input  obi_rsp_t obi_rsp_i,

  // Combinatorial request user assignment signals. If not used, assign '0 to *_i.
  output logic [NumBanks-1:0][        AxiIdWidth-1:0] req_aw_id_o,
  output logic [NumBanks-1:0][      AxiUserWidth-1:0] req_aw_user_o,
  output logic [NumBanks-1:0][      AxiUserWidth-1:0] req_w_user_o,
  input  logic [NumBanks-1:0][    ObiCfg.IdWidth-1:0] req_write_aid_i,
  input  logic [NumBanks-1:0][AUserWidthAdjusted-1:0] req_write_auser_i,
  input  logic [NumBanks-1:0][WUserWidthAdjusted-1:0] req_write_wuser_i,

  output logic [NumBanks-1:0][        AxiIdWidth-1:0] req_ar_id_o,
  output logic [NumBanks-1:0][      AxiUserWidth-1:0] req_ar_user_o,
  input  logic [NumBanks-1:0][    ObiCfg.IdWidth-1:0] req_read_aid_i,
  input  logic [NumBanks-1:0][AUserWidthAdjusted-1:0] req_read_auser_i,

  output logic               [      AxiUserWidth-1:0] rsp_write_aw_user_o,
  output logic               [      AxiUserWidth-1:0] rsp_write_w_user_o,
  output logic [NumBanks-1:0]                         rsp_write_bank_strb_o,
  output logic [NumBanks-1:0][    ObiCfg.IdWidth-1:0] rsp_write_rid_o,
  output logic [NumBanks-1:0][RUserWidthAdjusted-1:0] rsp_write_ruser_o,
  output logic                                        rsp_write_last_o,
  output logic                                        rsp_write_hs_o,
  input  logic               [      AxiUserWidth-1:0] rsp_b_user_i,

  output logic               [      AxiUserWidth-1:0] rsp_read_ar_user_o,
  output logic [NumBanks-1:0]                         rsp_read_size_enable_o,
  output logic [NumBanks-1:0][    ObiCfg.IdWidth-1:0] rsp_read_rid_o,
  output logic [NumBanks-1:0][RUserWidthAdjusted-1:0] rsp_read_ruser_o,
  input  logic               [      AxiUserWidth-1:0] rsp_r_user_i
);
  typedef struct packed {
    logic [AxiIdWidth-1:0] atop_id;
    logic                  lock;
    logic [5:0]            atop;
  } tmp_atop_t;

  axi_req_t axi_read_req, axi_write_req;
  axi_rsp_t axi_read_rsp, axi_write_rsp;

  localparam int unsigned IdRuserWidth = ObiCfg.IdWidth+ObiCfg.OptionalCfg.RUserWidth;

  logic            [2*NumBanks-1:0]                         bank_mem_req;
  logic            [2*NumBanks-1:0]                         bank_mem_gnt;
  logic            [2*NumBanks-1:0][      AxiAddrWidth-1:0] bank_mem_addr;
  logic            [2*NumBanks-1:0][  ObiCfg.DataWidth-1:0] bank_mem_wdata;
  logic            [2*NumBanks-1:0][ObiCfg.DataWidth/8-1:0] bank_mem_strb;
  axi_pkg::atop_t  [2*NumBanks-1:0]                         bank_mem_atop;
  logic            [2*NumBanks-1:0]                         bank_mem_lock;
  logic            [2*NumBanks-1:0][        AxiIdWidth-1:0] bank_mem_id;
  logic            [2*NumBanks-1:0][      AxiUserWidth-1:0] bank_mem_user;
  logic            [2*NumBanks-1:0]                         bank_mem_we;
  axi_pkg::cache_t [2*NumBanks-1:0]                         bank_mem_cache;
  axi_pkg::prot_t  [2*NumBanks-1:0]                         bank_mem_prot;
  logic            [2*NumBanks-1:0]                         bank_mem_rvalid;
  logic            [2*NumBanks-1:0][  ObiCfg.DataWidth-1:0] bank_mem_rdata;
  logic            [2*NumBanks-1:0]                         bank_mem_err;
  logic            [2*NumBanks-1:0]                         bank_mem_exokay;
  logic            [2*NumBanks-1:0][      IdRuserWidth-1:0] bank_mem_ruser;

  logic [2*NumBanks-1:0][  IdRuserWidth-1:0] rsp_ruser;
  logic [  NumBanks-1:0][2*AxiUserWidth-1:0] tmp_write_user;

  obi_req_t [2*NumBanks-1:0] obi_reqs;
  obi_rsp_t [2*NumBanks-1:0] obi_rsps;

  obi_pkg::atop_t [2*NumBanks-1:0] obi_atop;

  axi_demux_simple #(
    .AxiIdWidth  ( AxiIdWidth ),
    .AtopSupport ( 1'b1       ),
    .axi_req_t   ( axi_req_t  ),
    .axi_resp_t  ( axi_rsp_t  ),
    .NoMstPorts  ( 2          ),
    .MaxTrans    ( MaxTrans   ),
    .AxiLookBits ( 1          ),
    .UniqueIds   ( 1'b1       )
  ) i_read_write_demux (
    .clk_i,
    .rst_ni,
    .test_i         ( testmode_i ),
    .slv_req_i      ( axi_req_i  ),
    .slv_resp_o     ( axi_rsp_o  ),
    .slv_ar_select_i( 1'b0       ),
    .slv_aw_select_i( 1'b1       ),
    .mst_reqs_o     ( {axi_write_req, axi_read_req} ),
    .mst_resps_i    ( {axi_write_rsp, axi_read_rsp} )
  );

  axi_to_detailed_mem_user #(
    .axi_req_t   ( axi_req_t ),
    .axi_resp_t  ( axi_rsp_t ),
    .AddrWidth   ( AxiAddrWidth ),
    .DataWidth   ( AxiDataWidth ),
    .IdWidth     ( AxiIdWidth   ),
    .UserWidth   ( AxiUserWidth ),
    .NumBanks    ( NumBanks     ),
    .BufDepth    ( MaxTrans     ),
    .HideStrb    ( 1'b1         ),
    .OutFifoDepth( 2            ),
    .PropagateWUser ( 1'b0      ),
    .RUserExtra    (IdRuserWidth)
  ) i_axi_to_mem_read (
    .clk_i,
    .rst_ni,

    .busy_o      (),

    .axi_req_i   ( axi_read_req ),
    .axi_resp_o  ( axi_read_rsp ),

    .mem_req_o   ( bank_mem_req   [NumBanks-1:0] ),
    .mem_gnt_i   ( bank_mem_gnt   [NumBanks-1:0] ),
    .mem_addr_o  ( bank_mem_addr  [NumBanks-1:0] ),
    .mem_wdata_o ( bank_mem_wdata [NumBanks-1:0] ),
    .mem_strb_o  ( bank_mem_strb  [NumBanks-1:0] ),
    .mem_atop_o  ( bank_mem_atop  [NumBanks-1:0] ),
    .mem_lock_o  ( bank_mem_lock  [NumBanks-1:0] ),
    .mem_we_o    (), // bank_mem_we    [NumBanks-1:0] ),
    .mem_id_o    ( req_ar_id_o ), // bank_mem_id    [NumBanks-1:0] ),
    .mem_user_o  ( req_ar_user_o ), // bank_mem_user  [NumBanks-1:0] ),
    .mem_cache_o ( bank_mem_cache [NumBanks-1:0] ),
    .mem_prot_o  ( bank_mem_prot  [NumBanks-1:0] ),
    .mem_qos_o   (),
    .mem_region_o(),
    .mem_rvalid_i( bank_mem_rvalid[NumBanks-1:0] ),
    .mem_rdata_i ( bank_mem_rdata [NumBanks-1:0] ),
    .mem_err_i   ( bank_mem_err   [NumBanks-1:0] ),
    .mem_exokay_i( bank_mem_exokay[NumBanks-1:0] ),
    .mem_ruser_i ( bank_mem_ruser [NumBanks-1:0] ),

    .ruser_req_user_o       ( rsp_read_ar_user_o ),
    .ruser_req_bank_strb_o  (),
    .ruser_req_size_enable_o( rsp_read_size_enable_o ),
    .ruser_rsp_extra_o      ( rsp_ruser[NumBanks-1:0] ),
    .ruser_req_write_o      (),
    .ruser_req_last_o       (),
    .ruser_rsp_hs_o         (),
    .ruser_i                ( rsp_r_user_i )
  );
  assign bank_mem_we [NumBanks-1:0] = '0;
  assign bank_mem_id [NumBanks-1:0] = req_read_aid_i;
  assign bank_mem_user [NumBanks-1:0] = req_read_auser_i;

  axi_to_detailed_mem_user #(
    .axi_req_t   ( axi_req_t    ),
    .axi_resp_t  ( axi_rsp_t    ),
    .AddrWidth   ( AxiAddrWidth ),
    .DataWidth   ( AxiDataWidth ),
    .IdWidth     ( AxiIdWidth   ),
    .UserWidth   ( AxiUserWidth ),
    .NumBanks    ( NumBanks     ),
    .BufDepth    ( MaxTrans     ),
    .HideStrb    ( 1'b1         ),
    .OutFifoDepth( 2            ),
    .PropagateWUser(1'b1),
    .RUserExtra    (IdRuserWidth)
  ) i_axi_to_mem_write (
    .clk_i,
    .rst_ni,

    .busy_o      (),

    .axi_req_i   ( axi_write_req ),
    .axi_resp_o  ( axi_write_rsp ),

    .mem_req_o   ( bank_mem_req   [2*NumBanks-1:NumBanks] ),
    .mem_gnt_i   ( bank_mem_gnt   [2*NumBanks-1:NumBanks] ),
    .mem_addr_o  ( bank_mem_addr  [2*NumBanks-1:NumBanks] ),
    .mem_wdata_o ( bank_mem_wdata [2*NumBanks-1:NumBanks] ),
    .mem_strb_o  ( bank_mem_strb  [2*NumBanks-1:NumBanks] ),
    .mem_atop_o  ( bank_mem_atop  [2*NumBanks-1:NumBanks] ),
    .mem_lock_o  ( bank_mem_lock  [2*NumBanks-1:NumBanks] ),
    .mem_we_o    (), // bank_mem_we    [2*NumBanks-1:NumBanks] ),
    .mem_id_o    ( req_aw_id_o ), // bank_mem_id    [2*NumBanks-1:NumBanks] ),
    .mem_user_o  ( tmp_write_user ), // bank_mem_user  [2*NumBanks-1:NumBanks] ),
    .mem_cache_o ( bank_mem_cache [2*NumBanks-1:NumBanks] ),
    .mem_prot_o  ( bank_mem_prot  [2*NumBanks-1:NumBanks] ),
    .mem_qos_o   (),
    .mem_region_o(),
    .mem_rvalid_i( bank_mem_rvalid[2*NumBanks-1:NumBanks] ),
    .mem_rdata_i ( bank_mem_rdata [2*NumBanks-1:NumBanks] ),
    .mem_err_i   ( bank_mem_err   [2*NumBanks-1:NumBanks] ),
    .mem_exokay_i( bank_mem_exokay[2*NumBanks-1:NumBanks] ),
    .mem_ruser_i ( bank_mem_ruser [2*NumBanks-1:NumBanks] ),

    .ruser_req_user_o       ( {rsp_write_w_user_o, rsp_write_aw_user_o} ),
    .ruser_req_bank_strb_o  ( rsp_write_bank_strb_o ),
    .ruser_req_size_enable_o(),
    .ruser_rsp_extra_o      ( rsp_ruser[2*NumBanks-1:NumBanks] ),
    .ruser_req_write_o      (),
    .ruser_req_last_o       ( rsp_write_last_o ),
    .ruser_rsp_hs_o         ( rsp_write_hs_o ),
    .ruser_i                ( rsp_b_user_i )
  );
  assign bank_mem_we [2*NumBanks-1:NumBanks] = {NumBanks{1'b1}};
  assign bank_mem_id    [2*NumBanks-1:NumBanks] = req_write_aid_i;
  assign bank_mem_user  [2*NumBanks-1:NumBanks] = req_write_auser_i;

  for (genvar i = 0; i < NumBanks; i++) begin : gen_user_rid
    assign req_w_user_o[i] = tmp_write_user[i][2*AxiUserWidth-1:AxiUserWidth];
    assign req_aw_user_o[i] = tmp_write_user[i][AxiUserWidth-1:0];
    assign rsp_read_rid_o   [i] = rsp_ruser[         i][ObiCfg.IdWidth-1:0];
    assign rsp_read_ruser_o [i] = rsp_ruser[         i][IdRuserWidth-1:ObiCfg.IdWidth];
    assign rsp_write_rid_o  [i] = rsp_ruser[NumBanks+i][ObiCfg.IdWidth-1:0];
    assign rsp_write_ruser_o[i] = rsp_ruser[NumBanks+i][IdRuserWidth-1:ObiCfg.IdWidth];
  end

  if (ObiCfg.OptionalCfg.UseAtop) begin : gen_atop
    for (genvar i = 0; i < 2*NumBanks; i++) begin : gen_atop_banks
      always_comb begin : proc_atop_translate
        obi_atop[i] = obi_pkg::ATOPNONE;
        if (bank_mem_lock[i]) begin
          obi_atop[i] = bank_mem_we[i] ? obi_pkg::ATOPSC : obi_pkg::ATOPLR;
        end else if (bank_mem_atop[i] == axi_pkg::ATOP_ATOMICSWAP) begin
          obi_atop[i] = obi_pkg::AMOSWAP;
        end else if (bank_mem_atop[i] != '0) begin
          case (bank_mem_atop[i][2:0])
            axi_pkg::ATOP_ADD: obi_atop[i] = obi_pkg::AMOADD;
            axi_pkg::ATOP_EOR: obi_atop[i] = obi_pkg::AMOXOR;
            axi_pkg::ATOP_CLR: obi_atop[i] = obi_pkg::AMOAND;
            axi_pkg::ATOP_SET: obi_atop[i] = obi_pkg::AMOOR;
            axi_pkg::ATOP_SMIN: obi_atop[i] = obi_pkg::AMOMIN;
            axi_pkg::ATOP_SMAX: obi_atop[i] = obi_pkg::AMOMAX;
            axi_pkg::ATOP_UMIN: obi_atop[i] = obi_pkg::AMOMINU;
            axi_pkg::ATOP_UMAX: obi_atop[i] = obi_pkg::AMOMAXU;
            default: ;
          endcase
        end
      end
    end
  end else begin : gen_tie_atop
    assign obi_atop = '0;
  end

  for (genvar i = 0; i < 2*NumBanks; i++) begin : gen_obi_bank_assign
    assign obi_reqs[i].req     = bank_mem_req[i];
    assign bank_mem_gnt[i]     = obi_rsps[i].gnt;
    assign obi_reqs[i].a.addr  = bank_mem_addr[i];
    if (ObiCfg.OptionalCfg.UseAtop) begin : gen_obi_bank_assign_atop
      assign obi_reqs[i].a.a_optional.atop = obi_atop[i];
      assign obi_reqs[i].a.wdata = (obi_atop[i] == obi_pkg::AMOAND) ?
                                   ~bank_mem_wdata[i] : bank_mem_wdata[i];
      assign bank_mem_exokay[i] = obi_rsps[i].r.r_optional.exokay;
    end else begin : gen_obi_bank_tie_atop
      assign obi_reqs[i].a.wdata = bank_mem_wdata[i];
      assign bank_mem_exokay[i] = '0;
    end
    assign obi_reqs[i].a.be    = bank_mem_strb[i];
    assign obi_reqs[i].a.we    = bank_mem_we[i];
    assign bank_mem_rvalid[i]  = obi_rsps[i].rvalid;
    assign bank_mem_rdata[i]   = obi_rsps[i].r.rdata;
    assign bank_mem_err[i]     = obi_rsps[i].r.err;
    assign bank_mem_ruser[i][ObiCfg.IdWidth-1:0] = obi_rsps[i].r.rid;
    if (ObiCfg.OptionalCfg.RUserWidth) begin : gen_ruser
      assign bank_mem_ruser[i][IdRuserWidth-1:ObiCfg.IdWidth] = obi_rsps[i].r.r_optional.ruser;
    end
    if (ObiCfg.OptionalCfg.UseProt) begin : gen_obi_bank_assign_prot
      assign obi_reqs[i].a.a_optional.prot[0] = ~bank_mem_prot[i][2];
      assign obi_reqs[i].a.a_optional.prot[1] = ~bank_mem_prot[i][0];
      assign obi_reqs[i].a.a_optional.prot[2] = ~bank_mem_prot[i][0];
    end
    if (ObiCfg.OptionalCfg.UseMemtype) begin : gen_obi_bank_assign_memtype
      assign obi_reqs[i].a.a_optional.memtype[0] = bank_mem_cache[i][0];
      assign obi_reqs[i].a.a_optional.memtype[1] = ~bank_mem_cache[i][1];
    end
    assign obi_reqs[i].a.aid = bank_mem_id[i];
    if (i < NumBanks) begin : gen_bank_auser
      if (ObiCfg.OptionalCfg.AUserWidth) begin : gen_auser
        assign obi_reqs[i].a.a_optional.auser = req_read_auser_i;
      end
    end else begin : gen_bank_awuser
      if (ObiCfg.OptionalCfg.AUserWidth) begin : gen_auser
        assign obi_reqs[i].a.a_optional.auser = req_write_auser_i;
      end
      if (ObiCfg.OptionalCfg.WUserWidth) begin : gen_wuser
        assign obi_reqs[i].a.a_optional.wuser = req_write_wuser_i;
      end
    end
  end

  obi_mux #(
    .MgrPortObiCfg      ( ObiCfg       ),
    .SbrPortObiCfg      ( ObiCfg       ),
    .sbr_port_obi_req_t ( obi_req_t    ),
    .sbr_port_obi_rsp_t ( obi_rsp_t    ),
    .sbr_port_a_chan_t  ( obi_a_chan_t ),
    .sbr_port_r_chan_t  ( obi_r_chan_t ),
    .mgr_port_obi_req_t ( obi_req_t    ),
    .mgr_port_obi_rsp_t ( obi_rsp_t    ),
    .NumSbrPorts        ( 2*NumBanks   ),
    .NumMaxTrans        ( MaxTrans     ),
    .UseIdForRouting    ( 1'b0         )
  ) i_mux_banks (
    .clk_i,
    .rst_ni,
    .testmode_i,
    .sbr_ports_req_i( obi_reqs  ),
    .sbr_ports_rsp_o( obi_rsps  ),
    .mgr_port_req_o ( obi_req_o ),
    .mgr_port_rsp_i ( obi_rsp_i )
  );

endmodule
