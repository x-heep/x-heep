// xheep_wrapper.v
`include "cf_math_pkg_xheep.sv"
`include "obi_pkg.sv"
`include "esp_apb_pkg.sv"
`include "axi_pkg.sv"

module XHEEP_wrapper
#(
  parameter AXI_ADDR_WIDTH = 32, // match SoC (32 or 64 per CPU tile)
  parameter AXI_DATA_WIDTH = 32, // 64 for Ariane, 32 for Ibex
  parameter AXI_ID_WIDTH   = 4
)(
  // === Clocks / resets ===
  input  wire                     x_heep_clk,
  input  wire                     x_heep_rstn, // active-low
  input  wire                     direct_reset,   // active-low

  // ============ APB SLAVE (config/MMIO) ============
  input  wire [31:0]              paddr,
  input  wire                     psel,
  input  wire                     penable,
  input  wire                     pwrite,
  input  wire [31:0]              pwdata,
  output wire [31:0]              prdata,
  output wire                     pready,
  output wire                     pslverr,

  // ============ AXI4 MASTER ============
  output wire                     x_heep_axi_awvalid,
  input  wire                     x_heep_axi_awready,
  output wire [AXI_ID_WIDTH-1:0]  x_heep_axi_awid,
  output wire [7:0]               x_heep_axi_awlen,
  output wire [AXI_ADDR_WIDTH-1:0]x_heep_axi_awaddr,

  output wire                     x_heep_axi_wvalid,
  input  wire                     x_heep_axi_wready,
  output wire [AXI_DATA_WIDTH-1:0]x_heep_axi_wdata,
  output wire [(AXI_DATA_WIDTH/8)-1:0] x_heep_axi_wstrb,
  output wire                     x_heep_axi_wlast,

  output wire                     x_heep_axi_arvalid,
  input  wire                     x_heep_axi_arready,
  output wire [AXI_ID_WIDTH-1:0]  x_heep_axi_arid,
  output wire [7:0]               x_heep_axi_arlen,
  output wire [AXI_ADDR_WIDTH-1:0]x_heep_axi_araddr,

  input  wire [1:0]               x_heep_axi_bresp,
  input  wire                     x_heep_axi_bvalid,
  output wire                     x_heep_axi_bready,
  input  wire [AXI_ID_WIDTH-1:0]  x_heep_axi_bid,

  input  wire                     x_heep_axi_rvalid,
  output wire                     x_heep_axi_rready,
  input  wire [AXI_ID_WIDTH-1:0]  x_heep_axi_rid,
  input  wire                     x_heep_axi_rlast,
  input  wire [AXI_DATA_WIDTH-1:0]x_heep_axi_rdata,
  input  wire [1:0]               x_heep_axi_rresp,

  // === AXI sideband ===
  output wire [2:0]               x_heep_axi_awsize,
  output wire [2:0]               x_heep_axi_arsize,
  output wire [1:0]               x_heep_axi_awburst,
  output wire [1:0]               x_heep_axi_arburst,
  output wire                     x_heep_axi_awlock,
  output wire                     x_heep_axi_arlock,
  output wire [3:0]               x_heep_axi_awcache,
  output wire [3:0]               x_heep_axi_arcache,
  output wire [2:0]               x_heep_axi_awprot,
  output wire [2:0]               x_heep_axi_arprot,
  output wire [3:0]               x_heep_axi_awqos,
  output wire [3:0]               x_heep_axi_arqos,
  output wire [3:0]               x_heep_axi_awregion,
  output wire [3:0]               x_heep_axi_arregion,
  output wire [5:0]               x_heep_axi_awatop, // present in NVDLA; safe to tie off

  // ============ IRQ up to ESP ============
  output wire                     x_heep_intr
);

  localparam logic [31:0] XHEEP_INSTANCE_ID = 32'd0;

  localparam logic [31:0] EXT_SLAVE_START_ADDRESS = 32'hF000_0000; // from generated core_v_mini_mcu.h
  localparam logic [31:0] SOC_CTRL_START_ADDRESS = 32'h2000_0000; // from generated core_v_mini_mcu.h
  localparam logic [31:0] ESP_MEMORY_ADDRESS   = 32'h8000_0000; // from generated ESP's riscv.dts
  localparam int LSB = $clog2(AXI_DATA_WIDTH/8);
  localparam logic [31:0] XHEEP_SOC_CTRL_WRITE_OFFSET = 32'h0000_FF00; // fixed and hardcoded. It must fit in the area ESP allocates to X-HEEP.

  // Minimal sideband defaults; main sidebands driven by OBI->AXI bridge below
  assign x_heep_axi_awqos    = 4'b0000;
  assign x_heep_axi_arqos    = 4'b0000;
  assign x_heep_axi_awregion = 4'b0000;
  assign x_heep_axi_arregion = 4'b0000;

  // Active-high reset for X-HEEP/bridge
  wire rst_ni = x_heep_rstn & direct_reset;
  wire clk_i  = x_heep_clk;  // single domain for bridge + X-HEEP

  import esp_apb_pkg::*;
  esp_apb_pkg::apb_req_t apb_req;
  esp_apb_pkg::apb_rsp_t apb_rsp;

  // Intermediate APB request with translated address
  esp_apb_pkg::apb_req_t apb_req_translated;

  // Address translation logic for SoC control and power manager
  always_comb begin
    // Copy all fields from input
    apb_req_translated = apb_req;
    
    // ESP routing uses bits [31:20], we only care about the offset
    apb_req_translated.paddr = {12'h000, apb_req.paddr[19:0]};
    
    // Translate address based on target region
    if (apb_req_translated.paddr >= XHEEP_SOC_CTRL_WRITE_OFFSET) begin
      // Access to configuration registers - map to X-HEEP's SoC control space
      apb_req_translated.paddr = apb_req_translated.paddr + (SOC_CTRL_START_ADDRESS - XHEEP_SOC_CTRL_WRITE_OFFSET);
    end
    // else: normal access to X-Heep RAM at offset within [19:0]
  end

  assign apb_req.paddr   = paddr;
  assign apb_req.psel    = psel;
  assign apb_req.penable = penable;
  assign apb_req.pwrite  = pwrite;
  assign apb_req.pprot   = 3'b010;   // non-privileged, data, secure
  assign apb_req.pwdata  = pwdata;
  assign apb_req.pstrb   = 4'hF;     // full-word writes

  assign prdata  = apb_rsp.prdata;
  assign pready  = apb_rsp.pready;
  assign pslverr = apb_rsp.pslverr;

  // Flatten struct fields for VCD dumping (QuestaSim doesn't support struct.field syntax)
  logic [31:0] dbg_apb_req_paddr;
  logic        dbg_apb_req_psel;
  logic        dbg_apb_req_penable;
  logic        dbg_apb_req_pwrite;
  logic [31:0] dbg_apb_req_pwdata;
  logic [3:0]  dbg_apb_req_pstrb;
  logic [2:0]  dbg_apb_req_pprot;
  
  logic [31:0] dbg_apb_rsp_prdata;
  logic        dbg_apb_rsp_pready;
  logic        dbg_apb_rsp_pslverr;

  always_comb begin
    dbg_apb_req_paddr   = apb_req.paddr;
    dbg_apb_req_psel    = apb_req.psel;
    dbg_apb_req_penable = apb_req.penable;
    dbg_apb_req_pwrite  = apb_req.pwrite;
    dbg_apb_req_pwdata  = apb_req.pwdata;
    dbg_apb_req_pstrb   = apb_req.pstrb;
    dbg_apb_req_pprot   = apb_req.pprot;
    
    dbg_apb_rsp_prdata  = apb_rsp.prdata;
    dbg_apb_rsp_pready  = apb_rsp.pready;
    dbg_apb_rsp_pslverr = apb_rsp.pslverr;
  end


/*  // ========================================================================
  // DEBUG: Monitor APB writes to X-HEEP
  // ========================================================================
  always @(posedge clk_i) begin
    if (apb_req.psel && apb_req.penable && apb_req.pwrite) begin
      $display("[XHEEP_WRAPPER APB] x_heep_rstn=%d direct_reset=%d  WRITE addr=0x%08x data=0x%08x", 
               x_heep_rstn, direct_reset, apb_req.paddr, apb_req.pwdata);
    end
    if (apb_req.psel && apb_req.penable && !apb_req.pwrite && apb_rsp.pready) begin
      $display("[XHEEP_WRAPPER APB] x_heep_rstn=%d direct_reset=%d READ  addr=0x%08x data=0x%08x", 
               x_heep_rstn, direct_reset, apb_req.paddr, apb_rsp.prdata);
    end
  end*/

  import obi_pkg::*;
  obi_pkg::obi_req_t  [0:0] esp_obi_m_req;
  obi_pkg::obi_resp_t  [0:0] esp_obi_m_rsp;

  // -------- APB -> OBI bridge --------
  apb_to_obi #(
    .ObiCfg   (obi_pkg::ObiDefaultConfig),
    .apb_req_t(esp_apb_pkg::apb_req_t),
    .apb_rsp_t(esp_apb_pkg::apb_rsp_t),
    .obi_req_t(obi_pkg::obi_req_t),
    .obi_rsp_t(obi_pkg::obi_resp_t)
  ) u_apb2obi (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .apb_req_i (apb_req_translated),  // Use translated address
    .apb_rsp_o (apb_rsp),
    .obi_req_o (esp_obi_m_req[0]),
    .obi_rsp_i(esp_obi_m_rsp[0])
  );

  // Debug signals for APB->OBI (esp_obi_m)
  logic [31:0] dbg_obi_m_req_addr;
  logic        dbg_obi_m_req_req;
  logic [31:0] dbg_obi_m_req_wdata;
  logic        dbg_obi_m_req_we;
  logic [3:0]  dbg_obi_m_req_be;
  logic [31:0] dbg_obi_m_resp_rdata;
  logic        dbg_obi_m_resp_rvalid;
  logic        dbg_obi_m_resp_gnt;
  always_comb begin
    dbg_obi_m_req_req = esp_obi_m_req[0].req;
    dbg_obi_m_req_addr = esp_obi_m_req[0].addr;
    dbg_obi_m_req_wdata = esp_obi_m_req[0].wdata;
    dbg_obi_m_req_we = esp_obi_m_req[0].we;
    dbg_obi_m_req_be = esp_obi_m_req[0].be;
    dbg_obi_m_resp_rdata = esp_obi_m_rsp[0].rdata;
    dbg_obi_m_resp_rvalid = esp_obi_m_rsp[0].rvalid;
    dbg_obi_m_resp_gnt = esp_obi_m_rsp[0].gnt;
  end

  // Debug signals for core_data OBI (heep_core_data)
  logic        dbg_core_data_req_req;
  logic        dbg_core_data_req_we;
  logic [3:0]  dbg_core_data_req_be;
  logic [31:0] dbg_core_data_req_addr;
  logic [31:0] dbg_core_data_req_wdata;
  logic        dbg_core_data_resp_gnt;
  logic        dbg_core_data_resp_rvalid;
  logic [31:0] dbg_core_data_resp_rdata;
  always_comb begin
    dbg_core_data_req_req = heep_core_data_req.req;
    dbg_core_data_req_we = heep_core_data_req.we;
    dbg_core_data_req_be = heep_core_data_req.be;
    dbg_core_data_req_addr = heep_core_data_req.addr;
    dbg_core_data_req_wdata = heep_core_data_req.wdata;
    dbg_core_data_resp_gnt = heep_core_data_resp.gnt;
    dbg_core_data_resp_rvalid = heep_core_data_resp.rvalid;
    dbg_core_data_resp_rdata = heep_core_data_resp.rdata;
  end

  // Debug signals for core_instr OBI (heep_core_instr)
  logic        dbg_core_instr_req_req;
  logic        dbg_core_instr_req_we;
  logic [3:0]  dbg_core_instr_req_be;
  logic [31:0] dbg_core_instr_req_addr;
  logic [31:0] dbg_core_instr_req_wdata;
  logic        dbg_core_instr_resp_gnt;
  logic        dbg_core_instr_resp_rvalid;
  logic [31:0] dbg_core_instr_resp_rdata;
  always_comb begin
    dbg_core_instr_req_req = heep_core_instr_req.req;
    dbg_core_instr_req_we = heep_core_instr_req.we;
    dbg_core_instr_req_be = heep_core_instr_req.be;
    dbg_core_instr_req_addr = heep_core_instr_req.addr;
    dbg_core_instr_req_wdata = heep_core_instr_req.wdata;
    dbg_core_instr_resp_gnt = heep_core_instr_resp.gnt;
    dbg_core_instr_resp_rvalid = heep_core_instr_resp.rvalid;
    dbg_core_instr_resp_rdata = heep_core_instr_resp.rdata;
  end

  // Debug signals for debug_master OBI (heep_debug_master)
  logic        dbg_debug_master_req_req;
  logic        dbg_debug_master_req_we;
  logic [3:0]  dbg_debug_master_req_be;
  logic [31:0] dbg_debug_master_req_addr;
  logic [31:0] dbg_debug_master_req_wdata;
  logic        dbg_debug_master_resp_gnt;
  logic        dbg_debug_master_resp_rvalid;
  logic [31:0] dbg_debug_master_resp_rdata;
  always_comb begin
    dbg_debug_master_req_req = heep_debug_master_req.req;
    dbg_debug_master_req_we = heep_debug_master_req.we;
    dbg_debug_master_req_be = heep_debug_master_req.be;
    dbg_debug_master_req_addr = heep_debug_master_req.addr;
    dbg_debug_master_req_wdata = heep_debug_master_req.wdata;
    dbg_debug_master_resp_gnt = heep_debug_master_resp.gnt;
    dbg_debug_master_resp_rvalid = heep_debug_master_resp.rvalid;
    dbg_debug_master_resp_rdata = heep_debug_master_resp.rdata;
  end

  // Debug signals for ext_peripheral_slave OBI (heep_ext_peripheral_slave)
  logic        dbg_ext_periph_req_req;
  logic        dbg_ext_periph_req_we;
  logic [3:0]  dbg_ext_periph_req_be;
  logic [31:0] dbg_ext_periph_req_addr;
  logic [31:0] dbg_ext_periph_req_wdata;
  logic        dbg_ext_periph_resp_gnt;
  logic        dbg_ext_periph_resp_rvalid;
  logic [31:0] dbg_ext_periph_resp_rdata;
  always_comb begin
    dbg_ext_periph_req_req = heep_ext_peripheral_slave_req.req;
    dbg_ext_periph_req_we = heep_ext_peripheral_slave_req.we;
    dbg_ext_periph_req_be = heep_ext_peripheral_slave_req.be;
    dbg_ext_periph_req_addr = heep_ext_peripheral_slave_req.addr;
    dbg_ext_periph_req_wdata = heep_ext_peripheral_slave_req.wdata;
    dbg_ext_periph_resp_gnt = heep_ext_peripheral_slave_resp.gnt;
    dbg_ext_periph_resp_rvalid = heep_ext_peripheral_slave_resp.rvalid;
    dbg_ext_periph_resp_rdata = heep_ext_peripheral_slave_resp.rdata;
  end

// -------- X-HEEP top --------

  // Tie-off interfaces for XIF
  // Create separate interface instances for each XIF port to avoid multi-driven nets
  if_xif xif_compressed_if();
  if_xif xif_issue_if();
  if_xif xif_commit_if();
  if_xif xif_mem_if();
  if_xif xif_mem_result_if();
  if_xif xif_result_if();
  assign xif_compressed_if.compressed_ready = 1'b0;
  assign xif_compressed_if.compressed_resp  = '0;
  assign xif_issue_if.issue_ready = 1'b0;
  assign xif_issue_if.issue_resp  = '0;
  assign xif_mem_if.mem_ready = 1'b0;
  assign xif_mem_if.mem_resp  = '0;
  assign xif_mem_result_if.mem_result_valid = 1'b0;
  assign xif_mem_result_if.mem_result       = '0;
  assign xif_result_if.result_ready = 1'b0;

  // Sink for unused outputs to avoid floating ports
  logic unused_jtag_tdo;
  logic unused_uart_tx;
  logic unused_dma_done;

  // External OBI ports from X-HEEP (we will bridge core data to AXI)
  obi_pkg::obi_req_t  heep_core_instr_req;
  obi_pkg::obi_resp_t heep_core_instr_resp;
  obi_pkg::obi_req_t  heep_core_data_req;
  obi_pkg::obi_resp_t heep_core_data_resp;
  obi_pkg::obi_req_t  heep_debug_master_req;
  obi_pkg::obi_resp_t heep_debug_master_resp;
  obi_pkg::obi_req_t  [1:0] heep_dma_read_req;
  obi_pkg::obi_resp_t [1:0] heep_dma_read_resp;
  obi_pkg::obi_req_t  [1:0] heep_dma_write_req;
  obi_pkg::obi_resp_t [1:0] heep_dma_write_resp;
  obi_pkg::obi_req_t  [1:0] heep_dma_addr_req;
  obi_pkg::obi_resp_t [1:0] heep_dma_addr_resp;
  obi_pkg::obi_req_t  heep_ext_peripheral_slave_req;
  obi_pkg::obi_resp_t heep_ext_peripheral_slave_resp;
  logic               heep_exit_valid;
  logic               unused_ext_debug_req;

  core_v_mini_mcu #(
    .EXT_XBAR_NMASTER (1)
  ) u_xheep (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),

    .ext_xbar_master_req_i  (esp_obi_m_req),
    .ext_xbar_master_resp_o (esp_obi_m_rsp),

    .ext_ao_peripheral_slave_req_i ('0),
    .ext_ao_peripheral_slave_resp_o(),

    // External master OBI ports (exposed out of X-HEEP)
    .ext_core_instr_req_o         (heep_core_instr_req),
    .ext_core_instr_resp_i        (heep_core_instr_resp),
    .ext_core_data_req_o          (heep_core_data_req),
    .ext_core_data_resp_i         (heep_core_data_resp),
    .ext_debug_master_req_o       (heep_debug_master_req),
    .ext_debug_master_resp_i      (heep_debug_master_resp),
    .ext_dma_read_req_o           (heep_dma_read_req),
    .ext_dma_read_resp_i          (heep_dma_read_resp),
    .ext_dma_write_req_o          (heep_dma_write_req),
    .ext_dma_write_resp_i         (heep_dma_write_resp),
    .ext_dma_addr_req_o           (heep_dma_addr_req),
    .ext_dma_addr_resp_i          (heep_dma_addr_resp),
    .ext_peripheral_slave_req_o   (heep_ext_peripheral_slave_req),
    .ext_peripheral_slave_resp_i  (heep_ext_peripheral_slave_resp),
    .ext_debug_req_o              (unused_ext_debug_req),

      // JTAG / UART / exit
    .jtag_tdo_o                   (unused_jtag_tdo),
    .uart_tx_o                    (unused_uart_tx),
    .exit_valid_o                 (heep_exit_valid),

    // DMA ports (unused in this ESP integration)
    .ext_dma_slot_tx_i            (1'b0),
    .ext_dma_slot_rx_i            (1'b0),
    .dma_done_o                   (unused_dma_done),

    .boot_select_i                        (1'b0),
    .execute_from_flash_i                 (1'b0),
    .jtag_tck_i                           (1'b0),
    .jtag_tms_i                           (1'b1),
    .jtag_trst_ni                         (rst_ni),
    .jtag_tdi_i                           (1'b0),
    .uart_rx_i                            (1'b1),
    .intr_vector_ext_i                    ('0),
    .intr_ext_peripheral_i                (1'b0),
    .cpu_subsystem_powergate_switch_ack_ni        (1'b1),
    .peripheral_subsystem_powergate_switch_ack_ni (1'b1),
    .external_subsystem_powergate_switch_ack_ni   (1'b1),
  
    .xif_compressed_if (xif_compressed_if),
    .xif_issue_if      (xif_issue_if),
    .xif_commit_if     (xif_commit_if),
    .xif_mem_if        (xif_mem_if),
    .xif_mem_result_if (xif_mem_result_if),
    .xif_result_if     (xif_result_if),

    .xheep_instance_id_i(XHEEP_INSTANCE_ID)

  );

  // Export simple interrupt derived from X-HEEP exit event
  assign x_heep_intr = heep_exit_valid;

  // ---------------- OBI (manager) to AXI4 (master) bridge ----------------
  // Use the core DATA external OBI master as AXI master source (no arbitration yet)

  // Define AXI types via axi_pkg macros
  import axi_pkg::*;
  typedef logic [AXI_ADDR_WIDTH-1:0] xaxi_addr_t;
  typedef logic [AXI_ID_WIDTH-1:0]   xaxi_id_t;
  typedef logic [AXI_DATA_WIDTH-1:0] xaxi_data_t;
  typedef logic [(AXI_DATA_WIDTH/8)-1:0] xaxi_strb_t;
  typedef logic [0:0]                xaxi_user_t;
  `AXI_TYPEDEF_ALL(xheep_axi, xaxi_addr_t, xaxi_id_t, xaxi_data_t, xaxi_strb_t, xaxi_user_t)

  xheep_axi_req_t  xaxi_req;
  xheep_axi_resp_t xaxi_rsp;

  // Debug signals for AXI request (from OBI->AXI bridge output)
  logic                     dbg_xaxi_req_aw_valid;
  logic [AXI_ADDR_WIDTH-1:0] dbg_xaxi_req_aw_addr;
  logic [2:0]               dbg_xaxi_req_aw_size;
  logic                     dbg_xaxi_req_w_valid;
  logic [AXI_DATA_WIDTH-1:0] dbg_xaxi_req_w_data;
  logic [(AXI_DATA_WIDTH/8)-1:0] dbg_xaxi_req_w_strb;
  logic                     dbg_xaxi_req_w_last;
  logic                     dbg_xaxi_req_ar_valid;
  logic [AXI_ADDR_WIDTH-1:0] dbg_xaxi_req_ar_addr;
  logic [2:0]               dbg_xaxi_req_ar_size;
  logic                     dbg_xaxi_req_b_ready;
  logic                     dbg_xaxi_req_r_ready;
  
  // Debug signals for AXI response (to OBI->AXI bridge)
  logic                     dbg_xaxi_rsp_aw_ready;
  logic                     dbg_xaxi_rsp_w_ready;
  logic                     dbg_xaxi_rsp_ar_ready;
  logic                     dbg_xaxi_rsp_b_valid;
  logic [1:0]               dbg_xaxi_rsp_b_resp;
  logic                     dbg_xaxi_rsp_r_valid;
  logic [AXI_DATA_WIDTH-1:0] dbg_xaxi_rsp_r_data;
  logic [1:0]               dbg_xaxi_rsp_r_resp;
  logic                     dbg_xaxi_rsp_r_last;
  
  always_comb begin
    // AXI request signals
    dbg_xaxi_req_aw_valid = xaxi_req.aw_valid;
    dbg_xaxi_req_aw_addr = xaxi_req.aw.addr;
    dbg_xaxi_req_aw_size = xaxi_req.aw.size;
    dbg_xaxi_req_w_valid = xaxi_req.w_valid;
    dbg_xaxi_req_w_data = xaxi_req.w.data;
    dbg_xaxi_req_w_strb = xaxi_req.w.strb;
    dbg_xaxi_req_w_last = xaxi_req.w.last;
    dbg_xaxi_req_ar_valid = xaxi_req.ar_valid;
    dbg_xaxi_req_ar_addr = xaxi_req.ar.addr;
    dbg_xaxi_req_ar_size = xaxi_req.ar.size;
    dbg_xaxi_req_b_ready = xaxi_req.b_ready;
    dbg_xaxi_req_r_ready = xaxi_req.r_ready;
    
    // AXI response signals
    dbg_xaxi_rsp_aw_ready = xaxi_rsp.aw_ready;
    dbg_xaxi_rsp_w_ready = xaxi_rsp.w_ready;
    dbg_xaxi_rsp_ar_ready = xaxi_rsp.ar_ready;
    dbg_xaxi_rsp_b_valid = xaxi_rsp.b_valid;
    dbg_xaxi_rsp_b_resp = xaxi_rsp.b.resp;
    dbg_xaxi_rsp_r_valid = xaxi_rsp.r_valid;
    dbg_xaxi_rsp_r_data = xaxi_rsp.r.data;
    dbg_xaxi_rsp_r_resp = xaxi_rsp.r.resp;
    dbg_xaxi_rsp_r_last = xaxi_rsp.r.last;
  end

  // Drive AXI wires from request struct
  assign x_heep_axi_awvalid = xaxi_req.aw_valid;
  assign x_heep_axi_awid    = '0;                 // single ID for now
  assign x_heep_axi_awlen   = 8'd0;               // single beat
  // Full address arithmetic: translate from X-HEEP external space to ESP memory space
  assign x_heep_axi_awaddr = xaxi_req.aw.addr - EXT_SLAVE_START_ADDRESS + ESP_MEMORY_ADDRESS;  
  assign x_heep_axi_wvalid  = xaxi_req.w_valid;
  assign x_heep_axi_wdata   = xaxi_req.w.data;
  assign x_heep_axi_wstrb   = xaxi_req.w.strb;
  assign x_heep_axi_wlast   = xaxi_req.w.last;
  assign x_heep_axi_arvalid = xaxi_req.ar_valid;
  assign x_heep_axi_arid    = '0;
  assign x_heep_axi_arlen   = 8'd0;
  // Full address arithmetic: translate from X-HEEP external space to ESP memory space
  assign x_heep_axi_araddr = xaxi_req.ar.addr - EXT_SLAVE_START_ADDRESS + ESP_MEMORY_ADDRESS;  
  assign x_heep_axi_bready  = xaxi_req.b_ready;
  assign x_heep_axi_rready  = xaxi_req.r_ready;
  // Sideband from request
  assign x_heep_axi_awsize  = xaxi_req.aw.size;
  assign x_heep_axi_arsize  = xaxi_req.ar.size;
  assign x_heep_axi_awburst = xaxi_req.aw.burst;
  assign x_heep_axi_arburst = xaxi_req.ar.burst;
  assign x_heep_axi_awlock  = xaxi_req.aw.lock;
  assign x_heep_axi_arlock  = xaxi_req.ar.lock;
  assign x_heep_axi_awcache = xaxi_req.aw.cache;
  assign x_heep_axi_arcache = xaxi_req.ar.cache;
  assign x_heep_axi_awprot  = xaxi_req.aw.prot;
  assign x_heep_axi_arprot  = xaxi_req.ar.prot;
  assign x_heep_axi_awatop  = xaxi_req.aw.atop;

  // Capture AXI responses into struct for bridge
  assign xaxi_rsp.aw_ready = x_heep_axi_awready;
  assign xaxi_rsp.w_ready  = x_heep_axi_wready;
  assign xaxi_rsp.ar_ready = x_heep_axi_arready;
  assign xaxi_rsp.b_valid  = x_heep_axi_bvalid;
  assign xaxi_rsp.b.id     = x_heep_axi_bid;
  assign xaxi_rsp.b.resp   = x_heep_axi_bresp;
  assign xaxi_rsp.b.user   = '0;
  assign xaxi_rsp.r_valid  = x_heep_axi_rvalid;
  assign xaxi_rsp.r.id     = x_heep_axi_rid;
  assign xaxi_rsp.r.data   = x_heep_axi_rdata;
  assign xaxi_rsp.r.resp   = x_heep_axi_rresp;
  assign xaxi_rsp.r.last   = x_heep_axi_rlast;
  assign xaxi_rsp.r.user   = '0;

  // OBI->AXI bridge instance
  logic [1:0] _axi_rsp_channel_sel;
  logic [0:0] _axi_rsp_b_user;
  logic [0:0] _axi_rsp_r_user;

  obi_to_axi #(
    .ObiCfg      (obi_pkg::ObiDefaultConfig),
    .obi_req_t   (obi_pkg::obi_req_t),
    .obi_rsp_t   (obi_pkg::obi_resp_t),
    .AxiLite     (1'b0),
    .AxiAddrWidth(AXI_ADDR_WIDTH),
    .AxiDataWidth(AXI_DATA_WIDTH),
    .AxiBurstType(axi_pkg::BURST_INCR),
    .axi_req_t   (xheep_axi_req_t),
    .axi_rsp_t   (xheep_axi_resp_t),
    .MaxRequests (8)
  ) u_obi2axi_core_data (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .obi_req_i(heep_core_data_req),
    .obi_rsp_o(heep_core_data_resp),
    .axi_req_o(xaxi_req),
    .axi_rsp_i(xaxi_rsp),
    .axi_rsp_channel_sel(_axi_rsp_channel_sel)
  );

  // Tie off other external OBI masters for now
  assign heep_core_instr_resp         = '0;
  assign heep_debug_master_resp       = '0;
  assign heep_dma_read_resp           = '{default:'0};
  assign heep_dma_write_resp          = '{default:'0};
  assign heep_dma_addr_resp           = '{default:'0};
  assign heep_ext_peripheral_slave_resp = '0;

  // --- Wave dump: flattened signals (QuestaSim-compatible) ---
  initial begin

  end

endmodule
