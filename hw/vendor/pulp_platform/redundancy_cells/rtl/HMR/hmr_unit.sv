// Copyright 2023 ETH Zurich and University of Bologna.
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

module hmr_unit #(
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
  /// Interleave DMR/TMR cores, alternatively with sequential grouping
  parameter  bit          InterleaveGrps = 1'b1,
  /// General core inputs wrapping struct
  parameter  type         all_inputs_t = logic,
  /// General core outputs wrapping struct
  parameter  type         nominal_outputs_t = logic,
  /// Default nominal outputs when output ports are disabled
  parameter  nominal_outputs_t DefaultNominalOutputs = '{ default: '0 },
  /// Separates voters and checkers for data, which are then only checked if data request is valid
  parameter  bit          SeparateData   = 1'b0,
  /// Number of separate voters/checkers for individual buses (requires SeparateData)
  parameter  int unsigned NumBusVoters   = 1,
  /// Bus outputs wrapping struct (requires SeparateData)
  parameter  type         bus_outputs_t  = logic,
  /// Default bus outputs when output ports are disabled (requires SeparateData)
  parameter  bus_outputs_t DefaultBusOutputs = '{ default: '0 },
  /// Register bus types
  parameter  type         reg_req_t      = logic,
  parameter  type         reg_rsp_t      = logic,
  /// Enables rapid recovery feature
  parameter  bit          RapidRecovery  = 1'b0,
  /// Address width of the core register file (in RISC-V it should be always 6) (requires RapidRecovery)
  parameter  int unsigned RfAddrWidth    = 6,
  /// System data width for boot address and checkpoint address (in RISC-V it should be generally be 32) (requires RapidRecovery)
  parameter  int unsigned SysDataWidth   = 32,
  /// Cores' backup output bus (requires RapidRecovery)
  parameter  type         core_backup_t  = logic,
  /// Rapid recovery structure (requires RapidRecovery)
  parameter  type         rapid_recovery_t = logic,
  // Local parameters depending on the above ones
  /// Number of TMR groups (virtual TMR cores)
  localparam int unsigned NumTMRGroups   = (TMRFixed || TMRSupported) ? NumCores/3 : 1,
  /// Number of physical cores used for TMR
  localparam int unsigned NumTMRCores    = NumTMRGroups * 3,
  /// Number of physical cores NOT used for TMR
  localparam int unsigned NumTMRLeftover = NumCores - NumTMRCores,
  /// Number of DMR groups (virtual DMR cores)
  localparam int unsigned NumDMRGroups   = (DMRFixed || DMRSupported) ? NumCores/2 : 1,
  /// Nubmer of physical cores used for DMR
  localparam int unsigned NumDMRCores    = NumDMRGroups * 2,
  /// Number of physical cores NOT used for DMR
  localparam int unsigned NumDMRLeftover = NumCores - NumDMRCores,
  /// Number of cores visible to the system (Fixed mode removes unneeded system ports)
  localparam int unsigned NumSysCores    = DMRFixed ? NumDMRGroups :
                                           TMRFixed ? NumTMRGroups : NumCores
) (
  input  logic      clk_i ,
  input  logic      rst_ni,

  /// Port to configuration unit
  input  reg_req_t  reg_request_i ,
  output reg_rsp_t  reg_response_o,

  /// TMR signals
  /// Indicates if the TMR group has multiple mismatches
  output logic [NumTMRGroups-1:0] tmr_failure_o    ,
  /// Indicates if the TMR group has a single mismatch
  output logic [NumTMRGroups-1:0] tmr_error_o      ,
  /// Resynchronization request interrupt per core, trigger software resynchronization
  output logic [    NumCores-1:0] tmr_resynch_req_o,
  /// Software synchronization request per core, trigger software to lock independent cores together
  output logic [    NumCores-1:0] tmr_sw_synch_req_o,
  /// External hardware to indicate the cores are synchronized and ready to lock together
  input  logic [NumTMRGroups-1:0] tmr_cores_synch_i,

  /// DMR signals
  /// Indicates if the DMR group has multiple mismatches
  output logic [NumDMRGroups-1:0] dmr_failure_o    ,

  output logic [    NumCores-1:0] dmr_resynch_req_o,
  output logic [    NumCores-1:0] dmr_sw_synch_req_o,
  input  logic [NumDMRGroups-1:0] dmr_cores_synch_i,
  output logic                    redundancy_enable_o,

  // Rapid recovery buses
  output rapid_recovery_t [NumCores-1:0] rapid_recovery_o,
  input  core_backup_t    [NumCores-1:0] core_backup_i,

  // Boot address is handled apart from other signals
  input  logic                              [SysDataWidth-1:0] sys_bootaddress_i,
  input  all_inputs_t      [NumSysCores-1:0]                   sys_inputs_i,
  output nominal_outputs_t [NumSysCores-1:0]                   sys_nominal_outputs_o,
  output bus_outputs_t     [NumSysCores-1:0][NumBusVoters-1:0] sys_bus_outputs_o,
  input  logic             [NumSysCores-1:0]                   sys_fetch_en_i,
  input  logic             [NumSysCores-1:0][NumBusVoters-1:0] enable_bus_vote_i,

  // Boot address is handled apart from other signals
  output logic             [NumCores-1:0][SysDataWidth-1:0] core_bootaddress_o,
  output logic             [NumCores-1:0]                   core_setback_o,
  output all_inputs_t      [NumCores-1:0]                   core_inputs_o,
  input  nominal_outputs_t [NumCores-1:0]                   core_nominal_outputs_i,
  input  bus_outputs_t     [NumCores-1:0][NumBusVoters-1:0] core_bus_outputs_i
);
  function automatic int max(int a, int b);
    return (a > b) ? a : b;
  endfunction

  localparam int unsigned NumBackupRegs = max(DMRSupported || DMRFixed ? NumDMRGroups : 0,
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

  nominal_outputs_t [NumTMRGroups-1:0] tmr_nominal_outputs;
  bus_outputs_t     [NumTMRGroups-1:0][NumBusVoters-1:0] tmr_bus_outputs;

  nominal_outputs_t [NumDMRGroups-1:0] dmr_nominal_outputs;
  bus_outputs_t     [NumDMRGroups-1:0][NumBusVoters-1:0] dmr_bus_outputs;
  core_backup_t     [NumDMRGroups-1:0] dmr_backup_outputs;

  logic [NumTMRGroups-1:0] tmr_failure, tmr_failure_main;
  logic [NumTMRGroups-1:0][NumBusVoters-1:0] tmr_failure_data;
  logic [NumTMRGroups-1:0][2:0] tmr_error, tmr_error_main;
  logic [NumTMRGroups-1:0][NumBusVoters-1:0][2:0] tmr_error_data;
  logic [NumTMRGroups-1:0] tmr_single_mismatch;

  logic [NumDMRGroups-1:0] dmr_failure, dmr_failure_main, dmr_failure_backup;
  logic [NumDMRGroups-1:0][NumBusVoters-1:0] dmr_failure_data;
  logic [NumDMRGroups-1:0][SysDataWidth-1:0] checkpoint_reg_q;

  /**************************
   * Rapid Recovery Signals *
   **************************/
  logic             [ NumDMRGroups-1:0] dmr_recovery_start, dmr_recovery_finished;
  logic             [ NumTMRGroups-1:0] tmr_recovery_start, tmr_recovery_finished;
  logic             [NumBackupRegs-1:0] rapid_recovery_start, rapid_recovery_finished;
  logic             [NumBackupRegs-1:0] rapid_recovery_backup_en_inp, rapid_recovery_backup_en_oup;
  logic             [NumBackupRegs-1:0] rapid_recovery_setback;
  rapid_recovery_t  [NumBackupRegs-1:0] rapid_recovery_bus;
  core_backup_t     [NumBackupRegs-1:0] rapid_recovery_backup_bus, core_backup_q;
  nominal_outputs_t [NumBackupRegs-1:0] rapid_recovery_nominal;

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

  assign tmr_failure_o = |tmr_failure;
  assign tmr_error_o = |tmr_error;
  assign dmr_failure_o = |dmr_failure;

  assign redundancy_enable_o = (|core_in_dmr) | (|core_in_tmr);

  for (genvar i = 0; i < NumCores; i++) begin : gen_global_status
    assign core_in_independent[i] = ~core_in_dmr[i] & ~core_in_tmr[i];
    assign core_in_dmr[i] = (DMRSupported || DMRFixed) && i < NumDMRCores ?
                             ~dmr_grp_in_independent[dmr_group_id(i)] : '0;
    assign core_in_tmr[i] = (TMRSupported || TMRFixed) && i < NumTMRCores ?
                             ~tmr_grp_in_independent[tmr_group_id(i)] : '0;
    assign core_en_as_master[i] =
      ((tmr_core_id(tmr_group_id(i), 0) == i || i>=NumTMRCores) ? 1'b1 : ~core_in_tmr[i]) &
      ((dmr_core_id(dmr_group_id(i), 0) == i || i>=NumDMRCores) ? 1'b1 : ~core_in_dmr[i]);
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

  reg_req_t [3:0] top_register_reqs;
  reg_rsp_t [3:0] top_register_resps;

  // 0x000-0x100 -> Top config
  // 0x100-0x200 -> Core configs
  // 0x200-0x300 -> DMR configs
  // 0x300-0x400 -> TMR configs

  reg_demux #(
    .NoPorts    ( 4 ),
    .req_t      ( reg_req_t   ),
    .rsp_t      ( reg_rsp_t   )
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
    .reg_req_t( reg_req_t ),
    .reg_rsp_t( reg_rsp_t )
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

  reg_req_t [NumCores-1:0] core_register_reqs;
  reg_rsp_t [NumCores-1:0] core_register_resps;

  // 4 words per core

  reg_demux #(
    .NoPorts    ( NumCores ),
    .req_t      ( reg_req_t   ),
    .rsp_t      ( reg_rsp_t   )
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
      .reg_rsp_t(reg_rsp_t)
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
    reg_rsp_t [NumTMRGroups-1:0] tmr_register_resps;
    logic [NumTMRGroups-1:0] tmr_sw_resynch_req, tmr_sw_synch_req;

    localparam int unsigned TMRSelWidth = $clog2(NumTMRGroups);

    /***************
     *  Registers  *
     ***************/
    if (NumTMRGroups == 1) begin : gen_single_tmr_group_reg_connect
      assign tmr_register_reqs[0] = top_register_reqs[3];
      assign top_register_resps[3] = tmr_register_resps[0];
    end else begin : gen_multi_tmr_group_reg_connect
      reg_demux #(
        .NoPorts    ( NumTMRGroups ),
        .req_t      ( reg_req_t    ),
        .rsp_t      ( reg_rsp_t   )
      ) i_reg_demux (
        .clk_i,
        .rst_ni,
        .in_select_i( top_register_reqs[3].addr[4+$clog2(NumTMRGroups)-1:4] ),
        .in_req_i   ( top_register_reqs[3]           ),
        .in_rsp_o   ( top_register_resps[3]          ),
        .out_req_o  ( tmr_register_reqs              ),
        .out_rsp_i  ( tmr_register_resps             )
      );
    end

    for (genvar i = NumTMRCores; i < NumCores; i++) begin : gen_extra_core_assigns
      assign tmr_incr_mismatches[i] = '0;
      assign tmr_sw_synch_req_o[i] = '0;
      assign tmr_resynch_req_o[i] = '0;
    end

    for (genvar i = 0; i < NumTMRGroups; i++) begin : gen_tmr_groups

      hmr_tmr_ctrl #(
        .reg_req_t      ( reg_req_t      ),
        .reg_resp_t     ( reg_rsp_t     ),
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
        .sw_resynch_req_o     ( tmr_sw_resynch_req[i] ),
        .sw_synch_req_o       ( tmr_sw_synch_req[i] ),
        .grp_in_independent_o ( tmr_grp_in_independent[i] ),
        .rapid_recovery_en_o  ( tmr_rapid_recovery_en[i] ),
        .tmr_incr_mismatches_o( {tmr_incr_mismatches[tmr_core_id(i,2)],
                                 tmr_incr_mismatches[tmr_core_id(i,1)],
                                 tmr_incr_mismatches[tmr_core_id(i,0)]} ),
        .tmr_single_mismatch_i( tmr_single_mismatch[i] ),
        .tmr_error_i          ( tmr_error[i] ),
        .tmr_failure_i        ( tmr_failure[i] ),
        .sp_store_is_zero     ( sp_store_is_zero[tmr_core_id(i, 0)] ),
        .sp_store_will_be_zero( sp_store_will_be_zero[tmr_core_id(i, 0)] ),

        .fetch_en_i           ( sys_fetch_en_i[tmr_core_id(i, 0)] ),
        .cores_synch_i        ( tmr_cores_synch_i[i] ),

        .recovery_request_o   ( tmr_recovery_start [i] ),
        .recovery_finished_i  ( tmr_recovery_finished [i] )
      );

      assign tmr_sw_synch_req_o[tmr_core_id(i, 0)] = tmr_sw_synch_req[i];
      assign tmr_sw_synch_req_o[tmr_core_id(i, 1)] = tmr_sw_synch_req[i];
      assign tmr_sw_synch_req_o[tmr_core_id(i, 2)] = tmr_sw_synch_req[i];
      assign tmr_resynch_req_o[tmr_core_id(i, 0)] = tmr_sw_resynch_req[i];
      assign tmr_resynch_req_o[tmr_core_id(i, 1)] = tmr_sw_resynch_req[i];
      assign tmr_resynch_req_o[tmr_core_id(i, 2)] = tmr_sw_resynch_req[i];

      always_comb begin
        tmr_failure[i] = tmr_failure_main[i];
        tmr_error  [i] = tmr_error_main  [i];
        for (int j = 0; j < NumBusVoters; j++) begin
          if (enable_bus_vote_i[tmr_core_id(i, 0)][j]) begin
            tmr_failure[i] = tmr_failure[i] | tmr_failure_data[i][j];
            tmr_error  [i] = tmr_error  [i] | tmr_error_data  [i][j];
          end
        end
      end
      assign tmr_single_mismatch[i] = tmr_error[i] != 3'b000;

      bitwise_TMR_voter #(
        .DataWidth( $bits(nominal_outputs_t) ),
        .VoterType( 0 )
      ) i_main_voter (
        .a_i        ( core_nominal_outputs_i[tmr_core_id(i, 0)] ),
        .b_i        ( core_nominal_outputs_i[tmr_core_id(i, 1)] ),
        .c_i        ( core_nominal_outputs_i[tmr_core_id(i, 2)] ),
        .majority_o ( tmr_nominal_outputs   [            i    ] ),
        .error_o    ( tmr_failure_main      [            i    ] ),
        .error_cba_o( tmr_error_main        [            i    ] )
      );
      if (SeparateData) begin : gen_data_voter
        for (genvar j = 0; j < NumBusVoters; j++) begin : gen_bus_voter
          bitwise_TMR_voter #(
            .DataWidth( $bits(bus_outputs_t) ),
            .VoterType( 0 )
          ) i_data_voter (
            .a_i        ( core_bus_outputs_i[tmr_core_id(i, 0)][j] ),
            .b_i        ( core_bus_outputs_i[tmr_core_id(i, 1)][j] ),
            .c_i        ( core_bus_outputs_i[tmr_core_id(i, 2)][j] ),
            .majority_o ( tmr_bus_outputs   [            i    ][j] ),
            .error_o    ( tmr_failure_data  [            i    ][j] ),
            .error_cba_o( tmr_error_data    [            i    ][j] )
          );
        end
      end else begin : gen_no_data_voter
        for (genvar j = 0; j < NumBusVoters; j++) begin : gen_tieoffs
          assign tmr_bus_outputs[i][j] = DefaultBusOutputs;
          assign tmr_failure_data[i][j] = '0;
          assign tmr_error_data[i][j] = '0;
        end
      end
    end
  end else begin : gen_no_tmr_voted
    assign tmr_error_main   = '0;
    assign tmr_error_data   = '0;
    assign tmr_error        = '0;
    assign tmr_failure_main = '0;
    assign tmr_failure_data = '0;
    assign tmr_failure      = '0;
    assign tmr_nominal_outputs = DefaultNominalOutputs;
    assign tmr_bus_outputs     = DefaultBusOutputs;
    assign top_register_resps[3].rdata = '0;
    assign top_register_resps[3].error = 1'b1;
    assign top_register_resps[3].ready = 1'b1;
    assign tmr_incr_mismatches = '0;
    assign tmr_grp_in_independent = '1;
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
    reg_rsp_t [NumDMRGroups-1:0] dmr_register_resps;
    logic [NumDMRGroups-1:0] dmr_sw_synch_req;
    logic [NumDMRGroups-1:0] dmr_sw_resynch_req;

    localparam int unsigned DMRSelWidth = $clog2(NumDMRGroups);

    /***************
     *  Registers  *
     ***************/
    if (NumDMRGroups == 1) begin : gen_single_dmr_group_reg_connect
      assign dmr_register_reqs[0] = top_register_reqs[2];
      assign top_register_resps[2] = dmr_register_resps[0];
    end else begin : gen_multi_dmr_group_reg_connect
      reg_demux #(
        .NoPorts    ( NumDMRGroups ),
        .req_t      ( reg_req_t    ),
        .rsp_t      ( reg_rsp_t   )
      ) i_reg_demux (
        .clk_i,
        .rst_ni,
        .in_select_i( top_register_reqs[2].addr[4+$clog2(NumDMRGroups)-1:4] ),
        .in_req_i   ( top_register_reqs[2]           ),
        .in_rsp_o   ( top_register_resps[2]          ),
        .out_req_o  ( dmr_register_reqs              ),
        .out_rsp_i  ( dmr_register_resps             )
      );
    end

    for (genvar i = NumDMRCores; i < NumCores; i++) begin : gen_extra_core_assigns
      assign dmr_incr_mismatches[i] = '0;
      assign dmr_sw_synch_req_o[i] = '0;
      assign dmr_resynch_req_o[i] = '0;
    end

    for (genvar i = 0; i < NumDMRGroups; i++) begin : gen_dmr_groups

      hmr_dmr_ctrl #(
        .reg_req_t     ( reg_req_t ),
        .reg_resp_t    ( reg_rsp_t ),
        .DataWidth     ( SysDataWidth ),
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
        .sw_resynch_req_o      ( dmr_sw_resynch_req    [i] ),
        .sw_synch_req_o        ( dmr_sw_synch_req      [i] ),
        .checkpoint_o          ( checkpoint_reg_q      [i] ),
        .grp_in_independent_o  ( dmr_grp_in_independent[i] ),
        .rapid_recovery_en_o   ( dmr_rapid_recovery_en [i] ),
        .dmr_incr_mismatches_o ( {dmr_incr_mismatches[dmr_core_id(i, 1)],
                                  dmr_incr_mismatches[dmr_core_id(i, 0)]} ),
        .dmr_error_i           ( dmr_failure           [i] ),

        .fetch_en_i            ( sys_fetch_en_i[dmr_core_id(i, 0)] ),
        .cores_synch_i         ( dmr_cores_synch_i[i] ),

        .recovery_request_o    ( dmr_recovery_start    [i] ),
        .recovery_finished_i   ( dmr_recovery_finished [i] )
      );

      assign dmr_sw_synch_req_o[dmr_core_id(i, 0)] = dmr_sw_synch_req[i];
      assign dmr_sw_synch_req_o[dmr_core_id(i, 1)] = dmr_sw_synch_req[i];
      assign dmr_resynch_req_o[dmr_core_id(i, 0)] = dmr_sw_resynch_req[i];
      assign dmr_resynch_req_o[dmr_core_id(i, 1)] = dmr_sw_resynch_req[i];

      /*********************
       * DMR Core Checkers *
       *********************/
      DMR_checker #(
        .check_bus_t ( nominal_outputs_t )
      ) dmr_core_checker_main (
        .clk_i   (                                           ),
        .rst_ni  (                                           ),
        .inp_a_i ( core_nominal_outputs_i[dmr_core_id(i, 0)] ),
        .inp_b_i ( core_nominal_outputs_i[dmr_core_id(i, 1)] ),
        .check_o ( dmr_nominal_outputs   [            i    ] ),
        .error_o ( dmr_failure_main      [            i    ] )
      );
      if (SeparateData) begin : gen_data_checker
        for (genvar j = 0; j < NumBusVoters; j++) begin : gen_bus_checker
          DMR_checker # (
            .check_bus_t ( bus_outputs_t )
          ) dmr_core_checker_data (
            .clk_i   (                                          ),
            .rst_ni  (                                          ),
            .inp_a_i ( core_bus_outputs_i[dmr_core_id(i, 0)][j] ),
            .inp_b_i ( core_bus_outputs_i[dmr_core_id(i, 1)][j] ),
            .check_o ( dmr_bus_outputs   [            i    ][j] ),
            .error_o ( dmr_failure_data  [            i    ][j] )
          );
        end
      end else begin: gen_no_data_checker
        assign dmr_bus_outputs  [i] = DefaultBusOutputs;
        assign dmr_failure_data [i] = '0;
      end

      if (RapidRecovery) begin : gen_rapid_recovery_unit

        DMR_checker #(
          .check_bus_t ( core_backup_t ),
          .Pipeline  ( 1                       )
        ) dmr_core_checker_backup (
          .clk_i   ( clk_i                             ),
          .rst_ni  ( rst_ni                            ),
          .inp_a_i ( core_backup_i [dmr_core_id(i, 0)] ),
          .inp_b_i ( core_backup_i [dmr_core_id(i, 1)] ),
          .check_o ( dmr_backup_outputs [       i    ] ),
          .error_o ( dmr_failure_backup [       i    ] )
        );

        assign rapid_recovery_backup_en_inp[i] =
            core_in_tmr[i] ? (i < NumTMRGroups ? rapid_recovery_backup_en_oup[i] : 1'b0)// TMR mode
          : core_in_dmr[i] ? (rapid_recovery_backup_en_oup[i] & ~dmr_failure[i] )    // DMR mode
          : 1'b1;                                                                    // Independent
        rapid_recovery_unit    #(
          .RfAddrWidth          ( RfAddrWidth                         ),
          .DataWidth            ( SysDataWidth                        ),
          .regfile_write_t      ( rapid_recovery_pkg::regfile_write_t ),
          .regfile_raddr_t      ( rapid_recovery_pkg::regfile_raddr_t ),
          .regfile_rdata_t      ( rapid_recovery_pkg::regfile_rdata_t ),
          .csr_intf_t           ( rapid_recovery_pkg::csrs_intf_t     ),
          .pc_intf_t            ( rapid_recovery_pkg::pc_intf_t       )
        ) i_rapid_recovery_unit (
          .clk_i                    ( clk_i                                       ),
          .rst_ni                   ( rst_ni                                      ),
          .core_in_independent_i    ( core_in_independent[i]                      ),
          .regfile_write_i          ( rapid_recovery_backup_bus[i].regfile_backup ),
          .backup_csr_i             ( rapid_recovery_backup_bus[i].csr_backup     ),
          .recovery_csr_o           ( rapid_recovery_bus[i].csr_recovery          ),
          .backup_pc_i              ( rapid_recovery_backup_bus[i].pc_backup      ),
          .recovery_pc_o            ( rapid_recovery_bus[i].pc_recovery           ),
          .backup_enable_i          ( rapid_recovery_backup_en_inp[i]             ),
          .start_recovery_i         ( rapid_recovery_start[i]                     ),
          .backup_enable_o          ( rapid_recovery_backup_en_oup[i]             ),
          .recovery_finished_o      ( rapid_recovery_finished[i]                  ),
          .setback_o                ( rapid_recovery_setback[i]                   ),
          .instr_lock_o             ( rapid_recovery_bus[i].instr_lock            ),
          .enable_pc_recovery_o     ( rapid_recovery_bus[i].pc_recovery_en        ),
          .enable_rf_recovery_o     ( rapid_recovery_bus[i].rf_recovery_en        ),
          .regfile_recovery_wdata_o ( rapid_recovery_bus[i].rf_recovery_wdata     ),
          .regfile_recovery_rdata_o ( rapid_recovery_bus[i].rf_recovery_rdata     ),
          .debug_halt_i             ( rapid_recovery_nominal[i].debug_halted      ),
          .debug_req_o              ( rapid_recovery_bus[i].debug_req             ),
          .debug_resume_o           ( rapid_recovery_bus[i].debug_resume          )
        );

        always_comb begin
          dmr_failure[i] = dmr_failure_main[i] | dmr_failure_backup[i];
          for (int j = 0; j < NumBusVoters; j++) begin
            if (enable_bus_vote_i[dmr_core_id(i, 0)][j]) begin
              dmr_failure[i] = dmr_failure[i] | dmr_failure_backup[i] | dmr_failure_data[i][j];
            end
          end
        end
      end else begin : gen_standard_failure
        always_comb begin
          dmr_failure[i] = dmr_failure_main[i];
          for (int j = 0; j < NumBusVoters; j++) begin
            if (enable_bus_vote_i[dmr_core_id(i, 0)][j]) begin
              dmr_failure[i] = dmr_failure[i] | dmr_failure_data[i][j];
            end
          end
        end
      end
    end
  end else begin: gen_no_dmr_checkers
    assign dmr_failure_main = '0;
    assign dmr_failure_data = '0;
    assign dmr_failure      = '0;
    assign dmr_incr_mismatches = '0;
    assign dmr_nominal_outputs = DefaultNominalOutputs;
    assign dmr_bus_outputs     = DefaultBusOutputs;
    assign top_register_resps[2].rdata = '0;
    assign top_register_resps[2].error = 1'b1;
    assign top_register_resps[2].ready = 1'b1;
    assign dmr_sw_synch_req_o = '0;
    assign dmr_resynch_req_o = '0;
    assign dmr_grp_in_independent = '1;
  end

  if (RapidRecovery) begin: gen_rapid_recovery_connection

    for (genvar i = 0; i < NumBackupRegs; i++) begin : gen_core_backup_regs
      always_ff @(posedge clk_i, negedge rst_ni) begin
        if (~rst_ni) begin
          core_backup_q[i] <= '0;
        end else begin
          core_backup_q[i] <= core_backup_i[i];
        end
      end
    end

    always_comb begin
      rapid_recovery_nominal = '0;
      rapid_recovery_backup_bus = '0;
      rapid_recovery_start   = '0;
      dmr_recovery_finished  = '0;
      tmr_recovery_finished  = '0;
      if (InterleaveGrps) begin
        for (int i = 0; i < NumBackupRegs; i++) begin
          rapid_recovery_nominal[i] = dmr_nominal_outputs[i];
          rapid_recovery_backup_bus[i] = core_backup_q[i];
          rapid_recovery_start[i]   = dmr_recovery_start[i];
          dmr_recovery_finished[i]  = rapid_recovery_finished[i];
        end
      end
      for (int i = 0; i < NumDMRGroups; i++) begin
        if ((DMRFixed || (DMRSupported && ~dmr_grp_in_independent[i])) &&
            dmr_core_rapid_recovery_en[dmr_core_id(i, 0)]) begin
          rapid_recovery_nominal[dmr_shared_id(i)] = dmr_nominal_outputs[i];
          rapid_recovery_backup_bus[dmr_shared_id(i)] = dmr_backup_outputs[i];
          rapid_recovery_start[dmr_shared_id(i)]   = dmr_recovery_start[i];
          dmr_recovery_finished[i]                 = rapid_recovery_finished[dmr_shared_id(i)];
        end
      end
      for (int i = 0; i < NumTMRGroups; i++) begin
        if ((TMRFixed || (TMRSupported && ~tmr_grp_in_independent[i])) &&
            tmr_core_rapid_recovery_en[tmr_core_id(i, 0)]) begin
          rapid_recovery_nominal[tmr_shared_id(i)] = tmr_nominal_outputs[i];
          rapid_recovery_start[tmr_shared_id(i)]   = tmr_recovery_start[i];
          tmr_recovery_finished[i]                 = rapid_recovery_finished[tmr_shared_id(i)];
        end
      end
    end
  end else begin : gen_no_recovery
    assign core_backup_q           = '0;
    assign rapid_recovery_nominal  = '0;
    assign rapid_recovery_start    = '0;
    assign tmr_recovery_finished   = '1;
    assign dmr_recovery_finished   = '1;
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
        core_bootaddress_o[i] = (checkpoint_reg_q[dmr_shared_id(dmr_group_id(i))] != '0) ?
                              checkpoint_reg_q[dmr_shared_id(dmr_group_id(i))] : sys_bootaddress_i;
        if (RapidRecovery) begin
          // $error("UNIMPLEMENTED");
          rapid_recovery_o  [i] =
            (core_in_dmr[i] ? rapid_recovery_bus [dmr_shared_id(dmr_group_id(i))] :
            (core_in_tmr[i] ? rapid_recovery_bus [tmr_shared_id(tmr_group_id(i))] : '0));

          core_setback_o    [i] = tmr_setback_q   [tmr_group_id(i)][tmr_offset_id(i)]
              | dmr_setback_q   [dmr_group_id(i)][dmr_offset_id(i)]
              | (core_in_dmr[i] ? rapid_recovery_setback [dmr_shared_id(dmr_group_id(i))] :
                (core_in_tmr[i] ? rapid_recovery_setback [tmr_shared_id(tmr_group_id(i))] : '0));
        end else begin
          core_setback_o    [i] = tmr_setback_q   [tmr_group_id(i)][tmr_offset_id(i)]
                                | dmr_setback_q   [dmr_group_id(i)][dmr_offset_id(i)];
        end
        if (i >= NumTMRCores && i >= NumDMRCores) begin
          core_setback_o    [i] = '0;
        end else if (i < NumTMRCores && i >= NumDMRCores) begin
          core_setback_o    [i] = tmr_setback_q [tmr_group_id(i)][tmr_offset_id(i)] |
            (RapidRecovery ?
              (core_in_tmr[i] ? rapid_recovery_setback [tmr_shared_id(tmr_group_id(i))] : '0) : '0);
        end else if (i >= NumTMRCores && i < NumDMRCores) begin
          core_setback_o    [i] = dmr_setback_q [dmr_group_id(i)][dmr_offset_id(i)] |
            (RapidRecovery ?
              (core_in_dmr[i] ? rapid_recovery_setback [dmr_shared_id(dmr_group_id(i))] : '0) : '0);
        end
        if (i < NumTMRCores && core_in_tmr[i]) begin : tmr_mode
          core_inputs_o[i] = sys_inputs_i[TMRCoreIndex];
        end else if (i < NumDMRCores && core_in_dmr[i]) begin : dmr_mode
          core_inputs_o[i] = sys_inputs_i[DMRCoreIndex];
        end else begin : independent_mode
          core_inputs_o[i] = sys_inputs_i[i];
        end
      end
    end

    for (genvar i = 0; i < NumSysCores/*==NumCores*/; i++) begin : gen_core_outputs
      localparam int unsigned TMRCoreIndex = tmr_group_id(i);
      localparam int unsigned DMRCoreIndex = dmr_group_id(i);
      always_comb begin
        if (i < NumTMRCores && core_in_tmr[i]) begin : tmr_mode
          if (tmr_core_id(tmr_group_id(i), 0) == i) begin : is_tmr_main_core
            sys_nominal_outputs_o[i] = tmr_nominal_outputs[TMRCoreIndex];
            sys_bus_outputs_o[i] = tmr_bus_outputs[TMRCoreIndex];
          end else begin : disable_core // Assign disable
            sys_nominal_outputs_o[i] = DefaultNominalOutputs;
            sys_bus_outputs_o[i]     = DefaultBusOutputs;
          end
        end else if (i < NumDMRCores && core_in_dmr[i]) begin : dmr_mode
          if (dmr_core_id(dmr_group_id(i), 0) == i) begin : is_dmr_main_core
            sys_nominal_outputs_o[i] = dmr_nominal_outputs[DMRCoreIndex];
            for (int j = 0; j < NumBusVoters; j++) begin
              sys_bus_outputs_o[i][j] = dmr_bus_outputs[DMRCoreIndex][j];
            end
          end else begin : disable_core // Assign disable
            sys_nominal_outputs_o[i] = DefaultNominalOutputs;
            sys_bus_outputs_o[i]     = DefaultBusOutputs;
          end
        end else begin : independent_mode
            sys_nominal_outputs_o[i] = core_nominal_outputs_i[i];
            sys_bus_outputs_o[i]     = core_bus_outputs_i[i];
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
        core_bootaddress_o[i] = (checkpoint_reg_q[dmr_shared_id(dmr_group_id(i))] != '0) ?
                            checkpoint_reg_q[dmr_shared_id(dmr_group_id(i))] : sys_bootaddress_i;
        // Setback
        if (RapidRecovery) begin
          // $error("UNIMPLEMENTED");
          rapid_recovery_o  [i] = core_in_tmr[i] ?
                                  rapid_recovery_bus [tmr_shared_id(tmr_group_id(i))] : '0;

          core_setback_o    [i] = tmr_setback_q   [tmr_group_id(i)]
                                | rapid_recovery_setback [tmr_shared_id(tmr_group_id(i))];
        end else begin
          core_setback_o    [i] = tmr_setback_q   [tmr_group_id(i)];
        end
        if (i >= NumTMRCores) begin
          core_setback_o [i] = '0;
        end
      end
      if (i < NumTMRCores && (TMRFixed || core_in_tmr[i])) begin : gen_tmr_mode
        assign core_inputs_o[i] = sys_inputs_i[SysCoreIndex];
      end else begin : gen_independent_mode
        assign core_inputs_o[i] = sys_inputs_i[i];
      end
    end

    for (genvar i = 0; i < NumSysCores; i++) begin : gen_core_outputs
      localparam int unsigned CoreCoreIndex = TMRFixed ? i : tmr_group_id(i);
      if (TMRFixed && i < NumTMRGroups) begin : gen_fixed_tmr
        assign sys_nominal_outputs_o[i] = tmr_nominal_outputs[CoreCoreIndex];
        assign sys_bus_outputs_o    [i] = tmr_bus_outputs    [CoreCoreIndex];
      end else begin : gen_not_fixed_tmr
        if (i >= NumTMRCores) begin : gen_independent_stragglers
          assign sys_nominal_outputs_o[i] =
            core_nominal_outputs_i[TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
          assign sys_bus_outputs_o    [i] =
            core_bus_outputs_i    [TMRFixed ? i-NumTMRGroups+NumTMRCores : i];
        end else begin : gen_normal_tmr
          always_comb begin
            if (core_in_tmr[i]) begin : tmr_mode
              if (tmr_core_id(tmr_group_id(i), 0) == i) begin : is_tmr_main_core
                sys_nominal_outputs_o[i] = tmr_nominal_outputs[CoreCoreIndex];
                sys_bus_outputs_o    [i] = tmr_bus_outputs    [CoreCoreIndex];
              end else begin : disable_core // Assign disable
                sys_nominal_outputs_o[i] = DefaultNominalOutputs;
                sys_bus_outputs_o    [i] = DefaultBusOutputs;
              end
            end else begin : independent_mode
              sys_nominal_outputs_o[i] = core_nominal_outputs_i[i];
              sys_bus_outputs_o    [i] = core_bus_outputs_i    [i];
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

    for (genvar i = 0; i < NumCores; i++) begin : gen_core_inputs
      localparam int unsigned SysCoreIndex = DMRFixed ? i/2 : dmr_core_id(dmr_group_id(i), 0);
      always_comb begin
        core_bootaddress_o[i] = (checkpoint_reg_q[SysCoreIndex] != '0) ?
                                checkpoint_reg_q[SysCoreIndex] : sys_bootaddress_i;
        // Setback
        if (RapidRecovery) begin
          // $error("UNIMPLEMENTED");
          rapid_recovery_o  [i] = core_in_dmr[i] ?
                                  rapid_recovery_bus [dmr_shared_id(dmr_group_id(i))] : '0;

          core_setback_o    [i] = dmr_setback_q[dmr_group_id(i)][dmr_offset_id(i)]
                                | rapid_recovery_setback [dmr_shared_id(dmr_group_id(i))];
        end else begin
          core_setback_o    [i] = dmr_setback_q[dmr_group_id(i)][dmr_offset_id(i)];
        end
        if (i >= NumDMRCores) begin
          core_setback_o    [i] = '0;
        end
        if (i < NumDMRCores && (DMRFixed || core_in_dmr[i])) begin : dmr_mode
          core_inputs_o[i] = sys_inputs_i[SysCoreIndex];
        end else begin : gen_independent_mode
          core_inputs_o[i] = sys_inputs_i[i];
        end
      end
    end // gen_core_inputs

    for (genvar i = 0; i < NumSysCores; i++) begin : gen_core_outputs
      localparam int unsigned CoreCoreIndex = DMRFixed ? i : dmr_group_id(i);
      if (DMRFixed && i < NumDMRGroups) begin : gen_fixed_dmr
        assign sys_nominal_outputs_o[i] = dmr_nominal_outputs[CoreCoreIndex];
        assign sys_bus_outputs_o    [i] = dmr_bus_outputs    [CoreCoreIndex];
      end else begin : gen_not_fixed_dmr
        if (i >= NumDMRCores) begin : gen_independent_stragglers
          assign sys_nominal_outputs_o[i] =
            core_nominal_outputs_i[DMRFixed ? i-NumDMRGroups+NumDMRCores : i];
          assign sys_bus_outputs_o    [i] =
            core_bus_outputs_i    [DMRFixed ? i-NumDMRGroups+NumDMRCores : i];
        end else begin : gen_normal_dmr
          always_comb begin
            if (core_in_dmr[i]) begin : dmr_mode
              if (dmr_core_id(dmr_group_id(i), 0) == i) begin : is_dmr_main_core
                sys_nominal_outputs_o[i] = dmr_nominal_outputs[CoreCoreIndex];
                sys_bus_outputs_o    [i] = dmr_bus_outputs    [CoreCoreIndex];
              end else begin : disable_core // Assign disable
                sys_nominal_outputs_o[i] = DefaultNominalOutputs;
                sys_bus_outputs_o    [i] = DefaultBusOutputs;
              end
            end else begin : independent_mode
              sys_nominal_outputs_o[i] = core_nominal_outputs_i[i];
              sys_bus_outputs_o    [i] = core_bus_outputs_i    [i];
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
    assign core_bootaddress_o   = sys_bootaddress_i;
    assign core_inputs_o        = sys_inputs_i;
    assign sys_nominal_outputs_o = core_nominal_outputs_i;
    assign sys_bus_outputs_o     = core_bus_outputs_i;
  end

endmodule
