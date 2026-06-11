// test implementation for yosys flow, NOT FINAL
// author : Leonardo Vega
// adapted from https://yosyshq.readthedocs.io/projects/yosys/en/stable/using_yosys/synthesis/memory.html#synchronous-single-port-ram-with-write-first-behavior


module ssdp_wf_8192 (
    input clka,
    ena,
    wea,
    input logic [3:0] be_i,
    input logic [$clog2(32'd8192)-1:0] addra,
    input logic [31:0] dina,
    output reg [31:0] douta
);

  //========================================= write first
  /*
  reg [31:0] sram[8192-1:0];

  always @(posedge clka) begin
    if (wea) sram[addra] <= dina;
    if (ena)
      if (wea) douta <= dina;
      else douta <= sram[addra];
  end
*/
  //==========================================



  //========================================== read first

  reg [31:0] sram[8192-1:0];
  reg [31:0] data_out;

  always @(posedge clka) begin
    if (wea) begin 
      //sram[addra] <= dina;
      if(be_i[0]) sram[addra][7:0] <= dina[7:0];
      if(be_i[1]) sram[addra][15:8] <= dina[15:8];
      if(be_i[2]) sram[addra][23:16] <= dina[23:16];
      if(be_i[3]) sram[addra][31:24] <= dina[31:24];
    end
    if (ena) data_out <= sram[addra];
  end

  assign douta = data_out;

  //==========================================



  //========================================== test from icesugar litex linux
  /*
  reg [31:0] sram[8192-1:0];
  reg [31:0] sramdata;

  always @(posedge clka) begin
    if (wea) sram[addra] <= dina;
    sramdata <= sram[addra];
  end

  assign douta = sramdata;
*/
  //==========================================



endmodule


/* FROM YOSYSHQ
reg [DATA_WIDTH - 1 : 0] mem [2**ADDR_WIDTH - 1 : 0];

always @(posedge clk) begin
        if (write_enable)
                mem[addr] <= write_data;
        if (read_enable)
                if (write_enable)
                        read_data <= write_data;
                else
                        read_data <= mem[addr];
end
*/

