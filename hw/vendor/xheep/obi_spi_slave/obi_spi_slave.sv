// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module obi_spi_slave #(

    parameter OBI_ADDR_WIDTH = 32,
    parameter OBI_DATA_WIDTH = 32
) (
    //input  logic test_mode,
    input  logic spi_sclk_i,
    input  logic spi_cs_i,
    input  logic spi_mosi_i,
    output logic spi_miso_o,

    // OBI MASTER
    //***************************************
    input logic obi_clk_i,
    input logic obi_rstn_i,

    // ADDRESS CHANNEL
    output logic                      obi_master_req_o,
    input  logic                      obi_master_gnt_i,
    output logic [OBI_ADDR_WIDTH-1:0] obi_master_addr_o,
    output logic                      obi_master_we_o,
    output logic [OBI_DATA_WIDTH-1:0] obi_master_w_data_o,
    output logic [               3:0] obi_master_be_o,

    // RESPONSE CHANNEL
    input logic obi_master_r_valid_i,
    input logic [OBI_DATA_WIDTH-1:0] obi_master_r_data_i
);

  localparam DUMMY_CYCLES = 32;

  logic [               7:0] rx_counter;
  logic                      rx_counter_upd;
  logic [              31:0] rx_data;
  logic                      rx_data_valid;

  logic [               7:0] tx_counter;
  logic                      tx_counter_upd;
  logic [              31:0] tx_data;
  logic                      tx_data_valid;

  logic                      ctrl_rd_wr;

  logic [              31:0] ctrl_addr;
  logic                      ctrl_addr_valid;

  logic [              31:0] ctrl_data_rx;
  logic                      ctrl_data_rx_valid;
  logic [              31:0] ctrl_data_tx;
  logic                      ctrl_data_tx_ready;

  logic [              31:0] fifo_data_rx;
  logic                      fifo_data_rx_valid;
  logic                      fifo_data_rx_ready;
  logic [              31:0] fifo_data_tx;
  logic                      fifo_data_tx_valid;
  logic                      fifo_data_tx_ready;

  logic [OBI_ADDR_WIDTH-1:0] addr_sync;
  logic                      addr_valid_sync;
  logic                      cs_sync;

  logic                      tx_done;
  logic                      rd_wr_sync;

  logic [              15:0] wrap_length;
  logic                      test_mode;

  spi_slave_rx u_rxreg (
      .sclk          (spi_sclk_i),
      .cs            (spi_cs_i),
      .mosi          (spi_mosi_i),
      .counter_in    (rx_counter),
      .counter_in_upd(rx_counter_upd),
      .data          (rx_data),
      .data_ready    (rx_data_valid)
  );

  spi_slave_tx u_txreg (
      .test_mode     (test_mode),
      .sclk          (spi_sclk_i),
      .cs            (spi_cs_i),
      .miso          (spi_miso_o),
      .counter_in    (tx_counter),
      .counter_in_upd(tx_counter_upd),
      .data          (tx_data),
      .data_valid    (tx_data_valid),
      .done          (tx_done)
  );

  spi_slave_controller #(
    .DUMMY_CYCLES(DUMMY_CYCLES)
  ) u_slave_sm (
      .sclk              (spi_sclk_i),
      .sys_rstn          (obi_rstn_i),
      .cs                (spi_cs_i),
      .rx_counter        (rx_counter),
      .rx_counter_upd    (rx_counter_upd),
      .rx_data           (rx_data),
      .rx_data_valid     (rx_data_valid),
      .tx_counter        (tx_counter),
      .tx_counter_upd    (tx_counter_upd),
      .tx_data           (tx_data),
      .tx_data_valid     (tx_data_valid),
      .tx_done           (tx_done),
      .ctrl_rd_wr        (ctrl_rd_wr),
      .ctrl_addr         (ctrl_addr),
      .ctrl_addr_valid   (ctrl_addr_valid),
      .ctrl_data_rx      (ctrl_data_rx),
      .ctrl_data_rx_valid(ctrl_data_rx_valid),
      .ctrl_data_tx      (ctrl_data_tx),
      .ctrl_data_tx_ready(ctrl_data_tx_ready),
      .wrap_length       (wrap_length)
  );

  spi_slave_dc_fifo #(
      .DATA_WIDTH  (32)
  ) u_dcfifo_rx (
      .clk_a  (spi_sclk_i),
      .rstn_a (obi_rstn_i),
      .data_a (ctrl_data_rx),
      .valid_a(ctrl_data_rx_valid),
      .ready_a(),
      .clk_b  (obi_clk_i),
      .rstn_b (obi_rstn_i),
      .data_b (fifo_data_rx),
      .valid_b(fifo_data_rx_valid),
      .ready_b(fifo_data_rx_ready)
  );

  spi_slave_dc_fifo #(
      .DATA_WIDTH  (32)
  ) u_dcfifo_tx (
      .clk_a  (obi_clk_i),
      .rstn_a (obi_rstn_i),
      .data_a (fifo_data_tx),
      .valid_a(fifo_data_tx_valid),
      .ready_a(fifo_data_tx_ready),
      .clk_b  (spi_sclk_i),
      .rstn_b (obi_rstn_i),
      .data_b (ctrl_data_tx),
      .valid_b(),
      .ready_b(ctrl_data_tx_ready)
  );

  spi_slave_obi_plug #(
      .OBI_ADDR_WIDTH(OBI_ADDR_WIDTH),
      .OBI_DATA_WIDTH(OBI_DATA_WIDTH)
  ) u_obiplug (
      .obi_aclk          (obi_clk_i),
      .obi_aresetn       (obi_rstn_i),
      .obi_master_req    (obi_master_req_o),
      .obi_master_gnt    (obi_master_gnt_i),
      .obi_master_addr   (obi_master_addr_o),
      .obi_master_we     (obi_master_we_o),
      .obi_master_w_data (obi_master_w_data_o),
      .obi_master_be     (obi_master_be_o),
      .obi_master_r_valid(obi_master_r_valid_i),
      .obi_master_r_data (obi_master_r_data_i),
      .rxtx_addr         (addr_sync),
      .rxtx_addr_valid   (addr_valid_sync),
      .start_tx          (rd_wr_sync & addr_valid_sync),
      .cs                (cs_sync),
      .tx_data           (fifo_data_tx),
      .tx_valid          (fifo_data_tx_valid),
      .tx_ready          (fifo_data_tx_ready),
      .rx_data           (fifo_data_rx),
      .rx_valid          (fifo_data_rx_valid),
      .rx_ready          (fifo_data_rx_ready),
      .wrap_length       (wrap_length)
  );

  spi_slave_syncro #(
      .AXI_ADDR_WIDTH(OBI_ADDR_WIDTH)
  ) u_syncro (
      .sys_clk           (obi_clk_i),
      .rstn              (obi_rstn_i),
      .cs                (spi_cs_i),
      .address           (ctrl_addr),
      .address_valid     (ctrl_addr_valid),
      .rd_wr             (ctrl_rd_wr),
      .cs_sync           (cs_sync),
      .address_sync      (addr_sync),
      .address_valid_sync(addr_valid_sync),
      .rd_wr_sync        (rd_wr_sync)
  );

  assign test_mode = 1'b0;
endmodule
