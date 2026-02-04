module obi_to_esp_dma64 
  import obi_pkg::*;
    #(
    parameter int unsigned DATA_WIDTH = 64
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
    output logic [5:0]  dma_read_ctrl_data_user,

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
    output logic [5:0]  dma_write_ctrl_data_user,

    // Write Data Channel
    output logic dma_write_chnl_valid,
    input  logic dma_write_chnl_ready,
    output logic [DATA_WIDTH-1:0] dma_write_chnl_data,

    // ----------------------
    // Burst DMA CSR Interface
    // ----------------------
    output logic        burst_start_pulse,
    output logic        burst_dir,
    output logic [5:0]  burst_read_user_field,
    output logic [5:0]  burst_write_user_field,
    output logic [31:0] burst_addr_byte,
    output logic [31:0] burst_len_bytes,
    output logic [31:0] burst_xheep_addr,
    output logic        burst_status_clear_done,
    output logic        burst_status_clear_err,
    input  logic        burst_status_busy,
    input  logic        burst_status_done,
    input  logic        burst_status_err
);

    localparam logic [31:0] EXT_SLAVE_BASE = 32'hF000_0000;
    localparam logic [2:0]  DMA_SIZE_DWORD = 3'b011; // 64-bit
    localparam logic [31:0] CTRL_BASE      = 32'hF0FF_F000;
    localparam logic [31:0] CTRL_MASK      = 32'hFFFF_F000;

    // FSM States
    typedef enum logic [3:0] {
        IDLE,
        READ_CMD,
        READ_WAIT,
        RMW_READ_CMD,
        RMW_READ_WAIT,
        WRITE_CMD,
        WRITE_DATA
    } state_t;

    state_t state_d, state_q;

    // Registers
    logic [31:0] addr_q;
    logic [31:0] wdata_q;
    logic [3:0]  be_q;
    logic        addr_lsb_q;
    logic [63:0] rmw_data_q; 
    logic        is_p2p_q;   
    
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

    // Address Translation
    logic [5:0]  dma_user_field;
    logic [31:0] dma_index_addr;
    logic        is_ctrl;
    logic [31:0] csr_rdata;

    // CSR Registers
    logic [13:0] dma_ctrl_q;
    logic [31:0] dma_addr_q;
    logic [31:0] dma_len_q;
    logic [31:0] xheep_addr_q;

    assign dma_user_field = addr_q[27:22];
    assign dma_index_addr = {10'b0, addr_q[21:0]}; 
    assign is_ctrl = (obi_req_i.addr & CTRL_MASK) == CTRL_BASE;

    assign burst_dir             = dma_ctrl_q[1];
    assign burst_read_user_field = dma_ctrl_q[7:2];
    assign burst_write_user_field = dma_ctrl_q[13:8];
    assign burst_addr_byte       = dma_addr_q;
    assign burst_len_bytes       = dma_len_q;
    assign burst_xheep_addr      = xheep_addr_q;

    always_comb begin
        csr_rdata = 32'b0;
        case (obi_req_i.addr[5:2])
            4'h0: csr_rdata[13:0] = dma_ctrl_q;
            4'h1: begin
                csr_rdata[0] = burst_status_busy;
                csr_rdata[1] = burst_status_done;
                csr_rdata[2] = burst_status_err;
            end
            4'h2: csr_rdata = dma_addr_q;
            4'h3: csr_rdata = dma_len_q;
            4'h4: csr_rdata = xheep_addr_q;
            default: csr_rdata = 32'b0;
        endcase
    end

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
        burst_start_pulse       = 1'b0;
        burst_status_clear_done = 1'b0;
        burst_status_clear_err  = 1'b0;

        case (state_q)
            IDLE: begin
                if (obi_req_i.req) begin
                    if (is_ctrl) begin
                        obi_gnt    = 1'b1;
                        obi_rvalid = 1'b1;
                        obi_rdata  = csr_rdata;
                        if (obi_req_i.we) begin
                            burst_start_pulse       = obi_req_i.wdata[0] && (obi_req_i.addr[5:2] == 4'h0);
                            burst_status_clear_done = obi_req_i.wdata[1] && (obi_req_i.addr[5:2] == 4'h1);
                            burst_status_clear_err  = obi_req_i.wdata[2] && (obi_req_i.addr[5:2] == 4'h1);
                        end
                    end else if (obi_req_i.we) begin
                        if (obi_req_i.addr[27:22] == 6'b0) begin
                            state_d = RMW_READ_CMD;
                        end else begin
                            state_d = WRITE_CMD;
                        end
                    end else begin
                        state_d = READ_CMD;
                    end
                end
            end

            // -----------------------------------------------------------------
            // Standard Read
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
                    obi_rdata = addr_lsb_q ? dma_read_chnl_data[63:32] : dma_read_chnl_data[31:0];
                    state_d = IDLE;
                end
            end

            // -----------------------------------------------------------------
            // RMW Read Phase
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
                    state_d = WRITE_CMD;
                end
            end

            // -----------------------------------------------------------------
            // Write Phase
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
                
                if (is_p2p_q) begin
                    // Direct Write (P2P)
                    if (addr_lsb_q) begin
                        dma_wr_data_out = {wdata_q, 32'b0};
                    end else begin
                        dma_wr_data_out = {32'b0, wdata_q};
                    end
                end else begin
                    // RMW Merge (Memory)
                    dma_wr_data_out = rmw_data_q;
                    if (addr_lsb_q) begin
                        // Upper 32 bits
                        if (be_q[0]) dma_wr_data_out[39:32] = wdata_q[7:0];
                        if (be_q[1]) dma_wr_data_out[47:40] = wdata_q[15:8];
                        if (be_q[2]) dma_wr_data_out[55:48] = wdata_q[23:16];
                        if (be_q[3]) dma_wr_data_out[63:56] = wdata_q[31:24];
                    end else begin
                        // Lower 32 bits
                        if (be_q[0]) dma_wr_data_out[7:0]   = wdata_q[7:0];
                        if (be_q[1]) dma_wr_data_out[15:8]  = wdata_q[15:8];
                        if (be_q[2]) dma_wr_data_out[23:16] = wdata_q[23:16];
                        if (be_q[3]) dma_wr_data_out[31:24] = wdata_q[31:24];
                    end
                end

                if (dma_write_chnl_ready) begin
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
            be_q        <= '0;
            addr_lsb_q  <= 1'b0;
            rmw_data_q  <= '0;
            is_p2p_q    <= 1'b0;
            dma_ctrl_q  <= '0;
            dma_addr_q  <= '0;
            dma_len_q   <= '0;
            xheep_addr_q <= '0;
        end else begin
            state_q <= state_d;

            // Latch Request info in IDLE
            if (state_q == IDLE && obi_req_i.req) begin
                addr_q      <= obi_req_i.addr;
                wdata_q     <= obi_req_i.wdata;
                be_q        <= obi_req_i.be;
                addr_lsb_q  <= obi_req_i.addr[2];
                if (obi_req_i.addr[27:22] != 6'b0) begin
                    is_p2p_q <= 1'b1;
                end else begin
                    is_p2p_q <= 1'b0;
                end
            end

            if (state_q == IDLE && obi_req_i.req && is_ctrl && obi_req_i.we) begin
                case (obi_req_i.addr[5:2])
                    4'h0: dma_ctrl_q <= obi_req_i.wdata[13:0];
                    4'h2: dma_addr_q <= obi_req_i.wdata;
                    4'h3: dma_len_q  <= obi_req_i.wdata;
                    4'h4: xheep_addr_q <= obi_req_i.wdata;
                    default: begin end
                endcase
            end
            
            // Capture RMW Read Data
            if (state_q == RMW_READ_WAIT && dma_read_chnl_valid) begin
                rmw_data_q <= dma_read_chnl_data;
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
    assign dma_read_ctrl_data_index  = dma_index_addr[31:3]; 
    assign dma_read_ctrl_data_length = 32'd1;        
    assign dma_read_ctrl_data_size   = DMA_SIZE_DWORD;
    assign dma_read_ctrl_data_user   = dma_user_field;

    assign dma_read_chnl_ready       = dma_rd_chnl_rdy;

    assign dma_write_ctrl_valid       = dma_wr_ctrl_vld;
    assign dma_write_ctrl_data_index  = dma_index_addr[31:3];
    assign dma_write_ctrl_data_length = 32'd1;
    assign dma_write_ctrl_data_size   = DMA_SIZE_DWORD;
    assign dma_write_ctrl_data_user   = dma_user_field;

    assign dma_write_chnl_valid       = dma_wr_chnl_vld;
    assign dma_write_chnl_data        = dma_wr_data_out;

endmodule
