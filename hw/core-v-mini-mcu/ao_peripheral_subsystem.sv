// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1




module ao_peripheral_subsystem
  import obi_pkg::*;
  import reg_pkg::*;
  import power_manager_pkg::*;
  import fifo_pkg::*;
#(
    parameter AO_SPC_NUM = 0,
    //do not touch these parameters
    parameter AO_SPC_NUM_RND = AO_SPC_NUM == 0 ? 0 : AO_SPC_NUM - 1,
    parameter EXT_DOMAINS_RND = core_v_mini_mcu_pkg::EXTERNAL_DOMAINS == 0 ? 1 : core_v_mini_mcu_pkg::EXTERNAL_DOMAINS,
    parameter NEXT_INT_RND = core_v_mini_mcu_pkg::NEXT_INT == 0 ? 1 : core_v_mini_mcu_pkg::NEXT_INT
) (
    input logic clk_i,
    input logic rst_ni,

    input  reg_req_t slave_req_i,
    output reg_rsp_t slave_resp_o,

    input  reg_req_t [AO_SPC_NUM_RND:0] spc2ao_req_i,
    output reg_rsp_t [AO_SPC_NUM_RND:0] ao2spc_resp_o,

    // SOC CTRL
    input  logic [31:0] xheep_instance_id_i,
    input  logic        boot_select_i,
    input  logic        execute_from_flash_i,
    output logic        exit_valid_o,
    output logic [31:0] exit_value_o,

    // Memory Map SPI Region
    input  obi_req_t  spimemio_req_i,
    output obi_resp_t spimemio_resp_o,

    // SPI Interface to flash (YosysHW SPI and OpenTitan SPI multiplexed)
    output logic                               spi_flash_sck_o,
    output logic                               spi_flash_sck_en_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_o,
    output logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_en_o,
    output logic [                        3:0] spi_flash_sd_o,
    output logic [                        3:0] spi_flash_sd_en_o,
    input  logic [                        3:0] spi_flash_sd_i,

    // OpenTitan SPI interface to external spi slaves
    input logic spi_rx_valid_i,
    input logic spi_tx_ready_i,

    output logic spi_flash_intr_event_o,

    // flash controller interrupt
    output logic w25q128jw_controller_intr_o,

    // POWER MANAGER
    input logic [31:0] intr_i,
    input logic [NEXT_INT_RND-1:0] intr_vector_ext_i,
    input logic core_sleep_i,

    output power_manager_out_t cpu_subsystem_pwr_ctrl_o,
    output power_manager_out_t peripheral_subsystem_pwr_ctrl_o,
    output power_manager_out_t memory_subsystem_pwr_ctrl_o[core_v_mini_mcu_pkg::NUM_BANKS-1:0],
    output power_manager_out_t external_subsystem_pwr_ctrl_o[EXT_DOMAINS_RND-1:0],

    input power_manager_in_t cpu_subsystem_pwr_ctrl_i,
    input power_manager_in_t peripheral_subsystem_pwr_ctrl_i,
    input power_manager_in_t memory_subsystem_pwr_ctrl_i[core_v_mini_mcu_pkg::NUM_BANKS-1:0],
    input power_manager_in_t external_subsystem_pwr_ctrl_i[EXT_DOMAINS_RND-1:0],

    // RV TIMER
    output logic rv_timer_0_intr_o,
    output logic rv_timer_1_intr_o,

    // DMA
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_read_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_read_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_write_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_write_resp_i,
    output obi_req_t  [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_addr_req_o,
    input  obi_resp_t [core_v_mini_mcu_pkg::DMA_NUM_MASTER_PORTS-1:0] dma_addr_resp_i,
    output logic                                                      dma_done_intr_o,
    output logic                                                      dma_window_intr_o,

    output fifo_req_t  [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_req_o,
    input  fifo_resp_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_resp_i,

    // External PADs
    output reg_req_t pad_req_o,
    input  reg_rsp_t pad_resp_i,

    // FAST INTR CTRL
    input  logic [15:0] fast_intr_i,
    output logic [15:0] fast_intr_o,

    // GPIO
    input  logic [7:0] cio_gpio_i,
    output logic [7:0] cio_gpio_o,
    output logic [7:0] cio_gpio_en_o,
    output logic [7:0] intr_gpio_o,

    // I2s
    input logic i2s_rx_valid_i,

    // EXTERNAL PERIPH
    output reg_req_t ext_peripheral_slave_req_o,
    input  reg_rsp_t ext_peripheral_slave_resp_i,

    // SPC interface
    input  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_tx_i,
    input  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_slot_rx_i,
    input  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] ext_dma_stop_i,
    input  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] hw_fifo_done_i,
    output logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_o

);

  import core_v_mini_mcu_pkg::*;
  import tlul_pkg::*;

  localparam DMA_GLOBAL_TRIGGER_SLOT_NUM = 5;
  localparam DMA_EXT_TRIGGER_SLOT_NUM = core_v_mini_mcu_pkg::DMA_CH_NUM * 2;

  /*_________________________________________________________________________________________________________________________________ */

  /* Signals declaration */

  /* NOTE: Additional xbars signals defined in the xbar generate statement */

  /* Peripheral register inteface */
  reg_pkg::reg_req_t peripheral_req;
  reg_pkg::reg_rsp_t peripheral_rsp;
  reg_pkg::reg_req_t [core_v_mini_mcu_pkg::AO_PERIPHERALS-1:0] ao_peripheral_slv_req;
  reg_pkg::reg_rsp_t [core_v_mini_mcu_pkg::AO_PERIPHERALS-1:0] ao_peripheral_slv_rsp;
  logic [AO_PERIPHERALS_PORT_SEL_WIDTH-1:0] peripheral_select;

  tlul_pkg::tl_h2d_t rv_timer_tl_h2d;
  tlul_pkg::tl_d2h_t rv_timer_tl_d2h;

  /* SPI memory signals */
  logic use_spimemio;
  logic spi_flash_rx_valid;
  logic spi_flash_tx_ready;

  /* GPIOs signals */
  logic [23:0] intr_gpio_unused;
  logic [23:0] cio_gpio_unused;
  logic [23:0] cio_gpio_en_unused;

  /* DMA signals */
  logic dma_clk_gate_en_n[core_v_mini_mcu_pkg::DMA_CH_NUM-1:0];
  power_manager_out_t dma_subsystem_pwr_ctrl[core_v_mini_mcu_pkg::DMA_CH_NUM-1:0];
  logic [DMA_GLOBAL_TRIGGER_SLOT_NUM-1:0] dma_global_trigger_slots;
  logic [DMA_EXT_TRIGGER_SLOT_NUM-1:0] dma_ext_trigger_slots;
  obi_pkg::obi_req_t slave_fifoout_req;
  obi_pkg::obi_resp_t slave_fifoout_resp;
  reg_req_t perconv2regdemux_req;
  reg_rsp_t regdemux2perconv_resp;
  dma_reg_pkg::dma_hw2reg_t [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] external_dma_hw2reg;
  logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_ready;

  /*_________________________________________________________________________________________________________________________________ */

  /* Signal assignment */

  /* Peripheral demuxed register interface */
  assign ext_peripheral_slave_req_o = ao_peripheral_slv_req[core_v_mini_mcu_pkg::EXT_PERIPHERAL_IDX];
  assign ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::EXT_PERIPHERAL_IDX] = ext_peripheral_slave_resp_i;


  assign pad_req_o = ao_peripheral_slv_req[core_v_mini_mcu_pkg::PAD_CONTROL_IDX];
  assign ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::PAD_CONTROL_IDX] = pad_resp_i;

  assign dma_global_trigger_slots[0] = spi_rx_valid_i;
  assign dma_global_trigger_slots[1] = spi_tx_ready_i;
  assign dma_global_trigger_slots[2] = spi_flash_rx_valid;
  assign dma_global_trigger_slots[3] = spi_flash_tx_ready;
  assign dma_global_trigger_slots[4] = i2s_rx_valid_i;

  generate
    for (genvar i = 0; i < core_v_mini_mcu_pkg::DMA_CH_NUM; i++) begin : dma_trigger_slots_gen
      assign dma_ext_trigger_slots[2*i]   = ext_dma_slot_tx_i[i];
      assign dma_ext_trigger_slots[2*i+1] = ext_dma_slot_rx_i[i];
      if (i > 0) begin : external_dma_hw2reg_gen
        assign external_dma_hw2reg[i] = '0;  //TODO: make it programmable
      end
    end
  endgenerate

  /* DMA clock gating */
  generate
    for (genvar i = 0; i < core_v_mini_mcu_pkg::DMA_CH_NUM; i++) begin : dma_clk_gate_gen
      assign dma_clk_gate_en_n[i] = dma_subsystem_pwr_ctrl[i].clkgate_en_n;
    end
  endgenerate

  /*_________________________________________________________________________________________________________________________________ */

  /* Module instantiation */

  /* System bus to AO OBI FIFO */
  obi_fifo obi_fifo_i (
      .clk_i,
      .rst_ni,
      .producer_req_i (slave_req_i),
      .producer_resp_o(slave_resp_o),
      .consumer_req_o (slave_fifoout_req),
      .consumer_resp_i(slave_fifoout_resp)
  );

  /* Peripheral to register interface converter*/
  periph_to_reg #(
      .req_t(reg_pkg::reg_req_t),
      .rsp_t(reg_pkg::reg_rsp_t),
      .IW(1)
  ) periph_to_reg_i (
      .clk_i,
      .rst_ni,
      .req_i(slave_fifoout_req.req),
      .add_i(slave_fifoout_req.addr),
      .wen_i(~slave_fifoout_req.we),
      .wdata_i(slave_fifoout_req.wdata),
      .be_i(slave_fifoout_req.be),
      .id_i('0),
      .gnt_o(slave_fifoout_resp.gnt),
      .r_rdata_o(slave_fifoout_resp.rdata),
      .r_opc_o(),
      .r_id_o(),
      .r_valid_o(slave_fifoout_resp.rvalid),
      .reg_req_o(peripheral_req),
      .reg_rsp_i(peripheral_rsp)
  );

  /* SPC crossbar & FIFOs */
  generate
    if (AO_SPC_NUM > 0) begin : gen_aopb
      /* Assign the bus port to the first input port of the AOPB */
      reg_req_t [AO_SPC_NUM:0] packet_req;
      reg_rsp_t [AO_SPC_NUM:0] packet_rsp;

      assign packet_req[0]  = peripheral_req;
      assign peripheral_rsp = packet_rsp[0];

      for (genvar i = 0; i < AO_SPC_NUM; i++) begin : gen_spc
        assign packet_req[i+1]  = spc2ao_req_i[i];
        assign ao2spc_resp_o[i] = packet_rsp[i+1];
      end

      reg_mux #(
          .NoPorts(AO_SPC_NUM + 1),
          .req_t  (reg_pkg::reg_req_t),
          .rsp_t  (reg_pkg::reg_rsp_t),
          .AW     (32),
          .DW     (32)
      ) reg_mux_i (
          .clk_i,
          .rst_ni,
          .in_req_i (packet_req),
          .in_rsp_o (packet_rsp),
          .out_req_o(perconv2regdemux_req),
          .out_rsp_i(regdemux2perconv_resp)
      );

    end else begin : gen_no_aopb
      assign ao2spc_resp_o = '0;
      assign perconv2regdemux_req = peripheral_req;
      assign peripheral_rsp = regdemux2perconv_resp;
    end
  endgenerate

  /* Address decoder for the peripheral registers */
  addr_decode #(
      .NoIndices(core_v_mini_mcu_pkg::AO_PERIPHERALS),
      .NoRules(core_v_mini_mcu_pkg::AO_PERIPHERALS),
      .addr_t(logic [31:0]),
      .rule_t(addr_map_rule_pkg::addr_map_rule_t)
  ) i_addr_decode_soc_regbus_periph_xbar (
      .addr_i(perconv2regdemux_req.addr),
      .addr_map_i(core_v_mini_mcu_pkg::AO_PERIPHERALS_ADDR_RULES),
      .idx_o(peripheral_select),
      .dec_valid_o(),
      .dec_error_o(),
      .en_default_idx_i(1'b0),
      .default_idx_i('0)
  );

  /* Register demux */
  reg_demux #(
      .NoPorts(core_v_mini_mcu_pkg::AO_PERIPHERALS),
      .req_t  (reg_pkg::reg_req_t),
      .rsp_t  (reg_pkg::reg_rsp_t)
  ) reg_demux_i (
      .clk_i,
      .rst_ni,
      .in_select_i(peripheral_select),
      .in_req_i(perconv2regdemux_req),
      .in_rsp_o(regdemux2perconv_resp),
      .out_req_o(ao_peripheral_slv_req),
      .out_rsp_i(ao_peripheral_slv_rsp)
  );

  soc_ctrl #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) soc_ctrl_i (
      .clk_i,
      .rst_ni,
      .reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::SOC_CTRL_IDX]),
      .reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::SOC_CTRL_IDX]),
      .boot_select_i,
      .execute_from_flash_i,
      .xheep_instance_id_i,
      .use_spimemio_o(use_spimemio),
      .exit_valid_o,
      .exit_value_o
  );

  /* Boot ROM */
  boot_rom boot_rom_i (
      .reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::BOOTROM_IDX]),
      .reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::BOOTROM_IDX])
  );

  /* SPI subsystem */
  spi_subsystem spi_subsystem_i (
      .clk_i,
      .rst_ni,
      .use_spimemio_i(use_spimemio),
      .spimemio_req_i,
      .spimemio_resp_o,
      .yo_reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::SPI_MEMIO_IDX]),
      .yo_reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::SPI_MEMIO_IDX]),
      .ot_reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::SPI_FLASH_IDX]),
      .ot_reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::SPI_FLASH_IDX]),
      .flash_ctr_reg_req_i('0),
      .flash_ctr_reg_rsp_o(),
      .external_dma_hw2reg_o(external_dma_hw2reg[0]),
      .w25q128jw_controller_intr_o,
      .dma_ready_i(dma_ready),
      .dma_done_i(dma_done_o),
      .spi_flash_sck_o,
      .spi_flash_sck_en_o,
      .spi_flash_csb_o,
      .spi_flash_csb_en_o,
      .spi_flash_sd_o,
      .spi_flash_sd_en_o,
      .spi_flash_sd_i,
      .spi_flash_intr_error_o(),
      .spi_flash_intr_event_o,
      .spi_flash_rx_valid_o(spi_flash_rx_valid),
      .spi_flash_tx_ready_o(spi_flash_tx_ready)
  );

  /* Power manager */
  power_manager #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) power_manager_i (
      .clk_i,
      .rst_ni,
      .reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::POWER_MANAGER_IDX]),
      .reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::POWER_MANAGER_IDX]),
      .intr_i,
      .ext_irq_i(intr_vector_ext_i),
      .core_sleep_i,
      .cpu_subsystem_pwr_ctrl_o,
      .peripheral_subsystem_pwr_ctrl_o,
      .memory_subsystem_pwr_ctrl_o,
      .external_subsystem_pwr_ctrl_o,
      .cpu_subsystem_pwr_ctrl_i,
      .peripheral_subsystem_pwr_ctrl_i,
      .memory_subsystem_pwr_ctrl_i,
      .external_subsystem_pwr_ctrl_i,
      .dma_subsystem_pwr_ctrl_o(dma_subsystem_pwr_ctrl)
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
      .reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::RV_TIMER_AO_IDX]),
      .reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::RV_TIMER_AO_IDX])
  );

  rv_timer rv_timer_0_1_i (
      .clk_i,
      .rst_ni,
      .tl_i(rv_timer_tl_h2d),
      .tl_o(rv_timer_tl_d2h),
      .intr_timer_expired_0_0_o(rv_timer_0_intr_o),
      .intr_timer_expired_1_0_o(rv_timer_1_intr_o)
  );


  dma_subsystem #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t),
      .obi_req_t(obi_pkg::obi_req_t),
      .obi_resp_t(obi_pkg::obi_resp_t),
      .GLOBAL_SLOT_NUM(DMA_GLOBAL_TRIGGER_SLOT_NUM),
      .EXT_SLOT_NUM(DMA_EXT_TRIGGER_SLOT_NUM)
  ) dma_subsystem_i (
      .clk_i,
      .rst_ni,
      .clk_gate_en_ni(dma_clk_gate_en_n),
      .reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::DMA_IDX]),
      .reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::DMA_IDX]),
      .dma_read_req_o,
      .dma_read_resp_i,
      .dma_write_req_o,
      .dma_write_resp_i,
      .dma_addr_req_o,
      .dma_addr_resp_i,
      .hw_fifo_req_o,
      .hw_fifo_resp_i,
      .external_hw2reg_i(external_dma_hw2reg),
      .global_trigger_slot_i(dma_global_trigger_slots),
      .ext_trigger_slot_i(dma_ext_trigger_slots),
      .ext_dma_stop_i(ext_dma_stop_i),
      .hw_fifo_done_i,
      .dma_done_intr_o(dma_done_intr_o),
      .dma_window_intr_o(dma_window_intr_o),
      .dma_ready_o(dma_ready),
      .dma_done_o(dma_done_o)
  );


  fast_intr_ctrl #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) fast_intr_ctrl_i (
      .clk_i,
      .rst_ni,
      .reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::FAST_INTR_CTRL_IDX]),
      .reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::FAST_INTR_CTRL_IDX]),
      .fast_intr_i,
      .fast_intr_o
  );

  /* GPIO subsystem */
  gpio #(
      .reg_req_t(reg_pkg::reg_req_t),
      .reg_rsp_t(reg_pkg::reg_rsp_t)
  ) gpio_ao_i (
      .clk_i,
      .rst_ni,
      .reg_req_i(ao_peripheral_slv_req[core_v_mini_mcu_pkg::GPIO_AO_IDX]),
      .reg_rsp_o(ao_peripheral_slv_rsp[core_v_mini_mcu_pkg::GPIO_AO_IDX]),
      .gpio_in({24'b0, cio_gpio_i}),
      .gpio_out({cio_gpio_unused, cio_gpio_o}),
      .gpio_tx_en_o({cio_gpio_en_unused, cio_gpio_en_o}),
      .gpio_in_sync_o(),
      .pin_level_interrupts_o({intr_gpio_unused, intr_gpio_o}),
      .global_interrupt_o()
  );

endmodule : ao_peripheral_subsystem
