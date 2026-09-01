module fake_signals #(
    parameter int H_ACTIVE = 640,
    parameter int V_ACTIVE = 480,
    parameter int H_BLANK  = 16,
    parameter int V_BLANK  = 10,

    parameter int START_DELAY = 70000
) (
    input logic clk_i,
    input logic rst_ni,

    output logic pclk_o,
    output logic vsync_o,
    output logic href_o,
    input logic pattern_inc_i,
    output logic [31:0] test_pattern_o
);

  int x;
  int y;
  logic byte_sel;
  logic active;

  int unsigned start_cnt;
  logic armed;

  assign pclk_o = clk_i;

  assign active = (y < V_ACTIVE) && (x < H_ACTIVE);

  // Startup loop
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      start_cnt <= 0;
      armed     <= 1'b0;
    end else if (start_cnt == START_DELAY) begin
      armed <= 1'b1;
    end else begin
      start_cnt <= start_cnt + 1;
    end
  end
  // assign armed = 1;


  // Placeholder payload: increments once per pushed word.
  always_ff @(posedge pclk_o or negedge rst_ni) begin
    if (!rst_ni) begin
      test_pattern_o <= 32'hA9A8A7A6;
    end else if (pattern_inc_i) begin
      test_pattern_o <= test_pattern_o + 32'd1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni || !armed) begin
      x        <= 0;
      y        <= 0;
      byte_sel <= 0;

      href_o   <= 0;
      vsync_o  <= 1;
    end else begin
      vsync_o <= (y >= V_ACTIVE);
      href_o  <= active;
      if (active) begin
        byte_sel <= ~byte_sel;

        // Advance to next pixel after two bytes
        if (byte_sel) x <= x + 1;

      end else begin
        byte_sel <= 0;

        x <= x + 1;

        if (x == H_ACTIVE + H_BLANK - 1) begin
          x <= 0;
          y <= y + 1;

          if (y == V_ACTIVE + V_BLANK - 1) y <= 0;
        end
      end
    end
  end

endmodule
