// Copyright 2022 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Hybrid modular redundancy wrapping unit

module HMR_wrap
  import rapid_recovery_pkg::*;
#(
  // Wrapper parameters
  /// Number of physical cores
  parameter  int unsigned NumCores       = 0,
  /// Enables support for Dual Modular Redundancy
  parameter  bit          DMRSupported   = 1'b1,
  /// Locks HMR into permanent DMR mode
  parameter  bit          DMRFixed       = 1'b0,
  /// Enables support for Triple Modular Redundancy
  parameter  bit          TMRSupported   = 1'b1,
  /// Locks HMR into permanent TMR mode
  parameter  bit          TMRFixed       = 1'b0,
  /// Enables rapid recovery with a backup register file, PC, ...
  parameter  bit          RapidRecovery  = 1'b0,
  /// Separates voters and checkers for data, which are then only checked if data request is valid
  parameter  bit          SeparateData   = 1'b1,
  /// Interleave DMR/TMR cores, alternatively with sequential grouping
  parameter  bit          InterleaveGrps = 1'b1,
  parameter  int unsigned InstrDataWidth = 32,
  parameter  int unsigned DataWidth      = 32,
  parameter  int unsigned BeWidth        = 4,
  parameter  int unsigned UserWidth      = 0,
  parameter  int unsigned NumExtPerf     = 5,
  parameter  type         reg_req_t      = logic,
  parameter  type         reg_resp_t     = logic,
  // Local parameters depending on the above ones
  /// Number of TMR groups (virtual TMR cores)
  localparam int unsigned NumTMRGroups   = NumCores/3,
  /// Number of physical cores used for TMR
  localparam int unsigned NumTMRCores    = NumTMRGroups * 3,
  /// Number of physical cores NOT used for TMR
  localparam int unsigned NumTMRLeftover = NumCores - NumTMRCores,
  /// Number of DMR groups (virtual DMR cores)
  localparam int unsigned NumDMRGroups   = NumCores/2,
  /// Nubmer of physical cores used for DMR
  localparam int unsigned NumDMRCores    = NumDMRGroups * 2,
  /// Number of physical cores NOT used for DMR
  localparam int unsigned NumDMRLeftover = NumCores - NumDMRCores,
  /// Number of cores visible to the system (Fixed mode removes unneeded system ports)
  localparam int unsigned NumSysCores    = DMRFixed ? NumDMRCores :
                                           TMRFixed ? NumTMRCores : NumCores
) (
  input  logic      clk_i ,
  input  logic      rst_ni,

  // Port to configuration unit
  input  reg_req_t  reg_request_i ,
  output reg_resp_t reg_response_o,

  // TMR signals
  output logic [NumTMRGroups-1:0] tmr_failure_o    ,
  output logic [ NumSysCores-1:0] tmr_error_o      , // Should this not be NumTMRCores? or NumCores?
  output logic [NumTMRGroups-1:0] tmr_resynch_req_o,
  output logic [    NumCores-1:0] tmr_sw_synch_req_o,
  input  logic [NumTMRGroups-1:0] tmr_cores_synch_i,

  // DMR signals
  output logic [NumDMRGroups-1:0] dmr_failure_o    ,
  output logic [ NumSysCores-1:0] dmr_error_o      , // Should this not be NumDMRCores? or NumCores?
  output logic [NumDMRGroups-1:0] dmr_resynch_req_o,
  output logic [    NumCores-1:0] dmr_sw_synch_req_o,
  input  logic [NumDMRGroups-1:0] dmr_cores_synch_i,

  // Backup Port from Cores' CSRs
  input  csrs_intf_t [NumCores-1:0] backup_csr_i,
  // Recovery Port to Cores' CSRs
  output csrs_intf_t [NumCores-1:0] recovery_csr_o,
  // Backup Port from Cores'Program Counter
  input  logic [   NumCores-1:0][DataWidth-1:0] backup_program_counter_i,
  output logic [   NumCores-1:0]                pc_recover_o,
  output logic [   NumCores-1:0][DataWidth-1:0] recovery_program_counter_o,
  input  logic [   NumCores-1:0]                backup_branch_i,
  input  logic [   NumCores-1:0][DataWidth-1:0] backup_branch_addr_i,
  output logic [   NumCores-1:0]                recovery_branch_o,
  output logic [   NumCores-1:0][DataWidth-1:0] recovery_branch_addr_o,
  // Backup ports from Cores' RFs
  input  regfile_write_t [NumCores-1:0]         backup_regfile_wport_i,
  output regfile_write_t [NumCores-1:0]         core_recovery_regfile_wport_o,
  // Nonstandard core control signals
  output logic [   NumCores-1:0]                     core_setback_o      ,
  output logic [   NumCores-1:0]                     core_instr_lock_o   ,
  output logic [   NumCores-1:0]                     core_recover_o      ,
  output logic [   NumCores-1:0]                     core_debug_resume_o ,

  // Ports connecting to System
  input  logic [NumSysCores-1:0][           3:0]     sys_core_id_i      ,
  input  logic [NumSysCores-1:0][           5:0]     sys_cluster_id_i   ,

  input  logic [NumSysCores-1:0]                     sys_clock_en_i     ,
  input  logic [NumSysCores-1:0]                     sys_fetch_en_i     ,
  input  logic [NumSysCores-1:0][          31:0]     sys_boot_addr_i    ,
  output logic [NumSysCores-1:0]                     sys_core_busy_o    ,

  input  logic [NumSysCores-1:0]                     sys_irq_req_i      ,
  output logic [NumSysCores-1:0]                     sys_irq_ack_o      ,
  input  logic [NumSysCores-1:0][           4:0]     sys_irq_id_i       ,
  output logic [NumSysCores-1:0][           4:0]     sys_irq_ack_id_o   ,

  output logic [NumSysCores-1:0]                     sys_instr_req_o    ,
  input  logic [NumSysCores-1:0]                     sys_instr_gnt_i    ,
  output logic [NumSysCores-1:0][          31:0]     sys_instr_addr_o   ,
  input  logic [NumSysCores-1:0][InstrDataWidth-1:0] sys_instr_r_rdata_i,
  input  logic [NumSysCores-1:0]                     sys_instr_r_valid_i,
  input  logic [NumSysCores-1:0]                     sys_instr_err_i    ,

  input  logic [NumSysCores-1:0]                     sys_debug_req_i    ,

  output logic [NumSysCores-1:0]                     sys_data_req_o     ,
  output logic [NumSysCores-1:0][          31:0]     sys_data_add_o     ,
  output logic [NumSysCores-1:0]                     sys_data_wen_o     ,
  output logic [NumSysCores-1:0][ DataWidth-1:0]     sys_data_wdata_o   ,
  output logic [NumSysCores-1:0][ UserWidth-1:0]     sys_data_user_o    ,
  output logic [NumSysCores-1:0][   BeWidth-1:0]     sys_data_be_o      ,
  input  logic [NumSysCores-1:0]                     sys_data_gnt_i     ,
  input  logic [NumSysCores-1:0]                     sys_data_r_opc_i   ,
  input  logic [NumSysCores-1:0][ DataWidth-1:0]     sys_data_r_rdata_i ,
  input  logic [NumSysCores-1:0][ UserWidth-1:0]     sys_data_r_user_i  ,
  input  logic [NumSysCores-1:0]                     sys_data_r_valid_i ,
  input  logic [NumSysCores-1:0]                     sys_data_err_i     ,

  input  logic [NumSysCores-1:0][NumExtPerf-1:0]     sys_perf_counters_i,

  // Ports connecting to the cores
  output logic [   NumCores-1:0][           3:0]     core_core_id_o      ,
  output logic [   NumCores-1:0][           5:0]     core_cluster_id_o   ,

  output logic [   NumCores-1:0]                     core_clock_en_o     ,
  output logic [   NumCores-1:0]                     core_fetch_en_o     ,
  output logic [   NumCores-1:0][          31:0]     core_boot_addr_o    ,
  input  logic [   NumCores-1:0]                     core_core_busy_i    ,

  output logic [   NumCores-1:0]                     core_irq_req_o      ,
  input  logic [   NumCores-1:0]                     core_irq_ack_i      ,
  output logic [   NumCores-1:0][           4:0]     core_irq_id_o       ,
  input  logic [   NumCores-1:0][           4:0]     core_irq_ack_id_i   ,

  input  logic [   NumCores-1:0]                     core_instr_req_i    ,
  output logic [   NumCores-1:0]                     core_instr_gnt_o    ,
  input  logic [   NumCores-1:0][          31:0]     core_instr_addr_i   ,
  output logic [   NumCores-1:0][InstrDataWidth-1:0] core_instr_r_rdata_o,
  output logic [   NumCores-1:0]                     core_instr_r_valid_o,
  output logic [   NumCores-1:0]                     core_instr_err_o    ,

  output logic [   NumCores-1:0]                     core_debug_req_o    ,
  input  logic [   NumCores-1:0]                     core_debug_halted_i ,

  input  logic [   NumCores-1:0]                     core_data_req_i     ,
  input  logic [   NumCores-1:0][          31:0]     core_data_add_i     ,
  input  logic [   NumCores-1:0]                     core_data_wen_i     ,
  input  logic [   NumCores-1:0][ DataWidth-1:0]     core_data_wdata_i   ,
  input  logic [   NumCores-1:0][ UserWidth-1:0]     core_data_user_i    ,
  input  logic [   NumCores-1:0][   BeWidth-1:0]     core_data_be_i      ,
  output logic [   NumCores-1:0]                     core_data_gnt_o     ,
  output logic [   NumCores-1:0]                     core_data_r_opc_o   ,
  output logic [   NumCores-1:0][ DataWidth-1:0]     core_data_r_rdata_o ,
  output logic [   NumCores-1:0][ UserWidth-1:0]     core_data_r_user_o  ,
  output logic [   NumCores-1:0]                     core_data_r_valid_o ,
  output logic [   NumCores-1:0]                     core_data_err_o     ,

  output logic [   NumCores-1:0][NumExtPerf-1:0]     core_perf_counters_o

  // APU/SHARED_FPU not implemented
);
  function automatic int max(int a, int b);
    return (a > b) ? a : b;
  endfunction

  localparam int unsigned NumBackupRegfiles = max(DMRSupported || DMRFixed ? NumDMRGroups : 0,
                                                  TMRSupported || TMRFixed ? NumTMRGroups : 0);

  function automatic int tmr_group_id (int core_id);
    if (InterleaveGrps) return core_id % NumTMRGroups;
    else                return (core_id/3);
  endfunction

  function automatic int tmr_core_id (int group_id, int core_offset);
    if (InterleaveGrps) return group_id + core_offset * NumTMRGroups;
    else                return (group_id * 3) + core_offset;
  endfunction

  function automatic int tmr_shared_id (int group_id);
    if (InterleaveGrps || !(DMRSupported || DMRFixed)) return group_id;
    else                return group_id + group_id/2;
  endfunction

  function automatic int tmr_offset_id (int core_id);
    if (InterleaveGrps) return core_id / NumTMRGroups;
    else                return core_id % 3;
  endfunction

  function automatic int dmr_group_id (int core_id);
    if (InterleaveGrps) return core_id % NumDMRGroups;
    else                return (core_id/2);
  endfunction

  function automatic int dmr_core_id (int group_id, int core_offset);
    if (InterleaveGrps) return group_id + core_offset * NumDMRGroups;
    else                return (group_id * 2) + core_offset;
  endfunction

  function automatic int dmr_shared_id (int group_id);
    return group_id;
  endfunction

  function automatic int dmr_offset_id (int core_id);
    if (InterleaveGrps) return core_id / NumDMRGroups;
    else                return core_id % 2;
  endfunction

  if (TMRFixed && DMRFixed) $fatal(1, "Cannot fix both TMR and DMR!");

  localparam int unsigned CtrlConcatWidth = 1   + 1      + 5         + 1    + 32    + 1;
  //                                        busy  irq_ack  irq_ack_id  i_req  i_addr  d_req
  localparam int unsigned RapidRecoveryConcatWidth = RapidRecovery ? 165 + 65 + 76 : 0;
  //                                                                 csr   pc   rf
  localparam int unsigned DataConcatWidth = 32      + 1       + DataWidth + BeWidth + UserWidth;
  //                                        data_add  data_wen  data_wdata  data_be   data_user
  localparam int unsigned MainConcatWidth = RapidRecoveryConcatWidth +
                                            (SeparateData ? CtrlConcatWidth
                                                          : CtrlConcatWidth + DataConcatWidth);

  localparam int unsigned RFAddrWidth = 6;

  logic [    NumCores-1:0][MainConcatWidth-1:0] main_concat_in;
  logic [NumTMRGroups-1:0][MainConcatWidth-1:0] main_tmr_out;
  logic [NumDMRGroups-1:0][MainConcatWidth-1:0] main_dmr_out;

  logic [    NumCores-1:0][DataConcatWidth-1:0] data_concat_in;
  logic [NumTMRGroups-1:0][DataConcatWidth-1:0] data_tmr_out;
  logic [NumDMRGroups-1:0][DataConcatWidth-1:0] data_dmr_out;

  logic [NumTMRGroups-1:0] tmr_failure, tmr_failure_main, tmr_failure_data;
  logic [NumTMRGroups-1:0][2:0] tmr_error, tmr_error_main, tmr_error_data;
  logic [NumTMRGroups-1:0] tmr_single_mismatch;

  logic [NumDMRGroups-1:0] dmr_failure, dmr_failure_main, dmr_failure_data;
  // logic [NumDMRGroups-1:0][2:0] dmr_error, dmr_error_main, dmr_error_data;
  // logic [NumDMRGroups-1:0] dmr_single_mismatch;

  logic [NumTMRGroups-1:0]                 tmr_core_busy_out;
  logic [NumTMRGroups-1:0]                 tmr_irq_ack_out;
  logic [NumTMRGroups-1:0][           4:0] tmr_irq_ack_id_out;
  logic [NumTMRGroups-1:0]                 tmr_instr_req_out;
  logic [NumTMRGroups-1:0][          31:0] tmr_instr_addr_out;
  logic [NumTMRGroups-1:0]                 tmr_data_req_out;
  logic [NumTMRGroups-1:0][          31:0] tmr_data_add_out;
  logic [NumTMRGroups-1:0]                 tmr_data_wen_out;
  logic [NumTMRGroups-1:0][ DataWidth-1:0] tmr_data_wdata_out;
  logic [NumTMRGroups-1:0][ UserWidth-1:0] tmr_data_user_out;
  logic [NumTMRGroups-1:0][   BeWidth-1:0] tmr_data_be_out;

  logic [NumDMRGroups-1:0]                 dmr_core_busy_out;
  logic [NumDMRGroups-1:0]                 dmr_irq_ack_out;
  logic [NumDMRGroups-1:0][           4:0] dmr_irq_ack_id_out;
  logic [NumDMRGroups-1:0]                 dmr_instr_req_out;
  logic [NumDMRGroups-1:0][          31:0] dmr_instr_addr_out;
  logic [NumDMRGroups-1:0]                 dmr_data_req_out;
  logic [NumDMRGroups-1:0][          31:0] dmr_data_add_out;
  logic [NumDMRGroups-1:0]                 dmr_data_wen_out;
  logic [NumDMRGroups-1:0][ DataWidth-1:0] dmr_data_wdata_out;
  logic [NumDMRGroups-1:0][ UserWidth-1:0] dmr_data_user_out;
  logic [NumDMRGroups-1:0][   BeWidth-1:0] dmr_data_be_out;


  logic [     NumDMRGroups-1:0][RFAddrWidth-1:0] dmr_backup_regfile_waddr_a,
                                                 dmr_backup_regfile_waddr_b;
  logic [     NumDMRGroups-1:0][ DataWidth-1:0]  dmr_backup_program_counter,
                                                 dmr_backup_regfile_wdata_a,
                                                 dmr_backup_regfile_wdata_b,
                                                 dmr_backup_branch_addr_int;
  logic [     NumDMRGroups-1:0]                  dmr_backup_branch_int,
                                                 dmr_start_recovery,
                                                 dmr_backup_regfile_we_a,
                                                 dmr_backup_regfile_we_b,
                                                 dmr_recovery_finished;
  logic [     NumTMRGroups-1:0][RFAddrWidth-1:0] tmr_backup_regfile_waddr_a,
                                                 tmr_backup_regfile_waddr_b;
  logic [     NumTMRGroups-1:0][ DataWidth-1:0]  tmr_backup_program_counter,
                                                 tmr_backup_regfile_wdata_a,
                                                 tmr_backup_regfile_wdata_b,
                                                 tmr_backup_branch_addr_int;
  logic [     NumTMRGroups-1:0]                  tmr_backup_branch_int,
                                                 tmr_start_recovery,
                                                 tmr_backup_regfile_we_a,
                                                 tmr_backup_regfile_we_b,
                                                 tmr_recovery_finished;

  logic [NumBackupRegfiles-1:0][RFAddrWidth-1:0] backup_regfile_waddr_a,
                                                backup_regfile_waddr_b;
  logic [NumBackupRegfiles-1:0][ DataWidth-1:0] backup_branch_addr_int,
                                                recovery_branch_addr_out,
                                                backup_program_counter_int,
                                                recovery_program_counter_out,
                                                backup_regfile_wdata_a,
                                                backup_regfile_wdata_b;
  logic [NumBackupRegfiles-1:0]                 backup_branch_int,
                                                backup_regfile_we_a,
                                                backup_regfile_we_b,
                                                backup_program_counter_error,
                                                recovery_branch_out,
                                                backup_enable,
                                                recovery_csr_enable_out,
                                                recovery_pc_enable_out,
                                                recovery_debug_req_out,
                                                recovery_debug_halted_in,
                                                recovery_instr_lock_out,
                                                recovery_setback_out,
                                                recovery_trigger_out,
                                                recovery_debug_resume_out,
                                                start_recovery,
                                                recovery_finished;

  logic [NumBackupRegfiles-1:0] rapid_recovery_backup_enable;
  regfile_raddr_t [NumBackupRegfiles-1:0] core_regfile_raddr_out;
  regfile_rdata_t [NumBackupRegfiles-1:0] core_recovery_regfile_rdata_out;
  regfile_write_t [NumBackupRegfiles-1:0] core_recovery_regfile_wport_out;
  csrs_intf_t     [NumBackupRegfiles-1:0] backup_csr_int, dmr_backup_csr,
                                          tmr_backup_csr, recovery_csr_out;

  for (genvar i = 0; i < NumCores; i++) begin : gen_concat
    if (SeparateData) begin : gen_separate_data
      assign main_concat_in[i] = {core_core_busy_i[i], core_irq_ack_i[i], core_irq_ack_id_i[i],
                                  core_instr_req_i[i], core_instr_addr_i[i], core_data_req_i[i],
                                  // CSRs signals
                                  backup_csr_i[i].csr_mstatus , //  7-bits
                                  backup_csr_i[i].csr_mie     , // 32-bits
                                  backup_csr_i[i].csr_mtvec   , // 24-bits
                                  backup_csr_i[i].csr_mscratch, // 32-bits
                                  backup_csr_i[i].csr_mip     , // 32-bits
                                  backup_csr_i[i].csr_mepc    , // 32-bits
                                  backup_csr_i[i].csr_mcause  , //  6-bits
                                  // PC signals
                                  backup_program_counter_i[i], // 32-bits
                                  backup_branch_i[i], backup_branch_addr_i[i], // 1-bits + 32-bits
                                  // RF signals
                                  backup_regfile_wport_i[i].wdata_a, // 32-bits
                                  backup_regfile_wport_i[i].waddr_a, //  6-bits
                                  backup_regfile_wport_i[i].wdata_b, // 32-bits
                                  backup_regfile_wport_i[i].waddr_b};//  6-bits
      assign data_concat_in[i] = {core_data_add_i[i], core_data_wen_i[i], core_data_wdata_i[i],
                                  core_data_be_i[i], core_data_user_i[i]};
    end else begin : gen_single_group
      assign main_concat_in[i] = {core_core_busy_i[i], core_irq_ack_i[i], core_irq_ack_id_i[i],
                                  core_instr_req_i[i], core_instr_addr_i[i], core_data_req_i[i],
                                  core_data_add_i[i], core_data_wen_i[i], core_data_wdata_i[i],
                                  core_data_be_i[i], core_data_user_i[i],
                                  // CSRs signals
                                  backup_csr_i[i].csr_mstatus , //  7-bits
                                  backup_csr_i[i].csr_mie     , // 32-bits
                                  backup_csr_i[i].csr_mtvec   , // 24-bits
                                  backup_csr_i[i].csr_mscratch, // 32-bits
                                  backup_csr_i[i].csr_mip     , // 32-bits
                                  backup_csr_i[i].csr_mepc    , // 32-bits
                                  backup_csr_i[i].csr_mcause  , //  6-bits
                                  // PC signals
                                  backup_program_counter_i[i], // 32-bits
                                  backup_branch_i[i], backup_branch_addr_i[i], // 1-bits + 32-bits
                                  // RF signals
                                  backup_regfile_wport_i[i].wdata_a, // 32-bits
                                  backup_regfile_wport_i[i].waddr_a, //  6-bits
                                  backup_regfile_wport_i[i].wdata_b, // 32-bits
                                  backup_regfile_wport_i[i].waddr_b};//  6-bits
      assign data_concat_in = '0;
    end
  end

  logic [NumSysCores-1:0] filt_instr_req, filt_data_req;
  logic [NumSysCores-1:0] filt_instr_r_valid, filt_data_r_valid;
  logic [NumSysCores-1:0] filt_instr_gnt, filt_data_gnt;
  logic [NumSysCores-1:0] filt_data_we;
  logic [NumSysCores-1:0][31:0] filt_instr_addr, filt_data_addr;
  logic [NumSysCores-1:0][DataWidth-1:0] filt_data_data;
  logic [NumSysCores-1:0][BeWidth-1:0] filt_data_be;

  for (genvar i = 0; i < NumSysCores; i++) begin : gen_resp_suppress
    resp_suppress #(
      .AW (32),
      .DW (DataWidth)
    ) i_instr_suppress (
      .clk_i,
      .rst_ni,

      .ctrl_setback_i (core_setback_o[i]),

      .req_i     (filt_instr_req    [i]),
      .gnt_o     (filt_instr_gnt    [i]),
      .r_valid_o (filt_instr_r_valid[i]),
      .we_i      ('0),
      .addr_i    (filt_instr_addr   [i]),
      .data_i    ('0),
      .be_i      ('0),

      .req_o     (sys_instr_req_o[i]),
      .gnt_i     (sys_instr_gnt_i[i]),
      .r_valid_i (sys_instr_r_valid_i[i]),
      .we_o      (),
      .addr_o    (sys_instr_addr_o[i]),
      .data_o    (),
      .be_o      ()
    );
    resp_suppress #(
      .AW (32),
      .DW (DataWidth)
    ) i_data_suppress (
      .clk_i,
      .rst_ni,

      .ctrl_setback_i (core_setback_o[i]),

      .req_i     (filt_data_req    [i]),
      .gnt_o     (filt_data_gnt    [i]),
      .r_valid_o (filt_data_r_valid[i]),
      .we_i      (filt_data_we     [i]),
      .addr_i    (filt_data_addr   [i]),
      .data_i    (filt_data_data   [i]),
      .be_i      (filt_data_be     [i]),

      .req_o     (sys_data_req_o    [i]),
      .gnt_i     (sys_data_gnt_i    [i]),
      .r_valid_i (sys_data_r_valid_i[i]),
      .we_o      (sys_data_wen_o    [i]),
      .addr_o    (sys_data_add_o    [i]),
      .data_o    (sys_data_wdata_o  [i]),
      .be_o      (sys_data_be_o     [i])
    );
  end

  /***************************
   *  HMR Control Registers  *
   ***************************/

  logic [NumCores-1:0] core_en_as_master;
  logic [NumCores-1:0] core_in_independent;
  logic [NumCores-1:0] core_in_dmr;
  logic [NumCores-1:0] core_in_tmr;
  logic [NumCores-1:0] dmr_core_rapid_recovery_en;
  logic [NumCores-1:0] tmr_core_rapid_recovery_en;

  logic [NumDMRGroups-1:0][1:0] dmr_setback_q;
  logic [NumDMRGroups-1:0] dmr_grp_in_independent;
  logic [NumDMRGroups-1:0] dmr_rapid_recovery_en;

  logic [NumTMRGroups-1:0][2:0] tmr_setback_q;
  logic [NumTMRGroups-1:0] tmr_grp_in_independent;
  logic [NumTMRGroups-1:0] tmr_rapid_recovery_en;

  logic [NumCores-1:0] sp_store_is_zero;
  logic [NumCores-1:0] sp_store_will_be_zero;

  for (genvar i = 0; i < NumCores; i++) begin : gen_global_status
    assign core_in_independent[i] = ~core_in_dmr[i] & ~core_in_tmr[i];
    assign core_in_dmr[i] = (DMRSupported || DMRFixed) && i < NumDMRCores ?
                            ~dmr_grp_in_independent[dmr_group_id(i)] : '0;
    assign core_in_tmr[i] = (TMRSupported || TMRFixed) && i < NumTMRCores ?
                            ~tmr_grp_in_independent[tmr_group_id(i)] : '0;
    assign core_en_as_master[i] = ((tmr_core_id(tmr_group_id(i), 0) == i || i>=NumTMRCores) ?
                                  1'b1 : ~core_in_tmr[i]) &
                                  ((dmr_core_id(dmr_group_id(i), 0) == i || i>=NumDMRCores) ?
                                  1'b1 : ~core_in_dmr[i]);
    assign dmr_core_rapid_recovery_en[i] = (DMRSupported || DMRFixed) &&
                                           i < NumDMRCores &&
                                           RapidRecovery ?
                                           dmr_rapid_recovery_en[dmr_group_id(i)] :
                                           '0;
    assign tmr_core_rapid_recovery_en[i] = (TMRSupported || TMRFixed) &&
                                           i < NumTMRCores &&
                                           RapidRecovery ?
                                           tmr_rapid_recovery_en[tmr_group_id(i)] :
                                           '0;
  end

  reg_req_t  [3:0] top_register_reqs;
  reg_resp_t [3:0] top_register_resps;

  // 0x000-0x100 -> Top config
  // 0x100-0x200 -> Core configs
  // 0x200-0x300 -> DMR configs
  // 0x300-0x400 -> TMR configs

  reg_demux #(
    .NoPorts    ( 4 ),
    .req_t      ( reg_req_t    ),
    .rsp_t      ( reg_resp_t   )
  ) i_reg_demux (
    .clk_i,
    .rst_ni,
    .in_select_i( reg_request_i.addr[9:8] ),
    .in_req_i   ( reg_request_i      ),
    .in_rsp_o   ( reg_response_o     ),
    .out_req_o  ( top_register_reqs  ),
    .out_rsp_i  ( top_register_resps )
  );

  // Global config registers

  hmr_registers_reg_pkg::hmr_registers_hw2reg_t hmr_hw2reg;
  hmr_registers_reg_pkg::hmr_registers_reg2hw_t hmr_reg2hw;

  hmr_registers_reg_top #(
    .reg_req_t( reg_req_t  ),
    .reg_rsp_t( reg_resp_t )
  ) i_hmr_registers (
    .clk_i,
    .rst_ni,
    .reg_req_i(top_register_reqs[0] ),
    .reg_rsp_o(top_register_resps[0]),
    .reg2hw   (hmr_reg2hw),
    .hw2reg   (hmr_hw2reg),
    .devmode_i('0)
  );

  assign hmr_hw2reg.avail_config.independent.d = ~(TMRFixed | DMRFixed);
  assign hmr_hw2reg.avail_config.dual.d = DMRFixed | DMRSupported;
  assign hmr_hw2reg.avail_config.triple.d = TMRFixed | TMRSupported;
  assign hmr_hw2reg.avail_config.rapid_recovery.d = RapidRecovery;

  always_comb begin : proc_reg_status
    hmr_hw2reg.cores_en.d = '0;
    hmr_hw2reg.cores_en.d = core_en_as_master;

    hmr_hw2reg.dmr_enable.d = '0;
    hmr_hw2reg.dmr_enable.d[NumDMRGroups-1:0] = ~dmr_grp_in_independent;
    hmr_hw2reg.tmr_enable.d = '0;
    hmr_hw2reg.tmr_enable.d[NumTMRGroups-1:0] = ~tmr_grp_in_independent;
  end

  assign hmr_hw2reg.tmr_config.delay_resynch.d = '0;
  assign hmr_hw2reg.tmr_config.setback.d = '0;
  assign hmr_hw2reg.tmr_config.reload_setback.d  = '0;
  assign hmr_hw2reg.tmr_config.force_resynch.d = '0;
  assign hmr_hw2reg.tmr_config.rapid_recovery.d = '0;

  assign hmr_hw2reg.dmr_config.rapid_recovery.d = '0;
  assign hmr_hw2reg.dmr_config.force_recovery.d = '0;

  // Core Config Registers

  reg_req_t  [NumCores-1:0] core_register_reqs;
  reg_resp_t [NumCores-1:0] core_register_resps;

  // 4 words per core

  reg_demux #(
    .NoPorts    ( NumCores ),
    .req_t      ( reg_req_t    ),
    .rsp_t      ( reg_resp_t   )
  ) i_core_reg_demux (
    .clk_i,
    .rst_ni,
    .in_select_i( top_register_reqs [1].addr[4+$clog2(NumCores)-1:4] ),
    .in_req_i   ( top_register_reqs [1] ),
    .in_rsp_o   ( top_register_resps[1] ),
    .out_req_o  ( core_register_reqs ),
    .out_rsp_i  ( core_register_resps )
  );

  hmr_core_regs_reg_pkg::hmr_core_regs_reg2hw_t [NumCores-1:0] core_config_reg2hw;
  hmr_core_regs_reg_pkg::hmr_core_regs_hw2reg_t [NumCores-1:0] core_config_hw2reg;

  logic [NumCores-1:0] tmr_incr_mismatches;
  logic [NumCores-1:0] dmr_incr_mismatches;

  for (genvar i = 0; i < NumCores; i++) begin : gen_core_registers
    hmr_core_regs_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_resp_t)
    ) icore_registers (
      .clk_i,
      .rst_ni,
      .reg_req_i( core_register_reqs [i] ),
      .reg_rsp_o( core_register_resps[i] ),
      .reg2hw   ( core_config_reg2hw [i] ),
      .hw2reg   ( core_config_hw2reg [i] ),
      .devmode_i('0)
    );

    assign core_config_hw2reg[i].mismatches.d = core_config_reg2hw[i].mismatches.q + 1;
    assign core_config_hw2reg[i].mismatches.de = tmr_incr_mismatches[i] | dmr_incr_mismatches[i];
    assign core_config_hw2reg[i].current_mode.independent.d = core_in_independent[i];
    assign core_config_hw2reg[i].current_mode.dual.d        = core_in_dmr[i];
    assign core_config_hw2reg[i].current_mode.triple.d      = core_in_tmr[i];
    assign sp_store_is_zero[i] = core_config_reg2hw[i].sp_store.q == '0;
    assign sp_store_will_be_zero[i] = core_config_reg2hw[i].sp_store.qe &&
                                      core_register_reqs[i].wdata == '0;
  end


  /**********************************************************
   ******************** TMR Voters & Regs *******************
   **********************************************************/

  if (TMRSupported || TMRFixed) begin : gen_tmr_logic
    if (TMRFixed && NumCores % 3 != 0) $warning("Extra cores added not properly handled!");

    reg_req_t  [NumTMRGroups-1:0] tmr_register_reqs;
    reg_resp_t [NumTMRGroups-1:0] tmr_register_resps;
    logic [NumTMRGroups-1:0] tmr_sw_synch_req;

    localparam int unsigned TMRSelWidth = $clog2(NumTMRGroups);

    /***************
     *  Registers  *
     ***************/
    reg_demux #(
      .NoPorts    ( NumTMRGroups ),
      .req_t      ( reg_req_t    ),
      .rsp_t      ( reg_resp_t   )
    ) i_reg_demux (
      .clk_i,
      .rst_ni,
      .in_select_i( top_register_reqs[3].addr[4+$clog2(NumTMRGroups)-1:4] ),
      .in_req_i   ( top_register_reqs[3]           ),
      .in_rsp_o   ( top_register_resps[3]          ),
      .out_req_o  ( tmr_register_reqs              ),
      .out_rsp_i  ( tmr_register_resps             )
    );

    for (genvar i = NumTMRCores; i < NumCores; i++) begin : gen_extra_core_assigns
      assign tmr_incr_mismatches[i] = '0;
      assign tmr_sw_synch_req_o[i] = '0;
    end

    for (genvar i = 0; i < NumTMRGroups; i++) begin : gen_tmr_groups

      hmr_tmr_ctrl #(
        .reg_req_t      ( reg_req_t      ),
        .reg_resp_t     ( reg_resp_t     ),
        .TMRFixed       ( TMRFixed       ),
        .InterleaveGrps ( InterleaveGrps ),
        .DefaultInTMR   ( 1'b0           ),
        .RapidRecovery  ( RapidRecovery  )
      ) i_tmr_ctrl (
        .clk_i,
        .rst_ni,

        .reg_req_i            ( tmr_register_reqs[i] ),
        .reg_resp_o           ( tmr_register_resps[i] ),

        .tmr_enable_q_i       ( hmr_reg2hw.tmr_enable.q[i] ),
        .tmr_enable_qe_i      ( hmr_reg2hw.tmr_enable.qe ),
        .delay_resynch_q_i    ( hmr_reg2hw.tmr_config.delay_resynch.q ),
        .delay_resynch_qe_i   ( hmr_reg2hw.tmr_config.delay_resynch.qe ),
        .setback_q_i          ( hmr_reg2hw.tmr_config.setback.q ),
        .setback_qe_i         ( hmr_reg2hw.tmr_config.setback.qe ),
        .reload_setback_q_i   ( hmr_reg2hw.tmr_config.reload_setback.q ),
        .reload_setback_qe_i  ( hmr_reg2hw.tmr_config.reload_setback.qe ),
        .rapid_recovery_q_i   ( hmr_reg2hw.tmr_config.rapid_recovery.q ),
        .rapid_recovery_qe_i  ( hmr_reg2hw.tmr_config.rapid_recovery.qe ),
        .force_resynch_q_i    ( hmr_reg2hw.tmr_config.force_resynch.q ),
        .force_resynch_qe_i   ( hmr_reg2hw.tmr_config.force_resynch.qe ),

        .setback_o            ( tmr_setback_q[i] ),
        .sw_resynch_req_o     ( tmr_resynch_req_o[i] ),
        .sw_synch_req_o       ( tmr_sw_synch_req[i] ),
        .grp_in_independent_o ( tmr_grp_in_independent[i] ),
        .rapid_recovery_en_o  ( tmr_rapid_recovery_en[i] ),
        .tmr_incr_mismatches_o( {tmr_incr_mismatches[tmr_core_id(i,0)],
                                 tmr_incr_mismatches[tmr_core_id(i,1)],
                                 tmr_incr_mismatches[tmr_core_id(i,2)]} ),
        .tmr_single_mismatch_i( tmr_single_mismatch[i] ),
        .tmr_error_i          ( tmr_error[i] ),
        .tmr_failure_i        ( tmr_failure[i] ),
        .sp_store_is_zero     ( sp_store_is_zero[tmr_core_id(i, 0)] ),
        .sp_store_will_be_zero( sp_store_will_be_zero[tmr_core_id(i, 0)] ),

        .fetch_en_i           ( sys_fetch_en_i[tmr_core_id(i, 0)] ),
        .cores_synch_i        ( tmr_cores_synch_i[i] ),

        .recovery_request_o   ( tmr_start_recovery [i] ),
        .recovery_finished_i  ( tmr_recovery_finished [i] )
      );

      assign tmr_sw_synch_req_o[tmr_core_id(i, 0)] = tmr_sw_synch_req[i];
      assign tmr_sw_synch_req_o[tmr_core_id(i, 1)] = tmr_sw_synch_req[i];
      assign tmr_sw_synch_req_o[tmr_core_id(i, 2)] = tmr_sw_synch_req[i];

      assign tmr_failure[i]         = tmr_data_req_out[i] ?
                                      tmr_failure_main[i] | tmr_failure_data[i] :
                                      tmr_failure_main[i];
      assign tmr_error[i]           = tmr_data_req_out[i] ?
                                      tmr_error_main[i] | tmr_error_data[i] :
                                      tmr_error_main[i];
      assign tmr_single_mismatch[i] = tmr_error[i] != 3'b000;

      bitwise_TMR_voter #(
        .DataWidth( MainConcatWidth ),
        .VoterType( 0 )
      ) i_main_voter (
        .a_i        ( main_concat_in[tmr_core_id(i, 0)] ),
        .b_i        ( main_concat_in[tmr_core_id(i, 1)] ),
        .c_i        ( main_concat_in[tmr_core_id(i, 2)] ),
        .majority_o ( main_tmr_out  [i    ] ),
        .error_o    ( tmr_failure_main[i]   ),
        .error_cba_o( tmr_error_main[i    ] )
      );
      if (SeparateData) begin : gen_data_voter
        bitwise_TMR_voter #(
          .DataWidth( DataConcatWidth ),
          .VoterType( 0 )
        ) i_data_voter (
          .a_i        ( data_concat_in[tmr_core_id(i, 0)] ),
          .b_i        ( data_concat_in[tmr_core_id(i, 1)] ),
          .c_i        ( data_concat_in[tmr_core_id(i, 2)] ),
          .majority_o ( data_tmr_out  [i    ] ),
          .error_o    ( tmr_failure_data[i]   ),
          .error_cba_o( tmr_error_data[i    ] )
        );

        assign {tmr_core_busy_out[i], tmr_irq_ack_out[i], tmr_irq_ack_id_out[i],
               tmr_instr_req_out[i], tmr_instr_addr_out[i], tmr_data_req_out[i],
               // CSRs signals
               tmr_backup_csr[i].csr_mstatus , //  7-bits
               tmr_backup_csr[i].csr_mie     , // 32-bits
               tmr_backup_csr[i].csr_mtvec   , // 24-bits
               tmr_backup_csr[i].csr_mscratch, // 32-bits
               tmr_backup_csr[i].csr_mip     , // 32-bits
               tmr_backup_csr[i].csr_mepc    , // 32-bits
               tmr_backup_csr[i].csr_mcause  , //  6-bits
               // PC signals
               tmr_backup_program_counter[i], // 32-bits
               tmr_backup_branch_int[i], tmr_backup_branch_addr_int[i], // 1-bits + 32-bits
               // RF signals
               tmr_backup_regfile_wdata_a[i], // 32-bits
               tmr_backup_regfile_waddr_a[i], //  6-bits
               tmr_backup_regfile_wdata_b[i], // 32-bits
               tmr_backup_regfile_waddr_b[i]}
               = main_tmr_out[i];
        assign {tmr_data_add_out[i], tmr_data_wen_out[i], tmr_data_wdata_out[i],
               tmr_data_be_out[i], tmr_data_user_out[i]} = data_tmr_out[i];
      end else begin : gen_data_in_main
        assign tmr_failure_data[i] = 1'b0;
        assign tmr_error_data[i] = 3'b000;
        assign {tmr_core_busy_out[i], tmr_irq_ack_out[i], tmr_irq_ack_id_out[i],
                tmr_instr_req_out[i], tmr_instr_addr_out[i], tmr_data_req_out[i],
               tmr_data_add_out[i], tmr_data_wen_out[i], tmr_data_wdata_out[i],
               tmr_data_be_out[i], tmr_data_user_out[i],
               // CSRs signals
               tmr_backup_csr[i].csr_mstatus , //  7-bits
               tmr_backup_csr[i].csr_mie     , // 32-bits
               tmr_backup_csr[i].csr_mtvec   , // 24-bits
               tmr_backup_csr[i].csr_mscratch, // 32-bits
               tmr_backup_csr[i].csr_mip     , // 32-bits
               tmr_backup_csr[i].csr_mepc    , // 32-bits
               tmr_backup_csr[i].csr_mcause  , //  6-bits
               // PC signals
               tmr_backup_program_counter[i], // 32-bits
               tmr_backup_branch_int[i], tmr_backup_branch_addr_int[i], // 1-bits + 32-bits
               // RF signals
               tmr_backup_regfile_wdata_a[i], // 32-bits
               tmr_backup_regfile_waddr_a[i], //  6-bits
               tmr_backup_regfile_wdata_b[i], // 32-bits
               tmr_backup_regfile_waddr_b[i]} = main_tmr_out[i];
      end

      if (RapidRecovery) begin : gen_rapid_recovery_connection

        bitwise_TMR_voter #(
          .DataWidth( 1 ),
          .VoterType( 0 )
        ) i_voter_regfile_we_a (
          .a_i        ( backup_regfile_wport_i[tmr_core_id(i, 0)].we_a ),
          .b_i        ( backup_regfile_wport_i[tmr_core_id(i, 1)].we_a ),
          .c_i        ( backup_regfile_wport_i[tmr_core_id(i, 2)].we_a ),
          .majority_o ( tmr_backup_regfile_we_a [i] ),
          .error_o    ( ),
          .error_cba_o( )
        );

        bitwise_TMR_voter #(
          .DataWidth( 1 ),
          .VoterType( 0 )
        ) i_voter_regfile_we_b (
          .a_i        ( backup_regfile_wport_i[tmr_core_id(i, 0)].we_b ),
          .b_i        ( backup_regfile_wport_i[tmr_core_id(i, 1)].we_b ),
          .c_i        ( backup_regfile_wport_i[tmr_core_id(i, 2)].we_b ),
          .majority_o ( tmr_backup_regfile_we_b [i] ),
          .error_o    ( ),
          .error_cba_o( )
        );

      end else begin : gen_standard_failure
        assign tmr_failure [i] = tmr_data_req_out [i] ? (tmr_failure_main[i] | tmr_failure_data[i])
                                                      : tmr_failure_main[i];
      end
    end
  end else begin : gen_no_tmr_voted
    assign tmr_error_main   = '0;
    assign tmr_error_data   = '0;
    assign tmr_error        = '0;
    assign tmr_failure_main = '0;
    assign tmr_failure_data = '0;
    assign tmr_failure      = '0;
    assign main_tmr_out = '0;
    assign data_tmr_out = '0;
    assign {tmr_core_busy_out, tmr_irq_ack_out, tmr_irq_ack_id_out,
           tmr_instr_req_out, tmr_instr_addr_out, tmr_data_req_out,
           tmr_data_add_out, tmr_data_wen_out, tmr_data_wdata_out,
           tmr_data_be_out, tmr_data_user_out} = '0;
    assign top_register_resps[3].rdata = '0;
    assign top_register_resps[3].error = 1'b1;
    assign top_register_resps[3].ready = 1'b1;
    assign tmr_incr_mismatches = '0;
    assign tmr_grp_in_independent = '0;
    assign tmr_setback_q = '0;
    assign tmr_resynch_req_o = '0;
    assign tmr_sw_synch_req_o = '0;
  end

  /************************************************************
   ******************** DMR Voters and Regs *******************
   ************************************************************/

  if (DMRSupported || DMRFixed) begin: gen_dmr_logic

    hmr_dmr_regs_reg_pkg::hmr_dmr_regs_reg2hw_t [NumDMRGroups-1:0] dmr_reg2hw;
    hmr_dmr_regs_reg_pkg::hmr_dmr_regs_hw2reg_t [NumDMRGroups-1:0] dmr_hw2reg;

    reg_req_t  [NumDMRGroups-1:0] dmr_register_reqs;
    reg_resp_t [NumDMRGroups-1:0] dmr_register_resps;
    logic [NumDMRGroups-1:0] dmr_sw_synch_req;

    localparam int unsigned DMRSelWidth = $clog2(NumDMRGroups);

    /***************
     *  Registers  *
     ***************/
    reg_demux #(
      .NoPorts    ( NumDMRGroups ),
      .req_t      ( reg_req_t    ),
      .rsp_t      ( reg_resp_t   )
    ) i_reg_demux (
      .clk_i,
      .rst_ni,
      .in_select_i( top_register_reqs[2].addr[4+$clog2(NumDMRGroups)-1:4] ),
      .in_req_i   ( top_register_reqs[2]           ),
      .in_rsp_o   ( top_register_resps[2]          ),
      .out_req_o  ( dmr_register_reqs              ),
      .out_rsp_i  ( dmr_register_resps             )
    );

    for (genvar i = NumDMRCores; i < NumCores; i++) begin : gen_extra_core_assigns
      assign dmr_incr_mismatches[i] = '0;
      assign dmr_sw_synch_req_o[i] = '0;
    end

    for (genvar i = 0; i < NumDMRGroups; i++) begin : gen_dmr_groups

      hmr_dmr_ctrl #(
        .reg_req_t     ( reg_req_t ),
        .reg_resp_t    ( reg_resp_t ),
        .InterleaveGrps( InterleaveGrps ),
        .DMRFixed      ( DMRFixed ),
        .RapidRecovery ( RapidRecovery ),
        .DefaultInDMR  ( 1'b0 )
      ) i_dmr_ctrl (
        .clk_i,
        .rst_ni,

        .reg_req_i             ( dmr_register_reqs [i] ),
        .reg_resp_o            ( dmr_register_resps[i] ),

        .dmr_enable_q_i        ( hmr_reg2hw.dmr_enable.q[i] ),
        .dmr_enable_qe_i       ( hmr_reg2hw.dmr_enable.qe ),
        .rapid_recovery_q_i    ( hmr_reg2hw.dmr_config.rapid_recovery.q ),
        .rapid_recovery_qe_i   ( hmr_reg2hw.dmr_config.rapid_recovery.qe ),
        .force_recovery_q_i    ( hmr_reg2hw.dmr_config.force_recovery.q ),
        .force_recovery_qe_i   ( hmr_reg2hw.dmr_config.force_recovery.qe ),

        .setback_o             ( dmr_setback_q         [i] ),
        .sw_resynch_req_o      ( dmr_resynch_req_o     [i] ),
        .sw_synch_req_o        ( dmr_sw_synch_req      [i] ),
        .grp_in_independent_o  ( dmr_grp_in_independent[i] ),
        .rapid_recovery_en_o   ( dmr_rapid_recovery_en [i] ),
        .dmr_incr_mismatches_o ( {dmr_incr_mismatches[dmr_core_id(i, 0)],
                                  dmr_incr_mismatches[dmr_core_id(i, 1)]} ),
        .dmr_error_i           ( dmr_failure           [i] ),

        .fetch_en_i            ( sys_fetch_en_i[dmr_core_id(i, 0)] ),
        .cores_synch_i         ( dmr_cores_synch_i[i] ),

        .recovery_request_o    ( dmr_start_recovery   [i] ),
        .recovery_finished_i   ( dmr_recovery_finished[i] )
      );

      assign dmr_sw_synch_req_o[dmr_core_id(i, 0)] = dmr_sw_synch_req[i];
      assign dmr_sw_synch_req_o[dmr_core_id(i, 1)] = dmr_sw_synch_req[i];

      /*********************
       * DMR Core Checkers *
       *********************/
      DMR_checker #(
        .DataWidth ( MainConcatWidth )
      ) dmr_core_checker_main (
        .inp_a_i ( main_concat_in [dmr_core_id(i, 0)] ),
        .inp_b_i ( main_concat_in [dmr_core_id(i, 1)] ),
        .check_o ( main_dmr_out               [i]     ),
        .error_o ( dmr_failure_main           [i]     )
      );
      if (SeparateData) begin : gen_data_checker
        DMR_checker # (
          .DataWidth ( DataConcatWidth )
        ) dmr_core_checker_data (
          .inp_a_i ( data_concat_in [dmr_core_id(i, 0)] ),
          .inp_b_i ( data_concat_in [dmr_core_id(i, 1)] ),
          .check_o ( data_dmr_out               [i]     ),
          .error_o ( dmr_failure_data           [i]     )
        );
        assign {dmr_core_busy_out[i], dmr_irq_ack_out[i]   , dmr_irq_ack_id_out[i],
                dmr_instr_req_out[i], dmr_instr_addr_out[i], dmr_data_req_out[i],
                // CSRs signals
                dmr_backup_csr[i].csr_mstatus , //  7-bits
                dmr_backup_csr[i].csr_mie     , // 32-bits
                dmr_backup_csr[i].csr_mtvec   , // 24-bits
                dmr_backup_csr[i].csr_mscratch, // 32-bits
                dmr_backup_csr[i].csr_mip     , // 32-bits
                dmr_backup_csr[i].csr_mepc    , // 32-bits
                dmr_backup_csr[i].csr_mcause  , //  6-bits
                // PC signals
                dmr_backup_program_counter[i], // 32-bits
                dmr_backup_branch_int[i], dmr_backup_branch_addr_int[i], // 1-bits + 32-bits
                // RF signals
                dmr_backup_regfile_wdata_a[i], // 32-bits
                dmr_backup_regfile_waddr_a[i], //  6-bits
                dmr_backup_regfile_wdata_b[i], // 32-bits
                dmr_backup_regfile_waddr_b[i]} //  6-bits
                = main_dmr_out[i];
        assign {dmr_data_add_out[i], dmr_data_wen_out[i] , dmr_data_wdata_out[i],
                dmr_data_be_out[i] , dmr_data_user_out[i]                       }
                = data_dmr_out[i];
      end else begin : gen_data_in_main
        assign dmr_failure_data[i] = 1'b0;
        assign {dmr_core_busy_out[i], dmr_irq_ack_out[i]   , dmr_irq_ack_id_out[i],
                dmr_instr_req_out[i], dmr_instr_addr_out[i], dmr_data_req_out[i]  ,
                dmr_data_add_out[i] , dmr_data_wen_out[i]  , dmr_data_wdata_out[i],
                dmr_data_be_out[i]  , dmr_data_user_out[i],
                // CSRs signals
                dmr_backup_csr[i].csr_mstatus , //  7-bits
                dmr_backup_csr[i].csr_mie     , // 32-bits
                dmr_backup_csr[i].csr_mtvec   , // 24-bits
                dmr_backup_csr[i].csr_mscratch, // 32-bits
                dmr_backup_csr[i].csr_mip     , // 32-bits
                dmr_backup_csr[i].csr_mepc    , // 32-bits
                dmr_backup_csr[i].csr_mcause  , //  6-bits
                // PC signals
                dmr_backup_program_counter[i], // 32-bits
                dmr_backup_branch_int[i], dmr_backup_branch_addr_int[i], // 1-bits + 32-bits
                // RF signals
                dmr_backup_regfile_wdata_a[i], // 32-bits
                dmr_backup_regfile_waddr_a[i], //  6-bits
                dmr_backup_regfile_wdata_b[i], // 32-bits
                dmr_backup_regfile_waddr_b[i]} //  6-bits
                = main_dmr_out[i];
      end

      if (RapidRecovery) begin : gen_rapid_recovery_connection

        assign dmr_failure [i] = (dmr_data_req_out [i] ? (dmr_failure_main[i] | dmr_failure_data[i])
                                                       : dmr_failure_main[i]) ;

        assign dmr_backup_regfile_we_a [i] = backup_regfile_wport_i[dmr_core_id(i, 0)].we_a
                                       & backup_regfile_wport_i[dmr_core_id(i, 1)].we_a
                                       & ~dmr_failure [i];

        assign dmr_backup_regfile_we_b [i] = backup_regfile_wport_i[dmr_core_id(i, 0)].we_b
                                       & backup_regfile_wport_i[dmr_core_id(i, 1)].we_b
                                       & ~dmr_failure [i];

      end else begin : gen_standard_failure
        assign dmr_failure [i] = dmr_data_req_out [i] ? (dmr_failure_main[i] | dmr_failure_data[i])
                                                      : dmr_failure_main[i];
      end
    end
  end else begin: gen_no_dmr_checkers
    assign dmr_failure_main = '0;
    assign dmr_failure_data = '0;
    assign dmr_failure      = '0;
    assign dmr_incr_mismatches = '0;
    assign main_dmr_out = '0;
    assign data_dmr_out = '0;
    assign {dmr_core_busy_out, dmr_irq_ack_out   , dmr_irq_ack_id_out,
            dmr_instr_req_out, dmr_instr_addr_out, dmr_data_req_out  ,
            dmr_data_add_out , dmr_data_wen_out  , dmr_data_wdata_out,
            dmr_data_be_out  , dmr_data_user_out}
            = '0;
    assign top_register_resps[2].rdata = '0;
    assign top_register_resps[2].error = 1'b1;
    assign top_register_resps[2].ready = 1'b1;
    assign dmr_sw_synch_req_o = '0;
  end

  // RapidRecovery output signals
  if (RapidRecovery) begin : gen_rapid_recovery
    for (genvar i = 0; i < NumBackupRegfiles; i++) begin : gen_groups
      // Write Enable signal for backup registers
      assign rapid_recovery_backup_enable[i] =
        core_in_tmr[i] ? (i < NumTMRGroups ? backup_enable[i] : 1'b0) // TMR mode
      : core_in_dmr[i] ? (backup_enable[i] & ~dmr_failure[i] ) // DMR mode
      : 1'b1;                                                  // Independent mode
      // TODO: Only supports interleaved mode!!!



      hmr_rapid_recovery_ctrl #(
        .RFAddrWidth( RFAddrWidth )
      ) i_rapid_recovery_ctrl (
        .clk_i,
        .rst_ni,
        .start_recovery_i         ( start_recovery                 [i] ),
        .recovery_finished_o      ( recovery_finished              [i] ),
        .setback_o                ( recovery_setback_out           [i] ),
        .instr_lock_o             ( recovery_instr_lock_out        [i] ),
        .debug_req_o              ( recovery_debug_req_out         [i] ),
        .debug_halt_i             ( recovery_debug_halted_in       [i] ),
        .debug_resume_o           ( recovery_debug_resume_out      [i] ),
        .recovery_regfile_waddr_o ( core_recovery_regfile_wport_out[i] ),
        .backup_enable_o          ( backup_enable                  [i] ),
        .recover_csr_enable_o     ( recovery_csr_enable_out        [i] ),
        .recover_pc_enable_o      ( recovery_pc_enable_out         [i] ),
        .recover_rf_enable_o      ( recovery_trigger_out           [i] )
      );

      /*************************
       * Recovery CS Registers *
       *************************/
      recovery_csr #(
        .ECCEnabled ( 1 )
      ) RCSR (
        .clk_i          ( clk_i                            ),
        .rst_ni         ( rst_ni                           ),
        .read_enable_i  ( recovery_csr_enable_out [i]      ),
        .write_enable_i ( rapid_recovery_backup_enable [i] ),
        .backup_csr_i   ( backup_csr_int [i]               ),
        .recovery_csr_o ( recovery_csr_out [i]             )
      );

      /****************************
       * Recovery Program Counter *
       ****************************/
      recovery_pc #(
       .ECCEnabled ( 1 )
      ) RPC (
        // Control Ports
        .clk_i,
        .rst_ni,
        .clear_i                    ( '0                                ),
        .read_enable_i              ( recovery_pc_enable_out  [i]       ),
        .write_enable_i             ( rapid_recovery_backup_enable [i]  ),
        // Backup Ports
        .backup_program_counter_i   ( backup_program_counter_int    [i] ),
        .backup_branch_i            ( backup_branch_int             [i] ),
        .backup_branch_addr_i       ( backup_branch_addr_int        [i] ),
        // Recovery Pors
        .recovery_program_counter_o ( recovery_program_counter_out  [i] ),
        .recovery_branch_o          ( recovery_branch_out           [i] ),
        .recovery_branch_addr_o     ( recovery_branch_addr_out      [i] )
      );

      /***************************
       * Recovery Register Files *
       ***************************/
      recovery_rf  #(
       .ECCEnabled ( 1           ),
       .ADDR_WIDTH ( RFAddrWidth )
      ) RRF           (
        .clk_i,
        .rst_ni,
        .test_en_i    ( '0     ),
        //Read port A
        .raddr_a_i    ( core_recovery_regfile_wport_out[i].waddr_a ),
        .rdata_a_o    ( core_recovery_regfile_rdata_out[i].rdata_a ),
        //Read port B
        .raddr_b_i    ( core_recovery_regfile_wport_out[i].waddr_b ),
        .rdata_b_o    ( core_recovery_regfile_rdata_out[i].rdata_b ),
        //Read port C
        .raddr_c_i    ( '0 ),
        .rdata_c_o    (    ),
        // Write Port A
        .waddr_a_i    ( backup_regfile_waddr_a [i]       ),
        .wdata_a_i    ( backup_regfile_wdata_a [i]       ),
        .we_a_i       ( backup_regfile_we_a[i] &
                        rapid_recovery_backup_enable [i] ),
        // Write Port B
        .waddr_b_i    ( backup_regfile_waddr_b [i]       ),
        .wdata_b_i    ( backup_regfile_wdata_b [i]       ),
        .we_b_i       ( backup_regfile_we_b[i] &
                        rapid_recovery_backup_enable [i] )
      );

    end

    always_comb begin : proc_dmr_tmr_assignments
      backup_csr_int               = '0;
      backup_program_counter_int   = '0;
      backup_program_counter_error = '0;
      backup_branch_int            = '0;
      backup_branch_addr_int       = '0;
      backup_regfile_wdata_a       = '0;
      backup_regfile_wdata_b       = '0;
      backup_regfile_we_a          = '0;
      backup_regfile_we_b          = '0;
      backup_regfile_waddr_a       = '0;
      backup_regfile_waddr_b       = '0;
      start_recovery               = '0;
      dmr_recovery_finished        = '0;
      tmr_recovery_finished        = '0;
      recovery_debug_halted_in     = '0;

      // Continually backup master cores in interleaved mode for fast entry
      if (InterleaveGrps) begin
        for (int i = 0; i < NumBackupRegfiles; i++) begin
          backup_csr_int              [i] = backup_csr_i              [i];
          backup_program_counter_int  [i] = backup_program_counter_i [i];
          backup_branch_int           [i] = backup_branch_i          [i];
          backup_branch_addr_int      [i] = backup_branch_addr_i     [i];
          backup_regfile_wdata_a      [i] = backup_regfile_wport_i[i].wdata_a;
          backup_regfile_wdata_b      [i] = backup_regfile_wport_i[i].wdata_b;
          backup_regfile_we_a         [i] = backup_regfile_wport_i[i].we_a;
          backup_regfile_we_b         [i] = backup_regfile_wport_i[i].we_b;
          backup_regfile_waddr_a      [i] = backup_regfile_wport_i[i].waddr_a;
          backup_regfile_waddr_b      [i] = backup_regfile_wport_i[i].waddr_b;
        end
      end

      for (int i = 0; i < NumDMRGroups; i++) begin
        if ((DMRFixed || (DMRSupported && ~dmr_grp_in_independent[i])) &&
            dmr_core_rapid_recovery_en[dmr_core_id(i, 0)]) begin
          backup_csr_int              [dmr_shared_id(i)] = dmr_backup_csr [i];
          backup_program_counter_int  [dmr_shared_id(i)] = dmr_backup_program_counter      [i];
          // backup_program_counter_error[dmr_shared_id(i)] = dmr_backup_program_counter_error[i];
          backup_branch_int           [dmr_shared_id(i)] = dmr_backup_branch_int           [i];
          backup_branch_addr_int      [dmr_shared_id(i)] = dmr_backup_branch_addr_int      [i];
          backup_regfile_wdata_a      [dmr_shared_id(i)] = dmr_backup_regfile_wdata_a      [i];
          backup_regfile_wdata_b      [dmr_shared_id(i)] = dmr_backup_regfile_wdata_b      [i];
          backup_regfile_we_a         [dmr_shared_id(i)] = dmr_backup_regfile_we_a         [i];
          backup_regfile_we_b         [dmr_shared_id(i)] = dmr_backup_regfile_we_b         [i];
          backup_regfile_waddr_a      [dmr_shared_id(i)] = dmr_backup_regfile_waddr_a      [i];
          backup_regfile_waddr_b      [dmr_shared_id(i)] = dmr_backup_regfile_waddr_b      [i];
          start_recovery              [dmr_shared_id(i)] = dmr_start_recovery              [i];
          dmr_recovery_finished[i] = recovery_finished[dmr_shared_id(i)];
          recovery_debug_halted_in    [dmr_shared_id(i)] =
                core_debug_halted_i [dmr_core_id(dmr_group_id(i), 0)]
              & core_debug_halted_i [dmr_core_id(dmr_group_id(i), 1)];
        end
      end

      for (int i = 0; i < NumTMRGroups; i++) begin
        if ((TMRFixed || (TMRSupported && ~tmr_grp_in_independent[i])) &&
            tmr_core_rapid_recovery_en[tmr_core_id(i, 0)]) begin
          backup_csr_int              [tmr_shared_id(i)] = tmr_backup_csr [i];
          backup_program_counter_int  [tmr_shared_id(i)] = tmr_backup_program_counter      [i];
          backup_branch_int           [tmr_shared_id(i)] = tmr_backup_branch_int           [i];
          backup_branch_addr_int      [tmr_shared_id(i)] = tmr_backup_branch_addr_int      [i];
          backup_regfile_wdata_a      [tmr_shared_id(i)] = tmr_backup_regfile_wdata_a      [i];
          backup_regfile_wdata_b      [tmr_shared_id(i)] = tmr_backup_regfile_wdata_b      [i];
          backup_regfile_we_a         [tmr_shared_id(i)] = tmr_backup_regfile_we_a         [i];
          backup_regfile_we_b         [tmr_shared_id(i)] = tmr_backup_regfile_we_b         [i];
          backup_regfile_waddr_a      [tmr_shared_id(i)] = tmr_backup_regfile_waddr_a      [i];
          backup_regfile_waddr_b      [tmr_shared_id(i)] = tmr_backup_regfile_waddr_b      [i];
          start_recovery              [tmr_shared_id(i)] = tmr_start_recovery              [i];
          tmr_recovery_finished[i] = recovery_finished[tmr_shared_id(i)];
          recovery_debug_halted_in    [tmr_shared_id(i)] =
                core_debug_halted_i [tmr_core_id(tmr_group_id(i), 0)]
              & core_debug_halted_i [tmr_core_id(tmr_group_id(i), 1)]
              & core_debug_halted_i [tmr_core_id(tmr_group_id(i), 2)];
        end
      end
    end

    for (genvar i = 0; i < NumCores; i++) begin : gen_cores
      always_comb begin
        if ((DMRFixed || (DMRSupported && core_in_dmr[i])) && dmr_core_rapid_recovery_en[i]) begin

          core_debug_resume_o [i] = recovery_debug_resume_out    [dmr_shared_id(dmr_group_id(i))];

          // Setback
          core_recover_o      [i] = recovery_trigger_out         [dmr_shared_id(dmr_group_id(i))];
          core_instr_lock_o   [i] = recovery_instr_lock_out      [dmr_shared_id(dmr_group_id(i))];

          // CSRs
          recovery_csr_o      [i] = recovery_csr_out             [dmr_shared_id(dmr_group_id(i))];

          // PC
          pc_recover_o        [i] = recovery_pc_enable_out       [dmr_shared_id(dmr_group_id(i))];
          recovery_program_counter_o [i] =
            recovery_program_counter_out [dmr_shared_id(dmr_group_id(i))];
          recovery_branch_o   [i] = recovery_branch_out          [dmr_shared_id(dmr_group_id(i))];
          recovery_branch_addr_o [i] = recovery_branch_addr_out  [dmr_shared_id(dmr_group_id(i))];

          // RF
          core_recovery_regfile_wport_o[i].we_a    =
            core_recovery_regfile_wport_out[dmr_shared_id(dmr_group_id(i))].we_a;
          core_recovery_regfile_wport_o[i].waddr_a =
            core_recovery_regfile_wport_out[dmr_shared_id(dmr_group_id(i))].waddr_a;
          core_recovery_regfile_wport_o[i].wdata_a =
            core_recovery_regfile_rdata_out[dmr_shared_id(dmr_group_id(i))].rdata_a;
          core_recovery_regfile_wport_o[i].we_b    =
            core_recovery_regfile_wport_out[dmr_shared_id(dmr_group_id(i))].we_b;
          core_recovery_regfile_wport_o[i].waddr_b =
            core_recovery_regfile_wport_out[dmr_shared_id(dmr_group_id(i))].waddr_b;
          core_recovery_regfile_wport_o[i].wdata_b =
            core_recovery_regfile_rdata_out[dmr_shared_id(dmr_group_id(i))].rdata_b;

        end else if ((TMRFixed || (TMRSupported && core_in_tmr[i])) &&
                     tmr_core_rapid_recovery_en[i]) begin
          core_debug_resume_o [i] = recovery_debug_resume_out    [tmr_shared_id(tmr_group_id(i))];

          // Setback
          core_recover_o      [i] = recovery_trigger_out         [tmr_shared_id(tmr_group_id(i))];
          core_instr_lock_o   [i] = recovery_instr_lock_out      [tmr_shared_id(tmr_group_id(i))];

          // CSRs
          recovery_csr_o      [i] = recovery_csr_out             [tmr_shared_id(tmr_group_id(i))];

          // PC
          pc_recover_o        [i] = recovery_pc_enable_out       [tmr_shared_id(tmr_group_id(i))];
          recovery_program_counter_o [i] =
            recovery_program_counter_out [tmr_shared_id(tmr_group_id(i))];
          recovery_branch_o   [i] = recovery_branch_out          [tmr_shared_id(tmr_group_id(i))];
          recovery_branch_addr_o [i] = recovery_branch_addr_out  [tmr_shared_id(tmr_group_id(i))];

          // RF
          core_recovery_regfile_wport_o[i].we_a    =
            core_recovery_regfile_wport_out[tmr_shared_id(tmr_group_id(i))].we_a;
          core_recovery_regfile_wport_o[i].waddr_a =
            core_recovery_regfile_wport_out[tmr_shared_id(tmr_group_id(i))].waddr_a;
          core_recovery_regfile_wport_o[i].wdata_a =
            core_recovery_regfile_rdata_out[tmr_shared_id(tmr_group_id(i))].rdata_a;
          core_recovery_regfile_wport_o[i].we_b    =
            core_recovery_regfile_wport_out[tmr_shared_id(tmr_group_id(i))].we_b;
          core_recovery_regfile_wport_o[i].waddr_b =
            core_recovery_regfile_wport_out[tmr_shared_id(tmr_group_id(i))].waddr_b;
          core_recovery_regfile_wport_o[i].wdata_b =
            core_recovery_regfile_rdata_out[tmr_shared_id(tmr_group_id(i))].rdata_b;

        end else begin
          // Disable RapidRecovery
          core_debug_resume_o        [i] = '0;

          // Setback
          core_recover_o             [i] = '0;
          core_instr_lock_o          [i] = '0;

          // CSRs
          recovery_csr_o             [i] = '0;

          // PC
          pc_recover_o               [i] = '0;
          recovery_program_counter_o [i] = '0;
          recovery_branch_o          [i] = '0;
          recovery_branch_addr_o     [i] = '0;

          // RF
          core_recovery_regfile_wport_o[i].we_a    = '0;
          core_recovery_regfile_wport_o[i].waddr_a = '0;
          core_recovery_regfile_wport_o[i].wdata_a = '0;
          core_recovery_regfile_wport_o[i].we_b    = '0;
          core_recovery_regfile_wport_o[i].waddr_b = '0;
          core_recovery_regfile_wport_o[i].wdata_b = '0;
        end
      end
    end

  end else begin : gen_sw_recovery
    for (genvar i = 0; i < NumCores; i++) begin : gen_cores
      // Disable RapidRecovery
      assign core_debug_resume_o        [i] = '0;

      // Setback
      assign core_recover_o             [i] = '0;
      assign core_instr_lock_o          [i] = '0;

      // CSRs
      assign recovery_csr_o             [i] = '0;

      // PC
      assign pc_recover_o               [i] = '0;
      assign recovery_program_counter_o [i] = '0;
      assign recovery_branch_o          [i] = '0;
      assign recovery_branch_addr_o     [i] = '0;

      // RF
      assign core_recovery_regfile_wport_o[i].we_a    = '0;
      assign core_recovery_regfile_wport_o[i].waddr_a = '0;
      assign core_recovery_regfile_wport_o[i].wdata_a = '0;
      assign core_recovery_regfile_wport_o[i].we_b    = '0;
      assign core_recovery_regfile_wport_o[i].waddr_b = '0;
      assign core_recovery_regfile_wport_o[i].wdata_b = '0;
    end
  end

  // Assign output signals
  if (DMRSupported && TMRSupported) begin : gen_full_HMR
    /*****************
     *** TMR & DMR ***
     *****************/
    if (TMRFixed || DMRFixed) $fatal(1, "Cannot support both TMR and DMR and fix one!");

    for (genvar i = 0; i < NumCores; i++) begin : gen_core_inputs
      localparam int unsigned TMRCoreIndex = tmr_core_id(tmr_group_id(i), 0);
      localparam int unsigned DMRCoreIndex = dmr_core_id(dmr_group_id(i), 0);

      always_comb begin
        // Special signals
        if (RapidRecovery) begin
          core_setback_o    [i] =
              tmr_setback_q   [tmr_group_id(i)][tmr_offset_id(i)]
            | dmr_setback_q   [dmr_group_id(i)][dmr_offset_id(i)]
            | (core_in_dmr[i] ? recovery_setback_out [dmr_shared_id(dmr_group_id(i))] :
              (core_in_tmr[i] ? recovery_setback_out [tmr_shared_id(tmr_group_id(i))] : '0));
        end else begin
          core_setback_o    [i] = tmr_setback_q   [tmr_group_id(i)][tmr_offset_id(i)]
                                | dmr_setback_q   [dmr_group_id(i)][dmr_offset_id(i)];
        end
        if (i >= NumTMRCores && i >= NumDMRCores) begin
          core_setback_o    [i] = '0;
        end else if (i < NumTMRCores && i >= NumDMRCores) begin
          core_setback_o    [i] = tmr_setback_q [tmr_group_id(i)][tmr_offset_id(i)] |
            (RapidRecovery ?
              (core_in_tmr[i] ? recovery_setback_out [tmr_shared_id(tmr_group_id(i))] : '0) : '0);
        end else if (i >= NumTMRCores && i < NumDMRCores) begin
          core_setback_o    [i] = dmr_setback_q [dmr_group_id(i)][dmr_offset_id(i)] |
            (RapidRecovery ?
              (core_in_dmr[i] ? recovery_setback_out [dmr_shared_id(dmr_group_id(i))] : '0) : '0);
        end
        if (i < NumTMRCores && core_in_tmr[i]) begin : tmr_mode
          // CTRL
          core_core_id_o      [i] = sys_core_id_i      [TMRCoreIndex];
          core_cluster_id_o   [i] = sys_cluster_id_i   [TMRCoreIndex];

          core_clock_en_o     [i] = sys_clock_en_i     [TMRCoreIndex];
          core_fetch_en_o     [i] = sys_fetch_en_i     [TMRCoreIndex];
          core_boot_addr_o    [i] = sys_boot_addr_i    [TMRCoreIndex];

          if (RapidRecovery) begin
            core_debug_req_o  [i] = sys_debug_req_i     [TMRCoreIndex]
                                  | recovery_debug_req_out [tmr_shared_id(tmr_group_id(i))];
          end else begin
            core_debug_req_o  [i] = sys_debug_req_i     [TMRCoreIndex];
          end
          core_perf_counters_o[i] = sys_perf_counters_i[TMRCoreIndex];

          // IRQ
          core_irq_req_o      [i] = sys_irq_req_i      [TMRCoreIndex];
          core_irq_id_o       [i] = sys_irq_id_i       [TMRCoreIndex];

          // INSTR
          core_instr_gnt_o    [i] = filt_instr_gnt    [TMRCoreIndex];
          core_instr_r_rdata_o[i] = sys_instr_r_rdata_i[TMRCoreIndex];
          core_instr_r_valid_o[i] = filt_instr_r_valid[TMRCoreIndex];
          core_instr_err_o    [i] = sys_instr_err_i    [TMRCoreIndex];

          // DATA
          core_data_gnt_o     [i] = filt_data_gnt     [TMRCoreIndex];
          core_data_r_opc_o   [i] = sys_data_r_opc_i   [TMRCoreIndex];
          core_data_r_rdata_o [i] = sys_data_r_rdata_i [TMRCoreIndex];
          core_data_r_user_o  [i] = sys_data_r_user_i  [TMRCoreIndex];
          core_data_r_valid_o [i] = filt_data_r_valid [TMRCoreIndex];
          core_data_err_o     [i] = sys_data_err_i     [TMRCoreIndex];
        end else if (i < NumDMRCores && core_in_dmr[i]) begin : dmr_mode
          // CTRL
          core_core_id_o      [i] = sys_core_id_i      [DMRCoreIndex];
          core_cluster_id_o   [i] = sys_cluster_id_i   [DMRCoreIndex];

          core_clock_en_o     [i] = sys_clock_en_i     [DMRCoreIndex];
          core_fetch_en_o     [i] = sys_fetch_en_i     [DMRCoreIndex];
          core_boot_addr_o    [i] = sys_boot_addr_i    [DMRCoreIndex];

          if (RapidRecovery) begin
            core_debug_req_o  [i] = sys_debug_req_i     [DMRCoreIndex]
                                  | recovery_debug_req_out [dmr_shared_id(dmr_group_id(i))];
          end else begin
            core_debug_req_o  [i] = sys_debug_req_i     [DMRCoreIndex];
          end
          core_perf_counters_o[i] = sys_perf_counters_i[DMRCoreIndex];

          // IRQ
          core_irq_req_o      [i] = sys_irq_req_i      [DMRCoreIndex];
          core_irq_id_o       [i] = sys_irq_id_i       [DMRCoreIndex];

          // INSTR
          core_instr_gnt_o    [i] = filt_instr_gnt    [DMRCoreIndex];
          core_instr_r_rdata_o[i] = sys_instr_r_rdata_i[DMRCoreIndex];
          core_instr_r_valid_o[i] = filt_instr_r_valid[DMRCoreIndex];
          core_instr_err_o    [i] = sys_instr_err_i    [DMRCoreIndex];

          // DATA
          core_data_gnt_o     [i] = filt_data_gnt     [DMRCoreIndex];
          core_data_r_opc_o   [i] = sys_data_r_opc_i   [DMRCoreIndex];
          core_data_r_rdata_o [i] = sys_data_r_rdata_i [DMRCoreIndex];
          core_data_r_user_o  [i] = sys_data_r_user_i  [DMRCoreIndex];
          core_data_r_valid_o [i] = filt_data_r_valid [DMRCoreIndex];
          core_data_err_o     [i] = sys_data_err_i     [DMRCoreIndex];
        end else begin : independent_mode
          // CTRL
          core_core_id_o      [i] = sys_core_id_i      [i];
          core_cluster_id_o   [i] = sys_cluster_id_i   [i];

          core_clock_en_o     [i] = sys_clock_en_i     [i];
          core_fetch_en_o     [i] = sys_fetch_en_i     [i];
          core_boot_addr_o    [i] = sys_boot_addr_i    [i];

          core_debug_req_o    [i] = sys_debug_req_i    [i];
          core_perf_counters_o[i] = sys_perf_counters_i[i];

          // IRQ
          core_irq_req_o      [i] = sys_irq_req_i      [i];
          core_irq_id_o       [i] = sys_irq_id_i       [i];

          // INSTR
          core_instr_gnt_o    [i] = filt_instr_gnt    [i];
          core_instr_r_rdata_o[i] = sys_instr_r_rdata_i[i];
          core_instr_r_valid_o[i] = filt_instr_r_valid[i];
          core_instr_err_o    [i] = sys_instr_err_i    [i];

          // DATA
          core_data_gnt_o     [i] = filt_data_gnt     [i];
          core_data_r_opc_o   [i] = sys_data_r_opc_i   [i];
          core_data_r_rdata_o [i] = sys_data_r_rdata_i [i];
          core_data_r_user_o  [i] = sys_data_r_user_i  [i];
          core_data_r_valid_o [i] = filt_data_r_valid [i];
          core_data_err_o     [i] = sys_data_err_i     [i];
        end
      end
    end

    for (genvar i = 0; i < NumSysCores/*==NumCores*/; i++) begin : gen_core_outputs
      localparam int unsigned TMRCoreIndex = tmr_group_id(i);
      localparam int unsigned DMRCoreIndex = dmr_group_id(i);
      always_comb begin
        if (i < NumTMRCores && core_in_tmr[i]) begin : tmr_mode
          if (tmr_core_id(tmr_group_id(i), 0) == i) begin : is_tmr_main_core
            // CTRL
            sys_core_busy_o     [i] = tmr_core_busy_out [TMRCoreIndex];

            // IRQ
            sys_irq_ack_o       [i] = tmr_irq_ack_out   [TMRCoreIndex];
            sys_irq_ack_id_o    [i] = tmr_irq_ack_id_out[TMRCoreIndex];

            // INSTR
            filt_instr_req     [i] = tmr_instr_req_out [TMRCoreIndex];
            filt_instr_addr    [i] = tmr_instr_addr_out[TMRCoreIndex];

            // DATA
            filt_data_req      [i] = tmr_data_req_out  [TMRCoreIndex];
            filt_data_addr      [i] = tmr_data_add_out  [TMRCoreIndex];
            filt_data_we      [i] = tmr_data_wen_out  [TMRCoreIndex];
            filt_data_data    [i] = tmr_data_wdata_out[TMRCoreIndex];
            sys_data_user_o     [i] = tmr_data_user_out [TMRCoreIndex];
            filt_data_be       [i] = tmr_data_be_out   [TMRCoreIndex];
          end else begin : disable_core // Assign disable
            // CTLR
            sys_core_busy_o     [i] = '0;

            // IRQ
            sys_irq_ack_o       [i] = '0;
            sys_irq_ack_id_o    [i] = '0;

            // INSTR
            filt_instr_req     [i] = '0;
            filt_instr_addr    [i] = '0;

            // DATA
            filt_data_req      [i] = '0;
            filt_data_addr      [i] = '0;
            filt_data_we      [i] = '0;
            filt_data_data    [i] = '0;
            sys_data_user_o     [i] = '0;
            filt_data_be       [i] = '0;
          end
        end else if (i < NumDMRCores && core_in_dmr[i]) begin : dmr_mode
          if (dmr_core_id(dmr_group_id(i), 0) == i) begin : is_dmr_main_core
            // CTRL
            sys_core_busy_o     [i] = dmr_core_busy_out [DMRCoreIndex];

            // IRQ
            sys_irq_ack_o       [i] = dmr_irq_ack_out   [DMRCoreIndex];
            sys_irq_ack_id_o    [i] = dmr_irq_ack_id_out[DMRCoreIndex];

            // INSTR
            filt_instr_req     [i] = dmr_instr_req_out [DMRCoreIndex];
            filt_instr_addr    [i] = dmr_instr_addr_out[DMRCoreIndex];

            // DATA
            filt_data_req      [i] = dmr_data_req_out  [DMRCoreIndex];
            filt_data_addr      [i] = dmr_data_add_out  [DMRCoreIndex];
            filt_data_we      [i] = dmr_data_wen_out  [DMRCoreIndex];
            filt_data_data    [i] = dmr_data_wdata_out[DMRCoreIndex];
            sys_data_user_o     [i] = dmr_data_user_out [DMRCoreIndex];
            filt_data_be       [i] = dmr_data_be_out   [DMRCoreIndex];
          end else begin : disable_core // Assign disable
            // CTLR
            sys_core_busy_o     [i] = '0;

            // IRQ
            sys_irq_ack_o       [i] = '0;
            sys_irq_ack_id_o    [i] = '0;

            // INSTR
            filt_instr_req     [i] = '0;
            filt_instr_addr    [i] = '0;

            // DATA
            filt_data_req      [i] = '0;
            filt_data_addr      [i] = '0;
            filt_data_we      [i] = '0;
            filt_data_data    [i] = '0;
            sys_data_user_o     [i] = '0;
            filt_data_be       [i] = '0;
          end
        end else begin : independent_mode
          // CTRL
          sys_core_busy_o     [i] = core_core_busy_i [i];

          // IRQ
          sys_irq_ack_o       [i] = core_irq_ack_i   [i];
          sys_irq_ack_id_o    [i] = core_irq_ack_id_i[i];

          // INSTR
          filt_instr_req     [i] = core_instr_req_i [i];
          filt_instr_addr    [i] = core_instr_addr_i[i];

          // DATA
          filt_data_req      [i] = core_data_req_i  [i];
          filt_data_addr      [i] = core_data_add_i  [i];
          filt_data_we      [i] = core_data_wen_i  [i];
          filt_data_data    [i] = core_data_wdata_i[i];
          sys_data_user_o     [i] = core_data_user_i [i];
          filt_data_be       [i] = core_data_be_i   [i];
        end
      end
    end

  end else if (TMRSupported || TMRFixed) begin : gen_TMR_only
    /*****************
     *** TMR only ***
     *****************/
    for (genvar i = 0; i < NumCores; i++) begin : gen_core_inputs
      localparam int unsigned SysCoreIndex = TMRFixed ? i/3 : tmr_core_id(tmr_group_id(i), 0);
      always_comb begin
        // Special signals
        // Setback
        if (RapidRecovery) begin
          core_setback_o    [i] = tmr_setback_q   [tmr_group_id(i)]
                                | recovery_setback_out [tmr_shared_id(tmr_group_id(i))];
        end else begin
          core_setback_o    [i] = tmr_setback_q   [tmr_group_id(i)];
        end
        if (i >= NumTMRCores) begin
          core_setback_o [i] = '0;
        end
        if (i < NumTMRCores && (TMRFixed || core_in_tmr[i])) begin : tmr_mode
          // CTRL
          core_core_id_o      [i] = sys_core_id_i      [SysCoreIndex];
          core_cluster_id_o   [i] = sys_cluster_id_i   [SysCoreIndex];

          core_clock_en_o     [i] = sys_clock_en_i     [SysCoreIndex];
          core_fetch_en_o     [i] = sys_fetch_en_i     [SysCoreIndex];
          core_boot_addr_o    [i] = sys_boot_addr_i    [SysCoreIndex];

          if (RapidRecovery) begin
            core_debug_req_o  [i] = sys_debug_req_i     [SysCoreIndex]
                                  | recovery_debug_req_out [tmr_shared_id(tmr_group_id(i))];
          end else begin
            core_debug_req_o  [i] = sys_debug_req_i     [SysCoreIndex];
          end
          core_perf_counters_o[i] = sys_perf_counters_i[SysCoreIndex];

          // IRQ
          core_irq_req_o      [i] = sys_irq_req_i      [SysCoreIndex];
          core_irq_id_o       [i] = sys_irq_id_i       [SysCoreIndex];

          // INSTR
          core_instr_gnt_o    [i] = filt_instr_gnt    [SysCoreIndex];
          core_instr_r_rdata_o[i] = sys_instr_r_rdata_i[SysCoreIndex];
          core_instr_r_valid_o[i] = filt_instr_r_valid[SysCoreIndex];
          core_instr_err_o    [i] = sys_instr_err_i    [SysCoreIndex];

          // DATA
          core_data_gnt_o     [i] = filt_data_gnt     [SysCoreIndex];
          core_data_r_opc_o   [i] = sys_data_r_opc_i   [SysCoreIndex];
          core_data_r_rdata_o [i] = sys_data_r_rdata_i [SysCoreIndex];
          core_data_r_user_o  [i] = sys_data_r_user_i  [SysCoreIndex];
          core_data_r_valid_o [i] = filt_data_r_valid [SysCoreIndex];
          core_data_err_o     [i] = sys_data_err_i     [SysCoreIndex];
        end else begin : independent_mode
          // CTRL
          core_core_id_o      [i] = sys_core_id_i      [i];
          core_cluster_id_o   [i] = sys_cluster_id_i   [i];

          core_clock_en_o     [i] = sys_clock_en_i     [i];
          core_fetch_en_o     [i] = sys_fetch_en_i     [i];
          core_boot_addr_o    [i] = sys_boot_addr_i    [i];

          core_debug_req_o    [i] = sys_debug_req_i    [i];
          core_perf_counters_o[i] = sys_perf_counters_i[i];

          // IRQ
          core_irq_req_o      [i] = sys_irq_req_i      [i];
          core_irq_id_o       [i] = sys_irq_id_i       [i];

          // INSTR
          core_instr_gnt_o    [i] = filt_instr_gnt    [i];
          core_instr_r_rdata_o[i] = sys_instr_r_rdata_i[i];
          core_instr_r_valid_o[i] = filt_instr_r_valid[i];
          core_instr_err_o    [i] = sys_instr_err_i    [i];

          // DATA
          core_data_gnt_o     [i] = filt_data_gnt     [i];
          core_data_r_opc_o   [i] = sys_data_r_opc_i   [i];
          core_data_r_rdata_o [i] = sys_data_r_rdata_i [i];
          core_data_r_user_o  [i] = sys_data_r_user_i  [i];
          core_data_r_valid_o [i] = filt_data_r_valid [i];
          core_data_err_o     [i] = sys_data_err_i     [i];
        end
      end
    end

    for (genvar i = 0; i < NumSysCores; i++) begin : gen_core_outputs
      localparam int unsigned CoreCoreIndex = TMRFixed ? i : tmr_group_id(i);
      if (TMRFixed && i < NumTMRGroups) begin : gen_fixed_tmr
        // CTRL
        assign sys_core_busy_o     [i] = tmr_core_busy_out[CoreCoreIndex];

        // IRQ
        assign sys_irq_ack_o       [i] = tmr_irq_ack_out   [CoreCoreIndex];
        assign sys_irq_ack_id_o    [i] = tmr_irq_ack_id_out[CoreCoreIndex];

        // INSTR
        assign filt_instr_req     [i] = tmr_instr_req_out [CoreCoreIndex];
        assign filt_instr_addr    [i] = tmr_instr_addr_out[CoreCoreIndex];

        // DATA
        assign filt_data_req      [i] = tmr_data_req_out  [CoreCoreIndex];
        assign filt_data_addr      [i] = tmr_data_add_out  [CoreCoreIndex];
        assign filt_data_we      [i] = tmr_data_wen_out  [CoreCoreIndex];
        assign filt_data_data    [i] = tmr_data_wdata_out[CoreCoreIndex];
        assign sys_data_user_o     [i] = tmr_data_user_out [CoreCoreIndex];
        assign filt_data_be       [i] = tmr_data_be_out   [CoreCoreIndex];
      end else begin : gen_normal_tmr
        if (i >= NumTMRCores) begin : gen_independent_stragglers
          // CTRL
          assign sys_core_busy_o     [i] =
            core_core_busy_i [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];

          // IRQ
          assign sys_irq_ack_o       [i] =
            core_irq_ack_i   [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign sys_irq_ack_id_o    [i] =
            core_irq_ack_id_i[TMRFixed ? i-NumTMRGroups+NumTMRCores : i];

          // INSTR
          assign filt_instr_req     [i] =
            core_instr_req_i [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_instr_addr    [i] =
            core_instr_addr_i[TMRFixed ? i-NumTMRGroups+NumTMRCores : i];

          // DATA
          assign filt_data_req      [i] =
            core_data_req_i  [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_addr     [i] =
            core_data_add_i  [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_we       [i] =
            core_data_wen_i  [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_data     [i] =
            core_data_wdata_i[TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign sys_data_user_o    [i] =
            core_data_user_i [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_be       [i] =
            core_data_be_i   [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
        end else begin : gen_tmr_normal
          always_comb begin
            if (core_in_tmr[i]) begin : tmr_mode
              if (tmr_core_id(tmr_group_id(i), 0) == i) begin : is_tmr_main_core
                // CTRL
                sys_core_busy_o     [i] = tmr_core_busy_out[CoreCoreIndex];

                // IRQ
                sys_irq_ack_o       [i] = tmr_irq_ack_out   [CoreCoreIndex];
                sys_irq_ack_id_o    [i] = tmr_irq_ack_id_out[CoreCoreIndex];

                // INSTR
                filt_instr_req     [i] = tmr_instr_req_out [CoreCoreIndex];
                filt_instr_addr    [i] = tmr_instr_addr_out[CoreCoreIndex];

                // DATA
                filt_data_req      [i] = tmr_data_req_out  [CoreCoreIndex];
                filt_data_addr     [i] = tmr_data_add_out  [CoreCoreIndex];
                filt_data_we       [i] = tmr_data_wen_out  [CoreCoreIndex];
                filt_data_data     [i] = tmr_data_wdata_out[CoreCoreIndex];
                sys_data_user_o    [i] = tmr_data_user_out [CoreCoreIndex];
                filt_data_be       [i] = tmr_data_be_out   [CoreCoreIndex];
              end else begin : disable_core // Assign disable
                // CTLR
                sys_core_busy_o     [i] = '0;

                // IRQ
                sys_irq_ack_o       [i] = '0;
                sys_irq_ack_id_o    [i] = '0;

                // INSTR
                filt_instr_req     [i] = '0;
                filt_instr_addr    [i] = '0;

                // DATA
                filt_data_req      [i] = '0;
                filt_data_addr      [i] = '0;
                filt_data_we      [i] = '0;
                filt_data_data    [i] = '0;
                sys_data_user_o     [i] = '0;
                filt_data_be       [i] = '0;
              end
            end else begin : independent_mode
              // CTRL
              sys_core_busy_o     [i] = core_core_busy_i [i];

              // IRQ
              sys_irq_ack_o       [i] = core_irq_ack_i   [i];
              sys_irq_ack_id_o    [i] = core_irq_ack_id_i[i];

              // INSTR
              filt_instr_req      [i] = core_instr_req_i [i];
              filt_instr_addr     [i] = core_instr_addr_i[i];

              // DATA
              filt_data_req       [i] = core_data_req_i  [i];
              filt_data_addr      [i] = core_data_add_i  [i];
              filt_data_we        [i] = core_data_wen_i  [i];
              filt_data_data      [i] = core_data_wdata_i[i];
              sys_data_user_o     [i] = core_data_user_i [i];
              filt_data_be        [i] = core_data_be_i   [i];
            end
          end
        end
      end
    end

  end else if (DMRSupported || DMRFixed) begin : gen_DMR_only
    /*****************
     *** DMR only ***
     *****************/
    if (DMRFixed && NumCores % 2 != 0) $warning("Extra cores added not properly handled! :)");
    // Binding DMR outputs to zero for now
    assign dmr_failure_o     = '0;
    assign dmr_error_o       = '0;
    // assign dmr_resynch_req_o = '0;

    for (genvar i = 0; i < NumCores; i++) begin : gen_core_inputs
      localparam int unsigned SysCoreIndex = DMRFixed ? i/2 : dmr_core_id(dmr_group_id(i), 0);
      always_comb begin
        // Setback
        if (RapidRecovery) begin
          core_setback_o    [i] = dmr_setback_q[dmr_group_id(i)][dmr_offset_id(i)]
                                | recovery_setback_out [dmr_shared_id(dmr_group_id(i))];
        end else begin
          core_setback_o    [i] = '0;
        end
        if (i >= NumDMRCores) begin
          core_setback_o    [i] = '0;
        end
        if (i < NumDMRCores && (DMRFixed || core_in_dmr[i])) begin : dmr_mode
          // CTRL
          core_core_id_o      [i] = sys_core_id_i       [SysCoreIndex];
          core_cluster_id_o   [i] = sys_cluster_id_i    [SysCoreIndex];

          core_clock_en_o   [i] = sys_clock_en_i      [SysCoreIndex];
          core_fetch_en_o     [i] = sys_fetch_en_i      [SysCoreIndex];
          core_boot_addr_o    [i] = sys_boot_addr_i     [SysCoreIndex];

          if (RapidRecovery) begin
            core_debug_req_o  [i] = sys_debug_req_i     [SysCoreIndex]
                                  | recovery_debug_req_out [dmr_shared_id(dmr_group_id(i))];
          end else begin
            core_debug_req_o  [i] = sys_debug_req_i     [SysCoreIndex];
          end
          core_perf_counters_o[i] = sys_perf_counters_i [SysCoreIndex];

          // IRQ
          core_irq_req_o      [i] = sys_irq_req_i       [SysCoreIndex];
          core_irq_id_o       [i] = sys_irq_id_i        [SysCoreIndex];

          // INSTR
          core_instr_gnt_o    [i] = filt_instr_gnt     [SysCoreIndex];
          core_instr_r_rdata_o[i] = sys_instr_r_rdata_i [SysCoreIndex];
          core_instr_r_valid_o[i] = filt_instr_r_valid [SysCoreIndex];
          core_instr_err_o    [i] = sys_instr_err_i     [SysCoreIndex];

          // DATA
          core_data_gnt_o     [i] = filt_data_gnt      [SysCoreIndex];
          core_data_r_opc_o   [i] = sys_data_r_opc_i    [SysCoreIndex];
          core_data_r_rdata_o [i] = sys_data_r_rdata_i  [SysCoreIndex];
          core_data_r_user_o  [i] = sys_data_r_user_i   [SysCoreIndex];
          core_data_r_valid_o [i] = filt_data_r_valid  [SysCoreIndex];
          core_data_err_o     [i] = sys_data_err_i      [SysCoreIndex];
        end else begin : gen_independent_mode
          // CTRL
          core_core_id_o      [i] = sys_core_id_i      [i];
          core_cluster_id_o   [i] = sys_cluster_id_i   [i];

          core_clock_en_o     [i] = sys_clock_en_i     [i];
          core_fetch_en_o     [i] = sys_fetch_en_i     [i];
          core_boot_addr_o    [i] = sys_boot_addr_i    [i];

          core_debug_req_o    [i] = sys_debug_req_i    [i];
          core_perf_counters_o[i] = sys_perf_counters_i[i];

          // IRQ
          core_irq_req_o      [i] = sys_irq_req_i      [i];
          core_irq_id_o       [i] = sys_irq_id_i       [i];

          // INSTR
          core_instr_gnt_o    [i] = filt_instr_gnt    [i];
          core_instr_r_rdata_o[i] = sys_instr_r_rdata_i[i];
          core_instr_r_valid_o[i] = filt_instr_r_valid[i];
          core_instr_err_o    [i] = sys_instr_err_i    [i];

          // DATA
          core_data_gnt_o     [i] = filt_data_gnt     [i];
          core_data_r_opc_o   [i] = sys_data_r_opc_i   [i];
          core_data_r_rdata_o [i] = sys_data_r_rdata_i [i];
          core_data_r_user_o  [i] = sys_data_r_user_i  [i];
          core_data_r_valid_o [i] = filt_data_r_valid [i];
          core_data_err_o     [i] = sys_data_err_i     [i];
        end
      end
    end // gen_core_inputs

    for (genvar i = 0; i < NumSysCores; i++) begin : gen_core_outputs
      localparam int unsigned CoreCoreIndex = DMRFixed ? i : dmr_group_id(i);
      if (DMRFixed && i < NumDMRGroups) begin : gen_fixed_dmr
        // CTRL
        assign sys_core_busy_o     [i] = dmr_core_busy_out[CoreCoreIndex];

        // IRQ
        assign sys_irq_ack_o       [i] = dmr_irq_ack_out   [CoreCoreIndex];
        assign sys_irq_ack_id_o    [i] = dmr_irq_ack_id_out[CoreCoreIndex];

        // INSTR
        assign filt_instr_req     [i] = dmr_instr_req_out [CoreCoreIndex];
        assign filt_instr_addr    [i] = dmr_instr_addr_out[CoreCoreIndex];

        // DATA
        assign filt_data_req      [i] = dmr_data_req_out  [CoreCoreIndex];
        assign filt_data_addr      [i] = dmr_data_add_out  [CoreCoreIndex];
        assign filt_data_we      [i] = dmr_data_wen_out  [CoreCoreIndex];
        assign filt_data_data    [i] = dmr_data_wdata_out[CoreCoreIndex];
        assign sys_data_user_o     [i] = dmr_data_user_out [CoreCoreIndex];
        assign filt_data_be       [i] = dmr_data_be_out   [CoreCoreIndex];
      end else begin : gen_normal_dmr
        if (i >= NumDMRCores) begin : gen_independent_stragglers
          // CTRL
          assign sys_core_busy_o     [i] =
            dmr_core_busy_out [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];

          // IRQ
          assign sys_irq_ack_o       [i] =
            dmr_irq_ack_out   [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign sys_irq_ack_id_o    [i] =
            dmr_irq_ack_id_out[TMRFixed ? i-NumTMRGroups+NumTMRCores : i];

          // INSTR
          assign filt_instr_req     [i] =
            dmr_instr_req_out [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_instr_addr    [i] =
            dmr_instr_addr_out[TMRFixed ? i-NumTMRGroups+NumTMRCores : i];

          // DATA
          assign filt_data_req      [i] =
            dmr_data_req_out  [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_addr     [i] =
            dmr_data_add_out  [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_we       [i] =
            dmr_data_wen_out  [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_data     [i] =
            dmr_data_wdata_out[TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign sys_data_user_o    [i] =
            dmr_data_user_out [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign filt_data_be       [i] =
            dmr_data_be_out   [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
        end else begin : gen_dmr_normal
          always_comb begin
            if (core_in_dmr[i]) begin : dmr_mode
              if (dmr_core_id(dmr_group_id(i), 0) == i) begin : is_dmr_main_core
                // CTRL
                sys_core_busy_o     [i] = dmr_core_busy_out[CoreCoreIndex];

                // IRQ
                sys_irq_ack_o       [i] = dmr_irq_ack_out   [CoreCoreIndex];
                sys_irq_ack_id_o    [i] = dmr_irq_ack_id_out[CoreCoreIndex];

                // INSTR
                filt_instr_req     [i] = dmr_instr_req_out [CoreCoreIndex];
                filt_instr_addr    [i] = dmr_instr_addr_out[CoreCoreIndex];

                // DATA
                filt_data_req      [i] = dmr_data_req_out  [CoreCoreIndex];
                filt_data_addr     [i] = dmr_data_add_out  [CoreCoreIndex];
                filt_data_we       [i] = dmr_data_wen_out  [CoreCoreIndex];
                filt_data_data     [i] = dmr_data_wdata_out[CoreCoreIndex];
                sys_data_user_o    [i] = dmr_data_user_out [CoreCoreIndex];
                filt_data_be       [i] = dmr_data_be_out   [CoreCoreIndex];
              end else begin : disable_core // Assign disable
                // CTLR
                sys_core_busy_o     [i] = '0;

                // IRQ
                sys_irq_ack_o       [i] = '0;
                sys_irq_ack_id_o    [i] = '0;

                // INSTR
                filt_instr_req     [i] = '0;
                filt_instr_addr    [i] = '0;

                // DATA
                filt_data_req      [i] = '0;
                filt_data_addr     [i] = '0;
                filt_data_we       [i] = '0;
                filt_data_data     [i] = '0;
                sys_data_user_o    [i] = '0;
                filt_data_be       [i] = '0;
              end
            end else begin : independent_mode
              // CTRL
              sys_core_busy_o     [i] = core_core_busy_i [i];

              // IRQ
              sys_irq_ack_o       [i] = core_irq_ack_i   [i];
              sys_irq_ack_id_o    [i] = core_irq_ack_id_i[i];

              // INSTR
              filt_instr_req     [i] = core_instr_req_i [i];
              filt_instr_addr    [i] = core_instr_addr_i[i];

              // DATA
              filt_data_req      [i] = core_data_req_i  [i];
              filt_data_addr     [i] = core_data_add_i  [i];
              filt_data_we       [i] = core_data_wen_i  [i];
              filt_data_data     [i] = core_data_wdata_i[i];
              sys_data_user_o    [i] = core_data_user_i [i];
              filt_data_be       [i] = core_data_be_i   [i];
            end
          end
        end
      end
    end

  end else begin : gen_no_redundancy
    /*****************
     *** none ***
     *****************/
    // Direct assignment, disable all
    assign core_setback_o       = '0;

    // CTRL
    assign core_core_id_o       = sys_core_id_i;
    assign core_cluster_id_o    = sys_cluster_id_i;

    assign core_clock_en_o      = sys_clock_en_i;
    assign core_fetch_en_o      = sys_fetch_en_i;
    assign core_boot_addr_o     = sys_boot_addr_i;
    assign sys_core_busy_o      = core_core_busy_i;

    assign core_debug_req_o     = sys_debug_req_i;
    assign core_perf_counters_o = sys_perf_counters_i;

    // IRQ
    assign core_irq_req_o       = sys_irq_req_i;
    assign sys_irq_ack_o        = core_irq_ack_i;
    assign core_irq_id_o        = sys_irq_id_i;
    assign sys_irq_ack_id_o     = core_irq_ack_id_i;

    // INSTR
    assign filt_instr_req      = core_instr_req_i;
    assign core_instr_gnt_o     = filt_instr_gnt;
    assign filt_instr_addr     = core_instr_addr_i;
    assign core_instr_r_rdata_o = sys_instr_r_rdata_i;
    assign core_instr_r_valid_o = filt_instr_r_valid;
    assign core_instr_err_o     = sys_instr_err_i;

    // DATA
    assign filt_data_req       = core_data_req_i;
    assign filt_data_addr       = core_data_add_i;
    assign filt_data_we       = core_data_wen_i;
    assign filt_data_data     = core_data_wdata_i;
    assign sys_data_user_o      = core_data_user_i;
    assign filt_data_be        = core_data_be_i;
    assign core_data_gnt_o      = filt_data_gnt;
    assign core_data_r_opc_o    = sys_data_r_opc_i;
    assign core_data_r_rdata_o  = sys_data_r_rdata_i;
    assign core_data_r_user_o   = sys_data_r_user_i;
    assign core_data_r_valid_o  = filt_data_r_valid;
    assign core_data_err_o      = sys_data_err_i;
  end

endmodule
