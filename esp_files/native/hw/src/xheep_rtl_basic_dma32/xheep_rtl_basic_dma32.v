// xheep_rtl_basic_dma32.v

module xheep_rtl_basic_dma32 (
    clk,
    rst,
    dma_read_chnl_valid,
    dma_read_chnl_data,
    dma_read_chnl_ready,
    conf_info_boot_exit_loop,
    conf_info_boot_fetch_code,
    conf_info_boot_fetch_code_addr,
    conf_info_code_size_words,
    conf_done,
    acc_done,
    debug,
    dma_read_ctrl_valid,
    dma_read_ctrl_data_index,
    dma_read_ctrl_data_length,
    dma_read_ctrl_data_size,
    dma_read_ctrl_data_user,
    dma_read_ctrl_ready,
    dma_write_ctrl_valid,
    dma_write_ctrl_data_index,
    dma_write_ctrl_data_length,
    dma_write_ctrl_data_size,
    dma_write_ctrl_data_user,
    dma_write_ctrl_ready,
    dma_write_chnl_valid,
    dma_write_chnl_data,
    dma_write_chnl_ready
);
    // ========================================================================
    // Parameters & Imports
    // ========================================================================
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;

    // ========================================================================
    // I/O Ports
    // ========================================================================
    input clk;
    input rst;

    // Configuration Interface
    input [31:0]  conf_info_boot_exit_loop;
    input [31:0]  conf_info_boot_fetch_code;
    input [31:0]  conf_info_boot_fetch_code_addr;
    input [31:0]  conf_info_code_size_words;
    input conf_done;

    // DMA Read Control
    input dma_read_ctrl_ready;
    output logic dma_read_ctrl_valid;
    output logic [31:0] dma_read_ctrl_data_index;
    output logic [31:0] dma_read_ctrl_data_length;
    output logic [2:0] dma_read_ctrl_data_size;
    output logic [5:0] dma_read_ctrl_data_user;

    // DMA Read Channel
    output logic dma_read_chnl_ready;
    input dma_read_chnl_valid;
    input [31:0] dma_read_chnl_data;

    // DMA Write Control
    input dma_write_ctrl_ready;
    output logic dma_write_ctrl_valid;
    output logic [31:0] dma_write_ctrl_data_index;
    output logic [31:0] dma_write_ctrl_data_length;
    output logic [2:0] dma_write_ctrl_data_size;
    output logic [5:0] dma_write_ctrl_data_user;

    // DMA Write Channel
    input dma_write_chnl_ready;
    output logic dma_write_chnl_valid;
    output logic [31:0] dma_write_chnl_data;

    // Status / Debug
    output logic acc_done;
    output logic [31:0] debug;

    // ========================================================================
    // Internal Signals
    // ========================================================================

    logic x_heep_rst_n;

    // X-HEEP reset gating
    logic heep_hold_reset = 1'b0;
    assign x_heep_rst_n = rst | heep_hold_reset;

    // X-HEEP OBI Interfaces (Master Port of X-HEEP)
    obi_pkg::obi_req_t  heep_core_data_req;
    obi_pkg::obi_resp_t heep_core_data_resp;
    
    // Boot Controller OBI Interface (Master Port of Controller -> Slave Port of X-HEEP)
    obi_pkg::obi_req_t  boot_obi_req;
    obi_pkg::obi_resp_t boot_obi_resp;

    // X-HEEP Status
    logic heep_exit_valid;

    // Boot Controller Signals
    logic        boot_ctrl_busy;
    logic        boot_ctrl_fetch_done;
    
    // Bridge Signals (from Core)
    logic        bridge_dma_read_ctrl_valid;
    logic [31:0] bridge_dma_read_ctrl_index;
    logic [31:0] bridge_dma_read_ctrl_length;
    logic [2:0]  bridge_dma_read_ctrl_size;
    logic        bridge_dma_read_chnl_ready;

    // Boot Controller DMA Signals
    logic        boot_dma_read_ctrl_valid;
    logic [31:0] boot_dma_read_ctrl_index;
    logic [31:0] boot_dma_read_ctrl_length;
    logic [2:0]  boot_dma_read_ctrl_size;
    logic        boot_dma_read_chnl_ready;
    
    // Tie-offs for XIF
    if_xif xif_compressed_if();
    if_xif xif_issue_if();
    if_xif xif_commit_if();
    if_xif xif_mem_if();
    if_xif xif_mem_result_if();
    if_xif xif_result_if();

    assign xif_compressed_if.compressed_ready = 1'b0;
    assign xif_compressed_if.compressed_resp  = '0;
    assign xif_issue_if.issue_ready           = 1'b0;
    assign xif_issue_if.issue_resp            = '0;
    assign xif_mem_if.mem_ready               = 1'b0;
    assign xif_mem_if.mem_resp                = '0;
    assign xif_mem_result_if.mem_result_valid = 1'b0;
    assign xif_mem_result_if.mem_result       = '0;
    assign xif_result_if.result_ready         = 1'b0;

    // ========================================================================
    // X-HEEP Instance
    // ========================================================================
    core_v_mini_mcu #(
        .EXT_XBAR_NMASTER(1)
    ) u_xheep (
        .clk_i   (clk),
        .rst_ni  (x_heep_rst_n),

        // External Slave Port: Connected to Boot Controller
        .ext_xbar_master_req_i  (boot_obi_req),
        .ext_xbar_master_resp_o (boot_obi_resp),

        .ext_ao_peripheral_slave_req_i ('0),
        .ext_ao_peripheral_slave_resp_o(),

        // External Master Port: Connected to Bridge
        .ext_core_data_req_o          (heep_core_data_req),
        .ext_core_data_resp_i         (heep_core_data_resp),

        // Unused Ports
        .ext_core_instr_req_o         (), .ext_core_instr_resp_i        ('0),
        .ext_debug_master_req_o       (), .ext_debug_master_resp_i      ('0),
        .ext_dma_read_req_o           (), .ext_dma_read_resp_i          ('{default:'0}),
        .ext_dma_write_req_o          (), .ext_dma_write_resp_i         ('{default:'0}),
        .ext_dma_addr_req_o           (), .ext_dma_addr_resp_i          ('{default:'0}),
        .ext_peripheral_slave_req_o   (), .ext_peripheral_slave_resp_i  ('0),
        .ext_debug_req_o              (),
        .jtag_tdo_o                   (),
        .uart_tx_o                    (),
        .exit_valid_o                 (heep_exit_valid),
        .ext_dma_slot_tx_i            (4'b0),
        .ext_dma_slot_rx_i            (4'b0),
        .dma_done_o                   (),
        .boot_select_i                (1'b0), 
        .execute_from_flash_i         (1'b0),
        .jtag_tck_i                   (1'b0),
        .jtag_tms_i                   (1'b1),
        .jtag_trst_ni                 (x_heep_rst_n),
        .jtag_tdi_i                   (1'b0),
        .uart_rx_i                    (1'b1),
        .intr_vector_ext_i            ('0),
        .intr_ext_peripheral_i        (1'b0),
        .cpu_subsystem_powergate_switch_ack_ni        (1'b1),
        .peripheral_subsystem_powergate_switch_ack_ni (1'b1),
        .external_subsystem_powergate_switch_ack_ni   (1'b1),
        .xif_compressed_if(xif_compressed_if),
        .xif_issue_if(xif_issue_if),
        .xif_commit_if(xif_commit_if),
        .xif_mem_if(xif_mem_if),
        .xif_mem_result_if(xif_mem_result_if),
        .xif_result_if(xif_result_if),
        .xheep_instance_id_i(32'd0)
    );

    // ========================================================================
    // Boot Controller
    // ========================================================================
    xheep_boot_controller_dma32 u_boot_ctrl (
        .clk                 (clk),
        .rst_n               (rst),
        
        // Triggers from ESP Config
        .trigger_fetch       (conf_info_boot_fetch_code[0]),
        .fetch_addr_byte     (conf_info_boot_fetch_code_addr),
        .fetch_size_words    (conf_info_code_size_words),
        .trigger_boot_exit   (conf_info_boot_exit_loop[0]),
        .conf_done           (conf_done),
        
        // Boot DMA Read Control (Master)
        .dma_read_ctrl_valid       (boot_dma_read_ctrl_valid),
        .dma_read_ctrl_ready       (dma_read_ctrl_ready && boot_ctrl_busy), 
        .dma_read_ctrl_data_index  (boot_dma_read_ctrl_index),
        .dma_read_ctrl_data_length (boot_dma_read_ctrl_length),
        .dma_read_ctrl_data_size   (boot_dma_read_ctrl_size),
        
        // Boot DMA Read Channel (Slave)
        .dma_read_chnl_valid       (dma_read_chnl_valid && boot_ctrl_busy),
        .dma_read_chnl_ready       (boot_dma_read_chnl_ready),
        .dma_read_chnl_data        (dma_read_chnl_data),
        
        // OBI Master to X-HEEP
        .obi_req_o           (boot_obi_req),
        .obi_resp_i          (boot_obi_resp),
        
        .busy                (boot_ctrl_busy),
        .fetch_done_o        (boot_ctrl_fetch_done)
    );

    // Remember that the firmware fetch has completed once to preserve X-HEEP memory
    always_ff @(posedge clk) begin
        if (boot_ctrl_fetch_done) begin
            heep_hold_reset <= 1'b1;
        end
    end

    // ========================================================================
    // Bridge: OBI (X-HEEP Core) <-> DMA (ESP)
    // ========================================================================
    obi_to_esp_dma32 #(
        .DATA_WIDTH(32)
    ) u_bridge (
        .clk(clk),
        .rst(rst),
        
        // X-HEEP Side
        .obi_req_i(heep_core_data_req),
        .obi_resp_o(heep_core_data_resp),

        // ESP DMA Control Side
        .dma_read_ctrl_ready      (dma_read_ctrl_ready && !boot_ctrl_busy), 
        .dma_read_ctrl_valid      (bridge_dma_read_ctrl_valid),
        .dma_read_ctrl_data_index (bridge_dma_read_ctrl_index),
        .dma_read_ctrl_data_length(bridge_dma_read_ctrl_length),
        .dma_read_ctrl_data_size  (bridge_dma_read_ctrl_size),
        
        .dma_write_ctrl_ready     (dma_write_ctrl_ready),
        .dma_write_ctrl_valid     (dma_write_ctrl_valid),
        .dma_write_ctrl_data_index(dma_write_ctrl_data_index),
        .dma_write_ctrl_data_length(dma_write_ctrl_data_length),
        .dma_write_ctrl_data_size (dma_write_ctrl_data_size),

        // ESP DMA Data Channel Side
        .dma_read_chnl_valid      (dma_read_chnl_valid && !boot_ctrl_busy),
        .dma_read_chnl_ready      (bridge_dma_read_chnl_ready),
        .dma_read_chnl_data       (dma_read_chnl_data),
        
        .dma_write_chnl_valid     (dma_write_chnl_valid),
        .dma_write_chnl_ready     (dma_write_chnl_ready),
        .dma_write_chnl_data      (dma_write_chnl_data)
    );

    // ========================================================================
    // Muxing: DMA Read Channel (Boot Controller vs Bridge)
    // ========================================================================
    
    always_comb begin
        if (boot_ctrl_busy) begin
            // Boot Controller has priority/exclusivity
            dma_read_ctrl_valid       = boot_dma_read_ctrl_valid;
            dma_read_ctrl_data_index  = boot_dma_read_ctrl_index;
            dma_read_ctrl_data_length = boot_dma_read_ctrl_length;
            dma_read_ctrl_data_size   = boot_dma_read_ctrl_size;
            dma_read_chnl_ready       = boot_dma_read_chnl_ready;
        end else begin
            // X-HEEP Core via Bridge has control
            dma_read_ctrl_valid       = bridge_dma_read_ctrl_valid;
            dma_read_ctrl_data_index  = bridge_dma_read_ctrl_index;
            dma_read_ctrl_data_length = bridge_dma_read_ctrl_length;
            dma_read_ctrl_data_size   = bridge_dma_read_ctrl_size;
            dma_read_chnl_ready       = bridge_dma_read_chnl_ready;
        end
    end

    // ========================================================================
    // Status & Debug
    // ========================================================================
    
    // acc_done is high if X-HEEP finishes executing OR if the Boot Fetch logic completes.
    assign acc_done = heep_exit_valid | boot_ctrl_fetch_done;
    
    assign debug = {29'b0, boot_ctrl_fetch_done, boot_ctrl_busy, heep_exit_valid};
    assign dma_read_ctrl_data_user  = '0;
    assign dma_write_ctrl_data_user = '0;

endmodule
