module xheep_boot_controller_dma32 (
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
    input  logic [31:0] dma_read_chnl_data,

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
    localparam logic [2:0]  DMA_SIZE_WORD = 3'b010; // 32-bit

    // State Machine
    typedef enum logic [2:0] {
        IDLE,
        DMA_REQ,        // Issue Read Command to ESP
        DMA_WAIT_DATA,  // Receive Data from ESP and push to OBI
        EXIT_WRITE      // Write to SOC_CTRL to release CPU
    } state_t;

    state_t state_d, state_q;

    // Registers
    logic [31:0] current_ram_addr_d, current_ram_addr_q;
    logic [31:0] beat_cnt_d, beat_cnt_q;

    // Edge Detection
    logic rise_fetch;
    logic rise_exit;

    // one word buffer for incoming DMA data
    logic [31:0] buffered_word_d,  buffered_word_q;
    logic        buffered_valid_d, buffered_valid_q;

    assign rise_fetch = conf_done && trigger_fetch;
    assign rise_exit  = conf_done && trigger_boot_exit;

    // Output logic
    always_comb begin
        // Defaults
        state_d = state_q;
        current_ram_addr_d = current_ram_addr_q;
        beat_cnt_d = beat_cnt_q;
        
        busy = 1'b0;
        fetch_done_o = 1'b0;

        // DMA Control Defaults
        dma_read_ctrl_valid = 1'b0;
        // Index 0 means start of the buffer allocated by driver
        dma_read_ctrl_data_index = 32'd0; 
        // Length in beats (words)
        dma_read_ctrl_data_length = fetch_size_words; 
        dma_read_ctrl_data_size = DMA_SIZE_WORD;

        // Buffer defaults
        buffered_word_d  = buffered_word_q;
        buffered_valid_d = buffered_valid_q;

        // DMA Channel Default
        dma_read_chnl_ready = 1'b0;

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
                    current_ram_addr_d = XHEEP_RAM_START_ADDR;
                    beat_cnt_d = 0;
                    busy = 1'b1;
                    // reset buffer when starting a new fetch
                    buffered_valid_d = 1'b0;
                end else if (rise_exit) begin
                    state_d = EXIT_WRITE;
                    busy = 1'b1;
                end
            end

            // ---------------------------------------------------------
            // PHASE 1: Send Request to ESP DMA (control channel)
            // ---------------------------------------------------------
            DMA_REQ: begin
                busy = 1'b1;
                dma_read_ctrl_valid = 1'b1;

                // tell DMA channel we are ready to accept data
                dma_read_chnl_ready = !buffered_valid_q;

                if (dma_read_ctrl_ready) begin
                    state_d = DMA_WAIT_DATA;
                end
            end

            // ---------------------------------------------------------
            // PHASE 2: Stream Data (ESP -> Boot Ctrl -> OBI -> RAM)
            // ---------------------------------------------------------
            DMA_WAIT_DATA: begin
                busy = 1'b1;

                // tell DMA channel we are ready to accept data when buffer is free
                dma_read_chnl_ready = !buffered_valid_q;

                if (dma_read_chnl_valid && dma_read_chnl_ready) begin
                    buffered_word_d  = dma_read_chnl_data;
                    buffered_valid_d = 1'b1;
                end

                // If we have buffered data, push it out on OBI
                if (buffered_valid_q) begin
                    obi_req_o.req   = 1'b1;
                    obi_req_o.we    = 1'b1;
                    obi_req_o.addr  = current_ram_addr_q;
                    obi_req_o.wdata = buffered_word_q;
                    obi_req_o.be    = 4'b1111;

                    if (obi_resp_i.gnt) begin
                        buffered_valid_d   = 1'b0; // beat consumed
                        current_ram_addr_d = current_ram_addr_q + 4;
                        beat_cnt_d         = beat_cnt_q + 1;

                        if (beat_cnt_d == fetch_size_words) begin
                            state_d      = IDLE;
                            fetch_done_o = 1'b1;
                        end
                    end
                end
            end

            // ---------------------------------------------------------
            // PHASE 3: Boot Exit (Write to CSR)
            // ---------------------------------------------------------
            EXIT_WRITE: begin
                busy = 1'b1;

                // Write to SOC_CTRL to start X-Heep execution
                obi_req_o.req   = 1'b1;
                obi_req_o.we    = 1'b1;
                obi_req_o.addr  = XHEEP_SOC_CTRL_ADDR;
                obi_req_o.wdata = 32'd1; 
                obi_req_o.be    = 4'b1111;

                if (obi_resp_i.gnt) begin
                    state_d = IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q              <= IDLE;
            current_ram_addr_q   <= '0;
            beat_cnt_q           <= '0;

            buffered_word_q      <= '0;
            buffered_valid_q     <= 1'b0;
        end else begin
            state_q              <= state_d;
            current_ram_addr_q   <= current_ram_addr_d;
            beat_cnt_q           <= beat_cnt_d;

            buffered_word_q      <= buffered_word_d;
            buffered_valid_q     <= buffered_valid_d;
        end
    end

endmodule
