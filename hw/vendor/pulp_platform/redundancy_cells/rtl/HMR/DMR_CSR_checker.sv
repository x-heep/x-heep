/* Copyright 2020 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * CS Registers Checker
 *
 */

module DMR_CSR_checker
  import rapid_recovery_pkg::*;
(
  input  csrs_intf_t csr_a_i,
  input  csrs_intf_t csr_b_i,
  output csrs_intf_t check_o,
  output logic       error_o
);

logic compare_mstatus;
logic compare_mie;
logic compare_mtvec;
logic compare_mscratch;
logic compare_mip;
logic compare_mepc;
logic compare_mcause;
logic error;

assign compare_mstatus = |(csr_a_i.csr_mstatus ^ csr_b_i.csr_mstatus);
assign compare_mie = |(csr_a_i.csr_mie ^ csr_b_i.csr_mie);
assign compare_mtvec = |(csr_a_i.csr_mtvec ^ csr_b_i.csr_mtvec);
assign compare_mscratch = |(csr_a_i.csr_mscratch ^ csr_b_i.csr_mscratch);
assign compare_mip = |(csr_a_i.csr_mip ^ csr_b_i.csr_mip);
assign compare_mepc = |(csr_a_i.csr_mepc ^ csr_b_i.csr_mepc);
assign compare_mcause = |(csr_a_i.csr_mcause ^ csr_b_i.csr_mcause);

assign error = compare_mstatus  |
               compare_mie      |
               compare_mtvec    |
               compare_mscratch |
               compare_mip      |
               compare_mepc     |
               compare_mcause;
assign check_o = (error) ? csr_a_i : '0;
assign error_o = error;

endmodule : DMR_CSR_checker
