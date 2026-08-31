
module vpk180_rstgen #(
    parameter int unsigned NumRegs = 4
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic rst_test_mode_ni,
    input  logic test_mode_i,
    output logic rst_no,
    output logic init_no
);

  // internal reset
  logic rst_n;

  logic [NumRegs-1:0] synch_regs_q;

  BUFG_FABRIC BUFG_FABRIC_inst_0 (
      .O(rst_n),  // 1-bit output: Buffer
      .I(rst_ni)  // 1-bit input: Buffer
  );


  BUFG_FABRIC BUFG_FABRIC_inst_1 (
      .O(rst_no),  // 1-bit output: Buffer
      .I(synch_regs_q[NumRegs-1])  // 1-bit input: Buffer
  );

  BUFG_FABRIC BUFG_FABRIC_inst_2 (
      .O(init_no),  // 1-bit output: Buffer
      .I(synch_regs_q[NumRegs-1])  // 1-bit input: Buffer
  );


  always @(posedge clk_i or negedge rst_n) begin
    if (~rst_n) begin
      synch_regs_q <= 0;
    end else begin
      synch_regs_q <= {synch_regs_q[NumRegs-2:0], 1'b1};
    end
  end
  // `ifndef SYNTHESIS
  // `ifndef COMMON_CELLS_ASSERTS_OFF
  // initial begin : p_assertions
  //     if (NumRegs < 1) $fatal(1, "At least one register is required.");
  // end
  // `endif
  // `endif
endmodule
