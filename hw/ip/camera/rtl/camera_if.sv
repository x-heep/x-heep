

`define RGB565 3'b000
`define RGB555 3'b001
`define RGB444 3'b010
`define BYPASS_LITEND 3'b100
`define BYPASS_BIGEND 3'b101
`define BYPASS_10BITS 3'b110

module camera_if #(
    // Register Interface data types
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,

    parameter int unsigned FifoLogDepth = 5,
    parameter logic UseTestPattern = 1
) (
    input logic clk_i,
    input logic rst_ni,

    // Register interface from system bus
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // Output to camera
    output logic cam_xclk_o,
    output logic cam_rst_o,
    output logic cam_pwnd_o,

    // Input from camera
    input logic       cam_pclk_i,
    input logic       cam_href_i,
    input logic       cam_vsync_i,
    input logic [7:0] cam_data_i
);

  // ============== PACKAGE IMPORTS ==============
  import camera_reg_pkg::*;

  logic                  cam_pclk;
  logic                  cam_href;
  logic                  cam_vsync;

  // ============== REGISTER SIGNALS ==============
  camera_reg2hw_t        reg2hw;
  camera_hw2reg_t        hw2reg;

  reg_req_t              fifo_win_h2d;
  reg_rsp_t              fifo_win_d2h;
  reg_rsp_t              fifo_win_d2h_raw;

  // ============== OTHER SIGNALS ==============

  // Camera (cam_pclk_i) domain
  logic                  start_sync;
  logic                  frame_active;
  logic           [31:0] word_shift;
  logic           [ 1:0] byte_cnt;
  logic                  word_valid;
  logic           [31:0] test_pattern;
  logic           [31:0] fifo_wdata;
  logic                  fifo_src_valid;
  logic                  fifo_src_ready;

  // Bus (clk_i) domain
  logic           [31:0] fifo_rdata;
  logic                  fifo_dst_valid;
  logic                  fifo_pop;
  logic                  win_read;

  // Camera control
  assign cam_xclk_o = clk_i;
  assign cam_rst_o = reg2hw.control.reset.q;
  assign cam_pwnd_o = reg2hw.control.pwnd.q;


  // STATUS.RUNNING: a frame is being transmitted (vsync is active low here).
  assign hw2reg.status.d = ~cam_vsync;
  assign hw2reg.status.de = 1'b1;

  if (UseTestPattern) begin
    fake_signals fake_signals_i (
        .clk_i,
        .rst_ni,
        .pclk_o(cam_pclk),
        .vsync_o(cam_vsync),
        .href_o(cam_href),
        .pattern_inc_i(fifo_src_valid & fifo_src_ready),
        .test_pattern_o(test_pattern)
    );
  end else begin
    assign cam_pclk  = cam_pclk_i;
    assign cam_vsync = cam_vsync_i;
    assign cam_href  = cam_href_i;
  end


  // reg2hw.control.start.q is set in the clk_i (bus) domain; synchronize it
  // into the cam_pclk domain before using it in any camera-domain logic.
  sync #(
      .STAGES(2)
  ) start_sync_i (
      .clk_i   (cam_pclk),
      .rst_ni,
      .serial_i(reg2hw.control.start.q),
      .serial_o(start_sync)
  );

  // Enable: software armed the capture and we are inside a frame.
  always_ff @(posedge cam_pclk or negedge rst_ni) begin
    if (!rst_ni) frame_active <= 1'b0;
    else frame_active <= start_sync & ~cam_vsync;
  end

  // Pack four pixel bytes into one bus word. hsync (href) is the per-byte
  // data-valid coming from the camera.
  always_ff @(posedge cam_pclk or negedge rst_ni) begin
    //remove rst or 
    if (!rst_ni) begin
      word_shift <= '0;
      byte_cnt   <= '0;
      word_valid <= 1'b0;
    end else begin
      if (!frame_active) begin
        // Resynchronize on the word boundary at every frame/line gap.
        byte_cnt   <= '0;
        word_valid <= 1'b0;
      end else begin
        word_valid <= 1'b0;
        if (cam_href) begin
          word_shift <= {word_shift[23:0], cam_data_i};
          byte_cnt   <= byte_cnt + 2'd1;
          word_valid <= (byte_cnt == 2'd3);
        end
      end
    end
  end


  assign fifo_wdata     = UseTestPattern ? test_pattern : word_shift;

  // Write enable into the FIFO. A word arriving while the FIFO is full is
  // dropped; software is expected to keep draining through the DATA window.
  assign fifo_src_valid = word_valid;

  // ------------------------- Clock domain crossing FIFO
  cdc_fifo_gray #(
      .T(logic [31:0]),
      .LOG_DEPTH(FifoLogDepth)
  ) camera_fifo_i (
      .src_clk_i  (cam_pclk),
      .src_rst_ni (rst_ni),
      .src_data_i (fifo_wdata),
      .src_valid_i(fifo_src_valid),
      .src_ready_o(fifo_src_ready),

      .dst_clk_i  (clk_i),
      .dst_rst_ni (rst_ni),
      .dst_data_o (fifo_rdata),
      .dst_valid_o(fifo_dst_valid),
      .dst_ready_i(fifo_pop)
  );

  camera_window #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) camera_window_i (
      .win_i  (fifo_win_h2d),
      .win_o  (fifo_win_d2h_raw),
      .data_i (fifo_rdata),
      // High on a read of the DATA window
      .ready_o(win_read)
  );

  // An empty FIFO returns nothing at all rather than a made-up word: the read
  // is held off until the camera has actually produced a word. The bus master
  // (DMA or core) therefore runs at the pace of the pixel stream.
  // NOTE: a read issued while the camera is stopped stalls until it restarts.
  always_comb begin
    fifo_win_d2h       = fifo_win_d2h_raw;
    fifo_win_d2h.ready = fifo_win_d2h_raw.ready & (fifo_dst_valid | ~win_read);
  end

  // Pop only on the cycle the read actually completes.
  assign fifo_pop = win_read & fifo_dst_valid;

  // ------------------------- Registers
  camera_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) camera_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg2hw,
      .hw2reg,
      .reg_req_i,
      .reg_rsp_o,
      .reg_req_win_o(fifo_win_h2d),
      .reg_rsp_win_i(fifo_win_d2h),
      .devmode_i(1'b0)
  );

endmodule  // camera_if
