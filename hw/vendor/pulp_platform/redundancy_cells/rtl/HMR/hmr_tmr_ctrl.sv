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
// Hybrid modular redundancy TMR control unit

module hmr_tmr_ctrl #(
  parameter bit  InterleaveGrps = 1'b0,
  parameter bit  TMRFixed       = 1'b0,
  parameter bit  DefaultInTMR   = TMRFixed ? 1'b1 : 1'b0,
  parameter bit  RapidRecovery  = 1'b0,
  parameter type apb_req_t      = logic,
  parameter type apb_resp_t     = logic,
  parameter bit  SyncRegStates  = 1'b0
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  // input  logic       test_enable_i,

  // Register interface
  input  apb_req_t   apb_req_i,
  output apb_resp_t  apb_resp_o,

  // CTRL from external (e.g. HMR ctrl regs)
  input  logic       tmr_enable_q_i,
  input  logic       tmr_enable_qe_i,
  input  logic       delay_resynch_q_i,
  input  logic       delay_resynch_qe_i,
  input  logic       setback_q_i,
  input  logic       setback_qe_i,
  input  logic       reload_setback_q_i,
  input  logic       reload_setback_qe_i,
  input  logic       rapid_recovery_q_i,
  input  logic       rapid_recovery_qe_i,
  input  logic       force_resynch_q_i,
  input  logic       force_resynch_qe_i,

  // TMR control signals
  output logic [2:0] setback_o,
  output logic       sw_resynch_req_o,
  output logic       sw_synch_req_o,
  output logic       grp_in_independent_o,
  output logic       rapid_recovery_en_o,
  output logic [2:0] tmr_incr_mismatches_o,
  input  logic       tmr_single_mismatch_i,
  input  logic [2:0] tmr_error_i,
  input  logic       tmr_failure_i,
  input  logic       sp_store_is_zero,
  input  logic       sp_store_will_be_zero,
  input  logic       fetch_en_i,
  input  logic       cores_synch_i,
  output logic       recovery_request_o,
  input  logic       recovery_finished_i,

  output logic      [10:0] sync_reg_o,
  input  logic [1:0][10:0] sync_reg_i,
  output logic             fault_o
);

  logic [10:0] sync_reg_voted;

  logic synch_req,   synch_req_sent_d,   synch_req_sent_q_int,   synch_req_sent_q;
  logic resynch_req, resynch_req_sent_d, resynch_req_sent_q_int, resynch_req_sent_q;
  logic cores_synch_q_int, cores_synch_q;

  typedef enum logic [2:0] {NON_TMR, TMR_RUN, TMR_UNLOAD, TMR_RELOAD, TMR_RAPID} tmr_mode_e;
  localparam tmr_mode_e DefaultTMRMode = DefaultInTMR || TMRFixed ? TMR_RUN : NON_TMR;

  hmr_tmr_regs_reg_pkg::hmr_tmr__out_t tmr_reg2hw;
  hmr_tmr_regs_reg_pkg::hmr_tmr__in_t tmr_hw2reg;

  tmr_mode_e tmr_red_mode_d, tmr_red_mode_q_int, tmr_red_mode_q;

  assign grp_in_independent_o = tmr_red_mode_q == NON_TMR;
  assign tmr_resynch_req_o = tmr_red_mode_q == TMR_UNLOAD;
  assign rapid_recovery_en_o = tmr_reg2hw.tmr_config.rapid_recovery.value & RapidRecovery;

  assign sw_synch_req_o = synch_req & ~synch_req_sent_q;
  assign synch_req_sent_d = synch_req;
  assign sw_resynch_req_o = resynch_req & ~resynch_req_sent_q;
  assign resynch_req_sent_d = resynch_req;

  hmr_tmr_regs_reg_top i_tmr_regs (
    .clk (clk_i),
    .arst_n (rst_ni),
    .s_apb_psel (apb_req_i.psel),
    .s_apb_penable (apb_req_i.penable),
    .s_apb_pwrite (apb_req_i.pwrite),
    .s_apb_pprot (apb_req_i.pprot),
    .s_apb_paddr (apb_req_i.paddr[2:0]),
    .s_apb_pwdata (apb_req_i.pwdata),
    .s_apb_pstrb (apb_req_i.pstrb),
    .s_apb_pready (apb_resp_o.pready),
    .s_apb_prdata (apb_resp_o.prdata),
    .s_apb_pslverr (apb_resp_o.pslverr),
    .hwif_in (tmr_hw2reg),
    .hwif_out (tmr_reg2hw)
  );

  // Global config update
  if (SyncRegStates) begin : gen_global_synced
    assign sync_reg_o[6] = tmr_reg2hw.tmr_enable.tmr_enable.value;
    assign sync_reg_o[7] = tmr_reg2hw.tmr_config.delay_resynch.value;
    assign sync_reg_o[8] = tmr_reg2hw.tmr_config.setback.value;
    assign sync_reg_o[9] = tmr_reg2hw.tmr_config.reload_setback.value;
    assign sync_reg_o[10] = tmr_reg2hw.tmr_config.rapid_recovery.value;
    assign tmr_hw2reg.tmr_enable.tmr_enable.we       = 1'b1;
    assign tmr_hw2reg.tmr_enable.tmr_enable.next     = tmr_enable_qe_i ? tmr_enable_q_i : sync_reg_voted[6];
    assign tmr_hw2reg.tmr_config.delay_resynch.we    = 1'b1;
    assign tmr_hw2reg.tmr_config.delay_resynch.next  = delay_resynch_qe_i ? delay_resynch_q_i : sync_reg_voted[7];
    assign tmr_hw2reg.tmr_config.setback.we          = 1'b1;
    assign tmr_hw2reg.tmr_config.setback.next        = setback_qe_i ? setback_q_i : sync_reg_voted[8];
    assign tmr_hw2reg.tmr_config.reload_setback.we   = 1'b1;
    assign tmr_hw2reg.tmr_config.reload_setback.next = reload_setback_qe_i ? reload_setback_q_i : sync_reg_voted[9];
    assign tmr_hw2reg.tmr_config.rapid_recovery.we   = 1'b1;
    assign tmr_hw2reg.tmr_config.rapid_recovery.next = rapid_recovery_qe_i ? rapid_recovery_q_i : sync_reg_voted[10];
  end else begin : gen_global_not_synced
    assign sync_reg_o[10:6] = '0;
    assign tmr_hw2reg.tmr_enable.tmr_enable.we       = tmr_enable_qe_i;
    assign tmr_hw2reg.tmr_enable.tmr_enable.next     = tmr_enable_q_i;
    assign tmr_hw2reg.tmr_config.delay_resynch.we    = delay_resynch_qe_i;
    assign tmr_hw2reg.tmr_config.delay_resynch.next  = delay_resynch_q_i;
    assign tmr_hw2reg.tmr_config.setback.we          = setback_qe_i;
    assign tmr_hw2reg.tmr_config.setback.next        = setback_q_i;
    assign tmr_hw2reg.tmr_config.reload_setback.we   = reload_setback_qe_i;
    assign tmr_hw2reg.tmr_config.reload_setback.next = reload_setback_q_i;
    assign tmr_hw2reg.tmr_config.rapid_recovery.we   = rapid_recovery_qe_i;
    assign tmr_hw2reg.tmr_config.rapid_recovery.next = rapid_recovery_q_i;
  end
  assign tmr_hw2reg.tmr_config.force_resynch.next  = force_resynch_qe_i ? force_resynch_q_i : 1'b0;

  /**************************
   *  FSM for TMR lockstep  *
   **************************/
  always_comb begin : proc_fsm
    setback_o = 3'b000;
    tmr_red_mode_d = tmr_red_mode_q;
    tmr_incr_mismatches_o = '0;
    recovery_request_o = 1'b0;
    resynch_req = 1'b0;
    synch_req = 1'b0;

    tmr_hw2reg.tmr_config.force_resynch.we = force_resynch_qe_i;

    case (tmr_red_mode_q)
      TMR_RUN: begin
        // If forced execute resynchronization
        if (tmr_reg2hw.tmr_config.force_resynch.value) begin
          tmr_hw2reg.tmr_config.force_resynch.we = 1'b1;
          if (tmr_reg2hw.tmr_config.rapid_recovery.value == 1'b1 && RapidRecovery) begin
            tmr_red_mode_d = TMR_RAPID;
          end else if (tmr_reg2hw.tmr_config.delay_resynch.value == '0) begin
            tmr_red_mode_d = TMR_UNLOAD;
            // TODO: buffer the restoration until delay_resynch is disabled
          end
        end

        // If error detected, do resynchronization
        if (tmr_single_mismatch_i) begin
          // $display("[HMR-triple] %t - mismatch detected", $realtime);
          if (tmr_error_i[0]) tmr_incr_mismatches_o[0] = 1'b1;
          if (tmr_error_i[1]) tmr_incr_mismatches_o[1] = 1'b1;
          if (tmr_error_i[2]) tmr_incr_mismatches_o[2] = 1'b1;

          if (tmr_reg2hw.tmr_config.rapid_recovery.value == 1'b1 && RapidRecovery) begin
            tmr_red_mode_d = TMR_RAPID;
          end else if (tmr_reg2hw.tmr_config.delay_resynch.value == '0) begin
            tmr_red_mode_d = TMR_UNLOAD;
            // TODO: buffer the restoration until delay_resynch is disabled
          end
        end
      end

      TMR_UNLOAD: begin
        resynch_req = 1'b1;
        // If unload complete, go to reload (and reset)
        if (!sp_store_is_zero) begin
          tmr_red_mode_d = TMR_RELOAD;
          if (tmr_reg2hw.tmr_config.setback.value) begin
            setback_o = 3'b111;
          end
        end
      end

      TMR_RELOAD: begin
        // If reload complete, finish (or reset if error happens during reload)
        if (sp_store_is_zero) begin
          // $display("[HMR-triple] %t - mismatch restored", $realtime);
          tmr_red_mode_d = TMR_RUN;
        end else begin
          if ((tmr_single_mismatch_i || tmr_failure_i) && tmr_reg2hw.tmr_config.setback.value &&
              tmr_reg2hw.tmr_config.reload_setback.value &&
              !sp_store_will_be_zero) begin
            setback_o = 3'b111;
          end
        end
      end

      TMR_RAPID: begin
        recovery_request_o = 1'b1;
        if (recovery_finished_i) begin
          // $display("[HMR-triple] %t - mismatch restored", $realtime);
          tmr_red_mode_d = TMR_RUN;
        end
      end

      // Default: do nothing
      default: ;

    endcase

    // Logic to switch in and out of TMR
    if (!TMRFixed) begin
      // Set TMR mode on external signal that cores are synchronized
      if (tmr_red_mode_q == NON_TMR && tmr_reg2hw.tmr_enable.tmr_enable.value == 1'b1) begin
        synch_req = 1'b1;
        if (cores_synch_q == 1'b1) begin
          if (tmr_reg2hw.tmr_config.rapid_recovery.value == 1'b1 && RapidRecovery) begin
            tmr_red_mode_d = TMR_RAPID;
          end else begin
            tmr_red_mode_d = TMR_RELOAD;
            if (tmr_reg2hw.tmr_config.setback.value == 1'b1) begin
              setback_o = 3'b111;
            end
          end
        end
      end
      // Before core startup: set TMR mode from reg2hw.tmr_enable
      if (fetch_en_i == 0) begin
        if (tmr_reg2hw.tmr_enable.tmr_enable.value == 1'b0) begin
          tmr_red_mode_d = NON_TMR;
        end else begin
          tmr_red_mode_d = TMR_RUN;
          synch_req = 1'b0;
        end
      end
      // split tolerant mode to performance mode anytime (but require correct core state)
      if (tmr_red_mode_q == TMR_RUN) begin
        if (tmr_reg2hw.tmr_enable.tmr_enable.value == 1'b0) begin
          if (tmr_reg2hw.tmr_config.setback.value) begin
            setback_o = 3'b110;
          end
          tmr_red_mode_d = NON_TMR;
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_red_mode
    if(!rst_ni) begin
      tmr_red_mode_q_int <= DefaultTMRMode;
      synch_req_sent_q_int <= '0;
      resynch_req_sent_q_int <= '0;
      cores_synch_q_int <= '0;
    end else begin
      tmr_red_mode_q_int <= tmr_red_mode_d;
      synch_req_sent_q_int <= synch_req_sent_d;
      resynch_req_sent_q_int <= resynch_req_sent_d;
      cores_synch_q_int <= cores_synch_i;
    end
  end
  assign tmr_red_mode_q = tmr_mode_e'(sync_reg_voted[2:0]);
  assign synch_req_sent_q = sync_reg_voted[3];
  assign resynch_req_sent_q = sync_reg_voted[4];
  assign cores_synch_q = sync_reg_voted[5];

  assign sync_reg_o[2:0] = tmr_red_mode_q_int;
  assign sync_reg_o[3] = synch_req_sent_q_int;
  assign sync_reg_o[4] = resynch_req_sent_q_int;
  assign sync_reg_o[5] = cores_synch_q_int;
  if (SyncRegStates) begin : gen_vote_regs
    bitwise_TMR_voter_fail #(
      .DataWidth(11),
      .VoterType(1) // KP_MV
    ) i_sync_reg_voter (
      .a_i(sync_reg_i[0]),
      .b_i(sync_reg_i[1]),
      .c_i(sync_reg_o),
      .majority_o(sync_reg_voted),
      .fault_detected_o(fault_o)
    );
  end else begin : gen_pass_through
    assign sync_reg_voted = sync_reg_o;
    assign fault_o = 1'b0;
  end

  `ifdef TARGET_SIMULATION
  // Debug prints
  always @(posedge clk_i) begin
    if (tmr_red_mode_q == TMR_RUN && tmr_single_mismatch_i) begin
      $display("[HMR-triple] %t - mismatch detected", $realtime);
    end
    if (tmr_red_mode_q == TMR_RELOAD && sp_store_is_zero) begin
      $display("[HMR-triple] %t - mismatch restored", $realtime);
    end
    if (tmr_red_mode_q == TMR_RAPID && recovery_finished_i) begin
      $display("[HMR-triple] %t - mismatch restored", $realtime);
    end
  end
  `endif

endmodule
