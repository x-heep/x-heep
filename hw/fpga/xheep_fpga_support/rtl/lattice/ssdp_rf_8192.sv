// Memory module for use with iCESugar-pro flow (yosys)
// author : Leonardo Vega
// adapted from https://yosyshq.readthedocs.io/projects/yosys/en/stable/using_yosys/synthesis/memory.html#synchronous-single-port-ram-with-read-first-behavior
// with added byte enable behaviour.

module ssdp_wf_8192 (
    input clka,
    ena,
    wea,
    input logic [3:0] be_i,
    input logic [$clog2(32'd8192)-1:0] addra,
    input logic [31:0] dina,
    output reg [31:0] douta
);

  reg [31:0] sram[8192-1:0];
  reg [31:0] data_out;

  always @(posedge clka) begin
    if (wea) begin
      if (be_i[0]) sram[addra][7:0] <= dina[7:0];
      if (be_i[1]) sram[addra][15:8] <= dina[15:8];
      if (be_i[2]) sram[addra][23:16] <= dina[23:16];
      if (be_i[3]) sram[addra][31:24] <= dina[31:24];
    end
    if (ena) data_out <= sram[addra];
  end

  assign douta = data_out;

endmodule
