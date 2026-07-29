// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// ECC sram manager (loggs faults, triggers scrubber)

module ecc_manager #(
  parameter int unsigned NumBanks      = 6,
  parameter type         ecc_mgr_req_t = logic,
  parameter type         ecc_mgr_rsp_t = logic
) (
  input  logic                clk_i,
  input  logic                rst_ni,

  input  ecc_mgr_req_t        ecc_mgr_req_i,
  output ecc_mgr_rsp_t        ecc_mgr_rsp_o,

  input  logic [NumBanks-1:0] bank_faults_i,
  input  logic [NumBanks-1:0] scrub_fix_i,
  input  logic [NumBanks-1:0] scrub_uncorrectable_i,
  output logic [NumBanks-1:0] scrub_trigger_o,
  output logic [NumBanks-1:0][38:0] test_write_mask_no
);
  import ecc_manager_reg_pkg::*;

  logic [NumBanks-1:0][31:0] counter_value;

  ecc_mgr_req_t [NumBanks-1:0] reg_req;
  ecc_mgr_rsp_t [NumBanks-1:0] reg_rsp;

  ecc_manager_reg2hw_t [NumBanks-1:0] reg2hw;
  ecc_manager_hw2reg_t [NumBanks-1:0] hw2reg;

  reg_demux #(
    .req_t   ( ecc_mgr_req_t ),
    .rsp_t   ( ecc_mgr_rsp_t ),
    .NoPorts ( NumBanks      )
  ) i_reg_demux (
    .clk_i,
    .rst_ni,
    .in_req_i    ( ecc_mgr_req_i                           ),
    .in_rsp_o    ( ecc_mgr_rsp_o                           ),
    .out_req_o   ( reg_req                                 ),
    .out_rsp_i   ( reg_rsp                                 ),
    .in_select_i ( ecc_mgr_req_i.addr[5+:$clog2(NumBanks)] ) // 0x20 per manager registers
  );

  for (genvar i = 0; i < NumBanks; i++) begin : gen_fault_increment
    ecc_manager_reg_top #(
      .reg_req_t ( ecc_mgr_req_t ),
      .reg_rsp_t ( ecc_mgr_rsp_t )
    ) i_registers (
      .clk_i,
      .rst_ni,
      .reg_req_i ( reg_req[i] ),
      .reg_rsp_o ( reg_rsp[i] ),
      .reg2hw    ( reg2hw [i] ),
      .hw2reg    ( hw2reg [i] ),
      .devmode_i ( '0         )
    );


    // Count ECC fixes on access
    assign hw2reg[i].mismatch_count.d = reg2hw[i].mismatch_count.q + 1;
    assign hw2reg[i].mismatch_count.de = bank_faults_i[i];

    // Count ECC fixes on scrub
    assign hw2reg[i].scrub_fix_count.d = reg2hw[i].scrub_fix_count.q + 1;
    assign hw2reg[i].scrub_fix_count.de = scrub_fix_i[i];

    // Count uncorrectable scrubs
    assign hw2reg[i].scrub_uncorrectable_count.d = reg2hw[i].scrub_uncorrectable_count.q + 1;
    assign hw2reg[i].scrub_uncorrectable_count.de = scrub_uncorrectable_i[i];

    // Assign testing mask
    assign test_write_mask_no[i][31:0] = reg2hw[i].write_mask_data_n;
    assign test_write_mask_no[i][38:32] = reg2hw[i].write_mask_ecc_n;

    // Instantiate scrub trigger counter
    assign scrub_trigger_o[i] = (reg2hw[i].scrub_interval.q != '0) &&
                                (counter_value[i] == reg2hw[i].scrub_interval.q);
    counter #(
      .WIDTH           ( 32   ),
      .STICKY_OVERFLOW ( 1'b0 )
    ) i_scrub_counter (
      .clk_i,
      .rst_ni,
      .clear_i   ( reg2hw[i].scrub_interval.q == '0 ),
      .en_i      ( reg2hw[i].scrub_interval.q != '0 ),
      .load_i    ( counter_value[i] == reg2hw[i].scrub_interval.q ),
      .down_i    ( 1'b0 ),
      .d_i       ( '0 ),
      .q_o       ( counter_value[i] ),
      .overflow_o()
    );
  end

endmodule
