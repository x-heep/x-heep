module obi_to_esp_dma32 #(
    parameter int unsigned DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst,

    // ----------------------
    // OBI Interface (Slave)
    // ----------------------
    input  obi_pkg::obi_req_t  obi_req_i,
    output obi_pkg::obi_resp_t obi_resp_o,

    // ----------------------
    // ESP DMA Interface (Master)
    // ----------------------
    // Read Control
    input  logic dma_read_ctrl_ready,
    output logic dma_read_ctrl_valid,
    output logic [31:0] dma_read_ctrl_data_index,
    output logic [31:0] dma_read_ctrl_data_length,
    output logic [2:0]  dma_read_ctrl_data_size,

    // Read Data Channel
    input  logic dma_read_chnl_valid,
    output logic dma_read_chnl_ready,
    input  logic [DATA_WIDTH-1:0] dma_read_chnl_data,

    // Write Control
    input  logic dma_write_ctrl_ready,
    output logic dma_write_ctrl_valid,
    output logic [31:0] dma_write_ctrl_data_index,
    output logic [31:0] dma_write_ctrl_data_length,
    output logic [2:0]  dma_write_ctrl_data_size,

    // Write Data Channel
    output logic dma_write_chnl_valid,
    input  logic dma_write_chnl_ready,
    output logic [DATA_WIDTH-1:0] dma_write_chnl_data
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE,
        READ_CMD,
        READ_WAIT,
        RMW_READ_CMD,
        RMW_READ_WAIT,
        WRITE_CMD,
        WRITE_DATA,
        RESP_DONE
    } state_t;

    state_t state_d, state_q;

    // Registers to hold transaction details
    logic [31:0] addr_q;
    logic [31:0] wdata_q;
    logic [3:0]  be_q;
    logic        addr_lsb_q;
    logic        is_write_q;
    
    // Register to hold the data read during RMW
    logic [31:0] rmw_data_q; 

    // Output signals logic
    logic        obi_gnt;
    logic        obi_rvalid;
    logic [31:0] obi_rdata;

    // DMA Signals
    logic        dma_rd_ctrl_vld;
    logic        dma_rd_chnl_rdy;
    logic        dma_wr_ctrl_vld;
    logic        dma_wr_chnl_vld;
    logic [DATA_WIDTH-1:0] dma_wr_data_out;

    // -------------------------------------------------------------------------
    // Address Translation Logic
    // -------------------------------------------------------------------------
    // Must match EXT_SLAVE_START_ADDRESS in X-HEEP core_v_mini_mcu.h
    localparam logic [31:0] EXT_SLAVE_BASE = 32'hF000_0000;

    logic [31:0] relative_addr;
    assign relative_addr = addr_q - EXT_SLAVE_BASE;

    // -------------------------------------------------------------------------
    // Next State & Output Logic
    // -------------------------------------------------------------------------
    always_comb begin
        // Default Assignments
        state_d = state_q;
        
        obi_gnt    = 1'b0;
        obi_rvalid = 1'b0;
        obi_rdata  = '0;

        dma_rd_ctrl_vld = 1'b0;
        dma_rd_chnl_rdy = 1'b0;
        dma_wr_ctrl_vld = 1'b0;
        dma_wr_chnl_vld = 1'b0;
        dma_wr_data_out = '0;

        case (state_q)
            IDLE: begin
                // Wait for OBI Request
                if (obi_req_i.req) begin
                    if (obi_req_i.we) begin
                        // Check for Partial Write (Byte Enable != 1111)
                        if (obi_req_i.be != 4'b1111) begin
                            state_d = RMW_READ_CMD; // Must read first
                        end else begin
                            state_d = WRITE_CMD;    // Full word write, safe to proceed
                        end
                    end else begin
                        state_d = READ_CMD;
                    end
                end
            end

            // -----------------------------------------------------------------
            // Read Handling
            // -----------------------------------------------------------------
            READ_CMD: begin
                dma_rd_ctrl_vld = 1'b1;
                if (dma_read_ctrl_ready) begin
                    obi_gnt = 1'b1; 
                    state_d = READ_WAIT;
                end
            end

            READ_WAIT: begin
                dma_rd_chnl_rdy = 1'b1;
                if (dma_read_chnl_valid) begin
                    obi_rvalid = 1'b1;
                    obi_rdata = dma_read_chnl_data[31:0];
                    state_d = IDLE;
                end
            end

            // -----------------------------------------------------------------
            // Read-Modify-Write (RMW) Handling
            // -----------------------------------------------------------------
            RMW_READ_CMD: begin
                dma_rd_ctrl_vld = 1'b1;
                if (dma_read_ctrl_ready) begin
                    state_d = RMW_READ_WAIT;
                end
            end

            RMW_READ_WAIT: begin
                dma_rd_chnl_rdy = 1'b1;
                if (dma_read_chnl_valid) begin
                    // Data arrived, go to Write phase
                    state_d = WRITE_CMD; 
                end
            end

            // -----------------------------------------------------------------
            // Write Handling
            // -----------------------------------------------------------------
            WRITE_CMD: begin
                dma_wr_ctrl_vld = 1'b1;
                if (dma_write_ctrl_ready) begin
                    obi_gnt = 1'b1;
                    state_d = WRITE_DATA;
                end
            end

            WRITE_DATA: begin
                dma_wr_chnl_vld = 1'b1;
                
                // DATA MERGE LOGIC
                // If we did an RMW read, we merge. If it was a full write, be_q is 1111.
                // We use the latched 'rmw_data_q' (old value) and 'wdata_q' (new value)
                for (int i = 0; i < 4; i++) begin
                    if (be_q[i]) begin
                        dma_wr_data_out[i*8 +: 8] = wdata_q[i*8 +: 8]; // New data
                    end else begin
                        dma_wr_data_out[i*8 +: 8] = rmw_data_q[i*8 +: 8]; // Old data
                    end
                end

                if (dma_write_chnl_ready) begin
                    obi_gnt    = 1'b1; 
                    obi_rvalid = 1'b1; 
                    state_d    = IDLE;
                end
            end

            default: state_d = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Sequential Logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state_q     <= IDLE;
            addr_q      <= '0;
            wdata_q     <= '0;
            be_q        <= 4'b0000;
            rmw_data_q  <= '0;
            addr_lsb_q  <= 1'b0;
            is_write_q  <= 1'b0;
        end else begin
            state_q <= state_d;

            // Latch request info in IDLE
            if (state_q == IDLE && obi_req_i.req) begin
                addr_q      <= obi_req_i.addr;
                wdata_q     <= obi_req_i.wdata;
                be_q        <= obi_req_i.be;    // Latch Byte Enables
                addr_lsb_q  <= obi_req_i.addr[2]; 
                is_write_q  <= obi_req_i.we;
                
                // Pre-load rmw_data_q with 0 so full writes work cleanly if logic defaults to it
                rmw_data_q  <= '0; 
            end

            // Latch RMW Data
            if (state_q == RMW_READ_WAIT && dma_read_chnl_valid && dma_rd_chnl_rdy) begin
                rmw_data_q <= dma_read_chnl_data[31:0];
            end
        end
    end

    // -------------------------------------------------------------------------
    // Signal Assignments
    // -------------------------------------------------------------------------
    
    // OBI Output Assignments
    assign obi_resp_o.gnt    = obi_gnt;
    assign obi_resp_o.rvalid = obi_rvalid;
    assign obi_resp_o.rdata  = obi_rdata;

    // DMA Control Assignments
    assign dma_read_ctrl_valid       = dma_rd_ctrl_vld;
    assign dma_read_ctrl_data_index  = relative_addr[31:2]; 
    assign dma_read_ctrl_data_length = 32'd1;        
    assign dma_read_ctrl_data_size   = 3'b010;       

    assign dma_read_chnl_ready       = dma_rd_chnl_rdy;

    assign dma_write_ctrl_valid       = dma_wr_ctrl_vld;
    assign dma_write_ctrl_data_index  = relative_addr[31:2];
    assign dma_write_ctrl_data_length = 32'd1;
    assign dma_write_ctrl_data_size   = 3'b010;

    assign dma_write_chnl_valid       = dma_wr_chnl_vld;
    assign dma_write_chnl_data        = dma_wr_data_out;

endmodule
