// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "axi/typedef.svh"

/// Version 2 of a protocol converter from AXI4 to the register interface.
/// AXI Data Width >= Reg Data Width
module axi_to_reg_v2 #(
  /// The width of the address.
  parameter int unsigned AxiAddrWidth = 32'd0,
  /// The width of the data.
  parameter int unsigned AxiDataWidth = 32'd0,
  /// The width of the id.
  parameter int unsigned AxiIdWidth   = 32'd0,
  /// The width of the user signal.
  parameter int unsigned AxiUserWidth = 32'd0,
  /// The data width of the Reg bus
  parameter int unsigned RegDataWidth = 32'd0,
  /// Whether to cut paths just before conversion to reg protocol.
  /// This incurs O(AxiDataWidth/RegDataWidth) spill regs, but can
  /// significantly improve (usually uncut as in-cycle) reg timing.
  parameter bit          CutMemReqs   = 1'b0,
  parameter bit          CutMemRsps   = 1'b0,
  /// AXI request struct type.
  parameter type         axi_req_t    = logic,
  /// AXI response struct type.
  parameter type         axi_rsp_t    = logic,
  /// Regbus request struct type.
  parameter type         reg_req_t    = logic,
  /// Regbus response struct type.
  parameter type         reg_rsp_t    = logic,
  /// Dependent parameter: ID Width
  parameter type         id_t         = logic[AxiIdWidth-1:0]
)(
  input  logic      clk_i,
  input  logic      rst_ni,
  input  axi_req_t  axi_req_i,
  output axi_rsp_t  axi_rsp_o,
  output reg_req_t  reg_req_o,
  input  reg_rsp_t  reg_rsp_i,
  output id_t       reg_id_o,
  output logic      busy_o
);

  // how many times is the AXI bus wider than the regbus?
  localparam int unsigned NumBanks = AxiDataWidth / RegDataWidth;

  localparam type addr_t     = logic [AxiAddrWidth-1  :0];
  localparam type reg_data_t = logic [RegDataWidth-1  :0];
  localparam type reg_strb_t = logic [RegDataWidth/8-1:0];

  // TCDM BUS
  logic      [NumBanks-1:0] mem_qvalid;
  logic      [NumBanks-1:0] mem_qready;
  addr_t     [NumBanks-1:0] mem_addr;
  reg_data_t [NumBanks-1:0] mem_wdata;
  reg_strb_t [NumBanks-1:0] mem_strb;
  logic      [NumBanks-1:0] mem_we;
  id_t       [NumBanks-1:0] mem_id;
  logic      [NumBanks-1:0] mem_pvalid;
  reg_data_t [NumBanks-1:0] mem_rdata;
  logic      [NumBanks-1:0] mem_err;

  // sub reg buses
  reg_req_t [NumBanks-1:0] reg_req, valid_req, zero_w_req;
  reg_rsp_t [NumBanks-1:0] reg_rsp, valid_rsp, zero_w_rsp;

  // convert to TCDM first
  axi_to_detailed_mem #(
    .axi_req_t    ( axi_req_t     ),
    .axi_resp_t   ( axi_rsp_t     ),
    .AddrWidth    ( AxiAddrWidth  ),
    .DataWidth    ( AxiDataWidth  ),
    .IdWidth      ( AxiIdWidth    ),
    .UserWidth    ( AxiUserWidth  ),
    .NumBanks     ( NumBanks      ),
    .BufDepth     ( 32'd1         ),
    .HideStrb     ( 1'b0          ),
    .OutFifoDepth ( 32'd1         )
  ) i_axi_to_detailed_mem (
    .clk_i,
    .rst_ni,
    .busy_o,
    .axi_req_i,
    .axi_resp_o   ( axi_rsp_o           ),
    .mem_req_o    ( mem_qvalid          ),
    .mem_gnt_i    ( mem_qready          ),
    .mem_addr_o   ( mem_addr            ),
    .mem_wdata_o  ( mem_wdata           ),
    .mem_strb_o   ( mem_strb            ),
    .mem_atop_o   ( /* NOT CONNECTED */ ),
    .mem_lock_o   ( /* NOT CONNECTED */ ),
    .mem_we_o     ( mem_we              ),
    .mem_id_o     ( mem_id              ),
    .mem_user_o   ( /* NOT CONNECTED */ ),
    .mem_cache_o  ( /* NOT CONNECTED */ ),
    .mem_prot_o   ( /* NOT CONNECTED */ ),
    .mem_qos_o    ( /* NOT CONNECTED */ ),
    .mem_region_o ( /* NOT CONNECTED */ ),
    .mem_rvalid_i ( mem_pvalid          ),
    .mem_rdata_i  ( mem_rdata           ),
    .mem_err_i    ( mem_err             ),
    .mem_exokay_i ( '0                  )
  );

  // Some tools don't like typedefs inside generate blocks
  typedef struct packed {
    addr_t     addr;
    reg_data_t wdata;
    reg_strb_t strb;
    logic      we;
    id_t       id;
  } mem_req_t;

  typedef struct packed {
    reg_data_t rdata;
    logic      err;
  } mem_rsp_t;

  // every subbus is converted independently
  for (genvar i = 0; i < NumBanks; i++) begin : gen_tcdm_to_reg
    mem_req_t mem_req, mem_cut_req;
    mem_rsp_t mem_rsp, mem_cut_rsp;

    logic mem_cut_req_valid, mem_cut_req_ready;
    logic mem_cut_rsp_valid;

    // Assign request fields to struct
    assign mem_req.addr  = mem_addr  [i];
    assign mem_req.wdata = mem_wdata [i];
    assign mem_req.strb  = mem_strb  [i];
    assign mem_req.we    = mem_we    [i];
    assign mem_req.id    = mem_id    [i];

    // Assign response struct to fields
    assign mem_rdata [i] = mem_rsp.rdata;
    assign mem_err   [i] = mem_rsp.err;

    // Cut mem requests if enabled
    spill_register #(
      .T (mem_req_t),
      .Bypass (~CutMemReqs)
    ) i_mem_req_spill (
      .clk_i,
      .rst_ni,
      .valid_i ( mem_qvalid[i] ),
      .ready_o ( mem_qready[i] ),
      .data_i  ( mem_req ),
      .valid_o ( mem_cut_req_valid ),
      .ready_i ( mem_cut_req_ready ),
      .data_o  ( mem_cut_req )
    );

    // Cut mem responses if enabled
    spill_register #(
      .T (mem_rsp_t),
      .Bypass (~CutMemRsps)
    ) i_mem_rsp_spill (
      .clk_i,
      .rst_ni,
      .valid_i ( mem_cut_rsp_valid ),
      .ready_o ( ),
      .data_i  ( mem_cut_rsp ),
      .valid_o ( mem_pvalid[i] ),
      .ready_i ( 1'b1 ),
      .data_o  ( mem_rsp )
    );

    // forward the id, all banks carry the same ID here
    if (i == 0) begin : gen_id_fw
      assign reg_id_o = mem_cut_req.id;
    end

    periph_to_reg #(
      .AW    ( AxiAddrWidth ),
      .DW    ( RegDataWidth ),
      .IW    ( AxiIdWidth   ),
      .req_t ( reg_req_t    ),
      .rsp_t ( reg_rsp_t    )
    ) i_periph_to_reg (
      .clk_i,
      .rst_ni,
      .req_i     ( mem_cut_req_valid ),
      .add_i     ( mem_cut_req.addr  ),
      .wen_i     ( ~mem_cut_req.we   ),
      .wdata_i   ( mem_cut_req.wdata ),
      .be_i      ( mem_cut_req.strb  ),
      .id_i      ( '0 ),
      .gnt_o     ( mem_cut_req_ready ),
      .r_rdata_o ( mem_cut_rsp.rdata ),
      .r_opc_o   ( mem_cut_rsp.err   ),
      .r_id_o    ( ),
      .r_valid_o ( mem_cut_rsp_valid ),
      .reg_req_o ( reg_req[i] ),
      .reg_rsp_i ( reg_rsp[i] )
    );

    // filter zero strobe writes early, directly ack them
    reg_demux #(
      .NoPorts ( 32'd2     ),
      .req_t   ( reg_req_t ),
      .rsp_t   ( reg_rsp_t )
    ) i_reg_demux (
      .clk_i,
      .rst_ni,
      .in_select_i ( reg_req[i].write & (reg_req[i].wstrb == '0) ),
      .in_req_i    ( reg_req[i]                                  ),
      .in_rsp_o    ( reg_rsp[i]                                  ),
      .out_req_o   ( {zero_w_req[i], valid_req[i]}               ),
      .out_rsp_i   ( {zero_w_rsp[i], valid_rsp[i]}               )
    );

    // ack zero strobe writes here
    assign zero_w_rsp[i].ready = 1'b1;
    assign zero_w_rsp[i].error = 1'b0;
    assign zero_w_rsp[i].rdata = '0;
  end

  // arbitrate over valid accesses in sub buses
  reg_mux #(
    .NoPorts( NumBanks     ),
    .AW     ( AxiAddrWidth ),
    .DW     ( RegDataWidth ),
    .req_t  ( reg_req_t    ),
    .rsp_t  ( reg_rsp_t    )
  ) i_reg_mux (
    .clk_i,
    .rst_ni,
    .in_req_i  ( valid_req ),
    .in_rsp_o  ( valid_rsp ),
    .out_req_o ( reg_req_o ),
    .out_rsp_i ( reg_rsp_i )
  );

endmodule
