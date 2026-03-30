# Copyright 2020 Silicon Labs, Inc.
#
# This file, and derivatives thereof are licensed under the
# Solderpad License, Version 2.0 (the "License").
#
# Use of this file means you agree to the terms and conditions
# of the license and are in full compliance with the License.
#
# You may obtain a copy of the License at:
#
#     https://solderpad.org/licenses/SHL-2.0/
#
# Unless required by applicable law or agreed to in writing, software
# and hardware implementations thereof distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
#
# See the License for the specific language governing permissions and
# limitations under the License.

#//////////////////////////////////////////////////////////////////////////////
# Engineer:       Arjan Bink - arjan.bink@silabs.com                         //
#                                                                            //
# Project Name:   CV32E40P                                                   //
#                                                                            //
# Description:    Example synthesis constraints.                             //
#                                                                            //
#                 The clock period and input/output delays are technology    //
#                 and project dependent and are expected to be adjusted as   //
#                 needed.                                                    //
#                                                                            //
#                 OBI related bus inputs arrive late on purpose and OBI      //
#                 related outputs are available earlier (as they shall not   //
#                 combinatorially depend on the OBI inputs)                  //
#                                                                            //
#//////////////////////////////////////////////////////////////////////////////

# 200MHz
set clock_period 5.0

# Input delays for interrupts
set in_delay_irq          [expr $clock_period * 0.50]

# Input delay for wu_wfe_i
set in_delay_wfe          [expr $clock_period * 0.50]

# Delay for CLIC
# todo: set final constraints for CLIC signals
set in_delay_clic         [expr $clock_period * 0.50]
set out_delay_clic        [expr $clock_period * 0.50]

# Input delays for early signals

set in_delay_early [expr $clock_period * 0.10]

# Input delay for fencei handshake
set in_delay_fencei       [expr $clock_period * 0.80]
# Output delay for fencei handshake
set out_delay_fencei      [expr $clock_period * 0.60]

# OBI inputs delays
set in_delay_instr_gnt    [expr $clock_period * 0.70]
set in_delay_instr_rvalid [expr $clock_period * 0.80]
set in_delay_instr_rdata  [expr $clock_period * 0.80]
set in_delay_instr_err    [expr $clock_period * 0.80]

set in_delay_data_gnt     [expr $clock_period * 0.70]
set in_delay_data_rvalid  [expr $clock_period * 0.80]
set in_delay_data_rdata   [expr $clock_period * 0.70]
set in_delay_data_err     [expr $clock_period * 0.80]
set in_delay_data_exokay  [expr $clock_period * 0.80]

# OBI outputs delays
set out_delay_instr_req     [expr $clock_period * 0.60]
set out_delay_instr_addr    [expr $clock_period * 0.60]
set out_delay_instr_memtype [expr $clock_period * 0.60]
set out_delay_instr_prot    [expr $clock_period * 0.60]

set out_delay_data_req     [expr $clock_period * 0.60]
set out_delay_data_we      [expr $clock_period * 0.60]
set out_delay_data_be      [expr $clock_period * 0.60]
set out_delay_data_addr    [expr $clock_period * 0.60]
set out_delay_data_wdata   [expr $clock_period * 0.60]
set out_delay_data_atop    [expr $clock_period * 0.60]
set out_delay_data_memtype [expr $clock_period * 0.60]
set out_delay_data_prot    [expr $clock_period * 0.60]

# I/O delays for non RISC-V Bus Interface ports
set in_delay_other       [expr $clock_period * 0.10]
set out_delay_other      [expr $clock_period * 0.60]

# core_sleep_o output delay
set out_delay_core_sleep [expr $clock_period * 0.25]

# X-interface input delay
set in_delay_xif [expr $clock_period * 0.80]

# X-interface result data input delay
set in_delay_xif_result_data [expr $clock_period * 0.75]

# X-interface output delay
set out_delay_xif [expr $clock_period * 0.80]

# X-interface late data output delay
set out_delay_xif_data_late [expr $clock_period * 0.15]

# X-interface late control output delay
set out_delay_xif_control_late [expr $clock_period * 0.13]

# X-interface mem_if input delay
set in_delay_xif_mem_if [expr $clock_period * 0.30]

# X-interface mem_result.rdata output delay
set out_delay_xif_mem_result_rdata [expr $clock_period * 0.20]

# X-interface mem_result.result_valid output delay
set out_delay_xif_mem_result_valid [expr $clock_period * 0.15]

# All clocks
set clock_ports [list \
    clk_i \
]

# IRQ Input ports
set irq_input_ports [list \
    irq_i* \
]

# WFE Input ports
set wfe_input_ports [list \
    wu_wfe_i \
]

# CLIC Input ports
set clic_input_ports [list \
    clic_irq*_i* \
]
# CLIC Output ports
set clic_output_ports [list \
    clic_irq*_o* \
]

# Early Input ports (ideally from register)
set early_input_ports [list \
    debug_req_i \
    boot_addr_i* \
    mtvec_addr_i* \
    dm_halt_addr_i* \
    mhartid_i* \
    mimpid_i* \
    dm_exception_addr_i* \
]

# RISC-V OBI Input ports
set obi_input_ports [list \
    instr_gnt_i \
    instr_rvalid_i \
    instr_rdata_i* \
    instr_err_i \
    data_gnt_i \
    data_rvalid_i \
    data_rdata_i* \
    data_err_i \
    data_exokay_i \
]

# RISC-V OBI Output ports
set obi_output_ports [list \
    instr_req_o \
    instr_addr_o* \
    instr_memtype_o* \
    instr_prot_o* \
    instr_dbg_o \
    data_req_o \
    data_we_o \
    data_be_o* \
    data_addr_o* \
    data_wdata_o* \
    data_atop_o* \
    data_memtype_o* \
    data_prot_o* \
    data_dbg_o \
]

# RISC-V Sleep Output ports
set sleep_output_ports [list \
    core_sleep_o \
]

# Fencei handshake output ports
set fencei_output_ports [list \
    fencei_flush_req_o \
]

# Fencei handshake input ports
set fencei_input_ports [list \
    fencei_flush_ack_i \
]

# X-interface input ports
set xif_input_ports [list \
    xif_compressed_if_compressed_ready \
    xif_compressed_if_compressed_resp* \
    xif_issue_if_issue_ready \
    xif_issue_if_issue_resp* \
    xif_mem_if_mem_valid \
    xif_mem_if_mem_req* \
    xif_result_if_result* \
]

# X-interface output ports
set xif_output_ports [list \
    xif_compressed_if_compressed_valid \
    xif_compressed_if_compressed_req* \
    xif_issue_if_issue_req_instr* \
    xif_issue_if_issue_req_mode* \
    xif_issue_if_issue_req_id* \
    xif_commit_if_commit* \
    xif_mem_if_mem_ready \
    xif_mem_if_mem_resp* \
    xif_mem_result_if_mem_result_valid \
    xif_mem_result_if_mem_result* \
    xif_result_if_result_ready \
]

# X-interface late data outputs
set xif_output_ports_data_late [list \
    xif_issue_if_issue_req_rs* \
    xif_issue_if_issue_req_ecs* \
]

set xif_output_ports_control_late [list \
    xif_issue_if_issue_req_rs_valid* \
    xif_issue_if_issue_req_ecs_valid* \
    xif_issue_if_issue_valid \
    xif_commit_if_commit_valid \
]

# X-interface result data inputs
set xif_input_ports_result_data [list \
    xif_result_if_result_data* \
    xif_result_if_result_valid \
]

# X-interface mem_if input ports
set xif_mem_if_input_ports [list \
    xif_mem_if_mem_valid \
    xif_mem_if_mem_req* \
]

# X-interface mem_result rdata output ports
set xif_mem_result_if_rdata [list \
    xif_mem_result_if_mem_result_rdata* \
]

# X-interface mem_result rdata output ports
set xif_mem_result_if_valid [list \
    xif_mem_result_if_mem_result_valid \
]

############## Defining default clock definitions ##############

create_clock \
      -name clk_i \
      -period $clock_period \
      [get_ports clk_i]


########### Defining Default I/O constraints ###################

set all_clock_ports $clock_ports

set all_other_input_ports  [remove_from_collection [all_inputs]  [get_ports [list $all_clock_ports $obi_input_ports $irq_input_ports $wfe_input_ports $clic_input_ports $early_input_ports $fencei_input_ports $xif_input_ports $xif_input_ports_result_data $xif_mem_if_input_ports]]]

set all_other_output_ports [remove_from_collection [all_outputs] [get_ports [list $all_clock_ports $obi_output_ports $clic_output_ports $sleep_output_ports $fencei_output_ports $xif_output_ports $xif_output_ports_data_late $xif_output_ports_control_late $xif_mem_result_if_rdata $xif_mem_result_if_valid]]]

# IRQs
set_input_delay  $in_delay_irq          [get_ports $irq_input_ports        ] -clock clk_i
set_input_delay  $in_delay_clic         [get_ports $clic_input_ports       ] -clock clk_i
set_output_delay $out_delay_clic        [get_ports $clic_output_ports      ] -clock clk_i

# WFE
set_input_delay  $in_delay_wfe          [get_ports $wfe_input_ports        ] -clock clk_i

# OBI input/output delays
set_input_delay  $in_delay_instr_gnt    [ get_ports instr_gnt_i            ] -clock clk_i
set_input_delay  $in_delay_instr_rvalid [ get_ports instr_rvalid_i         ] -clock clk_i
set_input_delay  $in_delay_instr_rdata  [ get_ports instr_rdata_i*         ] -clock clk_i
set_input_delay  $in_delay_instr_err    [ get_ports instr_err_i*           ] -clock clk_i

set_input_delay  $in_delay_data_gnt     [ get_ports data_gnt_i             ] -clock clk_i
set_input_delay  $in_delay_data_rvalid  [ get_ports data_rvalid_i          ] -clock clk_i
set_input_delay  $in_delay_data_rdata   [ get_ports data_rdata_i*          ] -clock clk_i
set_input_delay  $in_delay_data_err     [ get_ports data_err_i             ] -clock clk_i
set_input_delay  $in_delay_data_exokay  [ get_ports data_exokay_i          ] -clock clk_i

set_output_delay $out_delay_instr_req      [ get_ports instr_req_o         ] -clock clk_i
set_output_delay $out_delay_instr_addr     [ get_ports instr_addr_o*       ] -clock clk_i
set_output_delay $out_delay_instr_memtype  [ get_ports instr_memtype_o*    ] -clock clk_i
set_output_delay $out_delay_instr_prot     [ get_ports instr_prot_o*       ] -clock clk_i

set_output_delay $out_delay_data_req      [ get_ports data_req_o           ] -clock clk_i
set_output_delay $out_delay_data_we       [ get_ports data_we_o            ] -clock clk_i
set_output_delay $out_delay_data_be       [ get_ports data_be_o*           ] -clock clk_i
set_output_delay $out_delay_data_addr     [ get_ports data_addr_o*         ] -clock clk_i
set_output_delay $out_delay_data_wdata    [ get_ports data_wdata_o*        ] -clock clk_i
set_output_delay $out_delay_data_atop     [ get_ports data_atop_o*         ] -clock clk_i
set_output_delay $out_delay_data_memtype  [ get_ports data_memtype_o*      ] -clock clk_i
set_output_delay $out_delay_data_prot     [ get_ports data_prot_o*         ] -clock clk_i

# Fencei handshake
set_input_delay  $in_delay_fencei       [get_ports $fencei_input_ports     ] -clock clk_i
set_output_delay $out_delay_fencei      [get_ports $fencei_output_ports    ] -clock clk_i

# X-interface
set_input_delay  $in_delay_xif                       [get_ports $xif_input_ports                ] -clock clk_i
set_input_delay  $in_delay_xif_result_data           [get_ports $xif_input_ports_result_data    ] -clock clk_i
set_input_delay  $in_delay_xif_mem_if                [get_ports $xif_mem_if_input_ports         ] -clock clk_i
set_output_delay $out_delay_xif_mem_result_rdata     [get_ports $xif_mem_result_if_rdata        ] -clock clk_i
set_output_delay $out_delay_xif_mem_result_valid     [get_ports $xif_mem_result_if_valid        ] -clock clk_i

set_output_delay $out_delay_xif                [get_ports $xif_output_ports               ] -clock clk_i
set_output_delay $out_delay_xif_data_late      [get_ports $xif_output_ports_data_late     ] -clock clk_i
set_output_delay $out_delay_xif_control_late   [get_ports $xif_output_ports_control_late  ] -clock clk_i


# Misc
set_input_delay  $in_delay_early        [get_ports $early_input_ports      ] -clock clk_i
set_input_delay  $in_delay_other        [get_ports $all_other_input_ports  ] -clock clk_i

set_output_delay $out_delay_other       [get_ports $all_other_output_ports ] -clock clk_i
set_output_delay $out_delay_core_sleep  [ get_ports core_sleep_o           ] -clock clk_i

