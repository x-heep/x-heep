// Copyright 2021 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Triple-Core Lock-Step unit

`include "register_interface/typedef.svh"
// Peripheral communication signals


module TCLS_unit #(
  parameter int unsigned InstrRdataWidth  = 32,
  parameter int unsigned NExtPerfCounters = 5,
  parameter int unsigned DataWidth        = 32,
  parameter int unsigned BEWidth          = 4,
  parameter type         tcls_req_t       = logic,
  parameter type         tcls_rsp_t       = logic
) (
  input logic                              clk_i,
  input logic                              rst_ni,

  input                                    tcls_req_t reg_request_i,
  output                                   tcls_rsp_t reg_response_o,

  output logic                             tcls_triple_core_mismatch_o,
  output logic                             tcls_single_core_mismatch_o,
  output logic                             resynch_req_o,

  // Ports to connect Interconnect/rest of system
  input logic [ 31:0]                      intc_hart_id_i,

  input logic                              intc_fetch_en_i,
  input logic [ 31:0]                      intc_boot_addr_i,

  input logic [31 :0]                      intc_irq_x_i,
  output logic                             intc_irq_x_ack_o,
  output logic [ 4:0]                      intc_irq_x_ack_id_o,


  input logic                              intc_instr_err_i,
  output logic                             intc_instr_req_o,
  input logic                              intc_instr_gnt_i,
  output logic [ 31:0]                     intc_instr_addr_o,
  input logic [InstrRdataWidth-1:0]        intc_instr_rdata_i,
  input logic                              intc_instr_rvalid_i,

  input logic                              intc_debug_req_i,

  output logic                             intc_data_req_o,
  output logic [ 31:0]                     intc_data_addr_o,
  output logic                             intc_data_we_o,
  output logic [ DataWidth-1:0]            intc_data_wdata_o,
  output logic [ BEWidth-1:0]              intc_data_be_o,
  input logic                              intc_data_gnt_i,
  input logic [ DataWidth-1:0]             intc_data_rdata_i,
  input logic                              intc_data_rvalid_i,
  input logic                              intc_data_err_i,

  input logic [NExtPerfCounters-1:0]       intc_perf_counters_i,

  // Ports to connect Cores
  output logic [2:0]                       core_setback_o,

  output logic [2:0][ 31:0]                core_hart_id_o,


  output logic [2:0]                       core_fetch_en_o,
  output logic [2:0][ 31:0]                core_boot_addr_o,

  output logic [2:0][ 31:0]                core_irq_x_o,
  input logic [2:0]                        core_irq_x_ack_i,
  input logic [2:0][ 4:0]                  core_irq_x_ack_id_i,

  output logic [2:0]                       core_instr_err_o,
  input logic [2:0]                        core_instr_req_i,
  output logic [2:0]                       core_instr_gnt_o,
  input logic [2:0][ 31:0]                 core_instr_addr_i,
  output logic [2:0][ InstrRdataWidth-1:0] core_instr_rdata_o,
  output logic [2:0]                       core_instr_rvalid_o,

  output logic [2:0]                       core_debug_req_o,

  input logic [2:0]                        core_data_req_i,
  input logic [2:0][ 31:0]                 core_data_addr_i,
  input logic [2:0]                        core_data_we_i,
  input logic [2:0][ DataWidth-1:0]        core_data_wdata_i,
  input logic [2:0][ BEWidth-1:0]          core_data_be_i,
  output logic [2:0]                       core_data_gnt_o,
  output logic [2:0][ DataWidth-1:0]       core_data_rdata_o,
  output logic [2:0]                       core_data_rvalid_o,
  output logic [2:0]                       core_data_err_o,

  output logic [2:0][NExtPerfCounters-1:0] core_perf_counters_o

  // APU/SHARED_FPU not implemented
);

  import tcls_manager_reg_pkg::* ;


  tcls_manager_reg2hw_t reg2hw;
  tcls_manager_hw2reg_t hw2reg;

  // State signals
  typedef enum logic [1:0] {TMR_RUN, TMR_UNLOAD, TMR_RELOAD} redundancy_mode_e;

  redundancy_mode_e red_mode_d, red_mode_q;

  logic setback_d, setback_q;

  // TMR signals
  logic       TMR_error, main_error, data_error;
  logic [2:0] TMR_error_detect, main_error_cba, data_error_cba;

  localparam int unsigned MainTmrWidth = 1      + 5          + 1        + 32        + 1;
  //                                     irq_ack  irq_ack_id   instr_req  instr_addr  data_req
  logic      [MainTmrWidth-1:0] main_tmr_out;
  logic [2:0][MainTmrWidth-1:0] main_tmr_in;

  localparam int unsigned DataTmrWidth = 32      + 1       + DataWidth + BEWidth;
  //                                     data_addr  data_we  data_wdata  data_be
  logic      [DataTmrWidth-1:0] data_tmr_out;
  logic [2:0][DataTmrWidth-1:0] data_tmr_in;


  logic                 irq_ack;
  logic [          4:0] irq_ack_id;

  logic                 instr_req;
  logic [         31:0] instr_addr;

  logic                 data_req;
  logic [         31:0] data_addr;
  logic                 data_we;
  logic [DataWidth-1:0] data_wdata;
  logic [  BEWidth-1:0] data_be;

  assign core_setback_o[0] = setback_q;
  assign core_setback_o[1] = setback_q;
  assign core_setback_o[2] = setback_q;

  /************************************
   *  Slave Peripheral communication  *
   ************************************/

  tcls_manager_reg_top #(
    .reg_req_t ( tcls_req_t ),
    .reg_rsp_t ( tcls_rsp_t )
  ) i_registers (
    .clk_i     ( clk_i            ),
    .rst_ni    ( rst_ni           ),
    .reg_req_i ( reg_request_i    ),
    .reg_rsp_o ( reg_response_o   ),
    .reg2hw    ( reg2hw           ),
    .hw2reg    ( hw2reg           ),
    .devmode_i ( '0               )
  );

  assign hw2reg.sp_store.d = '0;
  assign hw2reg.sp_store.de = '0;
  assign hw2reg.mismatches_0.d = reg2hw.mismatches_0.q + 1;
  assign hw2reg.mismatches_1.d = reg2hw.mismatches_1.q + 1;
  assign hw2reg.mismatches_2.d = reg2hw.mismatches_2.q + 1;

  /****************
   *  TMR Voters  *
   ****************/
  // TMR voters are separated for data, as this only needs to be compared when the core reads or writes data

  for (genvar i = 0; i < 3; i++) begin : gen_main_concat
    assign main_tmr_in[i] = {core_irq_x_ack_i[i], core_irq_x_ack_id_i[i],
        core_instr_req_i[i], core_instr_addr_i[i], core_data_req_i[i]};
  end

  assign { irq_ack, irq_ack_id,
      instr_req, instr_addr, data_req } = main_tmr_out;

  bitwise_TMR_voter #(
    .DataWidth( MainTmrWidth ),
    .VoterType( 0              )
  ) main_voter (
    .a_i         ( main_tmr_in[0] ),
    .b_i         ( main_tmr_in[1] ),
    .c_i         ( main_tmr_in[2] ),
    .majority_o  ( main_tmr_out   ),
    .error_o     ( main_error     ),
    .error_cba_o ( main_error_cba )
  );

  for (genvar i = 0; i < 3; i++) begin : gen_data_concat
    assign data_tmr_in[i] = {core_data_addr_i[i], core_data_we_i[i], core_data_wdata_i[i],
                             core_data_be_i[i]};
  end

  assign {data_addr, data_we, data_wdata, data_be} = data_tmr_out;

  bitwise_TMR_voter #(
    .DataWidth( DataTmrWidth ),
    .VoterType( 0              )
  ) data_voter (
    .a_i         ( data_tmr_in[0] ),
    .b_i         ( data_tmr_in[1] ),
    .c_i         ( data_tmr_in[2] ),
    .majority_o  ( data_tmr_out   ),
    .error_o     ( data_error     ),
    .error_cba_o ( data_error_cba )
  );

  always_comb begin : proc_TMR_error
    TMR_error        = main_error;
    TMR_error_detect = main_error_cba;
    if (data_req) begin
      TMR_error        = main_error | data_error;
      TMR_error_detect = main_error_cba | data_error_cba;
    end
  end
  assign tcls_single_core_mismatch_o = (TMR_error_detect != 3'b000);
  assign tcls_triple_core_mismatch_o = TMR_error;

  assign resynch_req_o = TMR_error && (red_mode_q == TMR_RUN);

  assign hw2reg.tcls_config.setback.d         = 1'b0;
  assign hw2reg.tcls_config.setback.de        = 1'b0;
  assign hw2reg.tcls_config.reload_setback.d  = 1'b0;
  assign hw2reg.tcls_config.reload_setback.de = 1'b0;
  assign hw2reg.tcls_config.force_resynch.d   = 1'b0;

  /***********************
   *  FSM for TCLS unit  *
   ***********************/

  always_comb begin : proc_fsm
    setback_d = 1'b0;
    red_mode_d = red_mode_q;
    hw2reg.mismatches_0.de = 1'b0;
    hw2reg.mismatches_1.de = 1'b0;
    hw2reg.mismatches_2.de = 1'b0;
    hw2reg.tcls_config.force_resynch.de = 1'b0;

    // If forced execute resynchronization
    if (red_mode_q == TMR_RUN && reg2hw.tcls_config.force_resynch.q) begin
      hw2reg.tcls_config.force_resynch.de = 1'b1;
      red_mode_d = TMR_UNLOAD;
    end

    // If error detected, do resynchronization
    if (red_mode_q == TMR_RUN && TMR_error_detect != 3'b000) begin
      $display("[TCLS] %t - mismatch detected", $realtime);
      if (TMR_error_detect[0]) hw2reg.mismatches_0.de = 1'b1;
      if (TMR_error_detect[1]) hw2reg.mismatches_1.de = 1'b1;
      if (TMR_error_detect[2]) hw2reg.mismatches_2.de = 1'b1;

      red_mode_d = TMR_UNLOAD;
    end

    // If unload complete, go to reload (and reset)
    if (red_mode_q == TMR_UNLOAD) begin
      if (reg2hw.sp_store.q != '0) begin
        red_mode_d = TMR_RELOAD;
        if (reg2hw.tcls_config.setback.q) begin
          setback_d = 1'b1;
        end
      end
    end

    // If reload complete, finish (or reset if error happens during reload)
    if (red_mode_q == TMR_RELOAD) begin
      if (reg2hw.sp_store.q == '0) begin
        $display("[TCLS] %t - mismatch restored", $realtime);
        red_mode_d = TMR_RUN;
      end else begin
        if (TMR_error_detect != 3'b000 && reg2hw.tcls_config.setback.q &&
            reg2hw.tcls_config.reload_setback.q &&
            !(reg2hw.sp_store.qe && reg_request_i.wdata == '0)) begin
          setback_d = 1'b1;
        end
      end
    end

    if (intc_fetch_en_i == 0) begin
      red_mode_d = TMR_RUN;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_red_mode
    if(!rst_ni) begin
      red_mode_q <= TMR_RUN;
      setback_q <= 1'b0;
    end else begin
      red_mode_q <= red_mode_d;
      setback_q <= setback_d;
    end
  end

  /***********************************************
   *  IRQ MUX - with re-synchronization Trigger  *
   ***********************************************/

  always_comb begin : proc_irq_assign
    intc_irq_x_ack_o    = irq_ack;
    intc_irq_x_ack_id_o = irq_ack_id;

    for (int i = 0; i < 3; i++) begin
      core_irq_x_o[i] = intc_irq_x_i;
    end
  end


  /*********************
   *  CTRL signal MUX  *
   ********************/



   always_comb begin : proc_ctrl_assign

     for (int i = 0; i < 3; i++) begin
       core_hart_id_o[i]          = intc_hart_id_i;

       core_fetch_en_o[i]         = intc_fetch_en_i; // May need config on state transition
       core_boot_addr_o[i]        = intc_boot_addr_i; // May need special
                                                      // value when restoring from tcls error
       core_debug_req_o[i]        = intc_debug_req_i;

       core_perf_counters_o[i]    = intc_perf_counters_i;
     end

   end // block: proc_ctrl_assign


  /******************
   *  Data bus MUX  *
   ******************/

  always_comb begin : proc_data_assign
    intc_data_req_o   = data_req;
    intc_data_addr_o  = data_addr;
    intc_data_we_o    = data_we;
    intc_data_wdata_o = data_wdata;
    intc_data_be_o    = data_be;

    for (int i = 0; i < 3; i++) begin
      core_data_gnt_o[i]     = intc_data_gnt_i;
      core_data_rdata_o[i] = intc_data_rdata_i;
      core_data_rvalid_o[i] = intc_data_rvalid_i;
      core_data_err_o[i] = intc_data_err_i;
    end

  end

  /*******************
   *  INSTR bus MUX  *
   *******************/

  always_comb begin : proc_instr_assign
    intc_instr_req_o  = instr_req;
    intc_instr_addr_o = instr_addr;

      for (int i = 0; i < 3; i++) begin
        core_instr_gnt_o[i]     = intc_instr_gnt_i;
        core_instr_rdata_o[i] = intc_instr_rdata_i;
        core_instr_rvalid_o[i]  = intc_instr_rvalid_i;
        core_instr_err_o[i] = intc_instr_err_i;
      end
  end


endmodule
