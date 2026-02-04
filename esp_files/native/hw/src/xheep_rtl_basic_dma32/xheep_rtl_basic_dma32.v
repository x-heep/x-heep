// xheep_rtl_basic_dma32.v

module xheep_rtl_basic_dma32  
  import obi_pkg::*;
    (
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
    obi_pkg::obi_resp_t heep_core_data_resp_comb;
    logic               heep_core_rvalid_q;
    logic [31:0]        heep_core_rdata_q;
    
    // Boot Controller OBI Interface (Master Port of Controller -> Slave Port of X-HEEP)
    obi_pkg::obi_req_t  boot_obi_req;
    obi_pkg::obi_resp_t boot_obi_resp;
    obi_pkg::obi_req_t  final_slave_obi_req;

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
    logic [5:0]  bridge_dma_read_ctrl_user;
    logic        bridge_dma_read_chnl_ready;

    logic        bridge_dma_write_ctrl_valid;
    logic [31:0] bridge_dma_write_ctrl_index;
    logic [31:0] bridge_dma_write_ctrl_length;
    logic [2:0]  bridge_dma_write_ctrl_size;
    logic [5:0]  bridge_dma_write_ctrl_user;
    logic        bridge_dma_write_chnl_valid;
    logic [31:0] bridge_dma_write_chnl_data;

    // Boot Controller DMA Signals
    logic        boot_dma_read_ctrl_valid;
    logic [31:0] boot_dma_read_ctrl_index;
    logic [31:0] boot_dma_read_ctrl_length;
    logic [2:0]  boot_dma_read_ctrl_size;
    logic        boot_dma_read_chnl_ready;

    // Burst DMA CSR Signals
    logic        burst_start_pulse;
    logic        burst_dir;
    logic [5:0]  burst_read_user_field;
    logic [5:0]  burst_write_user_field;
    logic [31:0] burst_addr_byte;
    logic [31:0] burst_len_bytes;
    logic [31:0] burst_xheep_addr;
    logic        burst_status_clear_done;
    logic        burst_status_clear_err;
    logic        burst_status_busy;
    logic        burst_status_done;
    logic        burst_status_err;

    // Burst DMA Signals
    logic        burst_dma_read_ctrl_valid;
    logic [31:0] burst_dma_read_ctrl_index;
    logic [31:0] burst_dma_read_ctrl_length;
    logic [2:0]  burst_dma_read_ctrl_size;
    logic [5:0]  burst_dma_read_ctrl_user;
    logic        burst_dma_read_chnl_ready;
    logic        burst_dma_write_ctrl_valid;
    logic [31:0] burst_dma_write_ctrl_index;
    logic [31:0] burst_dma_write_ctrl_length;
    logic [2:0]  burst_dma_write_ctrl_size;
    logic [5:0]  burst_dma_write_ctrl_user;
    logic        burst_dma_write_chnl_valid;
    logic [31:0] burst_dma_write_chnl_data;

    // Burst OBI Master Signals
    obi_pkg::obi_req_t  burst_obi_req;
    logic              burst_obi_gnt;
    logic              burst_obi_rvalid;
    logic [31:0]       burst_obi_rdata;
    
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

    always_comb begin
        if (boot_ctrl_busy) begin
            final_slave_obi_req = boot_obi_req;
        end else if (burst_status_busy) begin
            final_slave_obi_req = burst_obi_req;
        end else begin
            final_slave_obi_req.req   = 1'b0;
            final_slave_obi_req.we    = 1'b0;
            final_slave_obi_req.be    = 4'b0;
            final_slave_obi_req.addr  = '0;
            final_slave_obi_req.wdata = '0;
        end
    end

    // ========================================================================
    // X-HEEP Instance
    // ========================================================================
    core_v_mini_mcu #(
        .EXT_XBAR_NMASTER(1)
    ) u_xheep (
        .clk_i   (clk),
        .rst_ni  (x_heep_rst_n),

        // External Slave Port: Connected to Boot Controller
        .ext_xbar_master_req_i  (final_slave_obi_req),
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
        .obi_resp_o(heep_core_data_resp_comb),

        // ESP DMA Control Side
        .dma_read_ctrl_ready      (dma_read_ctrl_ready && !boot_ctrl_busy && !burst_status_busy), 
        .dma_read_ctrl_valid      (bridge_dma_read_ctrl_valid),
        .dma_read_ctrl_data_index (bridge_dma_read_ctrl_index),
        .dma_read_ctrl_data_length(bridge_dma_read_ctrl_length),
        .dma_read_ctrl_data_size  (bridge_dma_read_ctrl_size),
        .dma_read_ctrl_data_user  (bridge_dma_read_ctrl_user),
        
        .dma_write_ctrl_ready     (dma_write_ctrl_ready && !burst_write_active),
        .dma_write_ctrl_valid     (bridge_dma_write_ctrl_valid),
        .dma_write_ctrl_data_index(bridge_dma_write_ctrl_index),
        .dma_write_ctrl_data_length(bridge_dma_write_ctrl_length),
        .dma_write_ctrl_data_size (bridge_dma_write_ctrl_size),
        .dma_write_ctrl_data_user (bridge_dma_write_ctrl_user),

        // ESP DMA Data Channel Side
        .dma_read_chnl_valid      (dma_read_chnl_valid && !boot_ctrl_busy && !burst_status_busy),
        .dma_read_chnl_ready      (bridge_dma_read_chnl_ready),
        .dma_read_chnl_data       (dma_read_chnl_data),
        
        .dma_write_chnl_valid     (bridge_dma_write_chnl_valid),
        .dma_write_chnl_ready     (dma_write_chnl_ready && !burst_write_active),
        .dma_write_chnl_data      (bridge_dma_write_chnl_data),

        .burst_start_pulse        (burst_start_pulse),
        .burst_dir                (burst_dir),
        .burst_read_user_field    (burst_read_user_field),
        .burst_write_user_field   (burst_write_user_field),
        .burst_addr_byte          (burst_addr_byte),
        .burst_len_bytes          (burst_len_bytes),
        .burst_xheep_addr         (burst_xheep_addr),
        .burst_status_clear_done  (burst_status_clear_done),
        .burst_status_clear_err   (burst_status_clear_err),
        .burst_status_busy        (burst_status_busy),
        .burst_status_done        (burst_status_done),
        .burst_status_err         (burst_status_err)
    );

    // Register response valid/data to break combinational loops
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            heep_core_rvalid_q <= 1'b0;
            heep_core_rdata_q  <= '0;
        end else begin
            heep_core_rvalid_q <= heep_core_data_resp_comb.rvalid;
            if (heep_core_data_resp_comb.rvalid) begin
                heep_core_rdata_q <= heep_core_data_resp_comb.rdata;
            end
        end
    end

    assign heep_core_data_resp.gnt    = heep_core_data_resp_comb.gnt;
    assign heep_core_data_resp.rvalid = heep_core_rvalid_q;
    assign heep_core_data_resp.rdata  = heep_core_rdata_q;

    // ========================================================================
    // Burst DMA Engine (32-bit)
    // ========================================================================
    localparam logic [31:0] XHEEP_RAM_START_ADDR = 32'h0000_0000;
    localparam logic [31:0] EXT_SLAVE_START_ADDR = 32'hF000_0000;
    localparam logic [2:0]  DMA_SIZE_WORD = 3'b010;

    typedef enum logic [2:0] {
        BURST_IDLE,
        BURST_DMA_REQ_RD,
        BURST_STREAM_RD,
        BURST_DMA_REQ_WR,
        BURST_STREAM_WR
    } burst_state_t;

    burst_state_t burst_state_d, burst_state_q;

    logic [31:0] burst_dma_index_q;
    logic [31:0] burst_dma_len_beats_q;
    logic [31:0] burst_beats_remaining_q;
    logic [31:0] burst_beat_data_q;
    logic        burst_beat_valid_q;
    logic        burst_beat_last_q;
    logic [1:0]  burst_last_bytes_q;
    logic [31:0] burst_xheep_addr_q;
    logic        burst_dir_q;

    logic [31:0] burst_wr_beat_q;
    logic        burst_wr_beat_valid_q;
    logic        burst_wr_pending_q;
    logic [31:0] burst_wr_data_out;
    logic [31:0] burst_addr_offset;
    logic [31:0] burst_addr_index;

    logic        burst_start_accept;
    logic        burst_done_set;
    logic [3:0]  burst_be_mask;
    logic        burst_dma_read_chnl_valid;
    logic        burst_write_active;

    function automatic [3:0] be_mask(input logic [1:0] count);
        case (count)
            2'd0: be_mask = 4'b0000;
            2'd1: be_mask = 4'b0001;
            2'd2: be_mask = 4'b0011;
            2'd3: be_mask = 4'b0111;
        endcase
    endfunction

    function automatic [31:0] byte_mask32(input logic [1:0] count);
        case (count)
            2'd0: byte_mask32 = 32'h0000_0000;
            2'd1: byte_mask32 = 32'h0000_00FF;
            2'd2: byte_mask32 = 32'h0000_FFFF;
            2'd3: byte_mask32 = 32'h00FF_FFFF;
        endcase
    endfunction

    assign burst_status_busy = (burst_state_q != BURST_IDLE);
    assign burst_write_active = burst_status_busy && burst_dir_q;
    assign burst_obi_gnt = boot_obi_resp.gnt && !boot_ctrl_busy;
    assign burst_obi_rvalid = boot_obi_resp.rvalid && !boot_ctrl_busy;
    assign burst_obi_rdata  = boot_obi_resp.rdata;

    assign burst_dma_read_ctrl_index  = burst_dma_index_q;
    assign burst_dma_read_ctrl_length = burst_dma_len_beats_q;
    assign burst_dma_read_ctrl_size   = DMA_SIZE_WORD;
    assign burst_dma_read_ctrl_user   = burst_read_user_field;

    assign burst_dma_read_chnl_valid = dma_read_chnl_valid && burst_status_busy && !boot_ctrl_busy;

    assign burst_dma_write_ctrl_index  = burst_dma_index_q;
    assign burst_dma_write_ctrl_length = burst_dma_len_beats_q;
    assign burst_dma_write_ctrl_size   = DMA_SIZE_WORD;
    assign burst_dma_write_ctrl_user   = burst_write_user_field;

    assign burst_dma_write_chnl_data   = burst_wr_data_out;
    assign burst_addr_offset = burst_addr_byte - EXT_SLAVE_START_ADDR;
    assign burst_addr_index = {10'b0, burst_addr_offset[21:0]};

    always_comb begin
        burst_be_mask = 4'b1111;
        burst_wr_data_out = burst_wr_beat_q;

        if (burst_beat_last_q && (burst_last_bytes_q != 2'b00)) begin
            burst_be_mask = be_mask(burst_last_bytes_q);
        end

        if (burst_dir_q && (burst_beats_remaining_q == 32'd1) && (burst_last_bytes_q != 2'b00)) begin
            burst_wr_data_out = burst_wr_beat_q & byte_mask32(burst_last_bytes_q);
        end
    end

    always_comb begin
        burst_state_d = burst_state_q;
        burst_dma_read_ctrl_valid = 1'b0;
        burst_dma_read_chnl_ready = 1'b0;
        burst_dma_write_ctrl_valid = 1'b0;
        burst_dma_write_chnl_valid = 1'b0;
        burst_done_set = 1'b0;

        burst_obi_req.req   = 1'b0;
        burst_obi_req.we    = 1'b0;
        burst_obi_req.be    = 4'b0;
        burst_obi_req.addr  = '0;
        burst_obi_req.wdata = '0;

        burst_start_accept = burst_start_pulse &&
                             (burst_state_q == BURST_IDLE) &&
                             (burst_len_bytes != 32'd0);

        case (burst_state_q)
            BURST_IDLE: begin
                if (burst_start_accept) begin
                    if (burst_dir) begin
                        burst_state_d = BURST_DMA_REQ_WR;
                    end else begin
                        burst_state_d = BURST_DMA_REQ_RD;
                    end
                end
            end

            BURST_DMA_REQ_RD: begin
                burst_dma_read_ctrl_valid = 1'b1;
                if (dma_read_ctrl_ready && !boot_ctrl_busy) begin
                    burst_state_d = BURST_STREAM_RD;
                end
            end

            BURST_STREAM_RD: begin
                burst_dma_read_chnl_ready = (!burst_beat_valid_q) && (burst_beats_remaining_q != 0);

                if (burst_beat_valid_q) begin
                    burst_obi_req.req   = 1'b1;
                    burst_obi_req.we    = 1'b1;
                    burst_obi_req.be    = burst_be_mask;
                    burst_obi_req.addr  = burst_xheep_addr_q;
                    burst_obi_req.wdata = burst_beat_data_q;
                end

                if ((burst_beats_remaining_q == 0) && !burst_beat_valid_q) begin
                    burst_state_d = BURST_IDLE;
                    burst_done_set = 1'b1;
                end
            end

            BURST_DMA_REQ_WR: begin
                burst_dma_write_ctrl_valid = 1'b1;
                if (dma_write_ctrl_ready && !boot_ctrl_busy) begin
                    burst_state_d = BURST_STREAM_WR;
                end
            end

            BURST_STREAM_WR: begin
                if (!burst_wr_beat_valid_q && !burst_wr_pending_q) begin
                    burst_obi_req.req  = 1'b1;
                    burst_obi_req.we   = 1'b0;
                    burst_obi_req.be   = 4'b1111;
                    burst_obi_req.addr = burst_xheep_addr_q;
                end

                if (burst_wr_beat_valid_q) begin
                    burst_dma_write_chnl_valid = 1'b1;
                end

                if ((burst_beats_remaining_q == 0) && !burst_wr_beat_valid_q && !burst_wr_pending_q) begin
                    burst_state_d = BURST_IDLE;
                    burst_done_set = 1'b1;
                end
            end

            default: burst_state_d = BURST_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            burst_state_q          <= BURST_IDLE;
            burst_dma_index_q      <= '0;
            burst_dma_len_beats_q  <= '0;
            burst_beats_remaining_q <= '0;
            burst_beat_data_q      <= '0;
            burst_beat_valid_q     <= 1'b0;
            burst_beat_last_q      <= 1'b0;
            burst_last_bytes_q     <= 2'b00;
            burst_xheep_addr_q     <= XHEEP_RAM_START_ADDR;
            burst_dir_q            <= 1'b0;
            burst_wr_beat_q        <= '0;
            burst_wr_beat_valid_q  <= 1'b0;
            burst_wr_pending_q     <= 1'b0;
            burst_status_done      <= 1'b0;
            burst_status_err       <= 1'b0;
        end else begin
            burst_state_q <= burst_state_d;

            if (burst_status_clear_done) begin
                burst_status_done <= 1'b0;
            end
            if (burst_status_clear_err) begin
                burst_status_err <= 1'b0;
            end

            if (burst_start_pulse) begin
                if (burst_status_busy || (burst_len_bytes == 32'd0)) begin
                    burst_status_err <= 1'b1;
                end
            end

            if (burst_start_accept) begin
                burst_dma_index_q      <= burst_addr_index >> 2;
                burst_dma_len_beats_q  <= (burst_len_bytes + 32'd3) >> 2;
                burst_beats_remaining_q <= (burst_len_bytes + 32'd3) >> 2;
                burst_xheep_addr_q     <= burst_xheep_addr;
                burst_beat_valid_q     <= 1'b0;
                burst_beat_last_q      <= 1'b0;
                burst_last_bytes_q     <= burst_len_bytes[1:0];
                burst_dir_q            <= burst_dir;
                burst_wr_beat_q        <= '0;
                burst_wr_beat_valid_q  <= 1'b0;
                burst_wr_pending_q     <= 1'b0;
                burst_status_done      <= 1'b0;
            end

            if (burst_state_q == BURST_STREAM_RD) begin
                if (burst_dma_read_chnl_valid && burst_dma_read_chnl_ready) begin
                    burst_beat_data_q      <= dma_read_chnl_data;
                    burst_beat_valid_q     <= 1'b1;
                    burst_beat_last_q      <= (burst_beats_remaining_q == 32'd1);
                    burst_beats_remaining_q <= burst_beats_remaining_q - 1'b1;
                end

                if (burst_beat_valid_q && burst_obi_gnt) begin
                    burst_xheep_addr_q <= burst_xheep_addr_q + 32'd4;
                    burst_beat_valid_q <= 1'b0;
                end
            end

            if (burst_state_q == BURST_STREAM_WR) begin
                if (!burst_wr_beat_valid_q) begin
                    if (!burst_wr_pending_q && burst_obi_gnt) begin
                        if (burst_obi_rvalid) begin
                            burst_wr_beat_q <= burst_obi_rdata;
                            burst_wr_beat_valid_q <= 1'b1;
                            burst_xheep_addr_q <= burst_xheep_addr_q + 32'd4;
                            burst_wr_pending_q <= 1'b0;
                        end else begin
                            burst_wr_pending_q <= 1'b1;
                        end
                    end

                    if (burst_wr_pending_q && burst_obi_rvalid) begin
                        burst_wr_pending_q <= 1'b0;
                        burst_wr_beat_q <= burst_obi_rdata;
                        burst_wr_beat_valid_q <= 1'b1;
                        burst_xheep_addr_q <= burst_xheep_addr_q + 32'd4;
                    end
                end

                if (burst_wr_beat_valid_q && dma_write_chnl_ready) begin
                    burst_wr_beat_valid_q <= 1'b0;
                    burst_beats_remaining_q <= burst_beats_remaining_q - 1'b1;
                end
            end else begin
                burst_wr_pending_q <= 1'b0;
            end

            if (burst_done_set) begin
                burst_status_done <= 1'b1;
            end
        end
    end

    // ========================================================================
    // Muxing: DMA Read Channel (Boot Controller vs Burst vs Bridge)
    // ========================================================================
    
    always_comb begin
        if (boot_ctrl_busy) begin
            // Boot Controller has priority/exclusivity
            dma_read_ctrl_valid       = boot_dma_read_ctrl_valid;
            dma_read_ctrl_data_index  = boot_dma_read_ctrl_index;
            dma_read_ctrl_data_length = boot_dma_read_ctrl_length;
            dma_read_ctrl_data_size   = boot_dma_read_ctrl_size;
            dma_read_ctrl_data_user   = '0;
            dma_read_chnl_ready       = boot_dma_read_chnl_ready;
        end else if (burst_status_busy) begin
            dma_read_ctrl_valid       = burst_dma_read_ctrl_valid;
            dma_read_ctrl_data_index  = burst_dma_read_ctrl_index;
            dma_read_ctrl_data_length = burst_dma_read_ctrl_length;
            dma_read_ctrl_data_size   = burst_dma_read_ctrl_size;
            dma_read_ctrl_data_user   = burst_dma_read_ctrl_user;
            dma_read_chnl_ready       = burst_dma_read_chnl_ready;
        end else begin
            // X-HEEP Core via Bridge has control
            dma_read_ctrl_valid       = bridge_dma_read_ctrl_valid;
            dma_read_ctrl_data_index  = bridge_dma_read_ctrl_index;
            dma_read_ctrl_data_length = bridge_dma_read_ctrl_length;
            dma_read_ctrl_data_size   = bridge_dma_read_ctrl_size;
            dma_read_ctrl_data_user   = bridge_dma_read_ctrl_user;
            dma_read_chnl_ready       = bridge_dma_read_chnl_ready;
        end
    end

    always_comb begin
        if (burst_write_active) begin
            dma_write_ctrl_valid       = burst_dma_write_ctrl_valid;
            dma_write_ctrl_data_index  = burst_dma_write_ctrl_index;
            dma_write_ctrl_data_length = burst_dma_write_ctrl_length;
            dma_write_ctrl_data_size   = burst_dma_write_ctrl_size;
            dma_write_ctrl_data_user   = burst_dma_write_ctrl_user;
            dma_write_chnl_valid       = burst_dma_write_chnl_valid;
            dma_write_chnl_data        = burst_dma_write_chnl_data;
        end else begin
            dma_write_ctrl_valid       = bridge_dma_write_ctrl_valid;
            dma_write_ctrl_data_index  = bridge_dma_write_ctrl_index;
            dma_write_ctrl_data_length = bridge_dma_write_ctrl_length;
            dma_write_ctrl_data_size   = bridge_dma_write_ctrl_size;
            dma_write_ctrl_data_user   = bridge_dma_write_ctrl_user;
            dma_write_chnl_valid       = bridge_dma_write_chnl_valid;
            dma_write_chnl_data        = bridge_dma_write_chnl_data;
        end
    end

    // ========================================================================
    // Status & Debug
    // ========================================================================
    
    // acc_done is high if X-HEEP finishes executing OR if the Boot Fetch logic completes.
    assign acc_done = heep_exit_valid | boot_ctrl_fetch_done;
    
    assign debug = {29'b0, boot_ctrl_fetch_done, boot_ctrl_busy, heep_exit_valid};

endmodule
