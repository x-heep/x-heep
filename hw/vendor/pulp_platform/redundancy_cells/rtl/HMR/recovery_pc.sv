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
 * Recovery Program Counter
 * ECC-protected register that stores the Program Counter value from the cores
 *
 */

module recovery_pc #(
  parameter  int unsigned ECCEnabled        = 0,
  parameter  int unsigned NonProtectedWidth = 32,
  parameter  int unsigned ProtectedWidth    = 39,
  parameter  type         pc_intf_t         = logic,
  localparam int unsigned DataWidth  = ( ECCEnabled ) ? ProtectedWidth
                                                      : NonProtectedWidth
) (
  // Control Ports
  input  logic clk_i,
  input  logic rst_ni,
  input  logic clear_i,
  input  logic read_enable_i,
  input  logic write_enable_i,
  // Backup Ports
  input  logic [NonProtectedWidth-1:0] backup_program_counter_i,
  input  logic                         backup_branch_i,
  input  logic [NonProtectedWidth-1:0] backup_branch_addr_i,
  // Recovery Pors
  output logic [NonProtectedWidth-1:0] recovery_program_counter_o,
  output logic                         recovery_branch_o,
  output logic [NonProtectedWidth-1:0] recovery_branch_addr_o
);

logic branch_q;

logic [DataWidth-1:0] pc_d,
                      pc_q,
                      branch_addr_d,
                      branch_addr_q;
logic [NonProtectedWidth-1:0] pc_out,
                              branch_addr_out;

generate
  if (ECCEnabled) begin : gen_ecc_region
    /**************************
     * Program Counter Backup *
     **************************/
    prim_secded_39_32_enc pc_ecc_encoder (
      .in  ( backup_program_counter_i ),
      .out ( pc_d                     )
    );

    always_ff @(posedge clk_i, negedge rst_ni) begin : pc_value_sampler
      if (~rst_ni)
        pc_q <= '0;
      else begin
        if (clear_i)
          pc_q <= '0;
        else if (write_enable_i && pc_d != '0)
          pc_q <= pc_d;
        else
          pc_q <= pc_q;
      end
    end

    prim_secded_39_32_dec pc_ecc_decoder (
      .in         ( pc_q   ),
      .d_o        ( pc_out ),
      .syndrome_o (        ),
      .err_o      (        )
    );

    /**********************
     * Branch Addr Backup *
     **********************/
    prim_secded_39_32_enc branch_addr_ecc_encoder (
      .in  ( backup_branch_addr_i ),
      .out ( branch_addr_d        )
    );

    always_ff @(posedge clk_i, negedge rst_ni) begin : branch_addr_sampler
      if (~rst_ni)
        branch_addr_q <= '0;
      else begin
        if (clear_i)
          branch_addr_q <= '0;
        else if (backup_branch_i && write_enable_i)
          branch_addr_q <= branch_addr_d;
        else
          branch_addr_q <= branch_addr_q;
      end
    end

    prim_secded_39_32_dec branch_addr_ecc_decoder (
      .in         ( branch_addr_q   ),
      .d_o        ( branch_addr_out ),
      .syndrome_o (                 ),
      .err_o      (                 )
    );

    /************************
     * Branch Signal Backup *
     ************************/
    always_ff @(posedge clk_i, negedge rst_ni) begin : branch_sampler
      if (~rst_ni)
        branch_q <= '0;
      else begin
        if (clear_i)
          branch_q <= '0;
        else if (write_enable_i)
          branch_q <= backup_branch_i;
        else
          branch_q <= branch_q;
      end
    end

    /*****************
     * Output Assign *
     *****************/
    assign recovery_program_counter_o = (read_enable_i) ? pc_out : '0;
    assign recovery_branch_addr_o = (read_enable_i && branch_q) ? branch_addr_out : '0;
    assign recovery_branch_o      = (read_enable_i) ? branch_q : '0;
  end else begin : gen_no_ecc_region
    /**************************
     * Program Counter Backup *
     **************************/
    assign pc_d = backup_program_counter_i;
    always_ff @(posedge clk_i, negedge rst_ni) begin : pc_value_sampler
      if (~rst_ni)
        pc_q <= '0;
      else begin
        if (clear_i)
          pc_q <= '0;
        else if (write_enable_i)
          pc_q <= pc_d;
        else
          pc_q <= pc_d;
      end
    end
    assign pc_out = pc_q;

    /**********************
     * Branch Addr Backup *
     **********************/
    assign branch_addr_d = backup_branch_addr_i;
    always_ff @(posedge clk_i, negedge rst_ni) begin : branch_addr_sampler
      if (~rst_ni)
        branch_addr_q <= '0;
      else begin
        if (clear_i)
          branch_addr_q <= '0;
        else if (backup_branch_i && write_enable_i)
          branch_addr_q <= branch_addr_d;
        else
          branch_addr_q <= branch_addr_q;
      end
    end
    assign branch_addr_out = branch_addr_q;

    /************************
     * Branch Signal Backup *
     ************************/
    always_ff @(posedge clk_i, negedge rst_ni) begin : branch_sampler
      if (~rst_ni)
        branch_q <= '0;
      else begin
        if (clear_i)
          branch_q <= '0;
        else if (write_enable_i)
          branch_q <= backup_branch_i;
        else
          branch_q <= branch_q;
      end
    end

    /*****************
     * Output Assign *
     *****************/
    assign recovery_program_counter_o = (read_enable_i) ? pc_out : '0;
    assign recovery_branch_addr_o = (read_enable_i) ? branch_addr_out : '0;
    assign recovery_branch_o      = (read_enable_i) ? branch_q : '0;
  end
endgenerate

endmodule : recovery_pc
