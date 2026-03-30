// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`define WRITING 1'b1
`define READING 1'b0

module spi_slave_obi_plug #(
    parameter OBI_ADDR_WIDTH = 32,
    parameter OBI_DATA_WIDTH = 32
) (
    // OBI MASTER
    //***************************************
    input logic obi_aclk,
    input logic obi_aresetn,

    // ADDRESS CHANNEL
    output logic                      obi_master_req,
    input  logic                      obi_master_gnt,
    output logic [OBI_ADDR_WIDTH-1:0] obi_master_addr,
    output logic                      obi_master_we,
    output logic [OBI_DATA_WIDTH-1:0] obi_master_w_data,
    output logic [               3:0] obi_master_be,

    // RESPONSE CHANNEL
    input logic obi_master_r_valid,
    input logic [OBI_DATA_WIDTH-1:0] obi_master_r_data,

    //SPI/BUFFER
    input logic [OBI_ADDR_WIDTH-1:0] rxtx_addr,
    input logic rxtx_addr_valid,
    input logic start_tx,
    input logic cs,
    output logic [31:0] tx_data,
    output logic tx_valid,
    input logic tx_ready,
    input logic [31:0] rx_data,
    input logic rx_valid,
    output logic rx_ready,

    input logic [15:0] wrap_length
);

  logic [OBI_ADDR_WIDTH-1:0] curr_addr;
  logic [OBI_ADDR_WIDTH-1:0] next_addr;
  logic [              31:0] curr_data_rx;
  logic [OBI_DATA_WIDTH-1:0] curr_data_tx;
  logic                      sample_fifo;
  logic                      sample_obidata;
  logic                      sample_rxtx_state;
  logic                      rxtx_state;
  logic [               0:0] curr_rxtx_state;  //low for reading, high for writing
  logic                      incr_addr_w;
  logic                      incr_addr_r;



  // up to 64 kwords (256kB)
  logic [              15:0] tx_counter;

  logic [              15:0] wrap_length_t;


  enum logic [1:0] {
    IDLE,
    OBIADDR,
    OBIRESP,
    DATA
  }
      OBI_CS, OBI_NS;

  // Check if the wrap lenght is equal to '0'
  assign wrap_length_t = (wrap_length == 0) ? 16'h1 : wrap_length;


  always_ff @(posedge obi_aclk or negedge obi_aresetn) begin
    if (obi_aresetn == 0) begin
      OBI_CS          <= IDLE;
      curr_data_rx    <= 'h0;
      curr_data_tx    <= 'h0;
      curr_addr       <= 'h0;
      curr_rxtx_state <= 'h0;
    end else begin
      OBI_CS <= OBI_NS;
      if (sample_fifo) curr_data_rx <= rx_data;
      if (sample_obidata) curr_data_tx <= obi_master_r_data;
      if (sample_rxtx_state) curr_rxtx_state <= rxtx_state;
      if (rxtx_addr_valid) curr_addr <= rxtx_addr;
      else if (incr_addr_w | incr_addr_r) curr_addr <= next_addr;
    end
  end

  always_ff @(posedge obi_aclk or negedge obi_aresetn) begin
    if (obi_aresetn == 1'b0) tx_counter <= 16'h0;
    else if (start_tx) tx_counter <= 16'h0;
    else if (incr_addr_w | incr_addr_r) begin
      if (tx_counter == wrap_length_t - 1) tx_counter <= 16'h0;
      else tx_counter <= tx_counter + 16'h1;
    end
  end

  always_comb begin
    next_addr = 32'b0;
    if (rxtx_addr_valid) next_addr = rxtx_addr;
    else if (tx_counter == wrap_length_t - 1) next_addr = rxtx_addr;
    else next_addr = curr_addr + 32'h4;
  end


  always_comb begin
    OBI_NS            = IDLE;
    sample_fifo       = 1'b0;
    rx_ready          = 1'b0;
    tx_valid          = 1'b0;
    obi_master_req    = 1'b0;
    obi_master_we     = 1'b0;
    sample_obidata    = 1'b0;
    sample_rxtx_state = 1'b0;
    rxtx_state        = 1'b0;
    incr_addr_w       = 1'b0;
    incr_addr_r       = 1'b0;
    case (OBI_CS)
      IDLE: begin
        if (rx_valid) begin
          sample_fifo       = 1'b1;
          rx_ready          = 1'b1;
          rxtx_state        = `WRITING;
          sample_rxtx_state = 1'b1;
          OBI_NS            = OBIADDR;
        end else if (start_tx && !cs) begin
          rxtx_state = `READING;
          sample_rxtx_state = 1'b1;
          OBI_NS = OBIADDR;
        end else begin
          OBI_NS = IDLE;
        end
      end
      OBIADDR: begin
        if (curr_rxtx_state == `WRITING) begin
          obi_master_we = 1'b1;
        end

        obi_master_req = 1'b1;

        if (obi_master_gnt && ((tx_ready && (curr_rxtx_state == `READING)) || (curr_rxtx_state == `WRITING))) OBI_NS = OBIRESP;
        else OBI_NS = OBIADDR;
      end
      OBIRESP: begin
        if (obi_master_r_valid) begin
          OBI_NS = IDLE;
          if (curr_rxtx_state == `READING) begin
            sample_obidata = 1'b1;
            OBI_NS = DATA;
          end else incr_addr_w = 1'b1;
        end else OBI_NS = OBIRESP;
      end
      DATA: begin
        tx_valid = 1'b1;
        if (cs) begin
          OBI_NS = IDLE;
        end else begin
          if (tx_ready) begin
            if (tx_counter == wrap_length_t - 1) begin
              OBI_NS = IDLE;
            end else begin
              OBI_NS      = OBIADDR;
            end
            incr_addr_r = 1'b1;
          end else begin
            OBI_NS = DATA;
          end
        end

      end
    endcase
  end

  assign tx_data = curr_data_tx;
  assign obi_master_addr   =  curr_addr;
  assign obi_master_w_data    = curr_data_rx;
  assign obi_master_be = 4'b1111;
endmodule
