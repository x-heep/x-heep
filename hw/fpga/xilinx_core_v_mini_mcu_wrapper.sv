// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module xilinx_core_v_mini_mcu_wrapper
  import obi_pkg::*;
  import reg_pkg::*;
#(
    parameter CLK_LED_COUNT_LENGTH = 27
) (

`ifdef FPGA_ZCU104
    inout logic clk_300mhz_n,
    inout logic clk_300mhz_p,
`elsif FPGA_ZCU102
    inout logic clk_125mhz_n,
    inout logic clk_125mhz_p,
`elsif FPGA_AUP_ZU3
    inout logic clk_100mhz_n,
    inout logic clk_100mhz_p,
`elsif FPGA_GENESYS2
    inout logic clk_200mhz_n,
    inout logic clk_200mhz_p,
`else
    inout logic clk_i,
`endif
    inout logic rst_i,

    output logic rst_led_o,
    output logic clk_led_o,

    inout logic boot_select_i,
    inout logic execute_from_flash_i,

    inout logic jtag_tck_i,
    inout logic jtag_tms_i,
    inout logic jtag_trst_ni,
    inout logic jtag_tdi_i,
    inout logic jtag_tdo_o,

    inout logic uart_rx_i,
    inout logic uart_tx_o,

    inout logic [13:0] gpio_io,

    output logic exit_value_o,
    inout  logic exit_valid_o,

    inout logic [3:0] spi_flash_sd_io,
    inout logic spi_flash_csb_o,
    inout logic spi_flash_sck_o,

    inout logic [3:0] spi_sd_io,
    inout logic spi_csb_o,
    inout logic spi_sck_o,

    inout logic spi_slave_sck_io,
    inout logic spi_slave_cs_io,
    inout logic spi_slave_mosi_io,
    inout logic spi_slave_miso_io,

    inout logic [3:0] spi2_sd_io,
    inout logic [1:0] spi2_csb_o,
    inout logic spi2_sck_o,

    inout logic i2c_scl_io,
    inout logic i2c_sda_io,

    inout logic pdm2pcm_clk_io,
    inout logic pdm2pcm_pdm_io,

    inout logic i2s_sck_io,
    inout logic i2s_ws_io,
    inout logic i2s_sd_io

);

  wire                               clk_gen;
  logic [                      31:0] exit_value;
  wire                               rst_n;
  logic [CLK_LED_COUNT_LENGTH - 1:0] clk_count;

  // low active reset
`ifdef FPGA_NEXYS
  assign rst_n = rst_i;
`elsif FPGA_GENESYS2
  assign rst_n = rst_i;
`else
  assign rst_n = !rst_i;
`endif

  // reset LED for debugging
  assign rst_led_o = rst_n;

  // counter to blink an LED
  assign clk_led_o = clk_count[CLK_LED_COUNT_LENGTH-1];

  always_ff @(posedge clk_gen or negedge rst_n) begin : clk_count_process
    if (!rst_n) begin
      clk_count <= '0;
    end else begin
      clk_count <= clk_count + 1;
    end
  end

  // eXtension Interface
  if_xif #() ext_if ();

`ifdef FPGA_ZCU104
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_300mhz_n),
      .CLK_IN1_D_0_clk_p(clk_300mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_ZCU102
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_125mhz_n),
      .CLK_IN1_D_0_clk_p(clk_125mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_AUP_ZU3
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_100mhz_n),
      .CLK_IN1_D_0_clk_p(clk_100mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_GENESYS2
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .CLK_IN1_D_0_clk_n(clk_200mhz_n),
      .CLK_IN1_D_0_clk_p(clk_200mhz_p),
      .clk_out1_0(clk_gen)
  );
`elsif FPGA_NEXYS
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .clk_100MHz(clk_i),
      .clk_out1_0(clk_gen)
  );
`else  // FPGA PYNQ-Z2
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .clk_125MHz(clk_i),
      .clk_out1_0(clk_gen)
  );
`endif

  x_heep_system x_heep_system_i (
      .hart_id_i('0),
      .xheep_instance_id_i('0),
      .intr_vector_ext_i('0),
      .xif_compressed_if(ext_if),
      .xif_issue_if(ext_if),
      .xif_commit_if(ext_if),
      .xif_mem_if(ext_if),
      .xif_mem_result_if(ext_if),
      .xif_result_if(ext_if),
      .ext_xbar_master_req_i('0),
      .ext_xbar_master_resp_o(),
      .ext_core_instr_req_o(),
      .ext_core_instr_resp_i('0),
      .ext_core_data_req_o(),
      .ext_core_data_resp_i('0),
      .ext_debug_master_req_o(),
      .ext_debug_master_resp_i('0),
      .ext_dma_read_req_o(),
      .ext_dma_read_resp_i('0),
      .ext_dma_write_req_o(),
      .ext_dma_write_resp_i('0),
      .ext_dma_addr_req_o(),
      .ext_dma_addr_resp_i('0),
      .ext_peripheral_slave_req_o(),
      .ext_peripheral_slave_resp_i('0),
      .ext_ao_peripheral_req_i('0),
      .ext_ao_peripheral_resp_o(),
      .cpu_subsystem_powergate_switch_no(),
      .cpu_subsystem_powergate_switch_ack_ni('0),
      .peripheral_subsystem_powergate_switch_no(),
      .peripheral_subsystem_powergate_switch_ack_ni('0),
      .external_subsystem_powergate_switch_no(),
      .external_subsystem_powergate_switch_ack_ni('0),
      .external_subsystem_powergate_iso_no(),
      .external_subsystem_rst_no(),
      .external_ram_banks_set_retentive_no(),
      .external_subsystem_clkgate_en_no(),
      .exit_value_o(exit_value),
      .clk_i(clk_gen),
      .rst_ni(rst_n),
      .boot_select_i(boot_select_i),
      .execute_from_flash_i(execute_from_flash_i),
      .jtag_tck_i(jtag_tck_i),
      .jtag_tms_i(jtag_tms_i),
      .jtag_trst_ni(jtag_trst_ni),
      .jtag_tdi_i(jtag_tdi_i),
      .jtag_tdo_o(jtag_tdo_o),
      .uart_rx_i(uart_rx_i),
      .uart_tx_o(uart_tx_o),
      .exit_valid_o(exit_valid_o),
      .gpio_0_io(gpio_io[0]),
      .gpio_1_io(gpio_io[1]),
      .gpio_2_io(gpio_io[2]),
      .gpio_3_io(gpio_io[3]),
      .gpio_4_io(gpio_io[4]),
      .gpio_5_io(gpio_io[5]),
      .gpio_6_io(gpio_io[6]),
      .gpio_7_io(gpio_io[7]),
      .gpio_8_io(gpio_io[8]),
      .gpio_9_io(gpio_io[9]),
      .gpio_10_io(gpio_io[10]),
      .gpio_11_io(gpio_io[11]),
      .gpio_12_io(gpio_io[12]),
      .gpio_13_io(gpio_io[13]),
      .spi_slave_sck_io(spi_slave_sck_io),
      .spi_slave_cs_io(spi_slave_cs_io),
      .spi_slave_miso_io(spi_slave_miso_io),
      .spi_slave_mosi_io(spi_slave_mosi_io),
      .spi_flash_sd_0_io(spi_flash_sd_io[0]),
      .spi_flash_sd_1_io(spi_flash_sd_io[1]),
      .spi_flash_sd_2_io(spi_flash_sd_io[2]),
      .spi_flash_sd_3_io(spi_flash_sd_io[3]),
      .spi_flash_cs_0_io(spi_flash_csb_o),
      .spi_flash_cs_1_io(),
      .spi_flash_sck_io(spi_flash_sck_o),
      .spi_sd_0_io(spi_sd_io[0]),
      .spi_sd_1_io(spi_sd_io[1]),
      .spi_sd_2_io(spi_sd_io[2]),
      .spi_sd_3_io(spi_sd_io[3]),
      .spi_cs_0_io(spi_csb_o),
      .spi_cs_1_io(),
      .spi_sck_io(spi_sck_o),
      .i2c_scl_io,
      .i2c_sda_io,
      .spi2_sd_0_io(spi2_sd_io[0]),
      .spi2_sd_1_io(spi2_sd_io[1]),
      .spi2_sd_2_io(spi2_sd_io[2]),
      .spi2_sd_3_io(spi2_sd_io[3]),
      .spi2_cs_0_io(spi2_csb_o[0]),
      .spi2_cs_1_io(spi2_csb_o[1]),
      .spi2_sck_io(spi2_sck_o),
      .pdm2pcm_clk_io,
      .pdm2pcm_pdm_io,
      .i2s_sck_io(i2s_sck_io),
      .i2s_ws_io(i2s_ws_io),
      .i2s_sd_io(i2s_sd_io),
      .ext_dma_slot_tx_i('0),
      .ext_dma_slot_rx_i('0),
      .ext_dma_stop_i('0),
      .intr_ext_peripheral_i('0),
      .hw_fifo_done_i('0),
      .dma_done_o()
  );

  assign exit_value_o = exit_value[0];


endmodule
