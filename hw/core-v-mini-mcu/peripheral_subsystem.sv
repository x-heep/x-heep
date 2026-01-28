// Copyright(// Copyright) 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1



module peripheral_subsystem
  import obi_pkg::*;
  import reg_pkg::*;
#(
    //do not touch these parameters
    parameter NEXT_INT_RND = core_v_mini_mcu_pkg::NEXT_INT == 0 ? 1 : core_v_mini_mcu_pkg::NEXT_INT
) (
    input logic clk_i,
    input logic rst_ni,

    // Clock-gating signal
    input logic clk_gate_en_ni,

    input  obi_req_t  slave_req_i,
    output obi_resp_t slave_resp_o,

    //PLIC
    input  logic [NEXT_INT_RND-1:0] intr_vector_ext_i,
    output logic                    irq_plic_o,
    output logic                    msip_o,

    input logic w25q128jw_controller_intr_i,

    // UART
    input  logic uart_rx_i,
    output logic uart_tx_o,

    //GPIO
    input  logic [31:8] cio_gpio_i,
    output logic [31:8] cio_gpio_o,
    output logic [31:8] cio_gpio_en_o,

    // I2C Interface
    input  logic cio_scl_i,
    output logic cio_scl_o,
    output logic cio_scl_en_o,
    input  logic cio_sda_i,
    output logic cio_sda_o,
    output logic cio_sda_en_o,

    // SPI Host
    output logic                               spi_sck_o,
    output logic                               spi_sck_en_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_csb_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_csb_en_o,
    output logic [                        3:0] spi_sd_o,
    output logic [                        3:0] spi_sd_en_o,
    input  logic [                        3:0] spi_sd_i,
    output logic                               spi_intr_event_o,
    output logic                               spi_rx_valid_o,
    output logic                               spi_tx_ready_o,

    // SPI 2 Host
    output logic                               spi2_sck_o,
    output logic                               spi2_sck_en_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi2_csb_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi2_csb_en_o,
    output logic [                        3:0] spi2_sd_o,
    output logic [                        3:0] spi2_sd_en_o,
    input  logic [                        3:0] spi2_sd_i,


    //RV TIMER
    output logic rv_timer_2_intr_o,
    output logic rv_timer_3_intr_o,

    //I2s
    output logic i2s_sck_o,
    output logic i2s_sck_oe_o,
    input  logic i2s_sck_i,
    output logic i2s_ws_o,
    output logic i2s_ws_oe_o,
    input  logic i2s_ws_i,
    output logic i2s_sd_o,
    output logic i2s_sd_oe_o,
    input  logic i2s_sd_i,
    output logic i2s_rx_valid_o,

    // PDM2PCM Interface
    output logic pdm2pcm_clk_o,
    output logic pdm2pcm_clk_en_o,
    input  logic pdm2pcm_pdm_i
);

  import core_v_mini_mcu_pkg::*;
  import tlul_pkg::*;
  import rv_plic_reg_pkg::*;

  reg_pkg::reg_req_t peripheral_req;
  reg_pkg::reg_rsp_t peripheral_rsp;

  reg_pkg::reg_req_t [core_v_mini_mcu_pkg::PERIPHERALS_RND-1:0] peripheral_slv_req;
  reg_pkg::reg_rsp_t [core_v_mini_mcu_pkg::PERIPHERALS_RND-1:0] peripheral_slv_rsp;

  tlul_pkg::tl_h2d_t plic_tl_h2d;
  tlul_pkg::tl_d2h_t plic_tl_d2h;

  tlul_pkg::tl_h2d_t i2c_tl_h2d;
  tlul_pkg::tl_d2h_t i2c_tl_d2h;

  tlul_pkg::tl_h2d_t rv_timer_tl_h2d;
  tlul_pkg::tl_d2h_t rv_timer_tl_d2h;

  tlul_pkg::tl_h2d_t uart_tl_h2d;
  tlul_pkg::tl_d2h_t uart_tl_d2h;

  logic [rv_plic_reg_pkg::NumTarget-1:0] irq_plic;
  logic [rv_plic_reg_pkg::NumSrc-1:0] intr_vector;
  logic [$clog2(rv_plic_reg_pkg::NumSrc)-1:0] irq_id[rv_plic_reg_pkg::NumTarget];
  logic [$clog2(rv_plic_reg_pkg::NumSrc)-1:0] unused_irq_id[rv_plic_reg_pkg::NumTarget];

  logic [31:8] gpio_intr;
  logic [7:0] cio_gpio_unused;
  logic [7:0] cio_gpio_en_unused;
  logic [7:0] gpio_int_unused;

  logic i2c_intr_fmt_watermark;
  logic i2c_intr_rx_watermark;
  logic i2c_intr_fmt_overflow;
  logic i2c_intr_rx_overflow;
  logic i2c_intr_nak;
  logic i2c_intr_scl_interference;
  logic i2c_intr_sda_interference;
  logic i2c_intr_stretch_timeout;
  logic i2c_intr_sda_unstable;
  logic i2c_intr_trans_complete;
  logic i2c_intr_tx_empty;
  logic i2c_intr_tx_nonempty;
  logic i2c_intr_tx_overflow;
  logic i2c_intr_acq_overflow;
  logic i2c_intr_ack_stop;
  logic i2c_intr_host_timeout;
  logic spi2_intr_event;
  logic i2s_intr_event;
  logic uart_intr_tx_watermark;
  logic uart_intr_rx_watermark;
  logic uart_intr_tx_empty;
  logic uart_intr_rx_overflow;
  logic uart_intr_rx_frame_err;
  logic uart_intr_rx_break_err;
  logic uart_intr_rx_timeout;
  logic uart_intr_rx_parity_err;

  // this avoids lint errors
  assign unused_irq_id = irq_id;

  // Assign internal interrupts
  assign intr_vector[0] = 1'b0;  // ID [0] is a special case and must be tied to zero.
  assign intr_vector[1] = uart_intr_tx_watermark;
  assign intr_vector[2] = uart_intr_rx_watermark;
  assign intr_vector[3] = uart_intr_tx_empty;
  assign intr_vector[4] = uart_intr_rx_overflow;
  assign intr_vector[5] = uart_intr_rx_frame_err;
  assign intr_vector[6] = uart_intr_rx_break_err;
  assign intr_vector[7] = uart_intr_rx_timeout;
  assign intr_vector[8] = uart_intr_rx_parity_err;
  assign intr_vector[32:9] = gpio_intr;
  assign intr_vector[33] = i2c_intr_fmt_watermark;
  assign intr_vector[34] = i2c_intr_rx_watermark;
  assign intr_vector[35] = i2c_intr_fmt_overflow;
  assign intr_vector[36] = i2c_intr_rx_overflow;
  assign intr_vector[37] = i2c_intr_nak;
  assign intr_vector[38] = i2c_intr_scl_interference;
  assign intr_vector[39] = i2c_intr_sda_interference;
  assign intr_vector[40] = i2c_intr_stretch_timeout;
  assign intr_vector[41] = i2c_intr_sda_unstable;
  assign intr_vector[42] = i2c_intr_trans_complete;
  assign intr_vector[43] = i2c_intr_tx_empty;
  assign intr_vector[44] = i2c_intr_tx_nonempty;
  assign intr_vector[45] = i2c_intr_tx_overflow;
  assign intr_vector[46] = i2c_intr_acq_overflow;
  assign intr_vector[47] = i2c_intr_ack_stop;
  assign intr_vector[48] = i2c_intr_host_timeout;
  assign intr_vector[49] = spi2_intr_event;
  assign intr_vector[50] = i2s_intr_event;
  assign intr_vector[51] = w25q128jw_controller_intr_i;

  // External interrupts assignement
  for (genvar i = 0; i < NEXT_INT; i++) begin : gen_external_intr_vect
    assign intr_vector[i+PLIC_USED_NINT] = intr_vector_ext_i[i];
  end

  //Address Decoder
  logic [PERIPHERALS_PORT_SEL_WIDTH-1:0] peripheral_select;

  obi_pkg::obi_req_t slave_fifo_req_sel;
  obi_pkg::obi_resp_t slave_fifo_resp_sel;

  // Clock-gating
  logic clk_cg;
  tc_clk_gating clk_gating_cell (
      .clk_i,
      .en_i(clk_gate_en_ni),
      .test_en_i(1'b0),
      .clk_o(clk_cg)
  );


`ifdef REMOVE_OBI_FIFO

  assign slave_fifo_req_sel = slave_req_i;
  assign slave_resp_o       = slave_fifo_resp_sel;

`else

  obi_pkg::obi_req_t  slave_fifoin_req;
  obi_pkg::obi_resp_t slave_fifoin_resp;

  obi_pkg::obi_req_t  slave_fifoout_req;
  obi_pkg::obi_resp_t slave_fifoout_resp;

  obi_fifo obi_fifo_i (
      .clk_i(clk_cg),
      .rst_ni,
      .producer_req_i(slave_fifoin_req),
      .producer_resp_o(slave_fifoin_resp),
      .consumer_req_o(slave_fifoout_req),
      .consumer_resp_i(slave_fifoout_resp)
  );

  assign slave_fifo_req_sel = slave_fifoout_req;
  assign slave_fifoout_resp = slave_fifo_resp_sel;
  assign slave_fifoin_req   = slave_req_i;
  assign slave_resp_o       = slave_fifoin_resp;

`endif

  periph_to_reg #(
      .req_t(reg_pkg::reg_req_t),
      .rsp_t(reg_pkg::reg_rsp_t),
      .IW(1)
  ) periph_to_reg_i (
      .clk_i(clk_cg),
      .rst_ni,
      .req_i(slave_fifo_req_sel.req),
      .add_i(slave_fifo_req_sel.addr),
      .wen_i(~slave_fifo_req_sel.we),
      .wdata_i(slave_fifo_req_sel.wdata),
      .be_i(slave_fifo_req_sel.be),
      .id_i('0),
      .gnt_o(slave_fifo_resp_sel.gnt),
      .r_rdata_o(slave_fifo_resp_sel.rdata),
      .r_opc_o(),
      .r_id_o(),
      .r_valid_o(slave_fifo_resp_sel.rvalid),
      .reg_req_o(peripheral_req),
      .reg_rsp_i(peripheral_rsp)
  );

  addr_decode #(
      .NoIndices(core_v_mini_mcu_pkg::PERIPHERALS_RND),
      .NoRules(core_v_mini_mcu_pkg::PERIPHERALS_RND),
      .addr_t(logic [31:0]),
      .rule_t(addr_map_rule_pkg::addr_map_rule_t)
  ) i_addr_decode_soc_regbus_periph_xbar (
      .addr_i(peripheral_req.addr),
      .addr_map_i(core_v_mini_mcu_pkg::PERIPHERALS_ADDR_RULES),
      .idx_o(peripheral_select),
      .dec_valid_o(),
      .dec_error_o(),
      .en_default_idx_i(1'b0),
      .default_idx_i('0)
  );

  reg_demux #(
      .NoPorts(core_v_mini_mcu_pkg::PERIPHERALS_RND),
      .req_t  (reg_pkg::reg_req_t),
      .rsp_t  (reg_pkg::reg_rsp_t)
  ) reg_demux_i (
      .clk_i(clk_cg),
      .rst_ni,
      .in_select_i(peripheral_select),
      .in_req_i(peripheral_req),
      .in_rsp_o(peripheral_rsp),
      .out_req_o(peripheral_slv_req),
      .out_rsp_i(peripheral_slv_rsp)
  );

  reg_to_tlul #(
      .req_t(reg_pkg::reg_req_t),
      .rsp_t(reg_pkg::reg_rsp_t),
      .tl_h2d_t(tlul_pkg::tl_h2d_t),
      .tl_d2h_t(tlul_pkg::tl_d2h_t),
      .tl_a_user_t(tlul_pkg::tl_a_user_t),
      .tl_a_op_e(tlul_pkg::tl_a_op_e),
      .TL_A_USER_DEFAULT(tlul_pkg::TL_A_USER_DEFAULT),
      .PutFullData(tlul_pkg::PutFullData),
      .Get(tlul_pkg::Get)
  ) reg_to_tlul_plic_i (
      .tl_o(plic_tl_h2d),
      .tl_i(plic_tl_d2h),
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::RV_PLIC_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::RV_PLIC_IDX])
  );

  rv_plic rv_plic_i (
      .clk_i(clk_cg),
      .rst_ni,
      .tl_i(plic_tl_h2d),
      .tl_o(plic_tl_d2h),
      .intr_src_i(intr_vector),
      .irq_o(irq_plic_o),
      .irq_id_o(irq_id),
      .msip_o(msip_o)
  );

  spi_host #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) spi_host_dma_i (
      .clk_i(clk_cg),
      .rst_ni,
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::SPI_HOST_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::SPI_HOST_IDX]),
      .alert_rx_i(),
      .alert_tx_o(),
      .passthrough_i(spi_device_pkg::PASSTHROUGH_REQ_DEFAULT),
      .passthrough_o(),
      .cio_sck_o(spi_sck_o),
      .cio_sck_en_o(spi_sck_en_o),
      .cio_csb_o(spi_csb_o),
      .cio_csb_en_o(spi_csb_en_o),
      .cio_sd_o(spi_sd_o),
      .cio_sd_en_o(spi_sd_en_o),
      .cio_sd_i(spi_sd_i),
      .rx_valid_o(spi_rx_valid_o),
      .tx_ready_o(spi_tx_ready_o),
      .hw2reg_status_o(),
      .intr_error_o(),
      .intr_spi_event_o(spi_intr_event_o)
  );

  gpio #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) gpio_i (
      .clk_i(clk_cg),
      .rst_ni,
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::GPIO_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::GPIO_IDX]),
      .gpio_in({cio_gpio_i, 8'b0}),
      .gpio_out({cio_gpio_o, cio_gpio_unused}),
      .gpio_tx_en_o({cio_gpio_en_o, cio_gpio_en_unused}),
      .gpio_in_sync_o(),
      .pin_level_interrupts_o({gpio_intr, gpio_int_unused}),
      .global_interrupt_o()
  );

  reg_to_tlul #(
      .req_t(reg_pkg::reg_req_t),
      .rsp_t(reg_pkg::reg_rsp_t),
      .tl_h2d_t(tlul_pkg::tl_h2d_t),
      .tl_d2h_t(tlul_pkg::tl_d2h_t),
      .tl_a_user_t(tlul_pkg::tl_a_user_t),
      .tl_a_op_e(tlul_pkg::tl_a_op_e),
      .TL_A_USER_DEFAULT(tlul_pkg::TL_A_USER_DEFAULT),
      .PutFullData(tlul_pkg::PutFullData),
      .Get(tlul_pkg::Get)
  ) reg_to_tlul_i2c_i (
      .tl_o(i2c_tl_h2d),
      .tl_i(i2c_tl_d2h),
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::I2C_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::I2C_IDX])
  );

  i2c i2c_i (
      .clk_i(clk_cg),
      .rst_ni,
      .tl_i(i2c_tl_h2d),
      .tl_o(i2c_tl_d2h),
      .cio_scl_i,
      .cio_scl_o,
      .cio_scl_en_o,
      .cio_sda_i,
      .cio_sda_o,
      .cio_sda_en_o,
      .intr_fmt_watermark_o(i2c_intr_fmt_watermark),
      .intr_rx_watermark_o(i2c_intr_rx_watermark),
      .intr_fmt_overflow_o(i2c_intr_fmt_overflow),
      .intr_rx_overflow_o(i2c_intr_rx_overflow),
      .intr_nak_o(i2c_intr_nak),
      .intr_scl_interference_o(i2c_intr_scl_interference),
      .intr_sda_interference_o(i2c_intr_sda_interference),
      .intr_stretch_timeout_o(i2c_intr_stretch_timeout),
      .intr_sda_unstable_o(i2c_intr_sda_unstable),
      .intr_trans_complete_o(i2c_intr_trans_complete),
      .intr_tx_empty_o(i2c_intr_tx_empty),
      .intr_tx_nonempty_o(i2c_intr_tx_nonempty),
      .intr_tx_overflow_o(i2c_intr_tx_overflow),
      .intr_acq_overflow_o(i2c_intr_acq_overflow),
      .intr_ack_stop_o(i2c_intr_ack_stop),
      .intr_host_timeout_o(i2c_intr_host_timeout)
  );

  reg_to_tlul #(
      .req_t(reg_pkg::reg_req_t),
      .rsp_t(reg_pkg::reg_rsp_t),
      .tl_h2d_t(tlul_pkg::tl_h2d_t),
      .tl_d2h_t(tlul_pkg::tl_d2h_t),
      .tl_a_user_t(tlul_pkg::tl_a_user_t),
      .tl_a_op_e(tlul_pkg::tl_a_op_e),
      .TL_A_USER_DEFAULT(tlul_pkg::TL_A_USER_DEFAULT),
      .PutFullData(tlul_pkg::PutFullData),
      .Get(tlul_pkg::Get)
  ) rv_timer_reg_to_tlul_i (
      .tl_o(rv_timer_tl_h2d),
      .tl_i(rv_timer_tl_d2h),
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::RV_TIMER_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::RV_TIMER_IDX])
  );

  rv_timer rv_timer_2_3_i (
      .clk_i(clk_cg),
      .rst_ni,
      .tl_i(rv_timer_tl_h2d),
      .tl_o(rv_timer_tl_d2h),
      .intr_timer_expired_0_0_o(rv_timer_2_intr_o),
      .intr_timer_expired_1_0_o(rv_timer_3_intr_o)
  );

  spi_host #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) spi2_host (
      .clk_i(clk_cg),
      .rst_ni,
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::SPI2_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::SPI2_IDX]),
      .alert_rx_i(),
      .alert_tx_o(),
      .passthrough_i(spi_device_pkg::PASSTHROUGH_REQ_DEFAULT),
      .passthrough_o(),
      .cio_sck_o(spi2_sck_o),
      .cio_sck_en_o(spi2_sck_en_o),
      .cio_csb_o(spi2_csb_o),
      .cio_csb_en_o(spi2_csb_en_o),
      .cio_sd_o(spi2_sd_o),
      .cio_sd_en_o(spi2_sd_en_o),
      .cio_sd_i(spi2_sd_i),
      .rx_valid_o(),
      .tx_ready_o(),
      .hw2reg_status_o(),
      .intr_error_o(),
      .intr_spi_event_o(spi2_intr_event)
  );

  assign pdm2pcm_clk_o = '0;

  assign pdm2pcm_clk_en_o = 1;

  i2s #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) i2s_i (
      .clk_i(clk_cg),
      .rst_ni,
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::I2S_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::I2S_IDX]),

      .i2s_sck_o(i2s_sck_o),
      .i2s_sck_oe_o(i2s_sck_oe_o),
      .i2s_sck_i(i2s_sck_i),
      .i2s_ws_o(i2s_ws_o),
      .i2s_ws_oe_o(i2s_ws_oe_o),
      .i2s_ws_i(i2s_ws_i),
      .i2s_sd_o(i2s_sd_o),
      .i2s_sd_oe_o(i2s_sd_oe_o),
      .i2s_sd_i(i2s_sd_i),
      .intr_i2s_event_o(i2s_intr_event),
      .i2s_rx_valid_o(i2s_rx_valid_o)
  );



  reg_to_tlul #(
      .req_t(reg_pkg::reg_req_t),
      .rsp_t(reg_pkg::reg_rsp_t),
      .tl_h2d_t(tlul_pkg::tl_h2d_t),
      .tl_d2h_t(tlul_pkg::tl_d2h_t),
      .tl_a_user_t(tlul_pkg::tl_a_user_t),
      .tl_a_op_e(tlul_pkg::tl_a_op_e),
      .TL_A_USER_DEFAULT(tlul_pkg::TL_A_USER_DEFAULT),
      .PutFullData(tlul_pkg::PutFullData),
      .Get(tlul_pkg::Get)
  ) reg_to_tlul_uart_i (
      .tl_o(uart_tl_h2d),
      .tl_i(uart_tl_d2h),
      .reg_req_i(peripheral_slv_req[core_v_mini_mcu_pkg::UART_IDX]),
      .reg_rsp_o(peripheral_slv_rsp[core_v_mini_mcu_pkg::UART_IDX])
  );

  uart uart_i (
      .clk_i(clk_cg),
      .rst_ni,
      .tl_i(uart_tl_h2d),
      .tl_o(uart_tl_d2h),
      .cio_rx_i(uart_rx_i),
      .cio_tx_o(uart_tx_o),
      .cio_tx_en_o(),
      .intr_tx_watermark_o(uart_intr_tx_watermark),
      .intr_rx_watermark_o(uart_intr_rx_watermark),
      .intr_tx_empty_o(uart_intr_tx_empty),
      .intr_rx_overflow_o(uart_intr_rx_overflow),
      .intr_rx_frame_err_o(uart_intr_rx_frame_err),
      .intr_rx_break_err_o(uart_intr_rx_break_err),
      .intr_rx_timeout_o(uart_intr_rx_timeout),
      .intr_rx_parity_err_o(uart_intr_rx_parity_err)
  );



endmodule : peripheral_subsystem
