// Copyright (c) 2020 OpenHW Group
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0

// CV32E40X RVFI interface
// Contributors: Davide Schiavone <davide@openhwgroup.org>
//               Halfdan Bechmann <halfdan.bechmann@silabs.com>

module cv32e40x_rvfi
  import cv32e40x_pkg::*;
  import cv32e40x_rvfi_pkg::*;
  #(
    parameter bit     CLIC  = 0,
    parameter bit     DEBUG = 1,
    parameter a_ext_e A_EXT = A_NONE
  )
  (
   input logic                                clk_i,
   input logic                                rst_ni,

   // Non-pipeline Probes
   if_c_obi.monitor                           m_c_obi_instr_if,

   //// IF Probes ////
   input logic                                if_valid_i,
   input logic [31:0]                         pc_if_i,
   input logic                                instr_pmp_err_if_i,
   input logic                                last_op_if_i,
   input logic                                abort_op_if_i,
   input logic                                prefetch_valid_if_i,
   input logic                                prefetch_ready_if_i,
   input logic [31:0]                         prefetch_addr_if_i,
   input logic                                prefetch_compressed_if_i,
   input inst_resp_t                          prefetch_instr_if_i,
   input logic                                clic_ptr_if_i,
   input logic                                mret_ptr_if_i,
   input mpu_status_e                         mpu_status_i,
   input logic                                prefetch_trans_valid_i,
   input logic                                prefetch_trans_ready_i,
   input logic                                prefetch_resp_valid_i,

   // ID probes
   input logic                                id_valid_i,
   input logic                                id_ready_i,
   input logic [31:0]                         pc_id_i,
   input logic [ 1:0]                         rf_re_id_i,
   input logic                                sys_mret_id_i,
   input logic                                tbljmp_id_i,
   input logic                                jump_in_id_i,
   input logic                                is_compressed_id_i,
   input logic                                lsu_en_id_i,
   input logic                                lsu_we_id_i,
   input logic [1:0]                          lsu_size_id_i,
   input logic [4:0]                          rs1_addr_id_i,
   input logic [4:0]                          rs2_addr_id_i,
   input logic [31:0]                         operand_a_fw_id_i,
   input logic [31:0]                         operand_b_fw_id_i,
   input logic                                first_op_id_i,
   input logic                                clic_ptr_in_id_i,
   input logic                                mret_ptr_in_id_i,

   // EX probes
   input logic                                ex_ready_i,
   input logic                                ex_valid_i,
   input logic                                branch_in_ex_i,
   input logic                                branch_decision_ex_i,
   input logic                                dret_in_ex_i,
   input logic                                lsu_en_ex_i,
   input logic                                lsu_pmp_err_ex_i,
   input logic                                lsu_pma_err_ex_i,
   input logic                                lsu_pma_atomic_ex_i,
   input pma_cfg_t                            lsu_pma_cfg_ex_i,
   input logic                                lsu_misaligned_ex_i,
   input obi_data_req_t                       buffer_trans_ex_i,
   input logic                                buffer_trans_valid_ex_i,
   input logic                                lsu_split_q_ex_i,

   // WB probes
   input logic                                wb_ready_i,
   input logic                                wb_valid_i,
   input logic [31:0]                         pc_wb_i,
   input logic [31:0]                         instr_rdata_wb_i,
   input logic                                ebreak_in_wb_i,
   input logic                                csr_en_wb_i,
   input logic                                sys_wfi_insn_wb_i,
   input logic                                sys_en_wb_i,
   input logic                                last_op_wb_i,
   input logic                                first_op_wb_i,
   input logic                                abort_op_wb_i,
   input logic                                rf_we_wb_i,
   input logic [4:0]                          rf_addr_wb_i,
   input logic [31:0]                         rf_wdata_wb_i,
   input logic [31:0]                         lsu_rdata_wb_i,
   input logic                                mret_ptr_wb_i,
   input logic                                clic_ptr_wb_i,
   input logic                                csr_mscratchcsw_in_wb_i,
   input logic                                csr_mscratchcswl_in_wb_i,
   input logic                                csr_mnxti_in_wb_i,

   // PC
   input logic [31:0]                         branch_addr_n_i,

   input                                      privlvl_t priv_lvl_i,

   // Controller FSM probes
   input ctrl_fsm_t                           ctrl_fsm_i,
   input ctrl_state_e                         ctrl_fsm_cs_i,
   input ctrl_state_e                         ctrl_fsm_ns_i,
   input logic                                pending_single_step_i,
   input logic                                single_step_allowed_i,
   input logic                                nmi_pending_i,          // regular NMI pending
   input logic                                nmi_is_store_i,         // regular NMI type
   input logic                                debug_mode_q_i,
   input logic [2:0]                          debug_cause_n_i,

   // Interrupt Controller probes
   input logic [31:0]                         irq_i,
   input logic                                irq_wu_ctrl_i,
   input logic [9:0]                          irq_id_ctrl_i,

   //// CSR Probes ////
   input                                      jvt_t csr_jvt_n_i,
   input                                      jvt_t csr_jvt_q_i,
   input logic                                csr_jvt_we_i,
   input                                      mstatus_t csr_mstatus_n_i,
   input                                      mstatus_t csr_mstatus_q_i,
   input logic                                csr_mstatus_we_i,
   input                                      mstatush_t csr_mstatush_n_i,
   input                                      mstatush_t csr_mstatush_q_i,
   input logic                                csr_mstatush_we_i,
   input logic [31:0]                         csr_misa_n_i,
   input logic [31:0]                         csr_misa_q_i,
   input logic                                csr_misa_we_i,
   input logic [31:0]                         csr_mie_n_i,
   input logic [31:0]                         csr_mie_q_i,
   input logic                                csr_mie_we_i,
   input                                      mtvec_t csr_mtvec_n_i,
   input                                      mtvec_t csr_mtvec_q_i,
   input logic                                csr_mtvec_we_i,
   input                                      mtvt_t csr_mtvt_n_i,
   input                                      mtvt_t csr_mtvt_q_i,
   input logic                                csr_mtvt_we_i,
   input logic [31:0]                         csr_mcountinhibit_n_i,
   input logic [31:0]                         csr_mcountinhibit_q_i,
   input logic                                csr_mcountinhibit_we_i,
   input logic [31:0] [31:0]                  csr_mhpmevent_n_i,
   input logic [31:0] [31:0]                  csr_mhpmevent_q_i,
   input logic [31:0]                         csr_mhpmevent_we_i,
   input logic [31:0]                         csr_mscratch_n_i,
   input logic [31:0]                         csr_mscratch_q_i,
   input logic                                csr_mscratch_we_i,
   input logic [31:0]                         csr_mepc_n_i,
   input logic [31:0]                         csr_mepc_q_i,
   input logic                                csr_mepc_we_i,
   input                                      mcause_t csr_mcause_n_i,
   input                                      mcause_t csr_mcause_q_i,
   input logic                                csr_mcause_we_i,
   input logic [31:0]                         csr_mip_n_i,
   input logic [31:0]                         csr_mip_q_i,
   input logic                                csr_mip_we_i,
   input logic [31:0]                         csr_mnxti_n_i,
   input logic [31:0]                         csr_mnxti_q_i,
   input logic                                csr_mnxti_we_i,
   input                                      mintstatus_t csr_mintstatus_n_i,
   input                                      mintstatus_t csr_mintstatus_q_i,
   input logic                                csr_mintstatus_we_i,
   input logic [31:0]                         csr_mintthresh_n_i,
   input logic [31:0]                         csr_mintthresh_q_i,
   input logic                                csr_mintthresh_we_i,
   input logic [31:0]                         csr_mscratchcsw_n_i,
   input logic [31:0]                         csr_mscratchcsw_q_i,
   input logic                                csr_mscratchcsw_we_i,
   input logic [31:0]                         csr_mscratchcswl_n_i,
   input logic [31:0]                         csr_mscratchcswl_q_i,
   input logic                                csr_mscratchcswl_we_i,
   input logic [31:0]                         csr_tdata1_n_i,
   input logic [31:0]                         csr_tdata1_q_i,
   input logic                                csr_tdata1_we_i,
   input logic [31:0]                         csr_tdata2_n_i,
   input logic [31:0]                         csr_tdata2_q_i,
   input logic                                csr_tdata2_we_i,
   input logic [31:0]                         csr_tdata3_n_i,
   input logic [31:0]                         csr_tdata3_q_i,
   input logic                                csr_tdata3_we_i,
   input logic [31:0]                         csr_tinfo_n_i,
   input logic [31:0]                         csr_tinfo_q_i,
   input logic                                csr_tinfo_we_i,
   input logic [31:0]                         csr_tcontrol_n_i,
   input logic [31:0]                         csr_tcontrol_q_i,
   input logic                                csr_tcontrol_we_i,
   input logic [31:0]                         csr_tselect_n_i,
   input logic [31:0]                         csr_tselect_q_i,
   input logic                                csr_tselect_we_i,
   input                                      dcsr_t csr_dcsr_n_i,
   input                                      dcsr_t csr_dcsr_q_i,
   input logic                                csr_dcsr_we_i,
   input logic [31:0]                         csr_dpc_n_i,
   input logic [31:0]                         csr_dpc_q_i,
   input logic                                csr_dpc_we_i,
   input logic [31:0]                         csr_dscratch0_n_i,
   input logic [31:0]                         csr_dscratch0_q_i,
   input logic                                csr_dscratch0_we_i,
   input logic [31:0]                         csr_dscratch1_n_i,
   input logic [31:0]                         csr_dscratch1_q_i,
   input logic                                csr_dscratch1_we_i,
   input logic [31:0]                         csr_mconfigptr_n_i,
   input logic [31:0]                         csr_mconfigptr_q_i,
   input logic                                csr_mconfigptr_we_i,

   // performance counters
   //  cycle,  instret,  hpcounter,  cycleh,  instreth,  hpcounterh
   // mcycle, minstret, mhpcounter, mcycleh, minstreth, mhpcounterh
   input logic [31:0] [63:0]                  csr_mhpmcounter_n_i,
   input logic [31:0] [63:0]                  csr_mhpmcounter_q_i,
   input logic [31:0] [1:0]                   csr_mhpmcounter_we_i,

   input logic [31:0]                         csr_mvendorid_i,
   input logic [31:0]                         csr_marchid_i,
   input logic [31:0]                         csr_mhartid_i,
   input logic [31:0]                         csr_mimpid_i,

   input logic [31:0]                         csr_mcounteren_n_i,
   input logic [31:0]                         csr_mcounteren_q_i,
   input logic                                csr_mcounteren_we_i,

   input logic [ 7:0]                         csr_pmpcfg_n_i[16],
   input logic [ 7:0]                         csr_pmpcfg_q_i[16],
   input logic [15:0]                         csr_pmpcfg_we_i,
   input logic [31:0]                         csr_pmpaddr_n_i, // PMP address input shared for all pmpaddr registers
   input logic [31:0]                         csr_pmpaddr_q_i[16],
   input logic [15:0]                         csr_pmpaddr_we_i,
   input logic [31:0]                         csr_mseccfg_n_i,
   input logic [31:0]                         csr_mseccfg_q_i,
   input logic                                csr_mseccfg_we_i,
   input logic [31:0]                         csr_mseccfgh_n_i,
   input logic [31:0]                         csr_mseccfgh_q_i,
   input logic                                csr_mseccfgh_we_i,

   input logic [31:0]                         csr_menvcfg_n_i,
   input logic [31:0]                         csr_menvcfg_q_i,
   input logic                                csr_menvcfg_we_i,
   input logic [31:0]                         csr_menvcfgh_n_i,
   input logic [31:0]                         csr_menvcfgh_q_i,
   input logic                                csr_menvcfgh_we_i,

   input logic [31:0]                         csr_cpuctrl_n_i,
   input logic [31:0]                         csr_cpuctrl_q_i,
   input logic                                csr_cpuctrl_we_i,

   input logic [31:0]                         csr_secureseed0_n_i,
   input logic [31:0]                         csr_secureseed0_q_i,
   input logic                                csr_secureseed0_we_i,
   input logic [31:0]                         csr_secureseed1_n_i,
   input logic [31:0]                         csr_secureseed1_q_i,
   input logic                                csr_secureseed1_we_i,
   input logic [31:0]                         csr_secureseed2_n_i,
   input logic [31:0]                         csr_secureseed2_q_i,
   input logic                                csr_secureseed2_we_i,

   input logic [31:0]                         csr_mstateen0_n_i,
   input logic [31:0]                         csr_mstateen0_q_i,
   input logic                                csr_mstateen0_we_i,
   input logic [31:0]                         csr_mstateen1_n_i,
   input logic [31:0]                         csr_mstateen1_q_i,
   input logic                                csr_mstateen1_we_i,
   input logic [31:0]                         csr_mstateen2_n_i,
   input logic [31:0]                         csr_mstateen2_q_i,
   input logic                                csr_mstateen2_we_i,
   input logic [31:0]                         csr_mstateen3_n_i,
   input logic [31:0]                         csr_mstateen3_q_i,
   input logic                                csr_mstateen3_we_i,

   input logic [31:0]                         csr_mstateen0h_n_i,
   input logic [31:0]                         csr_mstateen0h_q_i,
   input logic                                csr_mstateen0h_we_i,
   input logic [31:0]                         csr_mstateen1h_n_i,
   input logic [31:0]                         csr_mstateen1h_q_i,
   input logic                                csr_mstateen1h_we_i,
   input logic [31:0]                         csr_mstateen2h_n_i,
   input logic [31:0]                         csr_mstateen2h_q_i,
   input logic                                csr_mstateen2h_we_i,
   input logic [31:0]                         csr_mstateen3h_n_i,
   input logic [31:0]                         csr_mstateen3h_q_i,
   input logic                                csr_mstateen3h_we_i,

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follow,
  // the convention of RISC-V Formal Interface Specification.
   output logic [ 0:0]                        rvfi_valid,
   output logic [63:0]                        rvfi_order,
   output logic [31:0]                        rvfi_insn,
   output logic [2:0]                         rvfi_instr_prot,
   output rvfi_trap_t                         rvfi_trap,
   output logic [ 0:0]                        rvfi_halt,
   output rvfi_intr_t                         rvfi_intr,
   output logic [ 1:0]                        rvfi_mode,
   output logic [ 1:0]                        rvfi_ixl,
   output logic [ 1:0]                        rvfi_nmip,

   output logic [ 2:0]                        rvfi_dbg,
   output logic [ 0:0]                        rvfi_dbg_mode,

   output logic [ 4:0]                        rvfi_rd_addr,
   output logic [31:0]                        rvfi_rd_wdata,
   output logic [ 4:0]                        rvfi_rs1_addr,
   output logic [ 4:0]                        rvfi_rs2_addr,
   output logic [31:0]                        rvfi_rs1_rdata,
   output logic [31:0]                        rvfi_rs2_rdata,

   output logic [31:0]                        rvfi_pc_rdata,
   output logic [31:0]                        rvfi_pc_wdata,

   output logic [32*NMEM-1:0]                 rvfi_mem_addr,
   output logic [ 4*NMEM-1:0]                 rvfi_mem_rmask,
   output logic [ 4*NMEM-1:0]                 rvfi_mem_wmask,
   output logic [32*NMEM-1:0]                 rvfi_mem_rdata,
   output logic [32*NMEM-1:0]                 rvfi_mem_wdata,
   output logic [ 3*NMEM-1:0]                 rvfi_mem_prot,

   output logic [32*32-1:0]                   rvfi_gpr_rdata,
   output logic [31:0]                        rvfi_gpr_rmask,
   output logic [32*32-1:0]                   rvfi_gpr_wdata,
   output logic [31:0]                        rvfi_gpr_wmask,


   // CSRs
   output logic [31:0]                        rvfi_csr_jvt_rmask,
   output logic [31:0]                        rvfi_csr_jvt_wmask,
   output logic [31:0]                        rvfi_csr_jvt_rdata,
   output logic [31:0]                        rvfi_csr_jvt_wdata,
   output logic [31:0]                        rvfi_csr_mstatus_rmask,
   output logic [31:0]                        rvfi_csr_mstatus_wmask,
   output logic [31:0]                        rvfi_csr_mstatus_rdata,
   output logic [31:0]                        rvfi_csr_mstatus_wdata,
   output logic [31:0]                        rvfi_csr_mstatush_rmask,
   output logic [31:0]                        rvfi_csr_mstatush_wmask,
   output logic [31:0]                        rvfi_csr_mstatush_rdata,
   output logic [31:0]                        rvfi_csr_mstatush_wdata,
   output logic [31:0]                        rvfi_csr_misa_rmask,
   output logic [31:0]                        rvfi_csr_misa_wmask,
   output logic [31:0]                        rvfi_csr_misa_rdata,
   output logic [31:0]                        rvfi_csr_misa_wdata,
   output logic [31:0]                        rvfi_csr_mie_rmask,
   output logic [31:0]                        rvfi_csr_mie_wmask,
   output logic [31:0]                        rvfi_csr_mie_rdata,
   output logic [31:0]                        rvfi_csr_mie_wdata,
   output logic [31:0]                        rvfi_csr_mtvec_rmask,
   output logic [31:0]                        rvfi_csr_mtvec_wmask,
   output logic [31:0]                        rvfi_csr_mtvec_rdata,
   output logic [31:0]                        rvfi_csr_mtvec_wdata,
   output logic [31:0]                        rvfi_csr_mtvt_rmask,
   output logic [31:0]                        rvfi_csr_mtvt_wmask,
   output logic [31:0]                        rvfi_csr_mtvt_rdata,
   output logic [31:0]                        rvfi_csr_mtvt_wdata,
   output logic [31:0]                        rvfi_csr_mcountinhibit_rmask,
   output logic [31:0]                        rvfi_csr_mcountinhibit_wmask,
   output logic [31:0]                        rvfi_csr_mcountinhibit_rdata,
   output logic [31:0]                        rvfi_csr_mcountinhibit_wdata,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmevent_rmask, // 3-31 implemented
   output logic [31:0] [31:0]                 rvfi_csr_mhpmevent_wmask,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmevent_rdata,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmevent_wdata,
   output logic [31:0]                        rvfi_csr_mscratch_rmask,
   output logic [31:0]                        rvfi_csr_mscratch_wmask,
   output logic [31:0]                        rvfi_csr_mscratch_rdata,
   output logic [31:0]                        rvfi_csr_mscratch_wdata,
   output logic [31:0]                        rvfi_csr_mepc_rmask,
   output logic [31:0]                        rvfi_csr_mepc_wmask,
   output logic [31:0]                        rvfi_csr_mepc_rdata,
   output logic [31:0]                        rvfi_csr_mepc_wdata,
   output logic [31:0]                        rvfi_csr_mcause_rmask,
   output logic [31:0]                        rvfi_csr_mcause_wmask,
   output logic [31:0]                        rvfi_csr_mcause_rdata,
   output logic [31:0]                        rvfi_csr_mcause_wdata,
   output logic [31:0]                        rvfi_csr_mtval_rmask,
   output logic [31:0]                        rvfi_csr_mtval_wmask,
   output logic [31:0]                        rvfi_csr_mtval_rdata,
   output logic [31:0]                        rvfi_csr_mtval_wdata,
   output logic [31:0]                        rvfi_csr_mip_rmask,
   output logic [31:0]                        rvfi_csr_mip_wmask,
   output logic [31:0]                        rvfi_csr_mip_rdata,
   output logic [31:0]                        rvfi_csr_mip_wdata,
   output logic [31:0]                        rvfi_csr_mnxti_rmask,
   output logic [31:0]                        rvfi_csr_mnxti_wmask,
   output logic [31:0]                        rvfi_csr_mnxti_rdata,
   output logic [31:0]                        rvfi_csr_mnxti_wdata,
   output logic [31:0]                        rvfi_csr_mintstatus_rmask,
   output logic [31:0]                        rvfi_csr_mintstatus_wmask,
   output logic [31:0]                        rvfi_csr_mintstatus_rdata,
   output logic [31:0]                        rvfi_csr_mintstatus_wdata,
   output logic [31:0]                        rvfi_csr_mintthresh_rmask,
   output logic [31:0]                        rvfi_csr_mintthresh_wmask,
   output logic [31:0]                        rvfi_csr_mintthresh_rdata,
   output logic [31:0]                        rvfi_csr_mintthresh_wdata,
   output logic [31:0]                        rvfi_csr_mscratchcsw_rmask,
   output logic [31:0]                        rvfi_csr_mscratchcsw_wmask,
   output logic [31:0]                        rvfi_csr_mscratchcsw_rdata,
   output logic [31:0]                        rvfi_csr_mscratchcsw_wdata,
   output logic [31:0]                        rvfi_csr_mscratchcswl_rmask,
   output logic [31:0]                        rvfi_csr_mscratchcswl_wmask,
   output logic [31:0]                        rvfi_csr_mscratchcswl_rdata,
   output logic [31:0]                        rvfi_csr_mscratchcswl_wdata,
   output logic [31:0]                        rvfi_csr_tselect_rmask,
   output logic [31:0]                        rvfi_csr_tselect_wmask,
   output logic [31:0]                        rvfi_csr_tselect_rdata,
   output logic [31:0]                        rvfi_csr_tselect_wdata,
   output logic [ 3:0] [31:0]                 rvfi_csr_tdata_rmask, // 1-3 implemented
   output logic [ 3:0] [31:0]                 rvfi_csr_tdata_wmask,
   output logic [ 3:0] [31:0]                 rvfi_csr_tdata_rdata,
   output logic [ 3:0] [31:0]                 rvfi_csr_tdata_wdata,
   output logic [31:0]                        rvfi_csr_tinfo_rmask,
   output logic [31:0]                        rvfi_csr_tinfo_wmask,
   output logic [31:0]                        rvfi_csr_tinfo_rdata,
   output logic [31:0]                        rvfi_csr_tinfo_wdata,
   output logic [31:0]                        rvfi_csr_tcontrol_rmask,
   output logic [31:0]                        rvfi_csr_tcontrol_wmask,
   output logic [31:0]                        rvfi_csr_tcontrol_rdata,
   output logic [31:0]                        rvfi_csr_tcontrol_wdata,
   output logic [31:0]                        rvfi_csr_dcsr_rmask,
   output logic [31:0]                        rvfi_csr_dcsr_wmask,
   output logic [31:0]                        rvfi_csr_dcsr_rdata,
   output logic [31:0]                        rvfi_csr_dcsr_wdata,
   output logic [31:0]                        rvfi_csr_dpc_rmask,
   output logic [31:0]                        rvfi_csr_dpc_wmask,
   output logic [31:0]                        rvfi_csr_dpc_rdata,
   output logic [31:0]                        rvfi_csr_dpc_wdata,
   output logic [ 1:0] [31:0]                 rvfi_csr_dscratch_rmask, // 0-1 implemented
   output logic [ 1:0] [31:0]                 rvfi_csr_dscratch_wmask,
   output logic [ 1:0] [31:0]                 rvfi_csr_dscratch_rdata,
   output logic [ 1:0] [31:0]                 rvfi_csr_dscratch_wdata,
   output logic [31:0]                        rvfi_csr_mcycle_rmask,
   output logic [31:0]                        rvfi_csr_mcycle_wmask,
   output logic [31:0]                        rvfi_csr_mcycle_rdata,
   output logic [31:0]                        rvfi_csr_mcycle_wdata,
   output logic [31:0]                        rvfi_csr_minstret_rmask,
   output logic [31:0]                        rvfi_csr_minstret_wmask,
   output logic [31:0]                        rvfi_csr_minstret_rdata,
   output logic [31:0]                        rvfi_csr_minstret_wdata,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounter_rmask, // 3-31 implemented
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounter_wmask,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounter_rdata,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounter_wdata,
   output logic [31:0]                        rvfi_csr_mcycleh_rmask,
   output logic [31:0]                        rvfi_csr_mcycleh_wmask,
   output logic [31:0]                        rvfi_csr_mcycleh_rdata,
   output logic [31:0]                        rvfi_csr_mcycleh_wdata,
   output logic [31:0]                        rvfi_csr_minstreth_rmask,
   output logic [31:0]                        rvfi_csr_minstreth_wmask,
   output logic [31:0]                        rvfi_csr_minstreth_rdata,
   output logic [31:0]                        rvfi_csr_minstreth_wdata,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounterh_rmask, // 3-31 implemented
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounterh_wmask,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounterh_rdata,
   output logic [31:0] [31:0]                 rvfi_csr_mhpmcounterh_wdata,
   output logic [31:0]                        rvfi_csr_cycle_rmask,
   output logic [31:0]                        rvfi_csr_cycle_wmask,
   output logic [31:0]                        rvfi_csr_cycle_rdata,
   output logic [31:0]                        rvfi_csr_cycle_wdata,
   output logic [31:0]                        rvfi_csr_instret_rmask,
   output logic [31:0]                        rvfi_csr_instret_wmask,
   output logic [31:0]                        rvfi_csr_instret_rdata,
   output logic [31:0]                        rvfi_csr_instret_wdata,
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounter_rmask, // 3-31 implemented
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounter_wmask,
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounter_rdata,
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounter_wdata,
   output logic [31:0]                        rvfi_csr_cycleh_rmask,
   output logic [31:0]                        rvfi_csr_cycleh_wmask,
   output logic [31:0]                        rvfi_csr_cycleh_rdata,
   output logic [31:0]                        rvfi_csr_cycleh_wdata,
   output logic [31:0]                        rvfi_csr_instreth_rmask,
   output logic [31:0]                        rvfi_csr_instreth_wmask,
   output logic [31:0]                        rvfi_csr_instreth_rdata,
   output logic [31:0]                        rvfi_csr_instreth_wdata,
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounterh_rmask, // 3-31 implemented
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounterh_wmask,
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounterh_rdata,
   output logic [31:0] [31:0]                 rvfi_csr_hpmcounterh_wdata,
   output logic [31:0]                        rvfi_csr_mvendorid_rmask,
   output logic [31:0]                        rvfi_csr_mvendorid_wmask,
   output logic [31:0]                        rvfi_csr_mvendorid_rdata,
   output logic [31:0]                        rvfi_csr_mvendorid_wdata,
   output logic [31:0]                        rvfi_csr_marchid_rmask,
   output logic [31:0]                        rvfi_csr_marchid_wmask,
   output logic [31:0]                        rvfi_csr_marchid_rdata,
   output logic [31:0]                        rvfi_csr_marchid_wdata,
   output logic [31:0]                        rvfi_csr_mimpid_rmask,
   output logic [31:0]                        rvfi_csr_mimpid_wmask,
   output logic [31:0]                        rvfi_csr_mimpid_rdata,
   output logic [31:0]                        rvfi_csr_mimpid_wdata,
   output logic [31:0]                        rvfi_csr_mhartid_rmask,
   output logic [31:0]                        rvfi_csr_mhartid_wmask,
   output logic [31:0]                        rvfi_csr_mhartid_rdata,
   output logic [31:0]                        rvfi_csr_mhartid_wdata,

   output logic [31:0]                        rvfi_csr_mcounteren_rmask,
   output logic [31:0]                        rvfi_csr_mcounteren_wmask,
   output logic [31:0]                        rvfi_csr_mcounteren_rdata,
   output logic [31:0]                        rvfi_csr_mcounteren_wdata,

   output logic [ 3:0] [31:0]                 rvfi_csr_pmpcfg_rmask,
   output logic [ 3:0] [31:0]                 rvfi_csr_pmpcfg_wmask,
   output logic [ 3:0] [31:0]                 rvfi_csr_pmpcfg_rdata,
   output logic [ 3:0] [31:0]                 rvfi_csr_pmpcfg_wdata,
   output logic [15:0] [31:0]                 rvfi_csr_pmpaddr_rmask,
   output logic [15:0] [31:0]                 rvfi_csr_pmpaddr_wmask,
   output logic [15:0] [31:0]                 rvfi_csr_pmpaddr_rdata,
   output logic [15:0] [31:0]                 rvfi_csr_pmpaddr_wdata,
   output logic        [31:0]                 rvfi_csr_mseccfg_rmask,
   output logic        [31:0]                 rvfi_csr_mseccfg_wmask,
   output logic        [31:0]                 rvfi_csr_mseccfg_rdata,
   output logic        [31:0]                 rvfi_csr_mseccfg_wdata,
   output logic        [31:0]                 rvfi_csr_mseccfgh_rmask,
   output logic        [31:0]                 rvfi_csr_mseccfgh_wmask,
   output logic        [31:0]                 rvfi_csr_mseccfgh_rdata,
   output logic        [31:0]                 rvfi_csr_mseccfgh_wdata,

   output logic [31:0]                        rvfi_csr_mconfigptr_rmask,
   output logic [31:0]                        rvfi_csr_mconfigptr_wmask,
   output logic [31:0]                        rvfi_csr_mconfigptr_rdata,
   output logic [31:0]                        rvfi_csr_mconfigptr_wdata,

   output logic        [31:0]                 rvfi_csr_menvcfg_rmask,
   output logic        [31:0]                 rvfi_csr_menvcfg_wmask,
   output logic        [31:0]                 rvfi_csr_menvcfg_rdata,
   output logic        [31:0]                 rvfi_csr_menvcfg_wdata,
   output logic        [31:0]                 rvfi_csr_menvcfgh_rmask,
   output logic        [31:0]                 rvfi_csr_menvcfgh_wmask,
   output logic        [31:0]                 rvfi_csr_menvcfgh_rdata,
   output logic        [31:0]                 rvfi_csr_menvcfgh_wdata,

   output logic        [31:0]                 rvfi_csr_cpuctrl_rmask,
   output logic        [31:0]                 rvfi_csr_cpuctrl_wmask,
   output logic        [31:0]                 rvfi_csr_cpuctrl_rdata,
   output logic        [31:0]                 rvfi_csr_cpuctrl_wdata,

   output logic        [31:0]                 rvfi_csr_secureseed0_rmask,
   output logic        [31:0]                 rvfi_csr_secureseed0_wmask,
   output logic        [31:0]                 rvfi_csr_secureseed0_rdata,
   output logic        [31:0]                 rvfi_csr_secureseed0_wdata,
   output logic        [31:0]                 rvfi_csr_secureseed1_rmask,
   output logic        [31:0]                 rvfi_csr_secureseed1_wmask,
   output logic        [31:0]                 rvfi_csr_secureseed1_rdata,
   output logic        [31:0]                 rvfi_csr_secureseed1_wdata,
   output logic        [31:0]                 rvfi_csr_secureseed2_rmask,
   output logic        [31:0]                 rvfi_csr_secureseed2_wmask,
   output logic        [31:0]                 rvfi_csr_secureseed2_rdata,
   output logic        [31:0]                 rvfi_csr_secureseed2_wdata,

   output logic        [31:0]                 rvfi_csr_mstateen0_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen0_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen0_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen0_wdata,
   output logic        [31:0]                 rvfi_csr_mstateen1_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen1_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen1_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen1_wdata,
   output logic        [31:0]                 rvfi_csr_mstateen2_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen2_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen2_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen2_wdata,
   output logic        [31:0]                 rvfi_csr_mstateen3_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen3_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen3_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen3_wdata,

   output logic        [31:0]                 rvfi_csr_mstateen0h_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen0h_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen0h_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen0h_wdata,
   output logic        [31:0]                 rvfi_csr_mstateen1h_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen1h_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen1h_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen1h_wdata,
   output logic        [31:0]                 rvfi_csr_mstateen2h_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen2h_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen2h_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen2h_wdata,
   output logic        [31:0]                 rvfi_csr_mstateen3h_rmask,
   output logic        [31:0]                 rvfi_csr_mstateen3h_wmask,
   output logic        [31:0]                 rvfi_csr_mstateen3h_rdata,
   output logic        [31:0]                 rvfi_csr_mstateen3h_wdata
);

  // Propagating from ID stage
  logic [3:0] [31:0] pc_wdata;
  logic [4:0]        debug_mode;
  logic [4:0] [ 2:0] debug_cause;
  logic [4:0]        instr_pmp_err;
  logic [4:0] [2:0]  instr_prot;
  rvfi_intr_t [4:0]  in_trap;
  logic [4:0] [ 4:0] rs1_addr;
  logic [4:0] [ 4:0] rs2_addr;
  logic [4:0] [31:0] rs1_rdata;
  logic [4:0] [31:0] rs2_rdata;
  logic [4:0] [ 3:0] mem_rmask;
  logic [4:0] [ 3:0] mem_wmask;

  // Propagate from ID stage on all suboperations.
  logic [3:0] [ 4:0] rs1_addr_subop;
  logic [3:0] [ 4:0] rs2_addr_subop;
  logic [3:0] [31:0] rs1_rdata_subop;
  logic [3:0] [31:0] rs2_rdata_subop;
  logic [3:0]        rs1_re_subop;
  logic [3:0]        rs2_re_subop;

  // Remember last instruction in WB
  logic [31:0]       instr_rdata_wb_past;
  logic [31:0]       pc_wb_past;
  logic [4:0]        rd_addr_wb_past;
  logic [31:0]       rd_wdata_wb_past;


  //Propagating from EX stage
  obi_data_req_t     ex_mem_trans;
  mem_err_t [3:0]    mem_err;

  logic              lsu_mem_split_wb;

  logic              branch_taken_ex;

  logic [ 3:0] rvfi_mem_mask_int;


  logic [ 4:0] rd_addr_wb;
  logic [31:0] rd_wdata_wb;

  logic [ 4:0] rs1_addr_id;
  logic [ 4:0] rs2_addr_id;
  logic [31:0] rs1_rdata_id;
  logic [31:0] rs2_rdata_id;

  // CSR inputs in struct format
  rvfi_csr_map_t rvfi_csr_rdata_d;
  rvfi_csr_map_t rvfi_csr_rmask_d;
  rvfi_csr_map_t rvfi_csr_wdata_d;
  rvfi_csr_map_t rvfi_csr_wmask_d;

  rvfi_csr_map_t rvfi_csr_rdata;
  rvfi_csr_map_t rvfi_csr_rmask;
  rvfi_csr_map_t rvfi_csr_wdata;
  rvfi_csr_map_t rvfi_csr_wmask;

  // Reads from autonomous registers propagate from EX stage
  rvfi_auto_csr_map_t ex_csr_rdata;
  rvfi_auto_csr_map_t ex_csr_rdata_d;

  logic [31:0][31:0] csr_mhpmcounter_n_l;
  logic [31:0][31:0] csr_mhpmcounter_n_h;
  logic [31:0][31:0] csr_mhpmcounter_q_l;
  logic [31:0][31:0] csr_mhpmcounter_q_h;
  logic [31:0][31:0] csr_mhpmcounter_we_l;
  logic [31:0][31:0] csr_mhpmcounter_we_h;

  // Signals for special handling of performance counters
  logic [31:0][31:0] mhpmcounter_l_rdata_q;
  logic [31:0][31:0] mhpmcounter_l_wdata_q;
  logic [31:0][31:0] mhpmcounter_h_rdata_q;
  logic [31:0][31:0] mhpmcounter_h_wdata_q;

  // Counter was written during WB and possibly before wb_valid
  logic [31:0]       mhpmcounter_l_during_wb;
  logic [31:0]       mhpmcounter_h_during_wb;

  logic         wb_valid_lastop;
  logic         wb_valid_subop;

  logic         pc_mux_debug;
  logic         pc_mux_dret;
  logic         pc_mux_exception;
  logic         pc_mux_interrupt;
  logic         pc_mux_nmi;

  logic [6:0]   insn_opcode;
  logic [4:0]   insn_rd;
  logic [2:0]   insn_funct3;
  logic [4:0]   insn_rs1;
  logic [4:0]   insn_rs2;
  logic [6:0]   insn_funct7;
  logic [11:0]  insn_csr;

  // PCs for jumps from ID and branches from EX
  logic [31:0]  pc_wdata_id_jump, pc_wdata_id_jump_q;
  logic [31:0]  pc_wdata_ex_branch, pc_wdata_ex_branch_q;

  // sub operation counter
  logic [3:0]   subop_cnt;

  // Memory operation counter
  logic [6:0]   memop_cnt;

  rvfi_obi_instr_t obi_instr_if;
  obi_data_req_t   lsu_data_trans;
  logic            lsu_data_trans_valid;

  // Detect mret initiated CLIC pointer in WB
  logic         mret_ptr_wb;

  // Detect a PMA error due to atomics accessing non-atomic regions
  logic         lsu_pma_err_atomic_ex;

  // Detect PMA errors due to misaligned accesses
  logic         lsu_pma_err_misaligned_ex;

  assign        mret_ptr_wb = mret_ptr_wb_i;

  // PMA error due to atomic not within an atomic region
  assign lsu_pma_err_atomic_ex = lsu_pma_err_ex_i && lsu_pma_atomic_ex_i && !lsu_pma_cfg_ex_i.atomic;

  // PMA error due to misaligned accesses to I/O memory
  assign lsu_pma_err_misaligned_ex = lsu_pma_err_ex_i && lsu_misaligned_ex_i && !lsu_pma_cfg_ex_i.main;

  assign insn_opcode = rvfi_insn[6:0];
  assign insn_rd     = rvfi_insn[11:7];
  assign insn_funct3 = rvfi_insn[14:12];
  assign insn_rs1    = rvfi_insn[19:15];
  assign insn_rs2    = rvfi_insn[24:20];
  assign insn_funct7 = rvfi_insn[31:25];
  assign insn_csr    = rvfi_insn[31:20];

  cv32e40x_rvfi_instr_obi
  rvfi_instr_obi_i
  (
    .clk                        ( clk_i                         ),
    .rst_n                      ( rst_ni                        ),

    .prefetch_valid_i           ( prefetch_valid_if_i           ),
    .prefetch_ready_i           ( prefetch_ready_if_i           ),
    .prefetch_addr_i            ( prefetch_addr_if_i            ),
    .prefetch_compressed_i      ( prefetch_compressed_if_i      ),
    .kill_if_i                  ( ctrl_fsm_i.kill_if            ),
    .mpu_status_i               ( mpu_status_i                  ),
    .prefetch_trans_valid_i     ( prefetch_trans_valid_i        ),
    .prefetch_trans_ready_i     ( prefetch_trans_ready_i        ),
    .prefetch_resp_valid_i      ( prefetch_resp_valid_i         ),
    .m_c_obi_instr_if           ( m_c_obi_instr_if              ),

    .obi_instr                  ( obi_instr_if                  )
  );

  cv32e40x_rvfi_data_obi
  rvfi_data_obi_i
  (
    .clk                        ( clk_i                   ),
    .rst_n                      ( rst_ni                  ),
    .buffer_trans_i             ( buffer_trans_ex_i       ),
    .buffer_trans_valid_i       ( buffer_trans_valid_ex_i ),
    .lsu_data_trans_o           ( lsu_data_trans          ),
    .lsu_data_trans_valid_o     ( lsu_data_trans_valid    )
  );


  // Generate PCs for jumps and branches taken from ID and EX stages
  // PCs must be kept sticky, since jumps and branches are taken in the first cycle, while the RVFI pipeline is
  // only updated when the next pipeline stage is ready (e.g. when id_valid_i && ex_ready_i)

  always_comb begin

    // Generate PC for jumps taken from ID
    pc_wdata_id_jump = pc_wdata_id_jump_q;

    if (ctrl_fsm_i.pc_set) begin
      if((ctrl_fsm_i.pc_mux == PC_MRET) ||
         (ctrl_fsm_i.pc_mux == PC_JUMP) ||
         (ctrl_fsm_i.pc_mux == PC_POINTER) ||
         (ctrl_fsm_i.pc_mux == PC_TBLJUMP)) begin
        pc_wdata_id_jump = branch_addr_n_i;
      end
    end

    // Generate PC for branches taken from EX
    pc_wdata_ex_branch = pc_wdata_ex_branch_q;

    if (ctrl_fsm_i.pc_set) begin
      if(ctrl_fsm_i.pc_mux == PC_BRANCH) begin
        pc_wdata_ex_branch = branch_addr_n_i;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_wdata_id_jump_q <= '0;
      pc_wdata_ex_branch_q <= '0;
    end
    else begin
      pc_wdata_id_jump_q   <= pc_wdata_id_jump;
      pc_wdata_ex_branch_q <= pc_wdata_ex_branch;
    end
  end

  // The pc_mux signals probe the MUX in the IF stage to extract information about events in the WB stage.
  // These signals are therefore used both in the WB stage to see effects of the executed instruction (e.g. rvfi_trap), and
  // in the IF stage to see the reason for executing the instruction (e.g. rvfi_intr).
  assign pc_mux_interrupt       = (ctrl_fsm_i.pc_mux == PC_TRAP_IRQ) || (ctrl_fsm_i.pc_mux == PC_TRAP_CLICV);
  assign pc_mux_nmi             = (ctrl_fsm_i.pc_mux == PC_TRAP_NMI);
  assign pc_mux_debug           = (ctrl_fsm_i.pc_mux == PC_TRAP_DBD);
  assign pc_mux_exception       = (ctrl_fsm_i.pc_mux == PC_TRAP_EXC) || (ctrl_fsm_i.pc_mux == PC_TRAP_DBE) ;
  assign pc_mux_dret            = (ctrl_fsm_i.pc_mux == PC_DRET);

  assign branch_taken_ex = branch_in_ex_i && branch_decision_ex_i;

  // Assign rvfi channels
  assign rvfi_halt = 1'b0; // No instruction causing halt in cv32e40x
  assign rvfi_ixl = 2'b01; // XLEN for current privilege level, must be 1(32) for RV32 systems

  logic         in_trap_clr;
  // Clear in trap pipeline when it reaches rvfi_intr
  // This is done to avoid reporting already signaled triggers as suppressed during by debug
  assign in_trap_clr = wb_valid_lastop && in_trap[STAGE_WB].intr;

  // Set rvfi_trap for instructions causing exception or debug entry.
  rvfi_trap_t  rvfi_trap_next;

  always_comb begin
    rvfi_trap_next = '0;

    if (pc_mux_debug) begin
      // All debug entries will set pc_mux_debug but only synchronous debug entries will set wb_valid (and in turn rvfi_valid)
      // as asynchronous entries will kill the WB stage whereas synchronous entries will not.
      // Indicate that the trap is a synchronous trap into debug mode
      rvfi_trap_next.debug       = 1'b1;
      // Special case for debug entry from debug mode caused by EBREAK as it is not captured by ctrl_fsm_i.debug_cause
      rvfi_trap_next.debug_cause = ebreak_in_wb_i ? DBG_CAUSE_EBREAK : ctrl_fsm_i.debug_cause;
    end

    if (pc_mux_exception) begin
      // Indicate synchronous (non-debug entry) trap
      rvfi_trap_next.exception       = 1'b1;
      rvfi_trap_next.exception_cause = ctrl_fsm_i.csr_cause.exception_code[5:0]; // All synchronous exceptions fit in lower 6 bits
      rvfi_trap_next.clicptr         = clic_ptr_wb_i;

      // Separate exception causes with the same ecseption cause code
      case (ctrl_fsm_i.csr_cause.exception_code)
        EXC_CAUSE_INSTR_FAULT : begin
          rvfi_trap_next.cause_type = instr_pmp_err[STAGE_WB] ? 2'h1 : 2'h0;
        end
        EXC_CAUSE_BREAKPOINT : begin
          // Todo: Add support for trigger match exceptions when implemented in rtl
        end
        EXC_CAUSE_LOAD_FAULT : begin
          rvfi_trap_next.cause_type = mem_err[STAGE_WB];
        end
        EXC_CAUSE_STORE_FAULT : begin
          rvfi_trap_next.cause_type = mem_err[STAGE_WB];
        end
        EXC_CAUSE_LOAD_MISALIGNED : begin
          rvfi_trap_next.cause_type = 2'h0;
        end
        EXC_CAUSE_STORE_MISALIGNED : begin
          rvfi_trap_next.cause_type = 2'h0;
        end
        default : begin
          // rvfi_trap_next.cause_type is only set for exception codes that can have multiple causes
        end
      endcase // case (ctrl_fsm_i.csr_cause.exception_code)

    end

    // Check for single step debug entry, need to include the actual debug_cause_n, as single step has the lowest priority
    // to enter debug and any higher priority cause could be active at the same time.
    if((pending_single_step_i && single_step_allowed_i) && (debug_cause_n_i == DBG_CAUSE_STEP)) begin
      // The timing of the single step debug entry does not allow using pc_mux for detection
      rvfi_trap_next.debug       = 1'b1;
      rvfi_trap_next.debug_cause = DBG_CAUSE_STEP;

      // In the case of an exception in WB and pending single step, both the exception and the debug flag will be set
    end

    // Set trap bit if there is an exception or debug entry
    rvfi_trap_next.trap = rvfi_trap_next.exception || rvfi_trap_next.debug;
  end

  // All instructions retire when wb_valid is high and it either is a last_op or an abort_op.
  // CLIC pointers are excluded if they do not raise an exception.
  // Faulted CLIC pointer fetches are reported with rvfi_valid and rvfi_trap.clicptr==1.
  // CLIC pointers that are a result of an mret (instr_meta.mret_ptr) finish the sequence mret->ptr, and shall raise rvfi_valid_* to retire the mret.
  assign wb_valid_subop    = wb_valid_i && !(clic_ptr_wb_i && !pc_mux_exception);
  assign wb_valid_lastop   = wb_valid_i && (last_op_wb_i || abort_op_wb_i) && !(clic_ptr_wb_i && !pc_mux_exception);


  // Pipeline stage model //

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_wdata           <= '0;
      in_trap            <= '0;
      debug_mode         <= '0;
      debug_cause        <= '0;
      instr_pmp_err      <= '0;
      instr_prot         <= '0;
      rs1_addr           <= '0;
      rs2_addr           <= '0;
      rs1_rdata          <= '0;
      rs2_rdata          <= '0;
      mem_rmask          <= '0;
      mem_wmask          <= '0;
      ex_mem_trans       <= '0;
      mem_err            <= {4{MEM_ERR_IO_ALIGN}};
      ex_csr_rdata       <= '0;
      rvfi_dbg           <= '0;
      rvfi_dbg_mode      <= '0;
      rvfi_valid         <= 1'b0;
      rvfi_order         <= '0;
      rvfi_insn          <= '0;
      rvfi_instr_prot    <= '0;
      rvfi_pc_rdata      <= '0;
      rvfi_pc_wdata      <= '0;
      rvfi_trap          <= '0;
      rvfi_intr          <= 1'b0;
      rvfi_mode          <= 2'b11;      // Reset value of rvfi_mode is being used as 'previous privilege level'
      rvfi_rd_addr       <= '0;
      rvfi_rd_wdata      <= '0;
      rvfi_csr_rdata     <= '0;
      rvfi_csr_wdata     <= '0;
      rvfi_csr_wmask     <= '0;
      rvfi_rs1_addr      <= '0;
      rvfi_rs2_addr      <= '0;
      rvfi_rs1_rdata     <= '0;
      rvfi_rs2_rdata     <= '0;
      rvfi_mem_addr      <= '0;
      rvfi_mem_rmask     <= '0;
      rvfi_mem_rdata     <= '0;
      rvfi_mem_wmask     <= '0;
      rvfi_mem_wdata     <= '0;
      rvfi_mem_prot      <= '0;
      rvfi_gpr_rdata     <= '0;
      rvfi_gpr_rmask     <= '0;
      rvfi_gpr_wdata     <= '0;
      rvfi_gpr_wmask     <= '0;

      subop_cnt          <= '0;
      memop_cnt          <= '0;

      rs1_addr_subop     <= '0;
      rs2_addr_subop     <= '0;
      rs1_rdata_subop    <= '0;
      rs2_rdata_subop    <= '0;
      rs1_re_subop       <= '0;
      rs2_re_subop       <= '0;

      lsu_mem_split_wb   <= '0;

      pc_wb_past          <= '0;
      instr_rdata_wb_past <= '0;
      rd_addr_wb_past     <= '0;
      rd_wdata_wb_past    <= '0;

    end else begin

      //// IF Stage ////
      if (if_valid_i && id_ready_i) begin
        debug_mode [STAGE_ID] <= ctrl_fsm_i.debug_mode; // Probing in IF to ensure LSU instructions that are not killed can complete
        instr_pmp_err[STAGE_ID] <= instr_pmp_err_if_i;    // Instruction fetch pmp error probed to separate pmp- from pma-errors

        // Capturing events that happen when the IF stage is not valid and
        // propagating them through the pipeline with the next valid instruction

        // Capture events
        in_trap    [STAGE_ID] <= in_trap    [STAGE_IF];
        debug_cause[STAGE_ID] <= debug_cause[STAGE_IF];

        // Clear captured events when last operation exits IF
        // Exception for clic pointers:
        //   - CLIC pointers are seen as single operation (first_op && last_op),
        //     but we still need the in_trap attached to the pointer target, which is
        //     only fetched when the CLIC pointer is in ID. Thus we must not clear in_trap
        //     when the pointer goes from IF to ID.
        // Any aborted operation will not cause any other side effects than taking an exception, and
        // thus that is the last part of an operation, leading to clearing in_trap and debug cause for STAGE_IF;
        if ((last_op_if_i && !clic_ptr_if_i) || abort_op_if_i) begin
          in_trap    [STAGE_IF] <= 1'b0;
          debug_cause[STAGE_IF] <= '0;
        end

        // Capture OBI prot for the instruction fetch
        instr_prot[STAGE_ID] <= obi_instr_if.req_payload.prot;

      end else begin
        // Clear in trap if trap reached rvfi outputs or we insert a bubble into the ID stage
        if (in_trap_clr || id_ready_i) begin
          // Clear interrupt pipeline when it reaches rvfi_intr
          in_trap    [STAGE_ID] <= '0;
        end

        // IF stage is killed and not valid during debug entry. If debug is taken,
        // debug cause is saved to propagate through rvfi pipeline together with next valid instruction
        if (pc_mux_debug) begin
          // Debug cause input only valid during debug taken
          // Special case for debug entry from debug mode caused by EBREAK as it is not captured by ctrl_fsm_i.debug_cause
          // A higher priority debug request (e.g. trigger match) will pull ebreak_in_wb_i low and allow the debug cause to propagate
          debug_cause[STAGE_IF] <=  ebreak_in_wb_i ? 3'h1 : ctrl_fsm_i.debug_cause;

          // If there is a trap in the pipeline when debug is taken, the trap will be suppressed but the side-effects will not.
          // The succeeding instruction therefore needs to re-trigger the intr signals if it it did not reach the rvfi output.
          //
          // in_trap is attached to the first instruction of interrupt or exception handlers. If such an instruction is killed by
          // an external haltrequest, the above comment holds and the in_trap info from the pipeline must be backpropagated to the IF stage.
          // If however the debug entry is due to a synchronous exception, the first handler instruction must have reached WB. For most synchronous
          // debug entries (except single step due to acking an interrupt) rvfi_valid == 1, thus the in_trap reached RVFI outputs and does not need to backpropagate fo IF.
          if (ctrl_fsm_i.debug_cause == DBG_CAUSE_HALTREQ) begin
            in_trap[STAGE_IF] <= in_trap[STAGE_IF].intr ? in_trap[STAGE_IF] :
                                 in_trap[STAGE_ID].intr ? in_trap[STAGE_ID] :
                                 in_trap[STAGE_EX].intr ? in_trap[STAGE_EX] :
                                                          in_trap[STAGE_WB];

          end else begin
            // Clear in_trap[STAGE_IF] if the handler instruction reached WB without being killed (trigger match, ebreak or stepping)
            // In case of taking single step debug due to acking an interrupt or NMI, the in_trap_clr will be zero and the the trap information
            // must be retained in the STAGE_IF to be communicated on RVFI for the first debug instruction.
            if (in_trap_clr) begin
              in_trap[STAGE_IF] <= '0;
            end
          end
        // In case the first instruction during debug mode gets an exception, if_stage will be killed and the clearing
        // of debug_cause due to last_op_if_i during (if_valid && id_ready) may never happen. This will lead to a wrong
        // value of debug_cause on RVFI outputs. To avoid this, debug_cause is cleared if IF stage is killed due to an exception.
        // The only sources of kill_if during debug mode is jumps, branches and exceptions. We cannot reset debug_cause due to
        // jumps and branches as they would then report wrong debug cause when they retire.
        end else if (ctrl_fsm_i.kill_if && pc_mux_exception) begin
          debug_cause[STAGE_IF] <= '0;
        end

        // Picking up trap entry when IF is not valid to propagate for next valid instruction
        // The in trap signal is set for the first instruction of interrupt- and exception handlers (not debug handler)
        if (pc_mux_interrupt || pc_mux_nmi || pc_mux_exception) begin
          in_trap[STAGE_IF].intr      <= 1'b1;
          in_trap[STAGE_IF].interrupt <= pc_mux_interrupt || pc_mux_nmi;
          in_trap[STAGE_IF].exception <= pc_mux_exception;
          in_trap[STAGE_IF].cause     <= ctrl_fsm_i.csr_cause.exception_code;
        end
      end

      //// ID Stage ////
      if (id_valid_i && ex_ready_i) begin

        if (sys_mret_id_i || jump_in_id_i || clic_ptr_in_id_i || mret_ptr_in_id_i) begin
          // Jump from ID, update PC
          pc_wdata [STAGE_EX] <= pc_wdata_id_jump;
        end else begin
          // No jump from ID, increment PC, but only during the first cycle in ID
          if(first_op_id_i) begin
            pc_wdata [STAGE_EX] <= is_compressed_id_i ?  pc_id_i + 2 : pc_id_i + 4;
          end
        end

        in_trap    [STAGE_EX] <= in_trap    [STAGE_ID];
        debug_mode [STAGE_EX] <= debug_mode [STAGE_ID];
        debug_cause[STAGE_EX] <= debug_cause[STAGE_ID];
        instr_pmp_err[STAGE_EX] <= instr_pmp_err[STAGE_ID];
        instr_prot[STAGE_EX]    <= instr_prot[STAGE_ID];

        // Only update rs1/rs2 on the first part of a multi operation instruction.
        // Jumps may actually use rs1 before (id_valid && ex_ready), an assertion exists to check that
        // the jump target is stable and it should be safe to use rs1/2_rdata at the time of the pipeline handshake.
        // rs1/2 address and rdata should reflect state of the first operation of any instruction, thus
        // the gating with first_op_id_i in the lines below to not update the fields multiple times for sequenced instructions (including table jumps).
        // The rs*_subop fields below are used to capture the state of _all_ operations within a sequence, and are used to populate the rvfi_gpr outputs
        // to reflect all values read by the entire instruction.
        rs1_addr   [STAGE_EX] <= first_op_id_i ? rs1_addr_id : rs1_addr[STAGE_EX];
        rs2_addr   [STAGE_EX] <= first_op_id_i ? rs2_addr_id : rs2_addr[STAGE_EX];
        rs1_rdata  [STAGE_EX] <= first_op_id_i ? rs1_rdata_id : rs1_rdata[STAGE_EX];
        rs2_rdata  [STAGE_EX] <= first_op_id_i ? rs2_rdata_id : rs2_rdata[STAGE_EX];

        mem_rmask  [STAGE_EX] <= (lsu_en_id_i && !lsu_we_id_i) ? rvfi_mem_mask_int : '0;
        mem_wmask  [STAGE_EX] <= (lsu_en_id_i &&  lsu_we_id_i) ? rvfi_mem_mask_int : '0;

        // Update rs1/2 values for all suboperations (will populate rvfi_gpr_rmask/rdata)
        rs1_addr_subop   [STAGE_EX] <= rs1_addr_id;
        rs2_addr_subop   [STAGE_EX] <= rs2_addr_id;
        rs1_rdata_subop  [STAGE_EX] <= rs1_rdata_id;
        rs2_rdata_subop  [STAGE_EX] <= rs2_rdata_id;
        rs1_re_subop     [STAGE_EX] <= rf_re_id_i[0];
        rs2_re_subop     [STAGE_EX] <= rf_re_id_i[1];
      end else begin
        if (in_trap_clr || ex_ready_i) begin
          // Clear in trap if trap reached rvfi outputs or we insert a bubble into the EX stage
          in_trap    [STAGE_EX] <= '0;
        end
      end


      //// EX Stage ////
      if (ex_valid_i && wb_ready_i) begin

        if (branch_taken_ex) begin
          // Branch taken from EX, update PC to branch target
          pc_wdata[STAGE_WB] <= pc_wdata_ex_branch;
        end
        else begin
          // No branch taken from EX
          pc_wdata[STAGE_WB] <= pc_wdata[STAGE_EX];
        end

        debug_mode [STAGE_WB] <= debug_mode         [STAGE_EX];
        debug_cause[STAGE_WB] <= debug_cause        [STAGE_EX];
        instr_pmp_err[STAGE_WB] <= instr_pmp_err    [STAGE_EX];
        instr_prot [STAGE_WB] <= instr_prot         [STAGE_EX];
        rs1_addr   [STAGE_WB] <= rs1_addr           [STAGE_EX];
        rs2_addr   [STAGE_WB] <= rs2_addr           [STAGE_EX];
        rs1_rdata  [STAGE_WB] <= rs1_rdata          [STAGE_EX];
        rs2_rdata  [STAGE_WB] <= rs2_rdata          [STAGE_EX];
        mem_rmask  [STAGE_WB] <= lsu_data_trans_valid ? mem_rmask[STAGE_EX] : '0;
        mem_wmask  [STAGE_WB] <= lsu_data_trans_valid ? mem_wmask[STAGE_EX] : '0;
        in_trap    [STAGE_WB] <= in_trap            [STAGE_EX];

        rs1_addr_subop   [STAGE_WB] <= rs1_addr_subop [STAGE_EX];
        rs2_addr_subop   [STAGE_WB] <= rs2_addr_subop [STAGE_EX];
        rs1_rdata_subop  [STAGE_WB] <= rs1_rdata_subop[STAGE_EX];
        rs2_rdata_subop  [STAGE_WB] <= rs2_rdata_subop[STAGE_EX];
        rs1_re_subop     [STAGE_WB] <= rs1_re_subop   [STAGE_EX];
        rs2_re_subop     [STAGE_WB] <= rs2_re_subop   [STAGE_EX];

        lsu_mem_split_wb <= lsu_split_q_ex_i;
        if (!lsu_split_q_ex_i) begin
          // The second part of the split misaligned access is suppressed to keep
          // the start address and data for the whole misaligned transfer
          ex_mem_trans <= lsu_data_trans;
        end

        // Capture cause of LSU exception for the cases that can have multiple reasons for an exception
        // These are currently load and store access faults trigger by misaligned access to i/o regions,
        // atomic accesses to regions not enabled for atomics or accesses blocked by PMP.
        mem_err [STAGE_WB]  = lsu_pma_err_misaligned_ex    ? MEM_ERR_IO_ALIGN          : // Non-natrually aligned access to !main
                              lsu_pma_err_atomic_ex        ? MEM_ERR_ATOMIC            : // Any atomic to non-atomic PMA region
                                                             MEM_ERR_PMP;                // PMP error

        // Read autonomuos CSRs from EX perspective
        ex_csr_rdata        <= ex_csr_rdata_d;

      end else begin
        if (in_trap_clr || wb_ready_i) begin
          // Clear in trap if trap reached rvfi outputs or we insert a bubble into the WB stage
          in_trap    [STAGE_WB] <= '0;
        end
      end


      //// WB Stage ////
      rvfi_valid      <= wb_valid_lastop;
      if (wb_valid_lastop) begin

        rvfi_order      <= rvfi_order + 64'b1;
        rvfi_pc_rdata   <= mret_ptr_wb ? pc_wb_past          : pc_wb_i;
        rvfi_insn       <= mret_ptr_wb ? instr_rdata_wb_past : instr_rdata_wb_i;

        // No muxing in past value here. If an mret has any exceptions, it will not cause a pointer fetch and it will
        // signal rvfi_valid when it reaches WB. If it causes a pointer fetch, we need the updated trap value for that fetch reported.
        rvfi_trap       <= rvfi_trap_next;

        rvfi_rd_addr    <= mret_ptr_wb ? rd_addr_wb_past  : rd_addr_wb;
        rvfi_rd_wdata   <= mret_ptr_wb ? rd_wdata_wb_past : rd_wdata_wb;

        // Read/Write CSRs
        // No mret pointer muxing, CSR updates for mret with CLIC pointer happens when the pointer reachces WB.
        rvfi_csr_rdata  <= rvfi_csr_rdata_d;
        rvfi_csr_rmask  <= rvfi_csr_rmask_d;
        rvfi_csr_wdata  <= rvfi_csr_wdata_d;
        rvfi_csr_wmask  <= rvfi_csr_wmask_d;

        rvfi_intr      <= mret_ptr_wb ? in_trap  [STAGE_WB_PAST] : in_trap   [STAGE_WB];
        rvfi_rs1_addr  <= mret_ptr_wb ? rs1_addr [STAGE_WB_PAST] : rs1_addr  [STAGE_WB];
        rvfi_rs2_addr  <= mret_ptr_wb ? rs2_addr [STAGE_WB_PAST] : rs2_addr  [STAGE_WB];
        rvfi_rs1_rdata <= mret_ptr_wb ? rs1_rdata[STAGE_WB_PAST] : rs1_rdata [STAGE_WB];
        rvfi_rs2_rdata <= mret_ptr_wb ? rs2_rdata[STAGE_WB_PAST] : rs2_rdata [STAGE_WB];
        rvfi_instr_prot<= mret_ptr_wb ? instr_prot[STAGE_WB_PAST] : instr_prot[STAGE_WB];

        rvfi_mode      <= priv_lvl_i;

        rvfi_dbg       <= mret_ptr_wb ? debug_cause[STAGE_WB_PAST] : debug_cause[STAGE_WB];
        rvfi_dbg_mode  <= mret_ptr_wb ? debug_mode [STAGE_WB_PAST] : debug_mode[STAGE_WB];

        // Set expected next PC, half-word aligned
        // Predict synchronous exceptions and synchronous debug entry in WB to include all causes
        rvfi_pc_wdata <= (pc_mux_debug || pc_mux_exception) ? branch_addr_n_i & ~32'b1 :
                         (pc_mux_dret) ? csr_dpc_q_i :
                         pc_wdata[STAGE_WB] & ~32'b1;
      end

      // Update state for suboperations - also valid for the last operation
      if (wb_valid_subop) begin
        // Set entries in *[STAGE_WB_PAST]
        in_trap  [STAGE_WB_PAST]    <= in_trap  [STAGE_WB];
        rs1_addr [STAGE_WB_PAST]    <= rs1_addr [STAGE_WB];
        rs2_addr [STAGE_WB_PAST]    <= rs1_addr [STAGE_WB];
        rs1_rdata[STAGE_WB_PAST]    <= rs1_rdata[STAGE_WB];
        rs2_rdata[STAGE_WB_PAST]    <= rs1_rdata[STAGE_WB];
        debug_cause [STAGE_WB_PAST] <= debug_cause [STAGE_WB];
        debug_mode [STAGE_WB_PAST]  <= debug_mode[STAGE_WB];
        instr_prot[STAGE_WB_PAST]   <= instr_prot[STAGE_WB];
        pc_wb_past                  <= pc_wb_i;
        instr_rdata_wb_past         <= instr_rdata_wb_i;
        rd_addr_wb_past             <= rd_addr_wb;
        rd_wdata_wb_past            <= rd_wdata_wb;

        // Clear rvfi_mem and rvfi_gpr on first op
        if (first_op_wb_i) begin
          rvfi_mem_addr      <= '0;
          rvfi_mem_rmask     <= '0;
          rvfi_mem_rdata     <= '0;
          rvfi_mem_wmask     <= '0;
          rvfi_mem_wdata     <= '0;
          rvfi_mem_prot      <= '0;

          rvfi_gpr_rdata     <= '0;
          rvfi_gpr_rmask     <= '0;
          rvfi_gpr_wdata     <= '0;
          rvfi_gpr_wmask     <= '0;
        end

        // Update rvfi_mem (first part of split misaligned do not cause update)
        if (!lsu_mem_split_wb) begin
          rvfi_mem_rdata[(32*(memop_cnt+1))-1 -: 32] <= lsu_rdata_wb_i;
          rvfi_mem_rmask[ (4*(memop_cnt+1))-1 -:  4] <= mem_rmask [STAGE_WB];
          rvfi_mem_wmask[ (4*(memop_cnt+1))-1 -:  4] <= mem_wmask [STAGE_WB];
          rvfi_mem_addr [(32*(memop_cnt+1))-1 -: 32] <= ex_mem_trans.addr;
          rvfi_mem_wdata[(32*(memop_cnt+1))-1 -: 32] <= ex_mem_trans.wdata;
          rvfi_mem_prot [ (3*(memop_cnt+1))-1 -:  3] <= ex_mem_trans.prot;
        end

        // Update rvfi_gpr for writes to RF
        if (rf_we_wb_i) begin
          rvfi_gpr_wdata[(32*(rd_addr_wb+1))-1 -: 32] <= rd_wdata_wb;
          rvfi_gpr_wmask[rd_addr_wb]                  <= 1'b1;
        end

        // Update rvfi_gpr for reads from RF
        if (rs1_re_subop[STAGE_WB]) begin
          rvfi_gpr_rmask[rs1_addr_subop[STAGE_WB]] <= 1'b1;
          rvfi_gpr_rdata[(32*(rs1_addr_subop[STAGE_WB]+1))-1 -: 32] <= rs1_rdata_subop[STAGE_WB];
        end

        if (rs2_re_subop[STAGE_WB]) begin
          rvfi_gpr_rmask[rs2_addr_subop[STAGE_WB]] <= 1'b1;
          rvfi_gpr_rdata[(32*(rs2_addr_subop[STAGE_WB]+1))-1 -: 32] <= rs2_rdata_subop[STAGE_WB];
        end

        // Handle counter for suboperations and memory operations
        if (last_op_wb_i || abort_op_wb_i) begin
          // Reset suboperation and memop counters when the last op is done in WB.
          subop_cnt <= 4'h0;
          memop_cnt <= '0;
        end else begin
          // Increment subop counter
          subop_cnt <= subop_cnt + 4'h1;

          if (|mem_rmask [STAGE_WB] || |mem_wmask [STAGE_WB]) begin
            memop_cnt <= memop_cnt + 7'h1;
          end
        end
      end
    end
  end // always_ff @

  assign rvfi_nmip = {nmi_is_store_i, nmi_pending_i};

  // Capture possible performance counter writes during WB, before wb_valid_lastop
  // If counter write happens before wb_valid_lastop (e.g. LSU stalled waiting for rvalid or WFI that is in WB multiple cycles),
  // we must keep _n and _q values to correctly set _rdata and _wdata when rvfi_valid is set.
  // If wb_valid_lastop occurs in the same cycle as the write, the flags are zero and any
  // stored values will not be used.
  generate for (genvar i = 0; i < 32; i++)
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        mhpmcounter_l_rdata_q[i] <= '0;
        mhpmcounter_h_rdata_q[i] <= '0;
        mhpmcounter_l_wdata_q[i] <= '0;
        mhpmcounter_h_wdata_q[i] <= '0;
        mhpmcounter_l_during_wb[i] <= 1'b0;
        mhpmcounter_h_during_wb[i] <= 1'b0;
      end else begin
        // Clear flags on wb_valid
        if (wb_valid_lastop) begin
          mhpmcounter_l_during_wb[i] <= 1'b0;
          mhpmcounter_h_during_wb[i] <= 1'b0;
        end else begin
          // Capture counter writes.
          if (csr_mhpmcounter_we_l[i]) begin
            mhpmcounter_l_during_wb[i] <= 1'b1;
            mhpmcounter_l_rdata_q[i]   <= csr_mhpmcounter_q_l[i];
            mhpmcounter_l_wdata_q[i]   <= csr_mhpmcounter_n_l[i];
          end

          if (csr_mhpmcounter_we_h[i]) begin
            mhpmcounter_h_during_wb[i] <= 1'b1;
            mhpmcounter_h_rdata_q[i]   <= csr_mhpmcounter_q_h[i];
            mhpmcounter_h_wdata_q[i]   <= csr_mhpmcounter_n_h[i];
          end
        end
      end
    end
  endgenerate
  //////////////////


  // Byte enable based on data size
  always_comb begin
    unique case (lsu_size_id_i)
      2'b00:   rvfi_mem_mask_int = 4'b0001;
      2'b01:   rvfi_mem_mask_int = 4'b0011;
      2'b10:   rvfi_mem_mask_int = 4'b1111;
      default: rvfi_mem_mask_int = 4'b0000;
    endcase
  end

  // Destination Register
  // The rd_addr signal in rtl can contain contain unused non-zero values when not reading
  assign rd_addr_wb  = (rf_we_wb_i)      ? rf_addr_wb_i  : '0;
  assign rd_wdata_wb = (rd_addr_wb != 0) ? rf_wdata_wb_i : '0; // Gating wdata for x0 as it is assigned to 0
                                                               // in RTL regardless of wdata (which can be non-zero)

  // Source Register Read Data
  // Setting register read data from operands if there was a read and clearing if there was not as operands can contain
  // data that is not read from the register file when not reading (e.g. for immediate instructions).
  // Can't use register file rdata directly as forwarded data is needed for instructions using the same register back-to-back
  assign rs1_rdata_id = (rf_re_id_i[0]) ? operand_a_fw_id_i : '0;
  assign rs2_rdata_id = (rf_re_id_i[1]) ? operand_b_fw_id_i : '0;
  // The rs* address signals can contain unused non-zero values when not reading
  assign rs1_addr_id  = (rf_re_id_i[0]) ? rs1_addr_id_i     : '0;
  assign rs2_addr_id  = (rf_re_id_i[1]) ? rs2_addr_id_i     : '0;

  ////////////////////////////////
  //  CSRs                      //
  ////////////////////////////////

  // Zc* Register (Jump Vector Table)
  assign rvfi_csr_rdata_d.jvt                = csr_jvt_q_i;
  assign rvfi_csr_rmask_d.jvt                = '1;
  assign rvfi_csr_wdata_d.jvt                = csr_jvt_n_i;
  assign rvfi_csr_wmask_d.jvt                = csr_jvt_we_i ? '1 : '0;

  // Machine trap setup
  assign rvfi_csr_rdata_d.mstatus            = csr_mstatus_q_i;
  assign rvfi_csr_rmask_d.mstatus            = '1;
  assign rvfi_csr_wdata_d.mstatus            = csr_mstatus_n_i;
  assign rvfi_csr_wmask_d.mstatus            = csr_mstatus_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mstatush           = csr_mstatush_q_i;
  assign rvfi_csr_rmask_d.mstatush           = '1;
  assign rvfi_csr_wdata_d.mstatush           = csr_mstatush_n_i;
  assign rvfi_csr_wmask_d.mstatush           = csr_mstatush_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.misa               = csr_misa_q_i;
  assign rvfi_csr_rmask_d.misa               = '1;
  assign rvfi_csr_wdata_d.misa               = csr_misa_n_i;
  assign rvfi_csr_wmask_d.misa               = csr_misa_we_i    ? '1 : '0;

  assign rvfi_csr_rdata_d.mie                = csr_mie_q_i;
  assign rvfi_csr_rmask_d.mie                = '1;
  assign rvfi_csr_wdata_d.mie                = csr_mie_n_i;
  assign rvfi_csr_wmask_d.mie                = csr_mie_we_i     ? '1 : '0;

  assign rvfi_csr_rdata_d.mtvec              = csr_mtvec_q_i;
  assign rvfi_csr_rmask_d.mtvec              = '1;
  assign rvfi_csr_wdata_d.mtvec              = csr_mtvec_n_i;
  assign rvfi_csr_wmask_d.mtvec              = csr_mtvec_we_i   ? '1 : '0;

  assign rvfi_csr_rdata_d.mtvt               = csr_mtvt_q_i;
  assign rvfi_csr_rmask_d.mtvt               = '1;
  assign rvfi_csr_wdata_d.mtvt               = csr_mtvt_n_i;
  assign rvfi_csr_wmask_d.mtvt               = csr_mtvt_we_i   ? '1 : '0;

  // Performance counters
  assign rvfi_csr_rdata_d.mcountinhibit      = csr_mcountinhibit_q_i;
  assign rvfi_csr_rmask_d.mcountinhibit      = '1;
  assign rvfi_csr_wdata_d.mcountinhibit      = csr_mcountinhibit_n_i;
  assign rvfi_csr_wmask_d.mcountinhibit      = csr_mcountinhibit_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mhpmevent          = csr_mhpmevent_q_i;
  assign rvfi_csr_rmask_d.mhpmevent          = '1;
  assign rvfi_csr_wdata_d.mhpmevent          = csr_mhpmevent_n_i;
  assign rvfi_csr_wmask_d.mhpmevent[2:0]     = '0; // No mhpevent0-2 registers
  generate for (genvar i = 3; i < 32; i++)
    assign rvfi_csr_wmask_d.mhpmevent[i]     = csr_mhpmevent_we_i[i] ? '1 : '0;
  endgenerate

  // Machine trap handling
  assign rvfi_csr_rdata_d.mscratch           = csr_mscratch_q_i;
  assign rvfi_csr_rmask_d.mscratch           = '1;
  assign rvfi_csr_wdata_d.mscratch           = csr_mscratch_n_i;
  assign rvfi_csr_wmask_d.mscratch           = csr_mscratch_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mepc               = csr_mepc_q_i;
  assign rvfi_csr_rmask_d.mepc               = '1;
  assign rvfi_csr_wdata_d.mepc               = csr_mepc_n_i;
  assign rvfi_csr_wmask_d.mepc               = csr_mepc_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mcause             = csr_mcause_q_i;
  assign rvfi_csr_rmask_d.mcause             = '1;
  assign rvfi_csr_wdata_d.mcause             = csr_mcause_n_i;
  assign rvfi_csr_wmask_d.mcause             = csr_mcause_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mtval              = '0;
  assign rvfi_csr_rmask_d.mtval              = '1;
  assign rvfi_csr_wdata_d.mtval              = '0; // Not implemented, read 0
  assign rvfi_csr_wmask_d.mtval              = '0;

  // MIP is read in EX by CSR instructions, evaluated combinatorically in WB by the WFI instruction,
  // and is evaluated in WB for all other instructions
  assign ex_csr_rdata_d.mip                  = csr_mip_q_i;
  assign rvfi_csr_rdata_d.mip                = csr_en_wb_i                        ? ex_csr_rdata.mip :
                                               (sys_en_wb_i && sys_wfi_insn_wb_i) ?            irq_i :
                                                                                          csr_mip_q_i;
  assign rvfi_csr_rmask_d.mip                = '1;
  assign rvfi_csr_wdata_d.mip                = csr_mip_n_i;
  assign rvfi_csr_wmask_d.mip                = csr_mip_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mnxti              = csr_mnxti_q_i;
  assign rvfi_csr_rmask_d.mnxti              = csr_mnxti_in_wb_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mnxti              = csr_mnxti_n_i;
  assign rvfi_csr_wmask_d.mnxti              = csr_mnxti_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mintstatus         = csr_mintstatus_q_i;
  assign rvfi_csr_rmask_d.mintstatus         = '1;
  assign rvfi_csr_wdata_d.mintstatus         = csr_mintstatus_n_i;
  assign rvfi_csr_wmask_d.mintstatus         = csr_mintstatus_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mintthresh         = csr_mintthresh_q_i;
  assign rvfi_csr_rmask_d.mintthresh         = '1;
  assign rvfi_csr_wdata_d.mintthresh         = csr_mintthresh_n_i;
  assign rvfi_csr_wmask_d.mintthresh         = csr_mintthresh_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mscratchcsw        = csr_mscratchcsw_q_i;
  assign rvfi_csr_rmask_d.mscratchcsw        = csr_mscratchcsw_in_wb_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mscratchcsw        = csr_mscratchcsw_n_i;
  assign rvfi_csr_wmask_d.mscratchcsw        = csr_mscratchcsw_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mscratchcswl       = csr_mscratchcswl_q_i;
  assign rvfi_csr_rmask_d.mscratchcswl       = csr_mscratchcswl_in_wb_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mscratchcswl       = csr_mscratchcswl_n_i;
  assign rvfi_csr_wmask_d.mscratchcswl       = csr_mscratchcswl_we_i ? '1 : '0;

  // Trigger
  assign rvfi_csr_rdata_d.tselect            = csr_tselect_q_i;
  assign rvfi_csr_rmask_d.tselect            = '1;
  assign rvfi_csr_wdata_d.tselect            = csr_tselect_n_i;
  assign rvfi_csr_wmask_d.tselect            = csr_tselect_we_i ? '1 : '0;

  // Tdata0 does not exist, tie off to zero
  assign rvfi_csr_rdata_d.tdata[0]           = '0;
  assign rvfi_csr_rmask_d.tdata[0]           = '0;
  assign rvfi_csr_wdata_d.tdata[0]           = '0;
  assign rvfi_csr_wmask_d.tdata[0]           = '0;

  assign rvfi_csr_rdata_d.tdata[1]           = csr_tdata1_q_i;
  assign rvfi_csr_rmask_d.tdata[1]           = '1;
  assign rvfi_csr_wdata_d.tdata[1]           = csr_tdata1_n_i;
  assign rvfi_csr_wmask_d.tdata[1]           = csr_tdata1_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.tdata[2]           = csr_tdata2_q_i;
  assign rvfi_csr_rmask_d.tdata[2]           = '1;
  assign rvfi_csr_wdata_d.tdata[2]           = csr_tdata2_n_i;
  assign rvfi_csr_wmask_d.tdata[2]           = csr_tdata2_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.tdata[3]           = csr_tdata3_q_i;
  assign rvfi_csr_rmask_d.tdata[3]           = '1;
  assign rvfi_csr_wdata_d.tdata[3]           = csr_tdata3_n_i;
  assign rvfi_csr_wmask_d.tdata[3]           = csr_tdata3_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.tinfo              = csr_tinfo_q_i;
  assign rvfi_csr_rmask_d.tinfo              = '1;
  assign rvfi_csr_wdata_d.tinfo              = csr_tinfo_n_i;
  assign rvfi_csr_wmask_d.tinfo              = csr_tinfo_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.tcontrol           = csr_tcontrol_q_i;
  assign rvfi_csr_rmask_d.tcontrol           = '1;
  assign rvfi_csr_wdata_d.tcontrol           = csr_tcontrol_n_i;
  assign rvfi_csr_wmask_d.tcontrol           = csr_tcontrol_we_i ? '1 : '0;

  // Debug / Trace
  assign ex_csr_rdata_d.nmip                 = csr_dcsr_q_i[3]; // dcsr.nmip is autonomous. Propagate read value from EX stage
  assign rvfi_csr_rdata_d.dcsr               = {csr_dcsr_q_i[31:4], ex_csr_rdata.nmip, csr_dcsr_q_i[2:0]};
  assign rvfi_csr_rmask_d.dcsr               = '1;
  assign rvfi_csr_wdata_d.dcsr               = csr_dcsr_n_i;
  assign rvfi_csr_wmask_d.dcsr               = csr_dcsr_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.dpc                = csr_dpc_q_i;
  assign rvfi_csr_rmask_d.dpc                = '1;
  assign rvfi_csr_wdata_d.dpc                = csr_dpc_n_i;
  assign rvfi_csr_wmask_d.dpc                = csr_dpc_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.dscratch[0]        = csr_dscratch0_q_i;
  assign rvfi_csr_rmask_d.dscratch[0]        = '1;
  assign rvfi_csr_wdata_d.dscratch[0]        = csr_dscratch0_n_i;
  assign rvfi_csr_wmask_d.dscratch[0]        = csr_dscratch0_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.dscratch[1]        = csr_dscratch1_q_i;
  assign rvfi_csr_rmask_d.dscratch[1]        = '1;
  assign rvfi_csr_wdata_d.dscratch[1]        = csr_dscratch1_n_i;
  assign rvfi_csr_wmask_d.dscratch[1]        = csr_dscratch1_we_i ? '1 : '0;

  // Performance Monitors
  generate
    for (genvar i = 0; i < 32; i++) begin
      assign csr_mhpmcounter_n_l[i]  = csr_mhpmcounter_n_i[i][31: 0];
      assign csr_mhpmcounter_n_h[i]  = csr_mhpmcounter_n_i[i][63:32];
      assign csr_mhpmcounter_q_l[i]  = csr_mhpmcounter_q_i[i][31: 0];
      assign csr_mhpmcounter_q_h[i]  = csr_mhpmcounter_q_i[i][63:32];
      assign csr_mhpmcounter_we_l[i] = csr_mhpmcounter_we_i[i][0] ? '1 : '0;
      assign csr_mhpmcounter_we_h[i] = csr_mhpmcounter_we_i[i][1] ? '1 : '0;
    end
  endgenerate

  assign ex_csr_rdata_d.mcycle               = csr_mhpmcounter_q_l [CSR_MCYCLE & 'hF];
  assign rvfi_csr_rdata_d.mcycle             = ex_csr_rdata.mcycle;
  assign rvfi_csr_rmask_d.mcycle             = '1;
  assign rvfi_csr_wdata_d.mcycle             = csr_mhpmcounter_n_l [CSR_MCYCLE & 'hF];
  assign rvfi_csr_wmask_d.mcycle             = csr_mhpmcounter_we_l[CSR_MCYCLE & 'hF];

  // Used flopped values in case write happened before wb_valid
  assign rvfi_csr_rdata_d.minstret           = !mhpmcounter_l_during_wb[CSR_MINSTRET & 'hF] ? csr_mhpmcounter_q_l [CSR_MINSTRET & 'hF] : mhpmcounter_l_rdata_q[CSR_MINSTRET & 'hF];
  assign rvfi_csr_rmask_d.minstret           = '1;
  assign rvfi_csr_wdata_d.minstret           = !mhpmcounter_l_during_wb[CSR_MINSTRET & 'hF] ? csr_mhpmcounter_n_l [CSR_MINSTRET & 'hF] : mhpmcounter_l_wdata_q[CSR_MINSTRET & 'hF];
  assign rvfi_csr_wmask_d.minstret           = !mhpmcounter_l_during_wb[CSR_MINSTRET & 'hF] ? csr_mhpmcounter_we_l[CSR_MINSTRET & 'hF] : '1;

  // mhpmcounter [2:0] does not exist, tie to zero
  assign rvfi_csr_rdata_d.mhpmcounter[ 2:0]  = '0;
  assign rvfi_csr_rmask_d.mhpmcounter[ 2:0]  = '0;
  assign rvfi_csr_wdata_d.mhpmcounter[ 2:0]  = '0;
  assign rvfi_csr_wmask_d.mhpmcounter[ 2:0]  = '0;

  // Used flopped values in case write happened before wb_valid
  generate
    for (genvar i = 3; i < 32; i++) begin
      assign rvfi_csr_rdata_d.mhpmcounter[i]  = !mhpmcounter_l_during_wb[i] ? csr_mhpmcounter_q_l [i] : mhpmcounter_l_rdata_q[i];
      assign rvfi_csr_rmask_d.mhpmcounter[i]  = '1;
      assign rvfi_csr_wdata_d.mhpmcounter[i]  = !mhpmcounter_l_during_wb[i] ? csr_mhpmcounter_n_l [i] : mhpmcounter_l_wdata_q[i];
      assign rvfi_csr_wmask_d.mhpmcounter[i]  = !mhpmcounter_l_during_wb[i] ? csr_mhpmcounter_we_l[i] : '1;
    end
  endgenerate

  assign ex_csr_rdata_d.mcycleh              = csr_mhpmcounter_q_h [CSR_MCYCLEH & 'hF];
  assign rvfi_csr_rdata_d.mcycleh            = ex_csr_rdata.mcycleh;
  assign rvfi_csr_rmask_d.mcycleh            = '1;
  assign rvfi_csr_wdata_d.mcycleh            = csr_mhpmcounter_n_h [CSR_MCYCLEH & 'hF];
  assign rvfi_csr_wmask_d.mcycleh            = csr_mhpmcounter_we_h[CSR_MCYCLEH & 'hF];

  // Used flopped values in case write happened before wb_valid
  assign rvfi_csr_rdata_d.minstreth          = !mhpmcounter_h_during_wb[CSR_MINSTRETH & 'hF] ? csr_mhpmcounter_q_h [CSR_MINSTRETH & 'hF] : mhpmcounter_h_rdata_q[CSR_MINSTRETH & 'hF];
  assign rvfi_csr_rmask_d.minstreth          = '1;
  assign rvfi_csr_wdata_d.minstreth          = !mhpmcounter_h_during_wb[CSR_MINSTRETH & 'hF] ? csr_mhpmcounter_n_h [CSR_MINSTRETH & 'hF] : mhpmcounter_h_wdata_q[CSR_MINSTRETH & 'hF];
  assign rvfi_csr_wmask_d.minstreth          = !mhpmcounter_h_during_wb[CSR_MINSTRETH & 'hF] ? csr_mhpmcounter_we_h[CSR_MINSTRETH & 'hF] : '1;

  // mhpmcounterh [2:0] does not exist, tie to zero
  assign rvfi_csr_rdata_d.mhpmcounterh[ 2:0] = '0;
  assign rvfi_csr_rmask_d.mhpmcounterh[ 2:0] = '0;
  assign rvfi_csr_wdata_d.mhpmcounterh[ 2:0] = '0;
  assign rvfi_csr_wmask_d.mhpmcounterh[ 2:0] = '0;

  // Used flopped values in case write happened before wb_valid
  generate
    for (genvar i = 3; i < 32; i++) begin
      assign rvfi_csr_rdata_d.mhpmcounterh[i]  = !mhpmcounter_h_during_wb[i] ? csr_mhpmcounter_q_h [i] : mhpmcounter_h_rdata_q[i];
      assign rvfi_csr_rmask_d.mhpmcounterh[i] = '1;
      assign rvfi_csr_wdata_d.mhpmcounterh[i]  = !mhpmcounter_h_during_wb[i] ? csr_mhpmcounter_n_h [i] : mhpmcounter_h_wdata_q[i];
      assign rvfi_csr_wmask_d.mhpmcounterh[i]  = !mhpmcounter_h_during_wb[i] ? csr_mhpmcounter_we_h[i] : '1;
    end
  endgenerate

  assign ex_csr_rdata_d.cycle                = csr_mhpmcounter_q_l [CSR_CYCLE & 'hF];
  assign rvfi_csr_rdata_d.cycle              = ex_csr_rdata.cycle;
  assign rvfi_csr_rmask_d.cycle              = '1;
  assign rvfi_csr_wdata_d.cycle              = csr_mhpmcounter_n_l [CSR_CYCLE & 'hF];
  assign rvfi_csr_wmask_d.cycle              = csr_mhpmcounter_we_l[CSR_CYCLE & 'hF];

  assign rvfi_csr_rdata_d.instret            = csr_mhpmcounter_q_l [CSR_INSTRET & 'hF];
  assign rvfi_csr_rmask_d.instret            = '1;
  assign rvfi_csr_wdata_d.instret            = csr_mhpmcounter_n_l [CSR_INSTRET & 'hF];
  assign rvfi_csr_wmask_d.instret            = csr_mhpmcounter_we_l[CSR_INSTRET & 'hF];

  // hpmcounter[2:0] does not exist, tie to zero
  assign rvfi_csr_rdata_d.hpmcounter[ 2:0]   = '0;
  assign rvfi_csr_rmask_d.hpmcounter[ 2:0]   = '0;
  assign rvfi_csr_wdata_d.hpmcounter[ 2:0]   = '0;
  assign rvfi_csr_wmask_d.hpmcounter[ 2:0]   = '0;

  assign rvfi_csr_rdata_d.hpmcounter[31:3]   = csr_mhpmcounter_q_l [31:3];
  assign rvfi_csr_rmask_d.hpmcounter[31:3]   = '1;
  assign rvfi_csr_wdata_d.hpmcounter[31:3]   = csr_mhpmcounter_n_l [31:3];
  assign rvfi_csr_wmask_d.hpmcounter[31:3]   = csr_mhpmcounter_we_l[31:3];

  assign ex_csr_rdata_d.cycleh               = csr_mhpmcounter_q_h [CSR_CYCLEH & 'hF];
  assign rvfi_csr_rdata_d.cycleh             = ex_csr_rdata.cycleh;
  assign rvfi_csr_rmask_d.cycleh             = '1;
  assign rvfi_csr_wdata_d.cycleh             = csr_mhpmcounter_n_h [CSR_CYCLEH & 'hF];
  assign rvfi_csr_wmask_d.cycleh             = csr_mhpmcounter_we_h[CSR_CYCLEH & 'hF];

  assign rvfi_csr_rdata_d.instreth           = csr_mhpmcounter_q_h [CSR_INSTRETH & 'hF];
  assign rvfi_csr_rmask_d.instreth           = '1;
  assign rvfi_csr_wdata_d.instreth           = csr_mhpmcounter_n_h [CSR_INSTRETH & 'hF];
  assign rvfi_csr_wmask_d.instreth           = csr_mhpmcounter_we_h[CSR_INSTRETH & 'hF];

  // hpmcounterh[2:0] does not exist, tie to zero
  assign rvfi_csr_rdata_d.hpmcounterh[ 2:0]  = '0;
  assign rvfi_csr_rmask_d.hpmcounterh[ 2:0]  = '0;
  assign rvfi_csr_wdata_d.hpmcounterh[ 2:0]  = '0;
  assign rvfi_csr_wmask_d.hpmcounterh[ 2:0]  = '0;

  assign rvfi_csr_rdata_d.hpmcounterh[31:3]  = csr_mhpmcounter_q_h [31:3];
  assign rvfi_csr_rmask_d.hpmcounterh[31:3]  = '1;
  assign rvfi_csr_wdata_d.hpmcounterh[31:3]  = csr_mhpmcounter_n_h [31:3];
  assign rvfi_csr_wmask_d.hpmcounterh[31:3]  = csr_mhpmcounter_we_h[31:3];

  // Machine info
  assign rvfi_csr_rdata_d.mvendorid          = csr_mvendorid_i;
  assign rvfi_csr_rmask_d.mvendorid          = '1;
  assign rvfi_csr_wdata_d.mvendorid          = '0; // Read Only
  assign rvfi_csr_wmask_d.mvendorid          = '0;

  assign rvfi_csr_wdata_d.marchid            = '0; // Read Only
  assign rvfi_csr_wmask_d.marchid            = '0;
  assign rvfi_csr_rdata_d.marchid            = csr_marchid_i;
  assign rvfi_csr_rmask_d.marchid            = '1;

  assign rvfi_csr_wdata_d.mimpid             = '0; // Read Only
  assign rvfi_csr_wmask_d.mimpid             = '0;
  assign rvfi_csr_rdata_d.mimpid             = csr_mimpid_i;
  assign rvfi_csr_rmask_d.mimpid             = '1;

  assign rvfi_csr_wdata_d.mhartid            = '0; // Read Only
  assign rvfi_csr_wmask_d.mhartid            = '0;
  assign rvfi_csr_rdata_d.mhartid            = csr_mhartid_i;
  assign rvfi_csr_rmask_d.mhartid            = '1;

  // User Mode
  assign rvfi_csr_rdata_d.mcounteren         = csr_mcounteren_q_i;
  assign rvfi_csr_rmask_d.mcounteren         = '1;
  assign rvfi_csr_wdata_d.mcounteren         = csr_mcounteren_n_i;
  assign rvfi_csr_wmask_d.mcounteren         = csr_mcounteren_we_i ? '1 : '0;

  // PMP
  // Special case for the PMP cfg registers because they are split by pmp region and not by register
  generate
    for (genvar i = 0; i < 16; i++ ) begin // Max 16 pmp regions
      // 4 regions in each register
      assign rvfi_csr_wdata_d.pmpcfg[i/4][8*(i%4)+:8] = csr_pmpcfg_n_i[i];
      assign rvfi_csr_rdata_d.pmpcfg[i/4][8*(i%4)+:8] = csr_pmpcfg_q_i[i];
      assign rvfi_csr_rmask_d.pmpcfg[i/4][8*(i%4)+:8] = '1;
      assign rvfi_csr_wmask_d.pmpcfg[i/4][8*(i%4)+:8] = csr_pmpcfg_we_i[i] ? '1 : '0;

      assign rvfi_csr_wdata_d.pmpaddr[i]          = csr_pmpaddr_n_i; // input shared between all registers
      assign rvfi_csr_rdata_d.pmpaddr[i]          = csr_pmpaddr_q_i[i];
      assign rvfi_csr_rmask_d.pmpaddr[i]          = '1;
    assign rvfi_csr_wmask_d.pmpaddr[i]       = csr_pmpaddr_we_i[i] ? '1 : '0;
    end
  endgenerate

  assign rvfi_csr_wdata_d.mseccfg         = csr_mseccfg_n_i;
  assign rvfi_csr_rdata_d.mseccfg         = csr_mseccfg_q_i;
  assign rvfi_csr_rmask_d.mseccfg         = '1;
  assign rvfi_csr_wmask_d.mseccfg         = csr_mseccfg_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mseccfgh        = csr_mseccfgh_n_i;
  assign rvfi_csr_rdata_d.mseccfgh        = csr_mseccfgh_q_i;
  assign rvfi_csr_rmask_d.mseccfgh        = '1;
  assign rvfi_csr_wmask_d.mseccfgh        = csr_mseccfgh_we_i ? '1 : '0;

  assign rvfi_csr_rdata_d.mconfigptr      = csr_mconfigptr_q_i;
  assign rvfi_csr_rmask_d.mconfigptr      = '1;
  assign rvfi_csr_wdata_d.mconfigptr      = csr_mconfigptr_n_i;
  assign rvfi_csr_wmask_d.mconfigptr      = csr_mconfigptr_we_i ? '1 : '0;

  assign rvfi_csr_wdata_d.menvcfg         = csr_menvcfg_n_i;
  assign rvfi_csr_rdata_d.menvcfg         = csr_menvcfg_q_i;
  assign rvfi_csr_rmask_d.menvcfg         = '1;
  assign rvfi_csr_wmask_d.menvcfg         = csr_menvcfg_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.menvcfgh        = csr_menvcfgh_n_i;
  assign rvfi_csr_rdata_d.menvcfgh        = csr_menvcfgh_q_i;
  assign rvfi_csr_rmask_d.menvcfgh        = '1;
  assign rvfi_csr_wmask_d.menvcfgh        = csr_menvcfgh_we_i ? '1 : '0;

  assign rvfi_csr_wdata_d.cpuctrl         = csr_cpuctrl_n_i;
  assign rvfi_csr_rdata_d.cpuctrl         = csr_cpuctrl_q_i;
  assign rvfi_csr_rmask_d.cpuctrl         = '1;
  assign rvfi_csr_wmask_d.cpuctrl         = csr_cpuctrl_we_i ? '1 : '0;

  assign rvfi_csr_wdata_d.secureseed0     = csr_secureseed0_n_i;
  assign rvfi_csr_rdata_d.secureseed0     = csr_secureseed0_q_i;
  assign rvfi_csr_rmask_d.secureseed0     = '1;
  assign rvfi_csr_wmask_d.secureseed0     = csr_secureseed0_we_i ? '1 : '0;

  assign rvfi_csr_wdata_d.secureseed1     = csr_secureseed1_n_i;
  assign rvfi_csr_rdata_d.secureseed1     = csr_secureseed1_q_i;
  assign rvfi_csr_rmask_d.secureseed1     = '1;
  assign rvfi_csr_wmask_d.secureseed1     = csr_secureseed1_we_i ? '1 : '0;

  assign rvfi_csr_wdata_d.secureseed2     = csr_secureseed2_n_i;
  assign rvfi_csr_rdata_d.secureseed2     = csr_secureseed2_q_i;
  assign rvfi_csr_rmask_d.secureseed2     = '1;
  assign rvfi_csr_wmask_d.secureseed2     = csr_secureseed2_we_i ? '1 : '0;

  assign rvfi_csr_wdata_d.mstateen0       = csr_mstateen0_n_i;
  assign rvfi_csr_rdata_d.mstateen0       = csr_mstateen0_q_i;
  assign rvfi_csr_rmask_d.mstateen0       = '1;
  assign rvfi_csr_wmask_d.mstateen0       = csr_mstateen0_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mstateen1       = csr_mstateen1_n_i;
  assign rvfi_csr_rdata_d.mstateen1       = csr_mstateen1_q_i;
  assign rvfi_csr_rmask_d.mstateen1       = '1;
  assign rvfi_csr_wmask_d.mstateen1       = csr_mstateen1_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mstateen2       = csr_mstateen2_n_i;
  assign rvfi_csr_rdata_d.mstateen2       = csr_mstateen2_q_i;
  assign rvfi_csr_rmask_d.mstateen2       = '1;
  assign rvfi_csr_wmask_d.mstateen2       = csr_mstateen2_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mstateen3       = csr_mstateen3_n_i;
  assign rvfi_csr_rdata_d.mstateen3       = csr_mstateen3_q_i;
  assign rvfi_csr_rmask_d.mstateen3       = '1;
  assign rvfi_csr_wmask_d.mstateen3       = csr_mstateen3_we_i ? '1 : '0;

  assign rvfi_csr_wdata_d.mstateen0h      = csr_mstateen0h_n_i;
  assign rvfi_csr_rdata_d.mstateen0h      = csr_mstateen0h_q_i;
  assign rvfi_csr_rmask_d.mstateen0h      = '1;
  assign rvfi_csr_wmask_d.mstateen0h      = csr_mstateen0h_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mstateen1h      = csr_mstateen1h_n_i;
  assign rvfi_csr_rdata_d.mstateen1h      = csr_mstateen1h_q_i;
  assign rvfi_csr_rmask_d.mstateen1h      = '1;
  assign rvfi_csr_wmask_d.mstateen1h      = csr_mstateen1h_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mstateen2h      = csr_mstateen2h_n_i;
  assign rvfi_csr_rdata_d.mstateen2h      = csr_mstateen2h_q_i;
  assign rvfi_csr_rmask_d.mstateen2h      = '1;
  assign rvfi_csr_wmask_d.mstateen2h      = csr_mstateen2h_we_i ? '1 : '0;
  assign rvfi_csr_wdata_d.mstateen3h      = csr_mstateen3h_n_i;
  assign rvfi_csr_rdata_d.mstateen3h      = csr_mstateen3h_q_i;
  assign rvfi_csr_rmask_d.mstateen3h      = '1;
  assign rvfi_csr_wmask_d.mstateen3h      = csr_mstateen3h_we_i ? '1 : '0;

  // CSR outputs //
  assign rvfi_csr_jvt_rdata               = rvfi_csr_rdata.jvt;
  assign rvfi_csr_jvt_rmask               = rvfi_csr_rmask.jvt;
  assign rvfi_csr_jvt_wdata               = rvfi_csr_wdata.jvt;
  assign rvfi_csr_jvt_wmask               = rvfi_csr_wmask.jvt;
  assign rvfi_csr_mstatus_rdata           = rvfi_csr_rdata.mstatus;
  assign rvfi_csr_mstatus_rmask           = rvfi_csr_rmask.mstatus;
  assign rvfi_csr_mstatus_wdata           = rvfi_csr_wdata.mstatus;
  assign rvfi_csr_mstatus_wmask           = rvfi_csr_wmask.mstatus;
  assign rvfi_csr_mstatush_rdata          = rvfi_csr_rdata.mstatush;
  assign rvfi_csr_mstatush_rmask          = rvfi_csr_rmask.mstatush;
  assign rvfi_csr_mstatush_wdata          = rvfi_csr_wdata.mstatush;
  assign rvfi_csr_mstatush_wmask          = rvfi_csr_wmask.mstatush;
  assign rvfi_csr_misa_rdata              = rvfi_csr_rdata.misa;
  assign rvfi_csr_misa_rmask              = rvfi_csr_rmask.misa;
  assign rvfi_csr_misa_wdata              = rvfi_csr_wdata.misa;
  assign rvfi_csr_misa_wmask              = rvfi_csr_wmask.misa;
  assign rvfi_csr_mie_rdata               = rvfi_csr_rdata.mie;
  assign rvfi_csr_mie_rmask               = rvfi_csr_rmask.mie;
  assign rvfi_csr_mie_wdata               = rvfi_csr_wdata.mie;
  assign rvfi_csr_mie_wmask               = rvfi_csr_wmask.mie;
  assign rvfi_csr_mtvec_rdata             = rvfi_csr_rdata.mtvec;
  assign rvfi_csr_mtvec_rmask             = rvfi_csr_rmask.mtvec;
  assign rvfi_csr_mtvec_wdata             = rvfi_csr_wdata.mtvec;
  assign rvfi_csr_mtvec_wmask             = rvfi_csr_wmask.mtvec;
  assign rvfi_csr_mtvt_rdata              = rvfi_csr_rdata.mtvt;
  assign rvfi_csr_mtvt_rmask              = rvfi_csr_rmask.mtvt;
  assign rvfi_csr_mtvt_wdata              = rvfi_csr_wdata.mtvt;
  assign rvfi_csr_mtvt_wmask              = rvfi_csr_wmask.mtvt;
  assign rvfi_csr_mcountinhibit_rdata     = rvfi_csr_rdata.mcountinhibit;
  assign rvfi_csr_mcountinhibit_rmask     = rvfi_csr_rmask.mcountinhibit;
  assign rvfi_csr_mcountinhibit_wdata     = rvfi_csr_wdata.mcountinhibit;
  assign rvfi_csr_mcountinhibit_wmask     = rvfi_csr_wmask.mcountinhibit;
  assign rvfi_csr_mhpmevent_rdata         = rvfi_csr_rdata.mhpmevent;
  assign rvfi_csr_mhpmevent_rmask[ 2:0]   = rvfi_csr_rmask.mhpmevent[2:0];
  assign rvfi_csr_mhpmevent_rmask[31:3]   = rvfi_csr_rmask.mhpmevent[31:3];
  assign rvfi_csr_mhpmevent_wdata         = rvfi_csr_wdata.mhpmevent;
  assign rvfi_csr_mhpmevent_wmask         = rvfi_csr_wmask.mhpmevent;
  assign rvfi_csr_mscratch_rdata          = rvfi_csr_rdata.mscratch;
  assign rvfi_csr_mscratch_rmask          = rvfi_csr_rmask.mscratch;
  assign rvfi_csr_mscratch_wdata          = rvfi_csr_wdata.mscratch;
  assign rvfi_csr_mscratch_wmask          = rvfi_csr_wmask.mscratch;
  assign rvfi_csr_mepc_rdata              = rvfi_csr_rdata.mepc;
  assign rvfi_csr_mepc_rmask              = rvfi_csr_rmask.mepc;
  assign rvfi_csr_mepc_wdata              = rvfi_csr_wdata.mepc;
  assign rvfi_csr_mepc_wmask              = rvfi_csr_wmask.mepc;
  assign rvfi_csr_mcause_rdata            = rvfi_csr_rdata.mcause;
  assign rvfi_csr_mcause_rmask            = rvfi_csr_rmask.mcause;
  assign rvfi_csr_mcause_wdata            = rvfi_csr_wdata.mcause;
  assign rvfi_csr_mcause_wmask            = rvfi_csr_wmask.mcause;
  assign rvfi_csr_mtval_rdata             = rvfi_csr_rdata.mtval;
  assign rvfi_csr_mtval_rmask             = rvfi_csr_rmask.mtval;
  assign rvfi_csr_mtval_wdata             = rvfi_csr_wdata.mtval;
  assign rvfi_csr_mtval_wmask             = rvfi_csr_wmask.mtval;
  assign rvfi_csr_mip_rdata               = rvfi_csr_rdata.mip;
  assign rvfi_csr_mip_rmask               = rvfi_csr_rmask.mip;
  assign rvfi_csr_mip_wdata               = rvfi_csr_wdata.mip;
  assign rvfi_csr_mip_wmask               = rvfi_csr_wmask.mip;
  assign rvfi_csr_mnxti_rmask             = rvfi_csr_rmask.mnxti;
  assign rvfi_csr_mnxti_rdata             = rvfi_csr_rdata.mnxti;
  assign rvfi_csr_mnxti_wmask             = rvfi_csr_wmask.mnxti;
  assign rvfi_csr_mnxti_wdata             = rvfi_csr_wdata.mnxti;
  assign rvfi_csr_mintstatus_rdata        = rvfi_csr_rdata.mintstatus;
  assign rvfi_csr_mintstatus_rmask        = rvfi_csr_rmask.mintstatus;
  assign rvfi_csr_mintstatus_wdata        = rvfi_csr_wdata.mintstatus;
  assign rvfi_csr_mintstatus_wmask        = rvfi_csr_wmask.mintstatus;
  assign rvfi_csr_mintthresh_rdata        = rvfi_csr_rdata.mintthresh;
  assign rvfi_csr_mintthresh_rmask        = rvfi_csr_rmask.mintthresh;
  assign rvfi_csr_mintthresh_wdata        = rvfi_csr_wdata.mintthresh;
  assign rvfi_csr_mintthresh_wmask        = rvfi_csr_wmask.mintthresh;
  assign rvfi_csr_mscratchcsw_rdata       = rvfi_csr_rdata.mscratchcsw;
  assign rvfi_csr_mscratchcsw_rmask       = rvfi_csr_rmask.mscratchcsw;
  assign rvfi_csr_mscratchcsw_wdata       = rvfi_csr_wdata.mscratchcsw;
  assign rvfi_csr_mscratchcsw_wmask       = rvfi_csr_wmask.mscratchcsw;
  assign rvfi_csr_mscratchcswl_rdata      = rvfi_csr_rdata.mscratchcswl;
  assign rvfi_csr_mscratchcswl_rmask      = rvfi_csr_rmask.mscratchcswl;
  assign rvfi_csr_mscratchcswl_wdata      = rvfi_csr_wdata.mscratchcswl;
  assign rvfi_csr_mscratchcswl_wmask      = rvfi_csr_wmask.mscratchcswl;
  assign rvfi_csr_tselect_rdata           = rvfi_csr_rdata.tselect;
  assign rvfi_csr_tselect_rmask           = rvfi_csr_rmask.tselect;
  assign rvfi_csr_tselect_wdata           = rvfi_csr_wdata.tselect;
  assign rvfi_csr_tselect_wmask           = rvfi_csr_wmask.tselect;
  assign rvfi_csr_tdata_rdata             = rvfi_csr_rdata.tdata;
  assign rvfi_csr_tdata_rmask[0]          = '0; // Does not exist
  assign rvfi_csr_tdata_rmask[3:1]        = rvfi_csr_rmask.tdata[3:1];
  assign rvfi_csr_tdata_wdata             = rvfi_csr_wdata.tdata;
  assign rvfi_csr_tdata_wmask             = rvfi_csr_wmask.tdata;
  assign rvfi_csr_tinfo_rdata             = rvfi_csr_rdata.tinfo;
  assign rvfi_csr_tinfo_rmask             = rvfi_csr_rmask.tinfo;
  assign rvfi_csr_tinfo_wdata             = rvfi_csr_wdata.tinfo;
  assign rvfi_csr_tinfo_wmask             = rvfi_csr_wmask.tinfo;
  assign rvfi_csr_tcontrol_rdata          = rvfi_csr_rdata.tcontrol;
  assign rvfi_csr_tcontrol_rmask          = rvfi_csr_rmask.tcontrol;
  assign rvfi_csr_tcontrol_wdata          = rvfi_csr_wdata.tcontrol;
  assign rvfi_csr_tcontrol_wmask          = rvfi_csr_wmask.tcontrol;
  assign rvfi_csr_dcsr_rdata              = rvfi_csr_rdata.dcsr;
  assign rvfi_csr_dcsr_rmask              = rvfi_csr_rmask.dcsr;
  assign rvfi_csr_dcsr_wdata              = rvfi_csr_wdata.dcsr;
  assign rvfi_csr_dcsr_wmask              = rvfi_csr_wmask.dcsr;
  assign rvfi_csr_dpc_rdata               = rvfi_csr_rdata.dpc;
  assign rvfi_csr_dpc_rmask               = rvfi_csr_rmask.dpc;
  assign rvfi_csr_dpc_wdata               = rvfi_csr_wdata.dpc;
  assign rvfi_csr_dpc_wmask               = rvfi_csr_wmask.dpc;
  assign rvfi_csr_dscratch_rdata          = rvfi_csr_rdata.dscratch;
  assign rvfi_csr_dscratch_rmask          = rvfi_csr_rmask.dscratch;
  assign rvfi_csr_dscratch_wdata          = rvfi_csr_wdata.dscratch;
  assign rvfi_csr_dscratch_wmask          = rvfi_csr_wmask.dscratch;
  assign rvfi_csr_mcycle_rdata            = rvfi_csr_rdata.mcycle;
  assign rvfi_csr_mcycle_rmask            = rvfi_csr_rmask.mcycle;
  assign rvfi_csr_mcycle_wdata            = rvfi_csr_wdata.mcycle;
  assign rvfi_csr_mcycle_wmask            = rvfi_csr_wmask.mcycle;
  assign rvfi_csr_minstret_rdata          = rvfi_csr_rdata.minstret;
  assign rvfi_csr_minstret_rmask          = rvfi_csr_rmask.minstret;
  assign rvfi_csr_minstret_wdata          = rvfi_csr_wdata.minstret;
  assign rvfi_csr_minstret_wmask          = rvfi_csr_wmask.minstret;
  assign rvfi_csr_mhpmcounter_rdata       = rvfi_csr_rdata.mhpmcounter;
  assign rvfi_csr_mhpmcounter_rmask[ 2:0] = rvfi_csr_rmask.mhpmcounter[2:0];
  assign rvfi_csr_mhpmcounter_rmask[31:3] = rvfi_csr_rmask.mhpmcounter[31:3];
  assign rvfi_csr_mhpmcounter_wdata       = rvfi_csr_wdata.mhpmcounter;
  assign rvfi_csr_mhpmcounter_wmask       = rvfi_csr_wmask.mhpmcounter;
  assign rvfi_csr_mcycleh_rdata           = rvfi_csr_rdata.mcycleh;
  assign rvfi_csr_mcycleh_rmask           = rvfi_csr_rmask.mcycleh;
  assign rvfi_csr_mcycleh_wdata           = rvfi_csr_wdata.mcycleh;
  assign rvfi_csr_mcycleh_wmask           = rvfi_csr_wmask.mcycleh;
  assign rvfi_csr_minstreth_rdata         = rvfi_csr_rdata.minstreth;
  assign rvfi_csr_minstreth_rmask         = rvfi_csr_rmask.minstreth;
  assign rvfi_csr_minstreth_wdata         = rvfi_csr_wdata.minstreth;
  assign rvfi_csr_minstreth_wmask         = rvfi_csr_wmask.minstreth;
  assign rvfi_csr_mhpmcounterh_rdata      = rvfi_csr_rdata.mhpmcounterh;
  assign rvfi_csr_mhpmcounterh_rmask[ 2:0] = rvfi_csr_rmask.mhpmcounterh[2:0];
  assign rvfi_csr_mhpmcounterh_rmask[31:3] = rvfi_csr_rmask.mhpmcounterh[31:3];
  assign rvfi_csr_mhpmcounterh_wdata      = rvfi_csr_wdata.mhpmcounterh;
  assign rvfi_csr_mhpmcounterh_wmask      = rvfi_csr_wmask.mhpmcounterh;
  assign rvfi_csr_mvendorid_rdata         = rvfi_csr_rdata.mvendorid;
  assign rvfi_csr_mvendorid_rmask         = rvfi_csr_rmask.mvendorid;
  assign rvfi_csr_mvendorid_wdata         = rvfi_csr_wdata.mvendorid;
  assign rvfi_csr_mvendorid_wmask         = rvfi_csr_wmask.mvendorid;
  assign rvfi_csr_marchid_rdata           = rvfi_csr_rdata.marchid;
  assign rvfi_csr_marchid_rmask           = rvfi_csr_rmask.marchid;
  assign rvfi_csr_marchid_wdata           = rvfi_csr_wdata.marchid;
  assign rvfi_csr_marchid_wmask           = rvfi_csr_wmask.marchid;
  assign rvfi_csr_mimpid_rdata            = rvfi_csr_rdata.mimpid;
  assign rvfi_csr_mimpid_rmask            = rvfi_csr_rmask.mimpid;
  assign rvfi_csr_mimpid_wdata            = rvfi_csr_wdata.mimpid;
  assign rvfi_csr_mimpid_wmask            = rvfi_csr_wmask.mimpid;
  assign rvfi_csr_mhartid_rdata           = rvfi_csr_rdata.mhartid;
  assign rvfi_csr_mhartid_rmask           = rvfi_csr_rmask.mhartid;
  assign rvfi_csr_mhartid_wdata           = rvfi_csr_wdata.mhartid;
  assign rvfi_csr_mhartid_wmask           = rvfi_csr_wmask.mhartid;
  assign rvfi_csr_cycle_rdata             = rvfi_csr_rdata.cycle;
  assign rvfi_csr_cycle_rmask             = rvfi_csr_rmask.cycle;
  assign rvfi_csr_cycle_wdata             = rvfi_csr_wdata.cycle;
  assign rvfi_csr_cycle_wmask             = rvfi_csr_wmask.cycle;
  assign rvfi_csr_instret_rdata           = rvfi_csr_rdata.instret;
  assign rvfi_csr_instret_rmask           = rvfi_csr_rmask.instret;
  assign rvfi_csr_instret_wdata           = rvfi_csr_wdata.instret;
  assign rvfi_csr_instret_wmask           = rvfi_csr_wmask.instret;
  assign rvfi_csr_hpmcounter_rdata        = rvfi_csr_rdata.hpmcounter;
  assign rvfi_csr_hpmcounter_rmask[ 2:0]  = rvfi_csr_rmask.hpmcounter[2:0];
  assign rvfi_csr_hpmcounter_rmask[31:3]  = rvfi_csr_rmask.hpmcounter[31:3];
  assign rvfi_csr_hpmcounter_wdata        = rvfi_csr_wdata.hpmcounter;
  assign rvfi_csr_hpmcounter_wmask        = rvfi_csr_wmask.hpmcounter;
  assign rvfi_csr_cycleh_rdata            = rvfi_csr_rdata.cycleh;
  assign rvfi_csr_cycleh_rmask            = rvfi_csr_rmask.cycleh;
  assign rvfi_csr_cycleh_wdata            = rvfi_csr_wdata.cycleh;
  assign rvfi_csr_cycleh_wmask            = rvfi_csr_wmask.cycleh;
  assign rvfi_csr_instreth_rdata          = rvfi_csr_rdata.instreth;
  assign rvfi_csr_instreth_rmask          = rvfi_csr_rmask.instreth;
  assign rvfi_csr_instreth_wdata          = rvfi_csr_wdata.instreth;
  assign rvfi_csr_instreth_wmask          = rvfi_csr_wmask.instreth;
  assign rvfi_csr_hpmcounterh_rdata       = rvfi_csr_rdata.hpmcounterh;
  assign rvfi_csr_hpmcounterh_rmask[ 2:0] = rvfi_csr_rmask.hpmcounterh[2:0];
  assign rvfi_csr_hpmcounterh_rmask[31:3] = rvfi_csr_rmask.hpmcounterh[31:3];
  assign rvfi_csr_hpmcounterh_wdata       = rvfi_csr_wdata.hpmcounterh;
  assign rvfi_csr_hpmcounterh_wmask       = rvfi_csr_wmask.hpmcounterh;
  assign rvfi_csr_mcounteren_rdata        = rvfi_csr_rdata.mcounteren;
  assign rvfi_csr_mcounteren_rmask        = rvfi_csr_rmask.mcounteren;
  assign rvfi_csr_mcounteren_wdata        = rvfi_csr_wdata.mcounteren;
  assign rvfi_csr_mcounteren_wmask        = rvfi_csr_wmask.mcounteren;
  assign rvfi_csr_pmpcfg_rdata            = rvfi_csr_rdata.pmpcfg;
  assign rvfi_csr_pmpcfg_rmask            = rvfi_csr_rmask.pmpcfg;
  assign rvfi_csr_pmpcfg_wdata            = rvfi_csr_wdata.pmpcfg;
  assign rvfi_csr_pmpcfg_wmask            = rvfi_csr_wmask.pmpcfg;
  assign rvfi_csr_pmpaddr_rdata           = rvfi_csr_rdata.pmpaddr;
  assign rvfi_csr_pmpaddr_rmask           = rvfi_csr_rmask.pmpaddr;
  assign rvfi_csr_pmpaddr_wdata           = rvfi_csr_wdata.pmpaddr;
  assign rvfi_csr_pmpaddr_wmask           = rvfi_csr_wmask.pmpaddr;
  assign rvfi_csr_mseccfg_rdata           = rvfi_csr_rdata.mseccfg;
  assign rvfi_csr_mseccfg_rmask           = rvfi_csr_rmask.mseccfg;
  assign rvfi_csr_mseccfg_wdata           = rvfi_csr_wdata.mseccfg;
  assign rvfi_csr_mseccfg_wmask           = rvfi_csr_wmask.mseccfg;
  assign rvfi_csr_mseccfgh_rdata          = rvfi_csr_rdata.mseccfgh;
  assign rvfi_csr_mseccfgh_rmask          = rvfi_csr_rmask.mseccfgh;
  assign rvfi_csr_mseccfgh_wdata          = rvfi_csr_wdata.mseccfgh;
  assign rvfi_csr_mseccfgh_wmask          = rvfi_csr_wmask.mseccfgh;
  assign rvfi_csr_menvcfg_rdata           = rvfi_csr_rdata.menvcfg;
  assign rvfi_csr_menvcfg_rmask           = rvfi_csr_rmask.menvcfg;
  assign rvfi_csr_menvcfg_wdata           = rvfi_csr_wdata.menvcfg;
  assign rvfi_csr_menvcfg_wmask           = rvfi_csr_wmask.menvcfg;
  assign rvfi_csr_menvcfgh_rdata          = rvfi_csr_rdata.menvcfgh;
  assign rvfi_csr_menvcfgh_rmask          = rvfi_csr_rmask.menvcfgh;
  assign rvfi_csr_menvcfgh_wdata          = rvfi_csr_wdata.menvcfgh;
  assign rvfi_csr_menvcfgh_wmask          = rvfi_csr_wmask.menvcfgh;
  assign rvfi_csr_cpuctrl_rdata           = rvfi_csr_rdata.cpuctrl;
  assign rvfi_csr_cpuctrl_rmask           = rvfi_csr_rmask.cpuctrl;
  assign rvfi_csr_cpuctrl_wdata           = rvfi_csr_wdata.cpuctrl;
  assign rvfi_csr_cpuctrl_wmask           = rvfi_csr_wmask.cpuctrl;
  assign rvfi_csr_mconfigptr_rdata        = rvfi_csr_rdata.mconfigptr;
  assign rvfi_csr_mconfigptr_rmask        = rvfi_csr_rmask.mconfigptr;
  assign rvfi_csr_mconfigptr_wdata        = rvfi_csr_wdata.mconfigptr;
  assign rvfi_csr_mconfigptr_wmask        = rvfi_csr_wmask.mconfigptr;
  assign rvfi_csr_secureseed0_rdata       = rvfi_csr_rdata.secureseed0;
  assign rvfi_csr_secureseed0_rmask       = rvfi_csr_rmask.secureseed0;
  assign rvfi_csr_secureseed0_wdata       = rvfi_csr_wdata.secureseed0;
  assign rvfi_csr_secureseed0_wmask       = rvfi_csr_wmask.secureseed0;
  assign rvfi_csr_secureseed1_rdata       = rvfi_csr_rdata.secureseed1;
  assign rvfi_csr_secureseed1_rmask       = rvfi_csr_rmask.secureseed1;
  assign rvfi_csr_secureseed1_wdata       = rvfi_csr_wdata.secureseed1;
  assign rvfi_csr_secureseed1_wmask       = rvfi_csr_wmask.secureseed1;
  assign rvfi_csr_secureseed2_rdata       = rvfi_csr_rdata.secureseed2;
  assign rvfi_csr_secureseed2_rmask       = rvfi_csr_rmask.secureseed2;
  assign rvfi_csr_secureseed2_wdata       = rvfi_csr_wdata.secureseed2;
  assign rvfi_csr_secureseed2_wmask       = rvfi_csr_wmask.secureseed2;

  assign rvfi_csr_mstateen0_rdata       = rvfi_csr_rdata.mstateen0;
  assign rvfi_csr_mstateen0_rmask       = rvfi_csr_rmask.mstateen0;
  assign rvfi_csr_mstateen0_wdata       = rvfi_csr_wdata.mstateen0;
  assign rvfi_csr_mstateen0_wmask       = rvfi_csr_wmask.mstateen0;
  assign rvfi_csr_mstateen1_rdata       = rvfi_csr_rdata.mstateen1;
  assign rvfi_csr_mstateen1_rmask       = rvfi_csr_rmask.mstateen1;
  assign rvfi_csr_mstateen1_wdata       = rvfi_csr_wdata.mstateen1;
  assign rvfi_csr_mstateen1_wmask       = rvfi_csr_wmask.mstateen1;
  assign rvfi_csr_mstateen2_rdata       = rvfi_csr_rdata.mstateen2;
  assign rvfi_csr_mstateen2_rmask       = rvfi_csr_rmask.mstateen2;
  assign rvfi_csr_mstateen2_wdata       = rvfi_csr_wdata.mstateen2;
  assign rvfi_csr_mstateen2_wmask       = rvfi_csr_wmask.mstateen2;
  assign rvfi_csr_mstateen3_rdata       = rvfi_csr_rdata.mstateen3;
  assign rvfi_csr_mstateen3_rmask       = rvfi_csr_rmask.mstateen3;
  assign rvfi_csr_mstateen3_wdata       = rvfi_csr_wdata.mstateen3;
  assign rvfi_csr_mstateen3_wmask       = rvfi_csr_wmask.mstateen3;
  assign rvfi_csr_mstateen0h_rdata      = rvfi_csr_rdata.mstateen0h;
  assign rvfi_csr_mstateen0h_rmask      = rvfi_csr_rmask.mstateen0h;
  assign rvfi_csr_mstateen0h_wdata      = rvfi_csr_wdata.mstateen0h;
  assign rvfi_csr_mstateen0h_wmask      = rvfi_csr_wmask.mstateen0h;
  assign rvfi_csr_mstateen1h_rdata      = rvfi_csr_rdata.mstateen1h;
  assign rvfi_csr_mstateen1h_rmask      = rvfi_csr_rmask.mstateen1h;
  assign rvfi_csr_mstateen1h_wdata      = rvfi_csr_wdata.mstateen1h;
  assign rvfi_csr_mstateen1h_wmask      = rvfi_csr_wmask.mstateen1h;
  assign rvfi_csr_mstateen2h_rdata      = rvfi_csr_rdata.mstateen2h;
  assign rvfi_csr_mstateen2h_rmask      = rvfi_csr_rmask.mstateen2h;
  assign rvfi_csr_mstateen2h_wdata      = rvfi_csr_wdata.mstateen2h;
  assign rvfi_csr_mstateen2h_wmask      = rvfi_csr_wmask.mstateen2h;
  assign rvfi_csr_mstateen3h_rdata      = rvfi_csr_rdata.mstateen3h;
  assign rvfi_csr_mstateen3h_rmask      = rvfi_csr_rmask.mstateen3h;
  assign rvfi_csr_mstateen3h_wdata      = rvfi_csr_wdata.mstateen3h;
  assign rvfi_csr_mstateen3h_wmask      = rvfi_csr_wmask.mstateen3h;
endmodule
