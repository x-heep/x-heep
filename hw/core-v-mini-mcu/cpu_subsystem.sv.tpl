// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
  cpu = xheep.cpu()
  xif = xheep.xif()
%>

module cpu_subsystem
  import core_v_mini_mcu_pkg::*;
#(
    parameter BOOT_ADDR = 'h180,
    parameter DM_HALTADDRESS = '0,
% if xheep.reliability:
    parameter type rel_obi_req_t = logic,
    parameter type rel_obi_rsp_t = logic,
    parameter xheep_obi_pkg::obi_cfg_t ObiCfg = xheep_obi_pkg::xheep_obiCfg,
% endif
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    // Core ID
    input logic [31:0] hart_id_i,

    // Instruction memory interface
% if xheep.reliability:
    output rel_obi_req_t  core_instr_req_o,
    input  rel_obi_rsp_t  core_instr_resp_i,

    // Data memory interface
    output rel_obi_req_t  core_data_req_o,
    input  rel_obi_rsp_t  core_data_resp_i,
% else:
    output obi_req_t  core_instr_req_o,
    input  obi_rsp_t  core_instr_resp_i,

    // Data memory interface
    output obi_req_t  core_data_req_o,
    input  obi_rsp_t  core_data_resp_i,
% endif

    // eXtension interface
    if_xif.cpu_compressed xif_compressed_if,
    if_xif.cpu_issue      xif_issue_if,
    if_xif.cpu_commit     xif_commit_if,
    if_xif.cpu_mem        xif_mem_if,
    if_xif.cpu_mem_result xif_mem_result_if,
    if_xif.cpu_result     xif_result_if,

    // Interrupt inputs
    input  logic [31:0] irq_i,      // CLINT interrupts + CLINT extension interrupts
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,

    // Debug Interface
    input logic debug_req_i,

    // sleep
    output logic core_sleep_o
);


  // CPU Control Signals
  logic fetch_enable;

  assign fetch_enable = 1'b1;

  // assign core_instr_req_o.a.wdata = '0;
  // assign core_instr_req_o.a.we    = '0;
  // assign core_instr_req_o.a.be    = 4'b1111;
  // assign instr_req.a.a_optional = '0;
  // assign data_req.a.a_optional  = '0;
  

  // logic core_instr_req, core_data_req;
  // assign core_instr_req_o.req        = core_instr_req;
  // assign core_instr_req_o.reqpar     = ~core_instr_req;
  // assign core_instr_req_o.rready     = 1'b1;
  // assign core_instr_req_o.rreadypar  = 1'b0;
  // assign core_data_req_o.req          = core_data_req;
  // assign core_data_req_o.reqpar       = ~core_data_req;
  // assign core_data_req_o.rready       = 1'b1;
  // assign core_data_req_o.rreadypar    = 1'b0;

% if cpu.name == "cv32e20":

<%
cv32e20_params = []

if cpu.is_defined("rv32e"):
    cv32e20_params.append(f".RV32E({cpu.get_sv_str('rv32e')})")

if cpu.is_defined("rv32m"):
    cv32e20_params.append(f".RV32M(cve2_pkg::{cpu.get_sv_str('rv32m')})")

if xif != None:
    cv32e20_params.append(f".X_INTERFACE(1'b1)")
    cv32e20_params.append(f".X_INTERFACE_NUM_RS({xif.x_num_rs})")

if cpu.is_defined("num_mhpmcounters"):
    cv32e20_params.append(f".MHPMCounterNum({cpu.get_sv_str('num_mhpmcounters')})")
%>

    cve2_xif_wrapper #(
${",\n".join(cv32e20_params)}
    ) cv32e20_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .test_en_i(1'b0),

        .hart_id_i,
        .boot_addr_i(BOOT_ADDR),
        .dm_exception_addr_i(32'h0),
        .dm_halt_addr_i(DM_HALTADDRESS),

        .instr_addr_o  (core_instr_req_o.a.addr),
        .instr_req_o   (core_instr_req_o.req),
        .instr_rdata_i (core_instr_resp_i.r.rdata),
        .instr_gnt_i   (core_instr_resp_i.gnt),
        .instr_rvalid_i(core_instr_resp_i.rvalid),

        .data_addr_o  (core_data_req_o.a.addr),
        .data_wdata_o (core_data_req_o.a.wdata),
        .data_we_o    (core_data_req_o.a.we),
        .data_req_o   (core_data_req_o.req),
        .data_be_o    (core_data_req_o.a.be),
        .data_rdata_i (core_data_resp_i.r.rdata),
        .data_gnt_i   (core_data_resp_i.gnt),
        .data_rvalid_i(core_data_resp_i.rvalid),

        .irq_software_i(irq_i[3]),
        .irq_timer_i   (irq_i[7]),
        .irq_external_i(irq_i[11]),
        .irq_fast_i    (irq_i[31:16]),

        .debug_req_i(debug_req_i),
        .debug_halted_o(),

        // CORE-V-XIF
        .xif_compressed_if,
        .xif_issue_if,
        .xif_commit_if,
        .xif_mem_if,
        .xif_mem_result_if,
        .xif_result_if,

        .fetch_enable_i(fetch_enable),
        .core_sleep_o
    );

    assign irq_ack_o = '0;
    assign irq_id_o  = '0;

% elif cpu.name == "cv32e40x":

<%
cv32e40x_params = []

if xif != None:
    cv32e40x_params.append(f".X_INTERFACE(1'b1)")
    cv32e40x_params.append(f".X_NUM_RS({xif.x_num_rs})")
    cv32e40x_params.append(f".X_ID_WIDTH({xif.x_id_width})")
    cv32e40x_params.append(f".X_MEM_WIDTH({xif.x_mem_width})")
    cv32e40x_params.append(f".X_RFR_WIDTH({xif.x_rfr_width})")
    cv32e40x_params.append(f".X_RFW_WIDTH({xif.x_rfw_width})")
    cv32e40x_params.append(f".X_MISA({xif.x_misa})")
    cv32e40x_params.append(f".X_ECS_XS({xif.x_ecs_xs})")

if cpu.is_defined("num_mhpmcounters"):
    cv32e40x_params.append(f".NUM_MHPMCOUNTERS({cpu.get_sv_str('num_mhpmcounters')})")

cv32e40x_params.append(f".DBG_NUM_TRIGGERS(0)")
%>

    cv32e40x_core #(
${",\n".join(cv32e40x_params)}
    ) cv32e40x_core_i (
        // Clock and reset
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .scan_cg_en_i(1'b0),

        // Static configuration
        .boot_addr_i(BOOT_ADDR),
        .dm_exception_addr_i(32'h0),
        .dm_halt_addr_i(DM_HALTADDRESS),
        .mhartid_i(32'h0),
        .mimpid_patch_i(4'h0),
        .mtvec_addr_i(32'h0),

        // Instruction memory interface
        .instr_req_o    (core_instr_req),
        .instr_gnt_i    (core_instr_resp_i.gnt),
        .instr_rvalid_i (core_instr_resp_i.rvalid),
        .instr_addr_o   (core_instr_req_o.a.addr),
        .instr_memtype_o(),
        .instr_prot_o   (),
        .instr_dbg_o    (),
        .instr_rdata_i  (core_instr_resp_i.r.rdata),
        .instr_err_i    (1'b0),

        // Data memory interface
        .data_req_o    (core_data_req),
        .data_gnt_i    (core_data_resp_i.gnt),
        .data_rvalid_i (core_data_resp_i.rvalid),
        .data_addr_o   (core_data_req_o.a.addr),
        .data_be_o     (core_data_req_o.a.be),
        .data_we_o     (core_data_req_o.a.we),
        .data_wdata_o  (core_data_req_o.a.wdata),
        .data_memtype_o(),
        .data_prot_o   (),
        .data_dbg_o    (),
        .data_atop_o   (),
        .data_rdata_i  (core_data_resp_i.r.rdata),
        .data_err_i    (1'b0),
        .data_exokay_i (1'b1),

        // Cycle count
        .mcycle_o(),

        // Time input
        .time_i(64'h0),

        // eXtension interface
        .xif_compressed_if,
        .xif_issue_if,
        .xif_commit_if,
        .xif_mem_if,
        .xif_mem_result_if,
        .xif_result_if,

        // Basic interrupt architecture
        .irq_i(irq_i),

        // Event wakeup signal
        .wu_wfe_i(1'b0),

        // Smclic interrupt architecture
        .clic_irq_i      (),
        .clic_irq_id_i   (),
        .clic_irq_level_i(),
        .clic_irq_priv_i (),
        .clic_irq_shv_i  (),

        // Fence.i flush handshake
        .fencei_flush_req_o(),
        .fencei_flush_ack_i(1'b1),

        // Debug interface
        .debug_req_i      (debug_req_i),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (),
        .debug_pc_valid_o (),
        .debug_pc_o       (),

        // CPU control signals
        .fetch_enable_i(fetch_enable),
        .core_sleep_o
    );

    assign irq_ack_o = '0;
    assign irq_id_o  = '0;

% elif cpu.name == "cv32e40px":

    import cv32e40px_core_v_xif_pkg::*;

    logic            instr_req;
    logic            instr_gnt;
    logic            instr_rvalid;
    logic     [31:0] instr_addr;
    logic     [31:0] instr_rdata;
    logic            data_req;
    logic            data_gnt;
    logic            data_rvalid;
    logic            data_we;
    logic     [ 3:0] data_be;
    logic     [31:0] data_addr;
    logic     [31:0] data_wdata;
    logic     [31:0] data_rdata;

% if xheep.reliability:

    logic            instr_err;
    logic            data_err;
    obi_req_t        instr_req_struct;
    obi_rsp_t        instr_rsp_struct;
    obi_req_t        data_req_struct;
    obi_rsp_t        data_rsp_struct;
    
    assign instr_req_struct.req          = instr_req;
    assign instr_req_struct.reqpar       = ~instr_req;
    assign instr_req_struct.rready       = 1'b1;
    assign instr_req_struct.rreadypar    = 1'b0;
    assign instr_req_struct.a.addr       = instr_addr;
    assign instr_req_struct.a.wdata      = '0;
    assign instr_req_struct.a.we         = '0;
    assign instr_req_struct.a.be         = '0;
    assign instr_req_struct.a.aid        = '0;
    assign instr_req_struct.a.a_optional = '0;
    
    assign data_req_struct.req          = data_req;
    assign data_req_struct.reqpar       = ~data_req;
    assign data_req_struct.rready       = 1'b1;
    assign data_req_struct.rreadypar    = 1'b0;
    assign data_req_struct.a.addr       = data_addr;
    assign data_req_struct.a.wdata      = data_wdata;
    assign data_req_struct.a.we         = data_we;
    assign data_req_struct.a.be         = data_be;
    assign data_req_struct.a.aid        = '0;
    assign data_req_struct.a.a_optional = '0;
    
    assign instr_gnt    = instr_rsp_struct.gnt;
    assign instr_rvalid = instr_rsp_struct.rvalid;
    assign instr_rdata  = instr_rsp_struct.r.rdata;
    assign instr_err    = instr_rsp_struct.r.err;
    assign data_gnt     = data_rsp_struct.gnt;
    assign data_rvalid  = data_rsp_struct.rvalid;
    assign data_rdata   = data_rsp_struct.r.rdata;
    assign data_err     = data_rsp_struct.r.err;
    
    relobi_encoder #(
        .Cfg(ObiCfg),
        .relobi_req_t(rel_obi_req_t),
        .relobi_rsp_t(rel_obi_rsp_t),
        .obi_req_t(obi_req_t),
        .obi_rsp_t(obi_rsp_t),
        .a_optional_t(logic),
        .r_optional_t(logic)
    ) i_instr_encoder (
        .req_i(instr_req_struct),
        .rsp_o(instr_rsp_struct),
        .rel_req_o(core_instr_req_o),
        .rel_rsp_i(core_instr_resp_i),
        .fault_o()
    );
    
    relobi_encoder #(
        .Cfg(ObiCfg),
        .relobi_req_t(rel_obi_req_t),
        .relobi_rsp_t(rel_obi_rsp_t),
        .obi_req_t(obi_req_t),
        .obi_rsp_t(obi_rsp_t),
        .a_optional_t(logic),
        .r_optional_t(logic)
    ) i_data_encoder (
        .req_i(data_req_struct),
        .rsp_o(data_rsp_struct),
        .rel_req_o(core_data_req_o),
        .rel_rsp_i(core_data_resp_i),
        .fault_o()
    );
% else:
    assign core_instr_req_o.a.addr = instr_addr;
    assign core_instr_req_o.req    = instr_req;
    assign instr_rdata             = core_instr_resp_i.r.rdata;
    assign instr_gnt               = core_instr_resp_i.gnt;
    assign instr_rvalid            = core_instr_resp_i.rvalid;

    assign core_data_req_o.a.addr  = data_addr;
    assign core_data_req_o.a.wdata = data_wdata;
    assign core_data_req_o.a.we    = data_we;
    assign core_data_req_o.req     = data_req;
    assign core_data_req_o.a.be    = data_be;
    assign data_rdata              = core_data_resp_i.r.rdata;
    assign data_gnt                = core_data_resp_i.gnt;
    assign data_rvalid             = core_data_resp_i.rvalid;
% endif


    
<%
cv32e40px_params = []

if cpu.is_defined("fpu"):
    cv32e40px_params.append(f".FPU({cpu.get_sv_str('fpu')})")

if cpu.is_defined("fpu_addmul_lat"):
    cv32e40px_params.append(f".FPU_ADDMUL_LAT({cpu.get_sv_str('fpu_addmul_lat')})")

if cpu.is_defined("fpu_others_lat"):
    cv32e40px_params.append(f".FPU_OTHERS_LAT({cpu.get_sv_str('fpu_others_lat')})")

if cpu.is_defined("zfinx"):
    cv32e40px_params.append(f".ZFINX({cpu.get_sv_str('zfinx')})")

if cpu.is_defined("corev_pulp"):
    cv32e40px_params.append(f".COREV_PULP({cpu.get_sv_str('corev_pulp')})")

if cpu.is_defined("num_mhpmcounters"):
    cv32e40px_params.append(f".NUM_MHPMCOUNTERS({cpu.get_sv_str('num_mhpmcounters')})")

if xif != None:
    cv32e40px_params.append(f".X_INTERFACE(1'b1)")
    cv32e40px_params.append(f".X_INTERFACE_NUM_RS({xif.x_num_rs})")
%>

    cv32e40px_xif_wrapper #(
${",\n".join(cv32e40px_params)}
    ) cv32e40px_xif_wrapper_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i,
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (instr_addr),
        .instr_req_o   (instr_req),
        .instr_rdata_i (instr_rdata),
        .instr_gnt_i   (instr_gnt),
        .instr_rvalid_i(instr_rvalid),

        .data_addr_o  (data_addr),
        .data_wdata_o (data_wdata),
        .data_we_o    (data_we),
        .data_req_o   (data_req),
        .data_be_o    (data_be),
        .data_rdata_i (data_rdata),
        .data_gnt_i   (data_gnt),
        .data_rvalid_i(data_rvalid),

        // CORE-V-XIF
        .xif_compressed_if,
        .xif_issue_if,
        .xif_commit_if,
        .xif_mem_if,
        .xif_mem_result_if,
        .xif_result_if,

        .irq_i    (irq_i),
        .irq_ack_o(irq_ack_o),
        .irq_id_o (irq_id_o),

        .debug_req_i      (debug_req_i),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o

    );

% else:

<%
cv32e40p_params = []

if cpu.is_defined("fpu"):
    cv32e40p_params.append(f".FPU({cpu.get_sv_str('fpu')})")

if cpu.is_defined("fpu_addmul_lat"):
    cv32e40p_params.append(f".FPU_ADDMUL_LAT({cpu.get_sv_str('fpu_addmul_lat')})")

if cpu.is_defined("fpu_others_lat"):
    cv32e40p_params.append(f".FPU_OTHERS_LAT({cpu.get_sv_str('fpu_others_lat')})")

if cpu.is_defined("zfinx"):
    cv32e40p_params.append(f".ZFINX({cpu.get_sv_str('zfinx')})")

if cpu.is_defined("corev_pulp"):
    cv32e40p_params.append(f".COREV_PULP({cpu.get_sv_str('corev_pulp')})")

if cpu.is_defined("num_mhpmcounters"):
    cv32e40p_params.append(f".NUM_MHPMCOUNTERS({cpu.get_sv_str('num_mhpmcounters')})")
%>

    cv32e40p_top #(
${",\n".join(cv32e40p_params)}
    ) cv32e40p_top_i (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .pulp_clock_en_i(1'b1),
        .scan_cg_en_i   (1'b0),

        .boot_addr_i        (BOOT_ADDR),
        .mtvec_addr_i       (32'h0),
        .dm_halt_addr_i     (DM_HALTADDRESS),
        .hart_id_i,
        .dm_exception_addr_i(32'h0),

        .instr_addr_o  (core_instr_req_o.a.addr),
        .instr_req_o   (core_instr_req_o.req),
        .instr_rdata_i (core_instr_resp_i.r.rdata),
        .instr_gnt_i   (core_instr_resp_i.gnt),
        .instr_rvalid_i(core_instr_resp_i.rvalid),

        .data_addr_o  (core_data_req_o.a.addr),
        .data_wdata_o (core_data_req_o.a.wdata),
        .data_we_o    (core_data_req_o.a.we),
        .data_req_o   (core_data_req_o.req),
        .data_be_o    (core_data_req_o.a.be),
        .data_rdata_i (core_data_resp_i.r.rdata),
        .data_gnt_i   (core_data_resp_i.gnt),
        .data_rvalid_i(core_data_resp_i.rvalid),

        .irq_i    (irq_i),
        .irq_ack_o(irq_ack_o),
        .irq_id_o (irq_id_o),

        .debug_req_i      (debug_req_i),
        .debug_havereset_o(),
        .debug_running_o  (),
        .debug_halted_o   (),

        .fetch_enable_i(fetch_enable),
        .core_sleep_o
    );

% endif

% if not xheep.reliability:
  // Drive OBI request-side control and integrity parity bits. The cores only
  // provide req/rready; parity mirrors the reliable path (reqpar = ~req).
  assign core_instr_req_o.rready    = 1'b1;
  assign core_instr_req_o.reqpar    = ~core_instr_req_o.req;
  assign core_instr_req_o.rreadypar = ~core_instr_req_o.rready;
  assign core_data_req_o.rready     = 1'b1;
  assign core_data_req_o.reqpar     = ~core_data_req_o.req;
  assign core_data_req_o.rreadypar  = ~core_data_req_o.rready;
% endif

endmodule
