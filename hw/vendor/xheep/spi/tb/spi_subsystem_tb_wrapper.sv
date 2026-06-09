// this wrapper is aimed to test axi_to_flash_controller

`include "axi/typedef.svh"

module spi_subsystem_tb_wrapper 
#(
  localparam int lenDW = 8,
  localparam int sizeDW = 3,
  localparam int burstDW = 2,
  localparam int respDW = 2,
  localparam int DataWidth = 64,
  localparam int DataBytes = DataWidth/8,
	localparam int AddrWidth = 64,
  localparam int ByteOrder = 1,
  localparam int RegDataWidth = 32
)(
  input logic clk_i,
  input logic rst_ni,

  // Flash controller interrupt
  output logic w25q128jw_controller_intr_o,

  // AXI interface AW channel
  input  logic [AddrWidth-1:0]     aw_addr_i,
  input  logic [sizeDW-1:0]        aw_size_i,
  input  logic [lenDW-1:0]         aw_len_i,
  input  logic                     aw_valid_i,
  output logic                     aw_ready_o,

  // AXI interface W channel
  input  logic [DataWidth-1:0]     w_data_i,
  input  logic [DataBytes-1:0]     w_strb_i,
  input  logic                     w_last_i,
  input  logic                     w_valid_i,
  output logic                     w_ready_o,

  // AXI interface B channel
  output logic                     b_valid_o,
  input  logic                     b_ready_i,

  // AXI interface AR channel
  input  logic [AddrWidth-1:0]     ar_addr_i,
  input  logic [sizeDW-1:0]        ar_size_i,
  input  logic [lenDW-1:0]         ar_len_i,
  input  logic                     ar_valid_i,
  output logic                     ar_ready_o,

  // AXI interface R channel
  output logic [DataWidth-1:0]     r_data_o,
  output logic                     r_last_o,
  output logic                     r_valid_o,
  input  logic                     r_ready_i,

  // spi_host register interface
  input  logic                      spihost_reg_valid_i,
  input  logic                      spihost_reg_write_i,
  input  logic [RegDataWidth/8-1:0] spihost_reg_wstrb_i,
  input  logic [AddrWidth-1:0]      spihost_reg_addr_i,
  input  logic [RegDataWidth-1:0]   spihost_reg_wdata_i,
  output logic                      spihost_reg_error_o,
  output logic                      spihost_reg_ready_o,
  output logic [RegDataWidth-1:0]   spihost_reg_rdata_o,

  // spi_subsystem register interface
  input  logic                      subsys_reg_valid_i,
  input  logic                      subsys_reg_write_i,
  input  logic [RegDataWidth/8-1:0] subsys_reg_wstrb_i,
  input  logic [AddrWidth-1:0]      subsys_reg_addr_i,
  input  logic [RegDataWidth-1:0]   subsys_reg_wdata_i,
  output logic                      subsys_reg_error_o,
  output logic                      subsys_reg_ready_o,
  output logic [RegDataWidth-1:0]   subsys_reg_rdata_o,

  // spi_host interrupts
  output logic spi_flash_intr_error_o,
  output logic spi_flash_intr_event_o,

  // SPI controller DMA interface
  output logic spi_flash_rx_valid_o,
  output logic spi_flash_tx_ready_o
);


  // definition of axi_req_t and axi_resp_t
  // reference : vendor/pulp_platform_axi/include/axi/typedef.svh
  import axi_pkg::*;
  typedef logic id_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataBytes-1:0] strb_t;
  typedef logic user_t;
  `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)


  // AXI Interface assignment
  axi_req_t  axi_req; // from host system
  axi_resp_t axi_rsp; // to host system

  always_comb begin
    // aw
    axi_req.aw.addr  = aw_addr_i;
    axi_req.aw.size  = aw_size_i;
    axi_req.aw.len   = aw_len_i;
    axi_req.aw_valid = aw_valid_i;
    aw_ready_o       = axi_rsp.aw_ready;
    // w
    axi_req.w.data   = w_data_i;
    axi_req.w.strb   = w_strb_i;
    axi_req.w.last   = w_last_i;
    axi_req.w_valid  = w_valid_i;
    w_ready_o        = axi_rsp.w_ready;
    // b
    b_valid_o        = axi_rsp.b_valid;
    axi_req.b_ready  = b_ready_i;
    // ar
    axi_req.ar.addr  = ar_addr_i;
    axi_req.ar.size  = ar_size_i;
    axi_req.ar.len   = ar_len_i;
    axi_req.ar_valid = ar_valid_i;
    ar_ready_o       = axi_rsp.ar_ready;
    // r
    r_data_o         = axi_rsp.r.data; 
    r_last_o         = axi_rsp.r.last;  
    r_valid_o        = axi_rsp.r_valid; 
    axi_req.r_ready  = r_ready_i;
  end


  // // REG Interface assignment
  // to spi_host top reg
  import reg_pkg::*;
  reg_pkg::reg_req_t spihost_reg_req; // from host system
  reg_pkg::reg_rsp_t spihost_reg_rsp; // to host system

  always_comb begin
    // req
    spihost_reg_req.valid = spihost_reg_valid_i;
    spihost_reg_req.write = spihost_reg_write_i;
    spihost_reg_req.wstrb = spihost_reg_wstrb_i;
    spihost_reg_req.addr  = spihost_reg_addr_i;
    spihost_reg_req.wdata = spihost_reg_wdata_i;
    // rsp
    spihost_reg_error_o = spihost_reg_rsp.error;
    spihost_reg_ready_o = spihost_reg_rsp.ready;
    spihost_reg_rdata_o = spihost_reg_rsp.rdata;
  end

  // to spi_subsystem top reg
  reg_pkg::reg_req_t subsys_reg_req; // from host system
  reg_pkg::reg_rsp_t subsys_reg_rsp; // to host system

  always_comb begin
    // req
    subsys_reg_req.valid = subsys_reg_valid_i;
    subsys_reg_req.write = subsys_reg_write_i;
    subsys_reg_req.wstrb = subsys_reg_wstrb_i;
    subsys_reg_req.addr  = subsys_reg_addr_i;
    subsys_reg_req.wdata = subsys_reg_wdata_i;
    // rsp
    subsys_reg_error_o = subsys_reg_rsp.error;
    subsys_reg_ready_o = subsys_reg_rsp.ready;
    subsys_reg_rdata_o = subsys_reg_rsp.rdata;
  end


  // SPI wires
  import spi_host_reg_pkg::*;
  logic       spi_flash_sck;
  logic       spi_flash_sck_en;
  logic       spi_flash_sck_gated;
  logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb;
  logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_en;
  logic [spi_host_reg_pkg::NumCS-1:0] spi_flash_csb_gated;
  logic [3:0] spi_flash_sd_mosi;
  logic [3:0] spi_flash_sd_mosi_en;
  logic [3:0] spi_flash_sd_mosi_gated;
  logic [3:0] spi_flash_sd_miso;
  
  always_comb begin
    spi_flash_sck_gated = spi_flash_sck_en ? spi_flash_sck : 1'b0;  // CPOL=0

    for ( int i=0 ; i<spi_host_reg_pkg::NumCS ; i++ ) begin
      spi_flash_csb_gated[i] = spi_flash_csb_en[i] ? spi_flash_csb[i] : 1'b1; // csb is active low
    end

    for ( int i=0 ; i<4 ; i++ ) begin
      spi_flash_sd_mosi_gated[i] = spi_flash_sd_mosi_en[i] ? spi_flash_sd_mosi[i] : 1'b0;
    end
  end


// spi_subsystem
spi_subsystem #(
    .DataWidth                    (DataWidth),
    .AddrWidth                    (AddrWidth),
    .ByteOrder                    (ByteOrder),
    .ClockFrequencyMAX_MHz        (1e3),
    .axi_req_t                    (axi_req_t),
    .axi_resp_t                   (axi_resp_t),
    .reg_req_t                    (reg_pkg::reg_req_t),
    .reg_rsp_t                    (reg_pkg::reg_rsp_t)
) DUT_spi_subsystem (
    .clk_i                        (clk_i), 
    .rst_ni                       (rst_ni), 
    .axi_req_i                    (axi_req),
    .axi_rsp_o                    (axi_rsp),
    .top_reg_req_i                (subsys_reg_req),
    .top_reg_rsp_o                (subsys_reg_rsp),
    .spihost_reg_req_i            (spihost_reg_req),
    .spihost_reg_rsp_o            (spihost_reg_rsp),
    .spi_flash_sck_o              (spi_flash_sck),
    .spi_flash_sck_en_o           (spi_flash_sck_en),
    .spi_flash_csb_o              (spi_flash_csb),
    .spi_flash_csb_en_o           (spi_flash_csb_en),
    .spi_flash_sd_o               (spi_flash_sd_mosi),
    .spi_flash_sd_en_o            (spi_flash_sd_mosi_en),
    .spi_flash_sd_i               (spi_flash_sd_miso),
    .spi_flash_intr_error_o       (spi_flash_intr_error_o),
    .spi_flash_intr_event_o       (spi_flash_intr_event_o),
    .spi_flash_rx_valid_o         (spi_flash_rx_valid_o),
    .spi_flash_tx_ready_o         (spi_flash_tx_ready_o)
   
);

// SPI flash
// (in veriletor only single SPI works)
spiflash u_spiflash (
    .csb    (spi_flash_csb_gated[0]),       // chip select (active low)
    .clk    (spi_flash_sck_gated),          // serial clock
    .io0    (spi_flash_sd_mosi_gated[0]),   // MOSI
    .io1    (spi_flash_sd_miso[1]),         // MISO   (1, not 0)
    .io2    (),
    .io3    ()
);

endmodule
