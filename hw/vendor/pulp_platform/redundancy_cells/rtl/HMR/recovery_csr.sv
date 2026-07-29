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
 * Recovery Control Status Registers
 * ECC-protected register that stores the CSRs values from the cores
 *
 */

module recovery_csr
  import rapid_recovery_pkg::*;
#(
  parameter  int unsigned ECCEnabled        = 0,
  parameter  int unsigned NonProtectedWidth = 32,
  parameter  int unsigned ProtectedWidth    = 39,
  parameter      type     csr_intf_t        = logic,
  localparam int unsigned DataWidth  = ( ECCEnabled ) ? ProtectedWidth
                                                      : NonProtectedWidth
) (
  input  logic clk_i ,
  input  logic rst_ni,
  input  logic read_enable_i,
  input  logic write_enable_i,
  input  csrs_intf_t backup_csr_i,
  output csrs_intf_t recovery_csr_o
);

csrs_intf_t csr_inp,
            csr_out;

logic [31:0] csr_dec_mstatus,
             csr_dec_mie,
             csr_dec_mtvec,
             csr_dec_mscratch,
             csr_dec_mip,
             csr_dec_mepc,
             csr_dec_mcause;

assign csr_inp = backup_csr_i;
assign recovery_csr_o = (read_enable_i) ? csr_out : '0;

if (ECCEnabled) begin : gen_ecc_csrs

  ecc_csrs_intf_t csr_d, csr_q;

  prim_secded_39_32_enc csr_mstatus_ecc_encoder (
    .in  ( {25'd0,csr_inp.csr_mstatus} ), // mtvec is a 7-bit value
    .out ( csr_d.csr_mstatus           )
  );
  prim_secded_39_32_enc csr_mie_ecc_encoder (
    .in  ( csr_inp.csr_mie ),
    .out ( csr_d.csr_mie   )
  );
  prim_secded_39_32_enc csr_mtvec_ecc_encoder (
    .in  ( {8'd0, csr_inp.csr_mtvec} ), // mtvec is a 24-bit value
    .out ( csr_d.csr_mtvec            )
  );
  prim_secded_39_32_enc csr_mscratch_ecc_encoder (
    .in  ( csr_inp.csr_mscratch ),
    .out ( csr_d.csr_mscratch   )
  );
  prim_secded_39_32_enc csr_mip_ecc_encoder (
    .in  ( csr_inp.csr_mip ),
    .out ( csr_d.csr_mip   )
  );
  prim_secded_39_32_enc csr_mepc_ecc_encoder (
    .in  ( csr_inp.csr_mepc),
    .out ( csr_d.csr_mepc  )
  );
  prim_secded_39_32_enc csr_mcause_ecc_encoder (
    .in  ( {26'd0, csr_inp.csr_mcause} ), // mcause is a 6-bit value
    .out ( csr_d.csr_mcause            )
  );

  always_ff @(posedge clk_i, negedge rst_ni) begin : ecc_csr_backup
    if (~rst_ni)
      csr_q <= '0;
    else if (write_enable_i)
      csr_q <= csr_d;
  end

  prim_secded_39_32_dec csr_mstatus_ecc_decoder (
    .in         ( csr_q.csr_mstatus ),
    .d_o        ( csr_dec_mstatus   ),
    .syndrome_o ( ),
    .err_o      ( )
  );
  prim_secded_39_32_dec csr_mie_ecc_decoder (
    .in         ( csr_q.csr_mie ),
    .d_o        ( csr_dec_mie   ),
    .syndrome_o ( ),
    .err_o      ( )
  );
  prim_secded_39_32_dec csr_mtvec_ecc_decoder (
    .in         ( csr_q.csr_mtvec ),
    .d_o        ( csr_dec_mtvec   ),
    .syndrome_o ( ),
    .err_o      ( )
  );
  prim_secded_39_32_dec csr_mscratch_ecc_decoder (
    .in         ( csr_q.csr_mscratch ),
    .d_o        ( csr_dec_mscratch   ),
    .syndrome_o ( ),
    .err_o      ( )
  );
  prim_secded_39_32_dec csr_mip_ecc_decoder (
    .in         ( csr_q.csr_mip ),
    .d_o        ( csr_dec_mip   ),
    .syndrome_o ( ),
    .err_o      ( )
  );
  prim_secded_39_32_dec csr_mepc_ecc_decoder (
    .in         ( csr_q.csr_mepc ),
    .d_o        ( csr_dec_mepc   ),
    .syndrome_o ( ),
    .err_o      ( )
  );
  prim_secded_39_32_dec csr_mcause_ecc_decoder (
    .in         ( csr_q.csr_mcause ),
    .d_o        ( csr_dec_mcause   ),
    .syndrome_o ( ),
    .err_o      ( )
  );
  assign csr_out.csr_mstatus = csr_dec_mstatus[6:0];
  assign csr_out.csr_mie = csr_dec_mie;
  assign csr_out.csr_mtvec = csr_dec_mtvec[23:0];
  assign csr_out.csr_mscratch = csr_dec_mscratch;
  assign csr_out.csr_mip = csr_dec_mip;
  assign csr_out.csr_mepc = csr_dec_mepc;
  assign csr_out.csr_mcause = csr_dec_mcause[5:0];
end else begin : gen_no_ecc_csrs
  csrs_intf_t csr_d, csr_q;

  assign csr_d = csr_inp;

  always_ff @(posedge clk_i, negedge rst_ni) begin : csr_backup
    if (~rst_ni)
      csr_q <= '0;
    else if (write_enable_i)
      csr_q <= csr_d;
  end
  assign csr_out = csr_q;

end

endmodule : recovery_csr
