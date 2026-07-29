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
  /// APB bus types for config registers
  parameter  type         apb_req_t      = logic,
  parameter  type         apb_resp_t     = logic,
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
  /// Triplicate internal control for reliability
  parameter  bit          TmrInternals     = 1'b1,
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
                                           TMRFixed ? NumTMRGroups : NumCores,
  localparam int unsigned HsWidth        = TmrInternals ? 3 : 1
) (
  input  logic      clk_i ,
  input  logic      rst_ni,

  /// Port to configuration unit
  input  apb_req_t  [HsWidth-1:0] apb_req_i ,
  output apb_resp_t [HsWidth-1:0] apb_resp_o,

  /// TMR signals
  /// Indicates if the TMR group has multiple mismatches
  output logic [HsWidth-1:0][NumTMRGroups-1:0] tmr_failure_o    ,
  /// Indicates if the TMR group has a single mismatch
  output logic [HsWidth-1:0][NumTMRGroups-1:0] tmr_error_o      ,
  /// Resynchronization request interrupt per core, trigger software resynchronization
  output logic [HsWidth-1:0][    NumCores-1:0] tmr_resynch_req_o,
  /// Software synchronization request per core, trigger software to lock independent cores together
  output logic [HsWidth-1:0][    NumCores-1:0] tmr_sw_synch_req_o,
  /// External hardware to indicate the cores are synchronized and ready to lock together
  input  logic [HsWidth-1:0][NumTMRGroups-1:0] tmr_cores_synch_i,

  /// DMR signals
  /// Indicates if the DMR group has multiple mismatches
  output logic [HsWidth-1:0][NumDMRGroups-1:0] dmr_failure_o    ,
  output logic [HsWidth-1:0][    NumCores-1:0] dmr_resynch_req_o,
  output logic [HsWidth-1:0][    NumCores-1:0] dmr_sw_synch_req_o,
  input  logic [HsWidth-1:0][NumDMRGroups-1:0] dmr_cores_synch_i,
  output logic [HsWidth-1:0]                   redundancy_enable_o,

  output logic ctrl_fault_o,

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

  logic [(NumTMRGroups*HsWidth)+1+(NumDMRGroups*HsWidth)+1-1:0] ctrl_faults;
  assign ctrl_fault_o = |ctrl_faults;

  /**************************
   * Rapid Recovery Signals *
   **************************/
  logic             [HsWidth-1:0][ NumDMRGroups-1:0] dmr_recovery_start, dmr_recovery_finished;
  logic             [HsWidth-1:0][ NumTMRGroups-1:0] tmr_recovery_start, tmr_recovery_finished;
  logic             [NumBackupRegs-1:0] rapid_recovery_start, rapid_recovery_finished;
  logic             [NumBackupRegs-1:0] rapid_recovery_backup_en_inp, rapid_recovery_backup_en_oup;
  logic             [NumBackupRegs-1:0] rapid_recovery_setback;
  rapid_recovery_t  [NumBackupRegs-1:0] rapid_recovery_bus;
  core_backup_t     [NumBackupRegs-1:0] rapid_recovery_backup_bus, core_backup_q;
  nominal_outputs_t [NumBackupRegs-1:0] rapid_recovery_nominal;

  /***************************
   *  HMR Control Registers  *
   ***************************/

  logic [HsWidth-1:0][NumCores-1:0] core_en_as_master;
  logic [HsWidth-1:0][NumCores-1:0] core_in_independent;
  logic [HsWidth-1:0][NumCores-1:0] core_in_dmr;
  logic [HsWidth-1:0][NumCores-1:0] core_in_tmr;
  logic [HsWidth-1:0][NumCores-1:0] dmr_core_rapid_recovery_en;
  logic [HsWidth-1:0][NumCores-1:0] tmr_core_rapid_recovery_en;

  logic [HsWidth-1:0][NumDMRGroups-1:0][1:0] dmr_setback_q;
  logic [NumDMRGroups-1:0][1:0] dmr_setback_q_voted;
  logic [HsWidth-1:0][NumDMRGroups-1:0] dmr_grp_in_independent;
  logic [HsWidth-1:0][NumDMRGroups-1:0] dmr_rapid_recovery_en;

  logic [HsWidth-1:0][NumTMRGroups-1:0][2:0] tmr_setback_q;
  logic [NumTMRGroups-1:0][2:0] tmr_setback_q_voted;
  logic [HsWidth-1:0][NumTMRGroups-1:0] tmr_grp_in_independent;
  logic [HsWidth-1:0][NumTMRGroups-1:0] tmr_rapid_recovery_en;

  logic [HsWidth-1:0][NumCores-1:0] sp_store_is_zero;
  logic [HsWidth-1:0][NumCores-1:0] sp_store_will_be_zero;

  assign tmr_failure_o = |tmr_failure;
  assign tmr_error_o = |tmr_error;
  assign dmr_failure_o = |dmr_failure;

  assign redundancy_enable_o = (|core_in_dmr) | (|core_in_tmr);

  for (genvar j = 0; j < HsWidth; j++) begin : gen_global_status_tmr_part
    for (genvar i = 0; i < NumCores; i++) begin : gen_global_status
      assign core_in_independent[j][i] = ~core_in_dmr[j][i] & ~core_in_tmr[j][i];
      assign core_in_dmr[j][i] = (DMRSupported || DMRFixed) && i < NumDMRCores ?
                              ~dmr_grp_in_independent[dmr_group_id(i)] : '0;
      assign core_in_tmr[j][i] = (TMRSupported || TMRFixed) && i < NumTMRCores ?
                              ~tmr_grp_in_independent[j][tmr_group_id(i)] : '0;
      assign core_en_as_master[j][i] =
        ((tmr_core_id(tmr_group_id(i), 0) == i || i>=NumTMRCores) ? 1'b1 : ~core_in_tmr[j][i]) &
        ((dmr_core_id(dmr_group_id(i), 0) == i || i>=NumDMRCores) ? 1'b1 : ~core_in_dmr[j][i]);
      assign dmr_core_rapid_recovery_en[j][i] = (DMRSupported || DMRFixed) &&
                                            i < NumDMRCores &&
                                            RapidRecovery ?
                                            dmr_rapid_recovery_en[dmr_group_id(i)] :
                                            '0;
      assign tmr_core_rapid_recovery_en[j][i] = (TMRSupported || TMRFixed) &&
                                            i < NumTMRCores &&
                                            RapidRecovery ?
                                            tmr_rapid_recovery_en[j][tmr_group_id(i)] :
                                            '0;
    end
  end

  apb_req_t  [HsWidth-1:0][3:0] top_register_reqs;
  apb_resp_t [HsWidth-1:0][3:0] top_register_resps;

  // 0x000-0x100 -> Top config
  // 0x100-0x200 -> Core configs
  // 0x200-0x300 -> DMR configs
  // 0x300-0x400 -> TMR configs

  for (genvar i = 0; i < HsWidth; i++) begin : gen_apb_demux
    apb_demux #(
      .NoMstPorts ( 4          ),
      .req_t      ( apb_req_t  ),
      .resp_t     ( apb_resp_t )
    ) i_reg_demux (
      .select_i   ( apb_req_i[i].paddr[9:8] ),
      .slv_req_i  ( apb_req_i[i]            ),
      .slv_resp_o ( apb_resp_o[i]           ),
      .mst_req_o  ( top_register_reqs[i]    ),
      .mst_resp_i ( top_register_resps[i]   )
    );
  end

  // Global config registers

  hmr_registers_reg_pkg::hmr__in_t  hmr_hw2reg [HsWidth];
  hmr_registers_reg_pkg::hmr__out_t hmr_reg2hw [HsWidth];

  for (genvar i = 0; i < HsWidth; i++) begin : gen_hmr_registers
    hmr_registers_reg_top i_hmr_registers (
      .clk           (clk_i),
      .arst_n        (rst_ni),
      .s_apb_psel    (top_register_reqs[i][0].psel),
      .s_apb_penable (top_register_reqs[i][0].penable),
      .s_apb_pwrite  (top_register_reqs[i][0].pwrite),
      .s_apb_pprot   (top_register_reqs[i][0].pprot),
      .s_apb_paddr   (top_register_reqs[i][0].paddr[4:0]),
      .s_apb_pwdata  (top_register_reqs[i][0].pwdata),
      .s_apb_pstrb   (top_register_reqs[i][0].pstrb),
      .s_apb_pready  (top_register_resps[i][0].pready),
      .s_apb_prdata  (top_register_resps[i][0].prdata),
      .s_apb_pslverr (top_register_resps[i][0].pslverr),
      .hwif_out       (hmr_reg2hw[i]),
      .hwif_in        (hmr_hw2reg[i])
    );

    always_comb begin : proc_reg_status
      hmr_hw2reg[i].avail_config.rd_data = '{default: '0};
      hmr_hw2reg[i].avail_config.rd_data.independent = ~(TMRFixed | DMRFixed);
      hmr_hw2reg[i].avail_config.rd_data.dual = DMRFixed | DMRSupported;
      hmr_hw2reg[i].avail_config.rd_data.triple = TMRFixed | TMRSupported;
      hmr_hw2reg[i].avail_config.rd_data.rapid_recovery = RapidRecovery;

      hmr_hw2reg[i].cores_en.rd_data = '{default: '0};
      hmr_hw2reg[i].cores_en.rd_data.cores_en = core_en_as_master;

      hmr_hw2reg[i].dmr_enable.rd_data = '{default: '0};
      hmr_hw2reg[i].dmr_enable.rd_data.dmr_enable[NumDMRGroups-1:0] = ~dmr_grp_in_independent;

      hmr_hw2reg[i].tmr_enable.rd_data = '{default: '0};
      hmr_hw2reg[i].tmr_enable.rd_data.tmr_enable[NumTMRGroups-1:0] = ~tmr_grp_in_independent[i];

      hmr_hw2reg[i].tmr_config.rd_data = '{default: '0};
      hmr_hw2reg[i].tmr_config.rd_data.delay_resynch = '0;
      hmr_hw2reg[i].tmr_config.rd_data.setback = '0;
      hmr_hw2reg[i].tmr_config.rd_data.reload_setback  = '0;
      hmr_hw2reg[i].tmr_config.rd_data.force_resynch = '0;
      hmr_hw2reg[i].tmr_config.rd_data.rapid_recovery = '0;

      hmr_hw2reg[i].dmr_config.rd_data = '{default: '0};
      hmr_hw2reg[i].dmr_config.rd_data.rapid_recovery = '0;
      hmr_hw2reg[i].dmr_config.rd_data.force_recovery = '0;
    end
    assign hmr_hw2reg[i].avail_config.rd_ack = hmr_reg2hw[i].avail_config.req &&
                                          !hmr_reg2hw[i].avail_config.req_is_wr;
    assign hmr_hw2reg[i].cores_en.rd_ack     = hmr_reg2hw[i].cores_en.req &&
                                          !hmr_reg2hw[i].cores_en.req_is_wr;
    assign hmr_hw2reg[i].dmr_enable.rd_ack   = hmr_reg2hw[i].dmr_enable.req &&
                                          !hmr_reg2hw[i].dmr_enable.req_is_wr;
    assign hmr_hw2reg[i].dmr_enable.wr_ack   = hmr_reg2hw[i].dmr_enable.req &&
                                            hmr_reg2hw[i].dmr_enable.req_is_wr;
    assign hmr_hw2reg[i].tmr_enable.rd_ack   = hmr_reg2hw[i].tmr_enable.req &&
                                          !hmr_reg2hw[i].tmr_enable.req_is_wr;
    assign hmr_hw2reg[i].tmr_enable.wr_ack   = hmr_reg2hw[i].tmr_enable.req &&
                                            hmr_reg2hw[i].tmr_enable.req_is_wr;

    assign hmr_hw2reg[i].tmr_config.rd_ack   = hmr_reg2hw[i].tmr_config.req &&
                                          !hmr_reg2hw[i].tmr_config.req_is_wr;
    assign hmr_hw2reg[i].tmr_config.wr_ack   = hmr_reg2hw[i].tmr_config.req &&
                                            hmr_reg2hw[i].tmr_config.req_is_wr;

    assign hmr_hw2reg[i].dmr_config.rd_ack   = hmr_reg2hw[i].dmr_config.req &&
                                          !hmr_reg2hw[i].dmr_config.req_is_wr;
    assign hmr_hw2reg[i].dmr_config.wr_ack   = hmr_reg2hw[i].dmr_config.req &&
                                            hmr_reg2hw[i].dmr_config.req_is_wr;
  end

  // Core Config Registers

  apb_req_t  [HsWidth-1:0][NumCores-1:0] core_register_reqs;
  apb_resp_t [HsWidth-1:0][NumCores-1:0] core_register_resps;
  logic [HsWidth-1:0][NumCores-1:0] tmr_incr_mismatches;
  logic [HsWidth-1:0][NumCores-1:0] dmr_incr_mismatches;

  for (genvar j = 0; j < HsWidth; j++) begin : gen_core_regs_tmr_part

    // 4 words per core
    apb_demux #(
      .NoMstPorts ( NumCores    ),
      .req_t      ( apb_req_t   ),
      .resp_t     ( apb_resp_t  )
    ) i_core_reg_demux (
      .select_i   ( top_register_reqs [j][1].paddr[4+$clog2(NumCores)-1:4] ),
      .slv_req_i  ( top_register_reqs [j][1] ),
      .slv_resp_o ( top_register_resps[j][1] ),
      .mst_req_o  ( core_register_reqs[j]    ),
      .mst_resp_i ( core_register_resps[j]   )
    );

    hmr_core_regs_reg_pkg::hmr_core__out_t core_config_reg2hw [NumCores];
    hmr_core_regs_reg_pkg::hmr_core__in_t  core_config_hw2reg [NumCores];


    for (genvar i = 0; i < NumCores; i++) begin : gen_core_registers
      hmr_core_regs_reg_top i_core_registers (
        .clk (clk_i),
        .arst_n (rst_ni),
        .s_apb_psel    ( core_register_reqs [j][i].psel ),
        .s_apb_penable ( core_register_reqs [j][i].penable ),
        .s_apb_pwrite  ( core_register_reqs [j][i].pwrite ),
        .s_apb_pprot   ( core_register_reqs [j][i].pprot ),
        .s_apb_paddr   ( core_register_reqs [j][i].paddr[3:0] ),
        .s_apb_pwdata  ( core_register_reqs [j][i].pwdata ),
        .s_apb_pstrb   ( core_register_reqs [j][i].pstrb ),
        .s_apb_pready  ( core_register_resps[j][i].pready ),
        .s_apb_prdata  ( core_register_resps[j][i].prdata ),
        .s_apb_pslverr ( core_register_resps[j][i].pslverr ),
        .hwif_out ( core_config_reg2hw [i] ),
        .hwif_in  ( core_config_hw2reg [i] )
      );

      // TODO: add reliability support for mismatches?
      assign core_config_hw2reg[i].mismatches.mismatches.next =
            core_config_reg2hw[i].mismatches.mismatches.value + 1;
      assign core_config_hw2reg[i].mismatches.mismatches.we = tmr_incr_mismatches[j][i] |
                                                              dmr_incr_mismatches[j][i];
      always_comb begin
        core_config_hw2reg[i].current_mode.rd_data = '{default: '0};
        core_config_hw2reg[i].current_mode.rd_data.independent = core_in_independent[i];
        core_config_hw2reg[i].current_mode.rd_data.dual        = core_in_dmr[i];
        core_config_hw2reg[i].current_mode.rd_data.triple      = core_in_tmr[i];
        core_config_hw2reg[i].current_mode.rd_ack = core_config_reg2hw[i].current_mode.req &&
                                                  !core_config_reg2hw[i].current_mode.req_is_wr;
      end
      assign sp_store_is_zero[j][i] = core_config_reg2hw[i].sp_store.sp_store.value == '0;
      assign sp_store_will_be_zero[j][i] = core_config_reg2hw[i].sp_store.sp_store.swmod &&
                                        core_register_reqs[j][i].pwdata == '0;
    end
  end

  /**********************************************************
   ******************** TMR Voters & Regs *******************
   **********************************************************/

  if (TMRSupported || TMRFixed) begin : gen_tmr_logic
    if (TMRFixed && NumCores % 3 != 0) $warning("Extra cores added not properly handled!");

    apb_req_t  [HsWidth-1:0][NumTMRGroups-1:0] tmr_register_reqs;
    apb_resp_t [HsWidth-1:0][NumTMRGroups-1:0] tmr_register_resps;
    logic [HsWidth-1:0][NumTMRGroups-1:0] tmr_sw_resynch_req, tmr_sw_synch_req;

    logic [HsWidth-1:0][NumTMRGroups-1:0][10:0] tmr_sync_reg;

    localparam int unsigned TMRSelWidth = $clog2(NumTMRGroups);

    for (genvar i = 0; i < NumTMRGroups; i++) begin : gen_tmr_groups
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
    /***************
     *  Registers  *
     ***************/
    for (genvar j = 0; j < HsWidth; j++) begin : gen_ctrl_tmr_part
      if (NumTMRGroups == 1) begin : gen_single_tmr_group_reg_connect
        assign tmr_register_reqs[j][0] = top_register_reqs[j][3];
        assign top_register_resps[j][3] = tmr_register_resps[j][0];
      end else begin : gen_multi_tmr_group_reg_connect
        apb_demux #(
          .NoMstPorts ( NumTMRGroups ),
          .req_t      ( apb_req_t    ),
          .resp_t     ( apb_resp_t   )
        ) i_reg_demux (
          .select_i   ( top_register_reqs[j][3].paddr[4+$clog2(NumTMRGroups)-1:4] ),
          .slv_req_i  ( top_register_reqs[j][3]  ),
          .slv_resp_o ( top_register_resps[j][3] ),
          .mst_req_o  ( tmr_register_reqs[j]     ),
          .mst_resp_i ( tmr_register_resps[j]    )
        );
      end

      for (genvar i = NumTMRCores; i < NumCores; i++) begin : gen_extra_core_assigns
        assign tmr_incr_mismatches[j][i] = '0;
        assign tmr_sw_synch_req_o[j][i] = '0;
        assign tmr_resynch_req_o[j][i] = '0;
      end

      for (genvar i = 0; i < NumTMRGroups; i++) begin : gen_tmr_groups

        hmr_tmr_ctrl #(
          .apb_req_t      ( apb_req_t      ),
          .apb_resp_t     ( apb_resp_t     ),
          .TMRFixed       ( TMRFixed       ),
          .InterleaveGrps ( InterleaveGrps ),
          .DefaultInTMR   ( 1'b0           ),
          .RapidRecovery  ( RapidRecovery  ),
          .SyncRegStates  ( TmrInternals   )
        ) i_tmr_ctrl (
          .clk_i,
          .rst_ni,

          .apb_req_i            ( tmr_register_reqs[j][i] ),
          .apb_resp_o           ( tmr_register_resps[j][i] ),

          .tmr_enable_q_i       ( hmr_reg2hw[j].tmr_enable.wr_data.tmr_enable[i] ),
          .tmr_enable_qe_i      ( hmr_reg2hw[j].tmr_enable.req &
                                  hmr_reg2hw[j].tmr_enable.req_is_wr &
                                  hmr_reg2hw[j].tmr_enable.wr_data.tmr_enable[i] ),
          .delay_resynch_q_i    ( hmr_reg2hw[j].tmr_config.wr_data.delay_resynch ),
          .delay_resynch_qe_i   ( hmr_reg2hw[j].tmr_config.req &
                                  hmr_reg2hw[j].tmr_config.req_is_wr &
                                  hmr_reg2hw[j].tmr_config.wr_data.delay_resynch ),
          .setback_q_i          ( hmr_reg2hw[j].tmr_config.wr_data.setback ),
          .setback_qe_i         ( hmr_reg2hw[j].tmr_config.req &
                                  hmr_reg2hw[j].tmr_config.req_is_wr &
                                  hmr_reg2hw[j].tmr_config.wr_data.setback ),
          .reload_setback_q_i   ( hmr_reg2hw[j].tmr_config.wr_data.reload_setback ),
          .reload_setback_qe_i  ( hmr_reg2hw[j].tmr_config.req &
                                  hmr_reg2hw[j].tmr_config.req_is_wr &
                                  hmr_reg2hw[j].tmr_config.wr_data.reload_setback ),
          .rapid_recovery_q_i   ( hmr_reg2hw[j].tmr_config.wr_data.rapid_recovery ),
          .rapid_recovery_qe_i  ( hmr_reg2hw[j].tmr_config.req &
                                  hmr_reg2hw[j].tmr_config.req_is_wr &
                                  hmr_reg2hw[j].tmr_config.wr_data.rapid_recovery ),
          .force_resynch_q_i    ( hmr_reg2hw[j].tmr_config.wr_data.force_resynch ),
          .force_resynch_qe_i   ( hmr_reg2hw[j].tmr_config.req &
                                  hmr_reg2hw[j].tmr_config.req_is_wr &
                                  hmr_reg2hw[j].tmr_config.wr_data.force_resynch ),

          .setback_o            ( tmr_setback_q[j][i] ),
          .sw_resynch_req_o     ( tmr_sw_resynch_req[j][i] ),
          .sw_synch_req_o       ( tmr_sw_synch_req[j][i] ),
          .grp_in_independent_o ( tmr_grp_in_independent[j][i] ),
          .rapid_recovery_en_o  ( tmr_rapid_recovery_en[j][i] ),
          .tmr_incr_mismatches_o( {tmr_incr_mismatches[j][tmr_core_id(i,2)],
                                  tmr_incr_mismatches[j][tmr_core_id(i,1)],
                                  tmr_incr_mismatches[j][tmr_core_id(i,0)]} ),
          .tmr_single_mismatch_i( tmr_single_mismatch[i] ),
          .tmr_error_i          ( tmr_error[i] ),
          .tmr_failure_i        ( tmr_failure[i] ),
          .sp_store_is_zero     ( sp_store_is_zero[j][tmr_core_id(i, 0)] ),
          .sp_store_will_be_zero( sp_store_will_be_zero[j][tmr_core_id(i, 0)] ),

          .fetch_en_i           ( sys_fetch_en_i[tmr_core_id(i, 0)] ),
          .cores_synch_i        ( tmr_cores_synch_i[j][i] ),

          .recovery_request_o   ( tmr_recovery_start [j][i] ),
          .recovery_finished_i  ( tmr_recovery_finished [j][i] ),

          .sync_reg_o (tmr_sync_reg[j][i]),
          .sync_reg_i ({tmr_sync_reg[(j+1)%HsWidth][i],tmr_sync_reg[(j+2)%HsWidth][i]}),
          .fault_o (ctrl_faults[HsWidth*i+j])
        );

        assign tmr_sw_synch_req_o[j][tmr_core_id(i, 0)] = tmr_sw_synch_req[j][i];
        assign tmr_sw_synch_req_o[j][tmr_core_id(i, 1)] = tmr_sw_synch_req[j][i];
        assign tmr_sw_synch_req_o[j][tmr_core_id(i, 2)] = tmr_sw_synch_req[j][i];
        assign tmr_resynch_req_o[j][tmr_core_id(i, 0)] = tmr_sw_resynch_req[j][i];
        assign tmr_resynch_req_o[j][tmr_core_id(i, 1)] = tmr_sw_resynch_req[j][i];
        assign tmr_resynch_req_o[j][tmr_core_id(i, 2)] = tmr_sw_resynch_req[j][i];

      end
    end
    if (TmrInternals) begin : gen_tmr_ctrl_vote
      bitwise_TMR_voter_fail #(
        .DataWidth( $bits(tmr_setback_q_voted) ),
        .VoterType( 1 )
      ) i_tmr_setback_voter (
        .a_i        ( tmr_setback_q[0] ),
        .b_i        ( tmr_setback_q[1] ),
        .c_i        ( tmr_setback_q[2] ),
        .majority_o ( tmr_setback_q_voted ),
        .fault_detected_o    ( ctrl_faults[HsWidth*NumTMRGroups] )
      );
    end else begin : gen_tmr_ctrl_assign
      assign tmr_setback_q_voted = tmr_setback_q[0];
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
    for (genvar j = 0; j < HsWidth; j++) begin : gen_tmr_reg_tmr_part
      apb_err_slv #(
        .req_t ( apb_req_t  ),
        .resp_t( apb_resp_t )
      ) i_apb_err_slv (
        .apb_req_i   ( top_register_reqs[j][3] ),
        .apb_resp_o  ( top_register_resps[j][3] )
      );
    end
    assign tmr_incr_mismatches = '0;
    assign tmr_grp_in_independent = '1;
    assign tmr_setback_q = '0;
    assign tmr_setback_q_voted = '0;
    assign tmr_resynch_req_o = '0;
    assign tmr_sw_synch_req_o = '0;
    assign ctrl_faults [NumTMRGroups*HsWidth-1:0] = '0;
  end

  /************************************************************
   ******************** DMR Voters and Regs *******************
   ************************************************************/

  if (DMRSupported || DMRFixed) begin: gen_dmr_logic

    apb_req_t  [HsWidth-1:0][NumDMRGroups-1:0] dmr_register_reqs;
    apb_resp_t [HsWidth-1:0][NumDMRGroups-1:0] dmr_register_resps;
    logic [HsWidth-1:0][NumDMRGroups-1:0] dmr_sw_synch_req;
    logic [HsWidth-1:0][NumDMRGroups-1:0] dmr_sw_resynch_req;

    logic [HsWidth-1:0][NumDMRGroups-1:0][38:0] dmr_sync_reg;

    localparam int unsigned DMRSelWidth = $clog2(NumDMRGroups);

    /***************
     *  Registers  *
     ***************/
    for (genvar j = 0; j < HsWidth; j++) begin : gen_dmr_ctrl_tmr_part
      if (NumDMRGroups == 1) begin : gen_single_dmr_group_reg_connect
        assign dmr_register_reqs[j][0] = top_register_reqs[j][2];
        assign top_register_resps[j][2] = dmr_register_resps[j][0];
      end else begin : gen_multi_dmr_group_reg_connect
        apb_demux #(
          .NoMstPorts ( NumDMRGroups ),
          .req_t      ( apb_req_t    ),
          .resp_t     ( apb_resp_t   )
        ) i_reg_demux (
          .select_i   ( top_register_reqs[j][2].paddr[4+$clog2(NumDMRGroups)-1:4] ),
          .slv_req_i  ( top_register_reqs[j][2]           ),
          .slv_resp_o ( top_register_resps[j][2]          ),
          .mst_req_o  ( dmr_register_reqs[j]             ),
          .mst_resp_i ( dmr_register_resps[j]             )
        );
      end

      for (genvar i = NumDMRCores; i < NumCores; i++) begin : gen_extra_core_assigns
        assign dmr_incr_mismatches[j][i] = '0;
        assign dmr_sw_synch_req_o[j][i] = '0;
        assign dmr_resynch_req_o[j][i] = '0;
      end

      for (genvar i = 0; i < NumDMRGroups; i++) begin : gen_dmr_groups

        hmr_dmr_ctrl #(
          .apb_req_t     ( apb_req_t ),
          .apb_resp_t    ( apb_resp_t ),
          .DataWidth     ( SysDataWidth ),
          .InterleaveGrps( InterleaveGrps ),
          .DMRFixed      ( DMRFixed ),
          .RapidRecovery ( RapidRecovery ),
          .DefaultInDMR  ( 1'b0 )
        ) i_dmr_ctrl (
          .clk_i,
          .rst_ni,

          .apb_req_i             ( dmr_register_reqs [j][i] ),
          .apb_resp_o            ( dmr_register_resps[j][i] ),

          .dmr_enable_q_i        ( hmr_reg2hw[j].dmr_enable.wr_data.dmr_enable[i] ),
          .dmr_enable_qe_i       ( hmr_reg2hw[j].dmr_enable.req &
                                  hmr_reg2hw[j].dmr_enable.req_is_wr &
                                  hmr_reg2hw[j].dmr_enable.wr_biten.dmr_enable[i] ),
          .rapid_recovery_q_i    ( hmr_reg2hw[j].dmr_config.wr_data.rapid_recovery ),
          .rapid_recovery_qe_i   ( hmr_reg2hw[j].dmr_config.req &
                                  hmr_reg2hw[j].dmr_config.req_is_wr &
                                  hmr_reg2hw[j].dmr_config.wr_biten.rapid_recovery ),
          .force_recovery_q_i    ( hmr_reg2hw[j].dmr_config.wr_data.force_recovery ),
          .force_recovery_qe_i   ( hmr_reg2hw[j].dmr_config.req &
                                  hmr_reg2hw[j].dmr_config.req_is_wr &
                                  hmr_reg2hw[j].dmr_config.wr_biten.force_recovery ),

          .setback_o             ( dmr_setback_q         [j][i] ),
          .sw_resynch_req_o      ( dmr_sw_resynch_req    [j][i] ),
          .sw_synch_req_o        ( dmr_sw_synch_req      [j][i] ),
          .checkpoint_o          ( checkpoint_reg_q      [i] ),
          .grp_in_independent_o  ( dmr_grp_in_independent[j][i] ),
          .rapid_recovery_en_o   ( dmr_rapid_recovery_en [j][i] ),
          .dmr_incr_mismatches_o ( {dmr_incr_mismatches[j][dmr_core_id(i, 1)],
                                    dmr_incr_mismatches[j][dmr_core_id(i, 0)]} ),
          .dmr_error_i           ( dmr_failure           [i] ),

          .fetch_en_i            ( sys_fetch_en_i[dmr_core_id(i, 0)] ),
          .cores_synch_i         ( dmr_cores_synch_i[j][i] ),

          .recovery_request_o    ( dmr_recovery_start    [j][i] ),
          .recovery_finished_i   ( dmr_recovery_finished [j][i] ),

          .sync_reg_o            ( dmr_sync_reg[j][i] ),
          .sync_reg_i            ( {dmr_sync_reg[(j+1)%HsWidth][i],
                                    dmr_sync_reg[(j+2)%HsWidth][i]} ),
          .fault_o               ( ctrl_faults[NumTMRGroups*HsWidth+1+HsWidth*i+j] )
        );

        assign dmr_sw_synch_req_o[j][dmr_core_id(i, 0)] = dmr_sw_synch_req[j][i];
        assign dmr_sw_synch_req_o[j][dmr_core_id(i, 1)] = dmr_sw_synch_req[j][i];
        assign dmr_resynch_req_o[j][dmr_core_id(i, 0)] = dmr_sw_resynch_req[j][i];
        assign dmr_resynch_req_o[j][dmr_core_id(i, 1)] = dmr_sw_resynch_req[j][i];
      end
    end

    for (genvar i = 0; i < NumDMRGroups; i++) begin : gen_dmr_groups
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
    if (TmrInternals) begin : gen_dmr_ctrl_vote
      bitwise_TMR_voter_fail #(
        .DataWidth( $bits(dmr_setback_q_voted) ),
        .VoterType( 1 )
      ) i_tmr_setback_voter (
        .a_i        ( dmr_setback_q[0] ),
        .b_i        ( dmr_setback_q[1] ),
        .c_i        ( dmr_setback_q[2] ),
        .majority_o ( dmr_setback_q_voted ),
        .fault_detected_o    ( ctrl_faults[NumTMRGroups*HsWidth+1+NumDMRGroups*HsWidth] )
      );
    end else begin : gen_tmr_ctrl_assign
      assign dmr_setback_q_voted = dmr_setback_q[0];
    end
  end else begin: gen_no_dmr_checkers
    assign dmr_failure_main = '0;
    assign dmr_failure_data = '0;
    assign dmr_failure      = '0;
    assign dmr_incr_mismatches = '0;
    assign dmr_nominal_outputs = DefaultNominalOutputs;
    assign dmr_bus_outputs     = DefaultBusOutputs;
    for (genvar i = 0; i < HsWidth; i++) begin : gen_dmr_reg_tmr_part
      apb_err_slv #(
        .req_t ( apb_req_t  ),
        .resp_t( apb_resp_t )
      ) i_apb_err_slv (
        .slv_req_i   ( top_register_reqs[i][2] ),
        .slv_resp_o  ( top_register_resps[i][2] )
      );
    end
    assign dmr_setback_q = '0;
    assign dmr_setback_q_voted = '0;
    assign dmr_sw_synch_req_o = '0;
    assign dmr_resynch_req_o = '0;
    assign dmr_grp_in_independent = '1;
  end

  // TODO TMR internals!!!
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

          core_setback_o    [i] = tmr_setback_q_voted   [tmr_group_id(i)][tmr_offset_id(i)]
              | dmr_setback_q_voted   [dmr_group_id(i)][dmr_offset_id(i)]
              | (core_in_dmr[i] ? rapid_recovery_setback [dmr_shared_id(dmr_group_id(i))] :
                (core_in_tmr[i] ? rapid_recovery_setback [tmr_shared_id(tmr_group_id(i))] : '0));
        end else begin
          core_setback_o    [i] = tmr_setback_q_voted   [tmr_group_id(i)][tmr_offset_id(i)]
                                | dmr_setback_q_voted   [dmr_group_id(i)][dmr_offset_id(i)];
        end
        if (i >= NumTMRCores && i >= NumDMRCores) begin
          core_setback_o    [i] = '0;
        end else if (i < NumTMRCores && i >= NumDMRCores) begin
          core_setback_o    [i] = tmr_setback_q_voted [tmr_group_id(i)][tmr_offset_id(i)] |
            (RapidRecovery ?
              (core_in_tmr[i] ? rapid_recovery_setback [tmr_shared_id(tmr_group_id(i))] : '0) : '0);
        end else if (i >= NumTMRCores && i < NumDMRCores) begin
          core_setback_o    [i] = dmr_setback_q_voted [dmr_group_id(i)][dmr_offset_id(i)] |
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

          core_setback_o    [i] = tmr_setback_q_voted   [tmr_group_id(i)]
                                | rapid_recovery_setback [tmr_shared_id(tmr_group_id(i))];
        end else begin
          core_setback_o    [i] = tmr_setback_q_voted   [tmr_group_id(i)];
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

          core_setback_o    [i] = dmr_setback_q_voted[dmr_group_id(i)][dmr_offset_id(i)]
                                | rapid_recovery_setback [dmr_shared_id(dmr_group_id(i))];
        end else begin
          core_setback_o    [i] = dmr_setback_q_voted[dmr_group_id(i)][dmr_offset_id(i)];
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
