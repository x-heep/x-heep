module camera_model #(
    parameter int H_ACTIVE = 640,
    parameter int V_ACTIVE = 480,
    parameter int H_BLANK  = 16,
    parameter int V_BLANK  = 10,

    parameter int START_DELAY = 30000  // Delay 300us to boot soft
) (
    input logic clk_i,  // Pixel clock
    input logic rst_ni,

    output logic pclk_o,
    output logic vsync_o,
    output logic href_o,
    output logic [7:0] data_o
);

  logic [15:0] image_mem[0:H_ACTIVE*V_ACTIVE-1];

  initial begin
    $readmemh("../../../tb/test_image.hex", image_mem);
  end

  int x;
  int y;
  int pixel_idx;
  logic byte_sel;
  logic active;

  logic clk_div16;
  logic [2:0] div_cnt;

  int unsigned start_cnt;
  logic armed;

  assign pixel_idx = y * H_ACTIVE + x;
  assign active = (y < V_ACTIVE) && (x < H_ACTIVE);


  assign pclk_o = clk_div16;

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

  // Clock divisor (may be remove later if dma is fast enough)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      div_cnt   <= 3'd0;
      clk_div16 <= 1'b0;
    end else begin
      if (div_cnt == 3'd7) begin
        div_cnt   <= 3'd0;
        clk_div16 <= ~clk_div16;
      end else begin
        div_cnt <= div_cnt + 1'b1;
      end
    end
  end

  always_ff @(posedge pclk_o or negedge rst_ni) begin
    if (~rst_ni || !armed) begin
      x        <= 0;
      y        <= 0;
      byte_sel <= 0;
    end else if (active) begin
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

  always_ff @(posedge pclk_o or negedge rst_ni) begin
    if (~rst_ni || !armed) begin
      // Idle: blanking, no data valid, so nothing is pushed into the FIFO.
      href_o  <= 0;
      vsync_o <= 1;
      data_o  <= 8'h00;
    end else begin
      vsync_o <= (y >= V_ACTIVE);
      href_o  <= active;

      if (active) begin
        data_o <= byte_sel ? image_mem[pixel_idx][7:0] : image_mem[pixel_idx][15:8];
      end else begin
        data_o <= 8'h00;
      end
    end
  end

endmodule
