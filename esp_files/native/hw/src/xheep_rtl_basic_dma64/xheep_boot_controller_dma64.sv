module xheep_boot_controller_dma64  
  import obi_pkg::*;
    (
    input  logic        clk,
    input  logic        rst_n,

    // Configuration Triggers
    input  logic        trigger_fetch,
    input  logic [31:0] fetch_addr_byte,
    input  logic [31:0] fetch_size_words,
    input  logic        trigger_boot_exit,
    input  logic        conf_done,

    // DMA Read Control (Master)
    output logic        dma_read_ctrl_valid,
    input  logic        dma_read_ctrl_ready,
    output logic [31:0] dma_read_ctrl_data_index,
    output logic [31:0] dma_read_ctrl_data_length,
    output logic [2:0]  dma_read_ctrl_data_size,

    // DMA Read Channel (Slave)
    input  logic        dma_read_chnl_valid,
    output logic        dma_read_chnl_ready,
    input  logic [63:0] dma_read_chnl_data,

    // OBI Master (To X-HEEP External Slave Port)
    output obi_pkg::obi_req_t  obi_req_o,
    input  obi_pkg::obi_resp_t obi_resp_i,

    // Status
    output logic        busy,
    output logic        fetch_done_o
);

    // X-HEEP Memory Map Constants (must match core_v_mini_mcu definitions)
    localparam logic [31:0] XHEEP_RAM_START_ADDR = 32'h0000_0000;
    localparam logic [31:0] XHEEP_SOC_CTRL_ADDR  = 32'h2000_000c; 

    // DMA Constants
    localparam logic [2:0]  DMA_SIZE_WORD = 3'b011; // 64-bit

    // State Machine
    typedef enum logic [1:0] {
        IDLE,
        DMA_REQ,
        DMA_WAIT_DATA,
        EXIT_WRITE
    } state_t;

    state_t state_d, state_q;

    // Registers for Boot process
    logic [31:0] boot_ram_addr_d, boot_ram_addr_q;
    logic [31:0] boot_word_cnt_d, boot_word_cnt_q;
    logic [63:0] boot_buffered_data_d,  boot_buffered_data_q;
    logic        boot_buffered_valid_d, boot_buffered_valid_q;
    logic        boot_buffered_use_upper_d, boot_buffered_use_upper_q;
    logic        boot_buffered_upper_pending_d, boot_buffered_upper_pending_q;

    // Edge Detection
    logic rise_fetch;
    logic rise_exit;
    logic trigger_boot_exit_q;
    logic pending_exit;

    assign rise_fetch = conf_done && trigger_fetch;
    assign rise_exit  = conf_done && pending_exit;
    
    // Output logic
    always_comb begin
        // Defaults
        state_d = state_q;
        boot_ram_addr_d = boot_ram_addr_q;
        boot_word_cnt_d = boot_word_cnt_q;

        busy = 1'b0;
        fetch_done_o = 1'b0;

        // Boot DMA Read Control Defaults
        dma_read_ctrl_valid = 1'b0;
        dma_read_ctrl_data_index = 32'd0; 
        dma_read_ctrl_data_length = (fetch_size_words >> 1) + fetch_size_words[0];
        dma_read_ctrl_data_size = DMA_SIZE_WORD;

        // Boot Buffer defaults
        boot_buffered_data_d          = boot_buffered_data_q;
        boot_buffered_valid_d         = boot_buffered_valid_q;
        boot_buffered_use_upper_d     = boot_buffered_use_upper_q;
        boot_buffered_upper_pending_d = boot_buffered_upper_pending_q;

        // DMA Read Channel (for Boot) Default
        dma_read_chnl_ready = !boot_buffered_valid_q;

        // OBI Defaults
        obi_req_o.req   = 1'b0;
        obi_req_o.we    = 1'b0;
        obi_req_o.be    = 4'b1111;
        obi_req_o.addr  = '0;
        obi_req_o.wdata = '0;

        case (state_q)
            IDLE: begin
                if (rise_fetch) begin 
                    state_d = DMA_REQ;
                    boot_ram_addr_d = XHEEP_RAM_START_ADDR;
                    boot_word_cnt_d = 0;
                    busy = 1'b1;
                    boot_buffered_valid_d         = 1'b0;
                    boot_buffered_use_upper_d     = 1'b0;
                    boot_buffered_upper_pending_d = 1'b0;
                end else if (rise_exit) begin
                    state_d = EXIT_WRITE;
                    busy = 1'b1;
                end
            end

            // =========================================================
            // BOOT SEQUENCE
            // =========================================================
            DMA_REQ: begin
                busy = 1'b1;
                dma_read_ctrl_valid = 1'b1;
                dma_read_chnl_ready = !boot_buffered_valid_q;

                if (dma_read_ctrl_ready) begin
                    state_d = DMA_WAIT_DATA;
                end
            end

            DMA_WAIT_DATA: begin
                busy = 1'b1;
                dma_read_chnl_ready = !boot_buffered_valid_q;

                if (dma_read_chnl_valid && dma_read_chnl_ready) begin
                    boot_buffered_data_d      = dma_read_chnl_data;
                    boot_buffered_valid_d     = 1'b1;
                    boot_buffered_use_upper_d = 1'b0;
                    boot_buffered_upper_pending_d = ((fetch_size_words - boot_word_cnt_q) > 1);
                end

                if (boot_buffered_valid_q) begin
                    obi_req_o.req   = 1'b1;
                    obi_req_o.we    = 1'b1;
                    obi_req_o.addr  = boot_ram_addr_q;
                    obi_req_o.wdata = boot_buffered_use_upper_q ? boot_buffered_data_q[63:32] : boot_buffered_data_q[31:0];

                    if (obi_resp_i.gnt) begin
                        boot_ram_addr_d = boot_ram_addr_q + 4;
                        boot_word_cnt_d = boot_word_cnt_q + 1;

                        if (!boot_buffered_use_upper_q && boot_buffered_upper_pending_q) begin
                            boot_buffered_use_upper_d     = 1'b1;
                            boot_buffered_upper_pending_d = 1'b0;
                        end else begin
                            boot_buffered_valid_d         = 1'b0;
                            boot_buffered_use_upper_d     = 1'b0;
                            boot_buffered_upper_pending_d = 1'b0;
                        end

                        if (boot_word_cnt_d == fetch_size_words) begin
                            state_d      = IDLE;
                            fetch_done_o = 1'b1;
                        end
                    end
                end
            end

            EXIT_WRITE: begin
                busy = 1'b1;
                obi_req_o.req   = 1'b1;
                obi_req_o.we    = 1'b1;
                obi_req_o.addr  = XHEEP_SOC_CTRL_ADDR;
                obi_req_o.wdata = 32'd1; 

                if (obi_resp_i.gnt) begin
                    state_d = IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= IDLE;
            boot_ram_addr_q   <= '0;
            boot_word_cnt_q   <= '0;
            boot_buffered_data_q  <= '0;
            boot_buffered_valid_q <= 1'b0;
            boot_buffered_use_upper_q <= 1'b0;
            boot_buffered_upper_pending_q <= 1'b0;
            trigger_boot_exit_q <= 1'b0;
            pending_exit <= 1'b0;
        end else begin
            state_q <= state_d;
            boot_ram_addr_q   <= boot_ram_addr_d;
            boot_word_cnt_q   <= boot_word_cnt_d;
            boot_buffered_data_q  <= boot_buffered_data_d;
            boot_buffered_valid_q <= boot_buffered_valid_d;
            boot_buffered_use_upper_q <= boot_buffered_use_upper_d;
            boot_buffered_upper_pending_q <= boot_buffered_upper_pending_d;
            trigger_boot_exit_q <= trigger_boot_exit;
            if (trigger_boot_exit && !trigger_boot_exit_q) begin
                pending_exit <= 1'b1;
            end else if (rise_exit) begin
                pending_exit <= 1'b0;
            end
        end
    end

endmodule
