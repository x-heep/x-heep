/*
 
  axi_to_flash_controller.sv
  Manager for W25Q128JW flash memory , AXI Subordinate.
 
  Uses a local scratchpad memory as sector buffer and a fifo as queue for AXI beats.
  RAM is not involved.

  ax_burst = INC , always.
 
  Author : Alessandro Barocci
 
  Based on XHEEP's w25q128jw_controller.sv

  FLASH DATASHEET : https://www.mouser.com/datasheet/2/949/W25Q128JW_RevB_11042019-1761358.pdf?srsltid=AfmBOopmMreOM8jLZ_O6yIwuR8ep6A4olsQW1t1oNTz8bvuKFsv5xtqs
  AXI PROTOCOL : https://developer.arm.com/documentation/ihi0022/latest

  CONDITION : 
    spi_host tx_fifo must be at least 64 words deep
    rx_fifo can be smaller because we read a flash word as soon as it enters the fifo, even if we demand all 1024 sector words in one command
    tx_fifo however requires first all 64 page program words to be in the tx_fifo, then they are released out to the flash after a command to spi_host

 */
 
module axi_to_flash_controller #(
  localparam int MaxBeats = 17,
  localparam int MaxBeatsDW = sizeInBits(MaxBeats+1),
  localparam int PageCountDW = sizeInBits(SE_PSIZE+1),
  localparam int SectorBufferLatency = 1,
  localparam int SecBuffLatencyDW = sizeInBits(SectorBufferLatency+1),
  localparam int w25q128jw_tRES1_us = 30, // from datasheet p. 64
  parameter int ClockFrequencyMAX_MHz = 1e3,
  localparam int PowerOnWaitCycles = ClockFrequencyMAX_MHz * w25q128jw_tRES1_us,
  localparam int PoweronWaitCycles_SIM = 300,
  localparam int PowerOnWaitCyclesDW = sizeInBits(PowerOnWaitCycles+1),
  localparam int SPI_FLASH_TX_FIFO_DEPTH = spi_host_reg_pkg::TxDepth,
  parameter logic ByteOrder = 1, // 1 == Little Endian , 0 == Big Endian  ; if 0 then beat_queues will swap bytes.
  parameter int AddrWidth = 64,
  parameter int FlashAddrW = 24,
  parameter int DataWidth = 64,
  parameter int DataBytes = DataWidth/8,
  parameter int RegDataWidth = 32,
  parameter type axi_req_t = logic,
  parameter type axi_resp_t = logic,
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic
)(
  input logic clk_i,
  input logic rst_ni,

  // Enable from spi_subsystem register
  input logic en_i,

  // Enable power-on sub-rutine
  input logic poweron_en_i,

  // Enable quad spi
  input logic quadspi_en_i,

  // Master ports to the SPI HOST
  output reg_req_t spi_host_reg_req_o,
  input  reg_rsp_t spi_host_reg_rsp_i,

  // spi_host hw2reg status register direct access
  input spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status_i,

  // AXI interface
  input  axi_req_t  axi_req_i,
  output axi_resp_t axi_rsp_o

);

  // ------------------------------------------------ AXI interface renaming ------------------------------------------------ //
  localparam int lenDW = 8;
  localparam int sizeDW = 3;
  
  logic [AddrWidth-1:0]     aw_addr;
  logic [sizeDW-1:0]        aw_size;
  logic [lenDW-1:0]         aw_len;
  logic                     aw_valid;
  logic                     aw_ready;
  // AXI - Write Data Channel
  logic [DataWidth-1:0]     w_data;
  logic [DataBytes-1:0]     w_strb;
  logic                     w_last;
  logic                     w_valid;
  logic                     w_ready;
  // AXI - Response Channel
  logic                     b_valid;
  logic                     b_ready;
  // AXI - Read Address Channel
  logic [AddrWidth-1:0]     ar_addr;
  logic [sizeDW-1:0]        ar_size;
  logic [lenDW-1:0]         ar_len;
  logic                     ar_valid;
  logic                     ar_ready;
  // AXI - Read Data Channel
  logic [DataWidth-1:0]     r_data;
  logic                     r_last;
  logic                     r_valid;
  logic                     r_ready;
  // Assignments
  always_comb begin
    aw_addr  = axi_req_i.aw.addr;
    aw_size  = axi_req_i.aw.size;
    aw_len   = axi_req_i.aw.len;
    aw_valid = axi_req_i.aw_valid;
    w_data   = axi_req_i.w.data;
    w_strb   = axi_req_i.w.strb;
    w_last   = axi_req_i.w.last;
    w_valid  = axi_req_i.w_valid;
    b_ready  = axi_req_i.b_ready;
    ar_addr  = axi_req_i.ar.addr;
    ar_size  = axi_req_i.ar.size;
    ar_len   = axi_req_i.ar.len;
    ar_valid = axi_req_i.ar_valid;
    r_ready  = axi_req_i.r_ready;

    axi_rsp_o.aw_ready = aw_ready;
    axi_rsp_o.w_ready  = w_ready;
    axi_rsp_o.b_valid  = b_valid;
    axi_rsp_o.ar_ready = ar_ready;
    axi_rsp_o.r.data   = r_data;
    axi_rsp_o.r.last   = r_last;
    axi_rsp_o.r_valid  = r_valid;
  end
  // ------------------------------------------------------------------------------------------------------------------------ //

  // Assert data width flag
  logic [DataWidth-1:0] A;
  logic datawidth_is_64_n32;
  always_comb begin
    A[DataWidth-1] = '1;
    A = A >> 32;
    datawidth_is_64_n32 = A[0];
  end

  // ---------------------------- Flash commands ----------------------------
  localparam logic [12:0] FC_RD = 13'h03,     // Read Data
                          FC_RDQIO = 13'heb,  // Read Data
                          FC_PO = 13'hab,     // Power On
                          FC_RSR1 = 13'h05,   // Read Status Register 1
                          FC_WE = 13'h06,     // Write Enable
                          FC_SE = 13'h20,     // Sector Erase 4KB
                          FC_PP = 13'h02,     // Page Program
                          FC_PPQ = 13'h32,    // Page Program Quad
  // --------------------------------------------------------------------------------

  // ---------------------------- Flash size constatnts ----------------------------
                          SE_WSIZE = 13'h400,                         // Sector size in words
                          SE_BSIZE = 13'h1000,                        // Sector size in bytes
                          PAGE_WSIZE = 13'h40,                        // Page size in words
                          PAGE_BSIZE = 13'h100;                       // Page size in bytes
  localparam int          SE_WSIZE_DW = sizeInBits(32'(SE_WSIZE+1));  // Used for signa declaration
  localparam int          SE_PSIZE = 32'(SE_WSIZE) / 32'(PAGE_WSIZE); // Sector size in pages
  // --------------------------------------------------------------------------------

  // Byte swap function
  function automatic [31:0] bitfield_byteswap32(input [31:0] adress_to_swap);
    bitfield_byteswap32 = {
      adress_to_swap[7:0],  // Byte 0 -> Byte 3
      adress_to_swap[15:8],  // Byte 1 -> Byte 2
      adress_to_swap[23:16],  // Byte 2 -> Byte 1
      adress_to_swap[31:24]  // Byte 3 -> Byte 0
    };
  endfunction

  // Function to compute data size in bits
  function automatic int sizeInBits (input int value);
    int i;
    if (value > 1) begin
      begin
        value = value - 1;
        for (i = 0; value > 0; i = i + 1)
          value = value >> 1;
        return i;
      end
    end else return 1;
  endfunction

  /*
                                            ────────────────────────────────────────
                                                       SFM STATE DEFINITION
                                            
  */

  // ============================================== TOP SFM ============================================== //
  // Each state is a sub-sfm
  typedef enum logic [sizeInBits(9)-1:0] {
    TOP_IDLE,     // Wait for valid AXI request
    TOP_AXIREQ,   // Memorize data from AXI manager
    TOP_POWERON,  // Issue the power-on command to the flash and wait cycles before operating, if enabled.
    TOP_READ,     // Store beats into queue or store sector into sector buffer, from flash.
    TOP_FWAIT,    // Wait for flash ready status.
    TOP_ERASE,    // Erase flash sector
    TOP_MODIFY,   // Modify sector buffer with write data
    TOP_WRITE,    // Page program the flash sector with modified buffer content
    TOP_AXIRESP   // Respond to AXI master
  } top_state_e;
  // ===================================================================================================== //


  // =========================================== AXIREQ SFM ============================================== //
  // Handles AXI request
  typedef enum logic [sizeInBits(4)-1:0] {
    AXIREQ_IDLE,       // Clear beat queues
    AXIREQ_AR,         // Answer to AR channel request
    AXIREQ_AW,         // Answer to AW channel request
    AXIREQ_W           // Answer to W channel request
  } axireq_state_e;
  // ===================================================================================================== //


  // =========================================== POWERON SFM ============================================== //
  // Sends the power on command to the flash. Executed once if enabled and if not yet executed since reset.
  typedef enum logic [sizeInBits(6)-1:0] {
    POWERON_IDLE,                 
    POWERON_SPI_CHECK_TX_FIFO,    // Check whether tx_fifo has room
    POWERON_SPI_FILL_TX_FIFO,     // Write power-on command into tx_fifo (FC_PO)
    POWERON_SPI_WAIT_READY,       // Wait for spi_host to be ready
    POWERON_SPI_SEND_CMD,         // send command to spi_host to release tx_fifo data to flash
    POWERON_WAIT_CYCLES           // Wait cycles before normal operation
  } poweron_state_e;
  // ===================================================================================================== //


  // =========================================== READ SFM ================================================ //
  // Handles flash read operation
  typedef enum logic [sizeInBits(26)-1:0] {
    READ_IDLE,               // In write, skip sector read if redundant. Evaluate flash access address
    READ_SET_RXWM_R,         // Read spi_host control register
    READ_SET_RXWM_W,         // Rewrite control register with rx_fifo watermark set to 1, to be immediately warned when flash data arrives
    READ_SPI_CHECK_TX_FIFO,  // Check whether tx_fifo has room
    
    // Standard spi branch
    READ_SPI_FILL_TX_FIFO,   // Write standard read command (FC_RD) + address to tx_fifo
    READ_SPI_WAIT_READY_1,   // Wait for spi_host to be ready
    READ_SPI_SEND_CMD_1,     // Send command to spi_host to release tx_fifo data to flash
    READ_SPI_WAIT_READY_2,   // Wait for spi_host to be ready
    READ_SPI_SEND_CMD_2,     // Send command to spi_host to receive data from flash into rx_fifo
    
    // Quad spi branch
    READ_QUAD_SPI_FILL_TX_FIFO_1,       // Write quad spi read command (FC_RDQIO) to tx_fifo
    READ_QUAD_SPI_WAIT_READY_1,         // Wait for spi_host to be ready
    READ_QUAD_SPI_SEND_CMD_1,           // Send command to spi_host to release tx_fifo data to flash
    READ_QUAD_SPI_CHECK_TX_FIFO_2,      // Check whether tx_fifo has room
    READ_QUAD_SPI_FILL_TX_FIFO_2,       // Write address to tx_fifo
    READ_QUAD_SPI_WAIT_READY_2,         // Wait for spi_host to be ready
    READ_QUAD_SPI_SEND_CMD_2,           // Send command to spi_host to release tx_fifo data to flash (at quad speed) 
    READ_QUAD_SPI_WAIT_READY_3,         // Wait for spi_host to be ready
    READ_QUAD_SPI_SEND_CMD_3,           // Send command to spi_host to execute dummy flash read cycles (at quad speed)
    READ_QUAD_SPI_WAIT_READY_4,         // Wait for spi_host to be ready 
    READ_QUAD_SPI_SEND_CMD_4,           // Send command to spi_host to receive data from flash into rx_fifo (at quad speed)

    READ_WAIT_RXWM,          // Check whether data is present in rx_fifo
    READ_W_SECTOR_STORE,     // Only write : store the beat's sector inside the local sector buffer, word by word.
    READ_R_BEAT_PUSH_DW32,   // Only read , 32 bits : store current beat inside local buffer
    READ_R_BEAT_PUSH_DW64_1, // Only read , 64 bits : store current beat inside local buffer
    READ_R_BEAT_PUSH_DW64_2, // Only read , 64 bits : store current beat inside local buffer  
    READ_R_BEAT_PUSH_FIN     // Only read , store current beat inside rd_beat_queue
  } read_state_e;
  // ===================================================================================================== //


  // =========================================== FWAIT SFM ================================================ //
  // Waits for flash internal operations to complete by polling the flash status register (Read Status Register 1)
  typedef enum logic [sizeInBits(11)-1:0] {
    FWAIT_IDLE,
    FWAIT_SET_RXWM_R,         // Read spi_host control register
    FWAIT_SET_RXWM_W,         // Rewrite control register with rx_fifo watermark set to 1, to be immediately warned when flash data arrives
    FWAIT_SPI_CHECK_TX_FIFO,  // Check whether tx_fifo has room
    FWAIT_SPI_FILL_TX_FIFO,   // Write Read Status Register 1 command (FC_RSR1) in tx_fifo
    FWAIT_SPI_WAIT_READY_1,   // Wait for spi_host ready
    FWAIT_SPI_SEND_CMD_1,     // Send command to spi_host to release tx_fifo data to flash
    FWAIT_SPI_WAIT_READY_2,   // Wait for spi_host to be ready
    FWAIT_SPI_SEND_CMD_2,     // Send command to spi_host to receive status from flash into rx_fifo
    FWAIT_WAIT_RXWM,          // Check whether data is present in rx_fifo
    FWAIT_READ_FLASH_STATUS   // Check status, if ready redirect to next top_state, otherwise repeat TOP_FWAIT.
  } fwait_state_e;
  // ===================================================================================================== //


  // =========================================== ERASE SFM ================================================ //
  // Erases a flash sector before writing
  typedef enum logic [sizeInBits(9)-1:0] {
    ERASE_IDLE,              // Evaluate skip_write flag, to postpone TOP_ERASE and TOP_WRITE to the next beat if possible
    ERASE_WE_CHECK_TX_FIFO,  // Check whether tx_fifo has room
    ERASE_WE_FILL_TX_FIFO,   // Write Write Enable command (FC_WE) in tx_fifo
    ERASE_WE_WAIT_READY,     // Wait for spi_host to be ready
    ERASE_WE_SEND_CMD,       // Send command to spi_host to release tx_fifo data to flash
    ERASE_SE_CHECK_TX_FIFO,  // Check whether tx_fifo has room
    ERASE_SE_FILL_TX_FIFO,   // Write Sector Erase command (FC_SE) + address in tx_fifo
    ERASE_SE_WAIT_READY,     // Wait for spi_host to be ready
    ERASE_SE_SEND_CMD        // Send command to spi_host to release tx_fifo data to flash
  } erase_state_e;
  // ===================================================================================================== //


  // =========================================== MODIFY SFM ================================================ //
  // Overwrite the sector in the buffer with the write beat
  typedef enum logic [sizeInBits(7)-1:0] {
    MODIFY_IDLE,
    MODIFY_BEAT_POP,              // Pop write beat from wr_beat_queue
    MODIFY_SECTOR_UPDATE_DW32_1,  // Update sector with new data (32 bit case) (1 of 2)
    MODIFY_SECTOR_UPDATE_DW32_2,  // Update sector with new data (32 bit case) (2 of 2)
    MODIFY_SECTOR_UPDATE_DW64_1,  // Update sector with new data (64 bit case) (1 of 3)
    MODIFY_SECTOR_UPDATE_DW64_2,  // Update sector with new data (64 bit case) (2 of 3)
    MODIFY_SECTOR_UPDATE_DW64_3   // Update sector with new data (64 bit case) (3 of 3)
  } modify_state_e;
  // ===================================================================================================== //


  // =========================================== WRITE SFM ================================================ //
  // Programs sector buffer into flash, page by page
  typedef enum logic [sizeInBits(14)-1:0] {
    WRITE_IDLE,              // Check skip_write to postpone write or not.
    WRITE_WE_CHECK_TX_FIFO,  // Check whether tx_fifo has room
    WRITE_WE_FILL_TX_FIFO,   // Write Write Enable command (FC_WE) in tx_fifo
    WRITE_WE_WAIT_READY,     // Wait for spi_host to be ready
    WRITE_WE_SEND_CMD,       // Send command to spi_host to release tx_fifo data to flash
    WRITE_PP_CHECK_TX_FIFO,  // Check whether tx_fifo has room
    WRITE_PP_FILL_TX_FIFO,   // Write Page Program command (FC_PP) + address in tx_fifo
    WRITE_PP_WAIT_READY,     // Wait for spi_host to be ready
    WRITE_PP_SEND_CMD,       // Send command to spi_host to release tx_fifo data to flash
    WRITE_PP_PAGE_WRITE_1,   // Send read request to sector buffer
    WRITE_PP_PAGE_WRITE_2,   // Save read 32 bit word into a register
    WRITE_PP_PAGE_WRITE_3,   // Check whether tx_fifo has room
    WRITE_PP_PAGE_WRITE_4,   // Store 32 bit word in tx_fifo, repeat 64 times.
    WRITE_PP_WAIT_READY_2,   // Wait for spi_host to be ready
    WRITE_PP_SEND_CMD_2      // Send command to spi_host to release tx_fifo data to flash, repat TOP_WRITE until sector is written
  } write_state_e;
  // ===================================================================================================== //


  // =========================================== AXIRESP SFM ================================================ //
  typedef enum logic [sizeInBits(3)-1:0] {
    AXIRESP_IDLE,
    AXIRESP_B,         // Make response in B channel
    AXIRESP_R          // Make response in R channel
  } axiresp_state_e;
  // ===================================================================================================== //


  /*

          SFM flow : 

           - Read  (rnw=1): TOP_IDLE -> TOP_AXIREQ -> TOP_READ -> TOP_AXIRESP -> TOP_IDLE
           
           - Write (rnw=0): TOP_IDLE -> TOP_AXIREQ -> TOP_READ -> TOP_FWAIT -> TOP_ERASE -> TOP_FWAIT -> 
                            TOP_MODIFY -> TOP_WRITE -> TOP_FWAIT -> TOP_AXIRESP -> TOP_IDLE



                                                  ────────────────────────────────────────
                                                       states and register definitons
                                                       
  */

  // FSM states
  top_state_e     top_state_q     , top_state_d;
  axireq_state_e  axireq_state_q  , axireq_state_d;
  poweron_state_e poweron_state_q , poweron_state_d;
  read_state_e    read_state_q    , read_state_d;
  erase_state_e   erase_state_q   , erase_state_d;
  fwait_state_e   fwait_state_q   , fwait_state_d;
  modify_state_e  modify_state_q  , modify_state_d;
  write_state_e   write_state_q   , write_state_d;
  axiresp_state_e axiresp_state_q , axiresp_state_d;

  // Registers and counters
  logic [MaxBeatsDW-1:0]             beat_count_q           , beat_count_d;
  logic [AddrWidth-1:0]              beat_addr_q            , beat_addr_d;
  logic [AddrWidth-1:0]              first_beat_addr_q      , first_beat_addr_d;
  logic [MaxBeatsDW-1:0]             beat_number_q          , beat_number_d;
  logic [DataBytes-1:0]              beat_size_q            , beat_size_d;
  logic                              rnw_q                  , rnw_d;
  logic [PowerOnWaitCyclesDW-1:0]    poweron_wait_count_q   , poweron_wait_count_d;
  logic                              flash_is_on_q          , flash_is_on_d;
  logic [FlashAddrW-1:0]             flash_addr_q           , flash_addr_d;
  logic [RegDataWidth-1:0]           spi_host_control_q     , spi_host_control_d;
  logic                              beat_half_index_q      , beat_half_index_d;
  logic [SE_WSIZE_DW-1:0]            word_count_q           , word_count_d;
  logic [DataWidth-1:0]              rd_queue_buffer_q      , rd_queue_buffer_d;
  logic [DataWidth-1:0]              wr_queue_buffer_data_q , wr_queue_buffer_data_d;
  logic [DataBytes-1:0]              wr_queue_buffer_be_q   , wr_queue_buffer_be_d;  
  logic [1:0]                        fwait_cnt_q            , fwait_cnt_d;
  logic                              skip_write_q           , skip_write_d;
  logic [PageCountDW-1:0]            page_count_q           , page_count_d;
  logic [SecBuffLatencyDW-1:0]       wait_latency_count_q   , wait_latency_count_d;
  logic [SectorBuffer_DataWidth-1:0] sec_buf_buffer_q       , sec_buf_buffer_d;

  /*
                                          ────────────────────────────────────────
                                                    SFM SEQUENTIAL LOGIC

  */

  // // // FSM sequential logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin

      // ----------------------------------------------------------- Reset

      // --------------------------- States
      top_state_q     <= TOP_IDLE;
      axireq_state_q  <= AXIREQ_IDLE;
      poweron_state_q <= POWERON_IDLE;
      read_state_q    <= READ_IDLE;
      erase_state_q   <= ERASE_IDLE;
      fwait_state_q   <= FWAIT_IDLE;
      modify_state_q  <= MODIFY_IDLE;
      write_state_q   <= WRITE_IDLE;
      axiresp_state_q <= AXIRESP_IDLE;

      // --------------------------- Registers and Counters
      beat_count_q           <= '0;
      beat_addr_q            <= '0;
      first_beat_addr_q      <= '0;
      beat_number_q          <= '0;
      beat_size_q            <= '0;
      rnw_q                  <= '0;
      poweron_wait_count_q   <= '0;
      flash_is_on_q          <= '0;
      flash_addr_q           <= '0;
      spi_host_control_q     <= '0;
      beat_half_index_q      <= '0;
      word_count_q           <= '0;
      rd_queue_buffer_q      <= '0;
      wr_queue_buffer_data_q <= '0;
      wr_queue_buffer_be_q   <= '0;
      fwait_cnt_q            <= '0;
      skip_write_q           <= '0;
      page_count_q           <= '0;
      wait_latency_count_q   <= '0;
      sec_buf_buffer_q       <= '0;
      
    end else begin
      // ----------------------------------------------------------------------- Sampling

      // ----------------------------------------- States
      top_state_q            <= top_state_d;
      axireq_state_q         <= axireq_state_d;
      poweron_state_q        <= poweron_state_d;
      read_state_q           <= read_state_d;
      erase_state_q          <= erase_state_d;
      fwait_state_q          <= fwait_state_d;
      modify_state_q         <= modify_state_d;
      write_state_q          <= write_state_d;
      axiresp_state_q        <= axiresp_state_d;

      // ----------------------------------------- Registers and Counters
      beat_count_q           <= beat_count_d;
      beat_addr_q            <= beat_addr_d;
      first_beat_addr_q      <= first_beat_addr_d;
      beat_number_q          <= beat_number_d;
      beat_size_q            <= beat_size_d;
      rnw_q                  <= rnw_d;
      poweron_wait_count_q   <= poweron_wait_count_d;
      flash_is_on_q          <= flash_is_on_d;
      flash_addr_q           <= flash_addr_d;
      spi_host_control_q     <= spi_host_control_d;
      beat_half_index_q      <= beat_half_index_d;
      word_count_q           <= word_count_d;
      rd_queue_buffer_q      <= rd_queue_buffer_d;
      wr_queue_buffer_data_q <= wr_queue_buffer_data_d;
      wr_queue_buffer_be_q   <= wr_queue_buffer_be_d;  
      fwait_cnt_q            <= fwait_cnt_d;
      skip_write_q           <= skip_write_d;
      page_count_q           <= page_count_d;
      wait_latency_count_q   <= wait_latency_count_d;
      sec_buf_buffer_q       <= sec_buf_buffer_d;    

    end
  end

  // reg_req.addr to spi_host -> only the offset changes
  logic [spi_host_reg_pkg::BlockAw-1:0] spi_host_reg_req_offset;
  //assign spi_host_reg_req_o.addr = core_v_mini_mcu_pkg::SPI_FLASH_START_ADDRESS + {{(64 - spi_host_reg_pkg::BlockAw){1'b0}}, spi_host_reg_req_offset};
  // is the offset from the package actaully useful? 
  localparam [AddrWidth-1:0] SPI_FLASH_START_ADDRESS = 0;
  assign spi_host_reg_req_o.addr = SPI_FLASH_START_ADDRESS + {{(64 - spi_host_reg_pkg::BlockAw){1'b0}}, spi_host_reg_req_offset};

// To shorten the simulation and to allow a smaller watchdog in the testbench, reduce the number of cycles waited inside the power-on rutine
int actual_poweron_wait_cycles;
`ifndef FPGA_SYNTHESIS
`ifndef SYNTHESIS
  assign actual_poweron_wait_cycles = PoweronWaitCycles_SIM;
`else
  assign actual_poweron_wait_cycles = PoweronWaitCycles;
`endif
`else
  assign actual_poweron_wait_cycles = PoweronWaitCycles;
`endif

/*
                                          ┌────────────────────────────────────────┐
                                          │                  SFM                   │
                                          └────────────────────────────────────────┘


                                          ──────────────────────────────────────────
                                                    SFM COMBINATIONAL LOGIC

*/
  always_comb begin
    // ---------------------------------------------------- default values

    // --------------------------------------- States
    top_state_d     = top_state_q;
    axireq_state_d  = axireq_state_q;
    poweron_state_d = poweron_state_q;
    read_state_d    = read_state_q;
    erase_state_d   = erase_state_q;
    fwait_state_d   = fwait_state_q;
    modify_state_d  = modify_state_q;
    write_state_d   = write_state_q;
    axiresp_state_d = axiresp_state_q;

    // --------------------------------------- Registers
    beat_count_d           = beat_count_q;
    beat_addr_d            = beat_addr_q;
    first_beat_addr_d      = first_beat_addr_q;
    beat_number_d          = beat_number_q;
    beat_size_d            = beat_size_q;
    rnw_d                  = rnw_q;
    poweron_wait_count_d   = poweron_wait_count_q;
    flash_is_on_d          = flash_is_on_q;
    flash_addr_d           = flash_addr_q;
    spi_host_control_d     = spi_host_control_q;
    beat_half_index_d      = beat_half_index_q;
    word_count_d           = word_count_q;
    rd_queue_buffer_d      = rd_queue_buffer_q;
    wr_queue_buffer_data_d = wr_queue_buffer_data_q;
    wr_queue_buffer_be_d   = wr_queue_buffer_be_q; 
    fwait_cnt_d            = fwait_cnt_q;
    skip_write_d           = skip_write_q;
    page_count_d           = page_count_q;
    wait_latency_count_d   = wait_latency_count_q;
    sec_buf_buffer_d       = sec_buf_buffer_q;

    // --------------------------------------- AXI
    ar_ready = 1'b0;
    aw_ready = 1'b0;
    w_ready = 1'b0;
    b_valid = 1'b0;
    r_valid = 1'b0;
    r_last = 1'b0;
    r_data = '0;

    // --------------------------------------- Queues
    axi2fls_wr_valid = '0;
    axi2fls_wr_data = '0;
    axi2fls_wr_be = '0;
    spihost_wr_ready = '0;
    spihost_rd_valid = '0;
    spihost_rd_data = '0;
    clear_queues = '0;

    // --------------------------------------- Sector buffer
    sect_buffer_req = 1'b0;
    sect_buffer_we = 1'b0;
    sect_buffer_addr = '0;
    sect_buffer_wdata ='0;
    sect_buffer_be = 4'b0000;

    // --------------------------------------- spi_host Register interface
    spi_host_reg_req_o.valid = 1'b0;
    spi_host_reg_req_o.wstrb = 4'b1111;
    spi_host_reg_req_o.write = 1'b0;
    spi_host_reg_req_o.wdata = '0;
    spi_host_reg_req_offset  = '0;

    /*
                                                  ==========================================================
                                                  |                         TOP SFM                        |
                                                  ==========================================================
    */
    case (top_state_q)
      TOP_IDLE: begin
        // Wait for a valid request from AR channel or W and AW
        if (en_i) begin
          if ( (aw_valid && w_valid) || ar_valid ) begin
            top_state_d = TOP_AXIREQ;
            axireq_state_d = AXIREQ_IDLE;
          end
        end
      end

    /*
                                                  ==========================================================
                                                  |                       AXIREQ SFM                       |
                                                  ==========================================================
    */
      TOP_AXIREQ: begin
        case(axireq_state_q)

          AXIREQ_IDLE: begin
            // Extract data from AXI request channels
            // Clear the beat queues
            clear_queues = 1'b1;
            // Reset beat counter
            beat_count_d = 0;
            // Next state evaluation
            if (aw_valid && w_valid) axireq_state_d = AXIREQ_AW;
            if (ar_valid)            axireq_state_d = AXIREQ_AR;
          end

          AXIREQ_AR: begin
            // Answer to the AR channel
            rnw_d = 1'b1;
            first_beat_addr_d = ar_addr;
            beat_addr_d = ar_addr;
            beat_number_d = ar_len + 1;
            beat_size_d = 1 << ar_size;
            ar_ready = 1'b1;
            // Next state evaluation
            if (~flash_is_on_q && poweron_en_i) begin
              // if, since last reset, the flash has not been powered on, the POWERON sfm needs to be executed to send the power-on command to the flash
              // POWERON can be bypassed by keeping poweron_en_i low.
              axireq_state_d = AXIREQ_IDLE;
              top_state_d = TOP_POWERON;
            end
            else begin
              // Otherwise, we can go on with the normal operation
              axireq_state_d = AXIREQ_IDLE;
              top_state_d = TOP_READ;
            end
          end

          AXIREQ_AW: begin
            // Answer to the AW channel
            rnw_d = 1'b0;
            first_beat_addr_d = aw_addr;
            beat_addr_d = aw_addr;
            beat_number_d = aw_len + 1;
            beat_size_d = 1 << aw_size;
            aw_ready = 1'b1;
            // Next state evaluation
            axireq_state_d = AXIREQ_W;
          end

          AXIREQ_W: begin
            // Answer to the W channel
            logic [AddrWidth-1:0]                 beat_addr_at_beat_count;
            logic [sizeInBits(DataBytes-1)-1:0]   lower_byte_lane, upper_byte_lane;
            logic [AddrWidth-1:0]                 alligned_beat_addr = (first_beat_addr_q / beat_size_q) * beat_size_q;
            int n;

            // Here w_data is put into the wr_beat_queue, however we need to be concious about which byte lanes in w_data are active for the current beat
            // They are function of the beat size and address
            if (w_valid) begin
              axi2fls_wr_valid = 1'b1;
              // Define the bytelanes
              if (beat_count_q == 0) begin
                lower_byte_lane = first_beat_addr_q - (first_beat_addr_q / DataBytes)*DataBytes;
                upper_byte_lane = alligned_beat_addr - (first_beat_addr_q / DataBytes)*DataBytes + (beat_size_q - 1);
              end
              if (beat_count_q > 0) begin
                beat_addr_at_beat_count = alligned_beat_addr + (beat_count_q)*beat_size_q;
                lower_byte_lane = beat_addr_at_beat_count - (first_beat_addr_q / DataBytes)*DataBytes;
                upper_byte_lane = lower_byte_lane + (beat_size_q - 1);
              end
              // Extract data from the correct byte lanes inside w_data
              axi2fls_wr_data = '0;
              axi2fls_wr_be = '0;
              n = 0;
              for (int i = lower_byte_lane ; i <= upper_byte_lane ; i++) begin
                // axi2fls_wr_data[n*8+7:n*8] =  w_data[i*8+7:i*8];
                axi2fls_wr_data[n*8 +: 8] = w_data[i*8 +: 8];
                axi2fls_wr_be[n] = w_strb[i];
                n++;
              end
              // As the queue samples, respond to write channel
              if (axi2fls_wr_ready) begin
                w_ready = 1'b1;
                // counter needs to be resused, after this state we want it to reset
                beat_count_d = w_last ? 0 : beat_count_q + 1;
              end
            end
            // Next state evaluation
            if ( w_valid && axi2fls_wr_ready && w_last ) begin
              if (~flash_is_on_q && poweron_en_i) begin
                // If, since last reset, the flash has not been powered on, the POWERON sfm needs to be executed to issue the power-on command
                // POWERON can be bypassed by keeping poweron_en_i low.
                axireq_state_d = AXIREQ_IDLE;
                top_state_d = TOP_POWERON;
              end
              else begin
                // otherwise, we can go on with the normal operation
                axireq_state_d = AXIREQ_IDLE;
                top_state_d = TOP_READ;
              end
            end
          end

        default: begin
          axireq_state_d = AXIREQ_IDLE;
        end
        endcase
      end


    /*
                                                  ==========================================================
                                                  |                       POWERON SFM                      |
                                                  ==========================================================
    */
      TOP_POWERON: begin
        case(poweron_state_q)

          POWERON_IDLE: begin
            poweron_state_d = POWERON_SPI_CHECK_TX_FIFO;
          end

          POWERON_SPI_CHECK_TX_FIFO: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              poweron_state_d = POWERON_SPI_FILL_TX_FIFO;
            end
          end

          POWERON_SPI_FILL_TX_FIFO: begin
            // Write "power on" command in tx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'b0, FC_PO};
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              poweron_state_d = POWERON_SPI_WAIT_READY;
            end
          end

          POWERON_SPI_WAIT_READY: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin 
              poweron_state_d = POWERON_SPI_SEND_CMD;
            end
          end

          POWERON_SPI_SEND_CMD: begin
            // Send command to spi_host : send power on command to flash 
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [24]    = CSAAT (1 = keep CS asserted for next command)
            //   [23:0]  = Length-1 (0 = 1 byte) (FC_OP is 1 byte command)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              poweron_state_d = POWERON_WAIT_CYCLES;
            end
          end

          POWERON_WAIT_CYCLES: begin
            poweron_wait_count_d = poweron_wait_count_q + 1;
            if (poweron_wait_count_d == actual_poweron_wait_cycles) flash_is_on_d = 1'b1;
            // Next state evaluation
            if (poweron_wait_count_d == actual_poweron_wait_cycles) begin
              poweron_state_d = POWERON_IDLE;
              top_state_d = TOP_READ;
            end
          end

          default: begin
            poweron_state_d = POWERON_IDLE;
          end
        endcase
      end


    /*
                                                  ==========================================================
                                                  |                       READ SFM                         |
                                                  ==========================================================
    */
      TOP_READ: begin
        case (read_state_q)

          READ_IDLE: begin
            // evaluate flash_addr to send to the flash and skip_sector_read
            logic skip_sector_read;
            logic [FlashAddrW-1:0] previous_flash_addr = flash_addr_q;
            logic [AddrWidth-1:0] sector_address_of_beat = (beat_addr_q >> 12) << 12;
            // Note : Flash address is byte-precise and 24 bits wide
            
            // Flash_addr evaluation
            flash_addr_d = rnw_q ? beat_addr_q[FlashAddrW-1:0] : sector_address_of_beat[FlashAddrW-1:0];

            // skip_sector_read evaluation
            // We want to skip the sector storage into the sector buffer in case nothing would change from the previous beat
            // Skip the sector read if :
            // We are writing
            // The sector base address sent to the flash would be the equal to the previous
            // it is not the first beat
            skip_sector_read = ((flash_addr_d == previous_flash_addr) && ~rnw_q && beat_count_q > 0 ) ? 1'b1 : 1'b0; 
            // Next state evaluation
            if (skip_sector_read) begin
              read_state_d = READ_IDLE;
              top_state_d = TOP_FWAIT;
            end else begin
              read_state_d = READ_SET_RXWM_R;
            end
          end

          READ_SET_RXWM_R: begin
            // Set RX watermark to 1 word so we get notified when status byte arrives
            // but we need to preserve other bits when modifying RXWM
            // this is why here we first read the entire spi_host control register to then write back the rest of the bits alongside the new wm
            // Read the control register:
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_CONTROL_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              spi_host_control_d = spi_host_reg_rsp_i.rdata;
            end
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SET_RXWM_W;
            end
          end

          READ_SET_RXWM_W: begin
            // Rewrite the command with updated wm:
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_CONTROL_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            // Keep upper CONTROL bits, set RXWM = 1
            spi_host_reg_req_o.wdata = {
              spi_host_control_q[31:8], 8'h01
            };  
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_CHECK_TX_FIFO;
            end
          end

          READ_SPI_CHECK_TX_FIFO: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            // At this point, given the value of quadspi_en_i (from external top register), it is decided the speed of the spi read
            // A different branch in the TOP_READ FSM is taken depending on the spi speed
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              if (~quadspi_en_i) read_state_d = READ_SPI_FILL_TX_FIFO;
              if ( quadspi_en_i) read_state_d = READ_QUAD_SPI_FILL_TX_FIFO_1;
            end
          end

          READ_SPI_FILL_TX_FIFO: begin
            // Here starts the standard spi speed read branch
            // Write standard read command + flash address in tx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata =  {
              (bitfield_byteswap32({ 8'h00 , flash_addr_q })) | {19'h0, FC_RD}
            };
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_WAIT_READY_1;
            end
          end

          READ_SPI_WAIT_READY_1: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_1;
            end
          end

          READ_SPI_SEND_CMD_1: begin
            // Send command to spi_host : send standard read command and address to flash 
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (1 = keep CS asserted for next command)
            //   [23:0]  = Length-1 (3 = 4 bytes: 1 command + 3 address)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h1, 24'h3
            }; // Reserved + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_WAIT_READY_2;
            end
          end

          READ_SPI_WAIT_READY_2: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_2;
            end
          end

          READ_SPI_SEND_CMD_2: begin
            // Send command to spi_host : store flash content into rx_fifo from flash
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (1 = RX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
            //   [23:0]  = Length-1 (See comments below)
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            if (rnw_q) begin
              // READ: receive a number of bytes specified by axi (beat_size) (up to 8 bytes)
              spi_host_reg_req_o.wdata = {
                3'h0, 2'h1, 2'h0, 1'h0,  {16'h0 , (8'h0 | (beat_size_q - 1'h1))}
              }; // Empty + Direction + Speed + Csaat + Length
            end
            if (~rnw_q) begin
              // WRITE: read full sector (4096 bytes)
              spi_host_reg_req_o.wdata = {
                3'h0, 2'h1, 2'h0, 1'h0, {11'b0, SE_BSIZE - 1'h1}
              }; // Empty + Direction + Speed + Csaat + Length
              word_count_d = 0; // restart the word counter to count up to one sector
            end
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_WAIT_RXWM;
            end
          end

          READ_QUAD_SPI_FILL_TX_FIFO_1: begin
            // Here starts the quad spi speed read branch
            // Write quad read command in tx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'h0, FC_RDQIO};
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_QUAD_SPI_WAIT_READY_1;
            end
          end

          READ_QUAD_SPI_WAIT_READY_1: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_QUAD_SPI_SEND_CMD_1;
            end
          end

          READ_QUAD_SPI_SEND_CMD_1: begin
            // Send command to spi_host : send quad read command to flash 
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (1 = keep CS asserted for next command)
            //   [23:0]  = Length-1 (0 = 1 byte) (FC_RDQIO is 1 byte command)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h1, 24'h0
            }; // Reserved + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_QUAD_SPI_SEND_CMD_1;
            end
          end

          READ_QUAD_SPI_CHECK_TX_FIFO_2: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              read_state_d = READ_QUAD_SPI_FILL_TX_FIFO_2;
            end
          end

          READ_QUAD_SPI_FILL_TX_FIFO_2: begin
            // Write flash address in tx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata =  {
              (bitfield_byteswap32({ 8'h00 , flash_addr_q }) >> 8) | 32'hff000000
            };
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_QUAD_SPI_WAIT_READY_2;
            end
          end

          READ_QUAD_SPI_WAIT_READY_2: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_QUAD_SPI_SEND_CMD_2;
            end
          end

          READ_QUAD_SPI_SEND_CMD_2: begin
            // Send command to spi_host : send address to flash 
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (2 = quad spi)
            //   [24]    = CSAAT (1 = keep CS asserted for next command)
            //   [23:0]  = Length-1 (3 = ff + 3 bytes of address)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h2, 1'h1, 24'h3
            }; // Reserved + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_QUAD_SPI_WAIT_READY_3;
            end
          end

          READ_QUAD_SPI_WAIT_READY_3: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_QUAD_SPI_SEND_CMD_3;
            end
          end

          READ_QUAD_SPI_SEND_CMD_3: begin
            // Send command to spi_host : execute dummy flash read cycles
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (0 = DUMMY reads)
            //   [26:25] = Speed (2 = quad spi)
            //   [24]    = CSAAT (1 = keep CS asserted for next command)
            //   [23:0]  = Length-1 (3 = 4 dummy wait cycles)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h0, 2'h2, 1'h1, 24'h3
            }; // Reserved + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_QUAD_SPI_WAIT_READY_4;
            end
          end

          READ_QUAD_SPI_WAIT_READY_4: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_QUAD_SPI_SEND_CMD_4;
            end
          end

          READ_QUAD_SPI_SEND_CMD_4: begin
            // Send command to spi_host : store flash content into rx_fifo from flash
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (1 = RX only)
            //   [26:25] = Speed (2 = quad spi)
            //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
            //   [23:0]  = Length-1 (See comments below)
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            if (rnw_q) begin
              // READ: receive a number of bytes specified by axi (beat_size) (up to 8 bytes)
              spi_host_reg_req_o.wdata = {
                3'h0, 2'h1, 2'h2, 1'h0,  {16'h0 , (8'h0 | (beat_size_q - 1'h1))}
              }; // Empty + Direction + Speed + Csaat + Length
            end
            if (~rnw_q) begin
              // WRITE: read full sector (4096 bytes)
              spi_host_reg_req_o.wdata = {
                3'h0, 2'h1, 2'h2, 1'h0, {11'b0, SE_BSIZE - 1'h1}
              }; // Empty + Direction + Speed + Csaat + Length
              word_count_d = 0; // restart the word counter to count up to one sector
            end
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_WAIT_RXWM;
            end
          end

          READ_WAIT_RXWM: begin
            // Wait for flash data to be present in the rx_fifo before sending a pop request (check whether wm is reached)
            // This is why we set rx_wm to 1
            if (external_spi_host_hw2reg_status_i.rxwm.d) begin
              if (rnw_q) begin
                // Read : load beat into queue
                // Depending on parallelism chose a different sfm branch
                if (~datawidth_is_64_n32) begin   // 32bit
                  read_state_d = READ_R_BEAT_PUSH_DW32;   
                end
                if (datawidth_is_64_n32) begin   // 64bit
                  if (beat_half_index_q == 0) begin   // First half of the beat
                    read_state_d = READ_R_BEAT_PUSH_DW64_1;
                  end 
                  if (beat_half_index_q == 1) begin   // Second half of the beat
                    read_state_d = READ_R_BEAT_PUSH_DW64_2;
                  end
                end 
              end 
              // Write : load sector in sector buffer
              if (~rnw_q) read_state_d = READ_W_SECTOR_STORE;
            end
          end

          READ_W_SECTOR_STORE: begin
            // Copy the sector from flash to buffer
            // Send a pop request to rx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_RXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // When word is popped, send a write request to the sector buffer
              sect_buffer_req = 1'b1;
              sect_buffer_we = 1'b1;
              sect_buffer_addr = '0 + word_count_q; 
              sect_buffer_wdata = spi_host_reg_rsp_i.rdata;
              sect_buffer_be = 4'b1111;
              word_count_d = word_count_q + 1;
            end
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              if (word_count_d == SE_WSIZE) begin
                top_state_d = TOP_FWAIT;
                read_state_d = READ_IDLE;
              end
              if (word_count_d < SE_WSIZE) begin
                read_state_d = READ_WAIT_RXWM;
              end
            end
          end

          READ_R_BEAT_PUSH_DW32: begin
            // Bring the beat into rd_queue_buffer, where spi_host rx_fifo data is stored temporarily before going into the rd_beat_queue
            // Send a pop request to rx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_RXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              rd_queue_buffer_d = spi_host_reg_rsp_i.rdata;
            end
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_R_BEAT_PUSH_FIN;
            end
          end

          READ_R_BEAT_PUSH_DW64_1: begin
            /*
            If AXI's DataWidth (and this module's) is 64, beat queues and their buffer also are 64 bit wide,
            however the width of spi_host and its fifos (and the flash) stays the same at 32 bits.
            This means that two states may be required to load data from rx_fifo to rd_beat_queue_buffer, since beat_size can be > 4.
            Here we write the lower 32 bites of the rd_queue_buffer.
            */
            // Send a pop request to rx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_RXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              rd_queue_buffer_d[31:0] = spi_host_reg_rsp_i.rdata;
              beat_half_index_d = 1'b1;
            end
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_WAIT_RXWM;
            end
          end

          READ_R_BEAT_PUSH_DW64_2: begin
            // Here we write the upper 32 bites of the rd_queue_buffer
            // If the beat size is not higher than 4 bytes, then we can bypass the request and just write zeroes
            if (beat_size_q > 4) begin
              spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_RXDATA_OFFSET;
              spi_host_reg_req_o.write = 1'b0;
              spi_host_reg_req_o.valid = 1'b1;
              if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
                rd_queue_buffer_d[DataWidth-1:DataWidth/2] = spi_host_reg_rsp_i.rdata;
              end
            end
            // Reset this counter to reuse it later
            beat_half_index_d = 1'b0;
            // Next state evaluation
            if (beat_size_q > 4) begin
              if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
                read_state_d = READ_R_BEAT_PUSH_FIN;
              end
            end
            else begin  // Bypass register response if second half was not required
              read_state_d = READ_R_BEAT_PUSH_FIN;
            end
          end

          READ_R_BEAT_PUSH_FIN: begin
            // push read beat into the rd_queue
            spihost_rd_valid = 1'b1;
            spihost_rd_data = rd_queue_buffer_q;
            if (spihost_rd_ready) begin
              beat_count_d = beat_count_q + 1;
              // If there are more beats to read we update beat_address, otherwise we move to TOP_AXIRESP
              if (beat_count_d < beat_number_q) begin
                // This controller assumes to work only in INCR bursts
                // addr_0 = ax_addr
                // addr_0_alligned = INT(addr_0 / size) * size
                // addr_N = addr_0_alligned + size*N
                beat_addr_d = ( (first_beat_addr_q / beat_size_q) * beat_size_q) + (beat_count_q + 1)*beat_size_q;
                flash_addr_d = beat_addr_d; // It is enstablished that we are reading
              end
            end
            // Next state evaluation
            if (spihost_rd_ready && beat_count_d <  beat_number_q) begin
              read_state_d = READ_SPI_CHECK_TX_FIFO;
            end
            if (spihost_rd_ready && beat_count_d == beat_number_q) begin
              read_state_d = READ_IDLE;
              top_state_d = TOP_AXIRESP;
            end
          end

          default: begin
            read_state_d = READ_IDLE;
          end
        endcase
      end


    /*
                                                  ==========================================================
                                                  |                       FWAIT SFM                        |
                                                  ==========================================================
    */
      // Polls the flash Status Register 1 (SR1) to check if the flash is busy
      // The BUSY bit (bit 0) is set during erase/program operations in spi_host
      // This FSM is called multiple times during a write operation:
      //
      //   fwait_cnt = 0: After READ  -> wait for flash ready, then go to ERASE
      //   fwait_cnt = 1: After ERASE -> wait for flash ready, then go to MODIFY
      //   fwait_cnt = 2: After WRITE -> wait for flash ready, then return to WRITE or complete if all pages have been programmed
      TOP_FWAIT: begin
        case (fwait_state_q)
          FWAIT_IDLE: begin
            fwait_state_d = FWAIT_SET_RXWM_R;
          end
          FWAIT_SET_RXWM_R: begin
            // Set RX watermark to 1 word so we get notified when status byte arrives
            // but we need to preserve other bits when modifying RXWM
            // this is why here we first read the entire spi_host control register to then write back the rest of the bits alongside the new wm
            // Read the control register:
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_CONTROL_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              spi_host_control_d = spi_host_reg_rsp_i.rdata;
            end
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_SET_RXWM_W;
            end
          end

          FWAIT_SET_RXWM_W: begin
            // Rewrite the command with updated wm:
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_CONTROL_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            // Keep upper CONTROL bits, set RXWM = 1
            spi_host_reg_req_o.wdata = {
              spi_host_control_q[31:8], 8'h01
            };  
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_SPI_CHECK_TX_FIFO;
            end
          end

          FWAIT_SPI_CHECK_TX_FIFO: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              fwait_state_d = FWAIT_SPI_FILL_TX_FIFO;
            end
          end
        
          FWAIT_SPI_FILL_TX_FIFO: begin
            // Write Status Register 1 Read command in tx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'b0, FC_RSR1};
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_SPI_WAIT_READY_1;
            end
          end

          FWAIT_SPI_WAIT_READY_1: begin
            // Wait for spi_host to be ready (command queue not busy) 
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              fwait_state_d = FWAIT_SPI_SEND_CMD_1;
            end
          end

          FWAIT_SPI_SEND_CMD_1: begin
            // Send command to spi_host : send status read command to flash
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (1 = keep CS asserted for next command)
            //   [23:0]  = Length-1 (0 = 1 byte) (FC_RSR1 is 1 byte command)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h1, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_SPI_WAIT_READY_2;
            end
          end

          FWAIT_SPI_WAIT_READY_2: begin
            // Wait for spi_host to be ready (command queue not busy) 
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              fwait_state_d = FWAIT_SPI_SEND_CMD_2;
            end
          end

          FWAIT_SPI_SEND_CMD_2: begin
            // Send command to spi_host : recieve status from flash
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (1 = RX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
            //   [23:0]  = Length-1 (0 = 1 byte)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h1, 2'h0, 1'h0, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_WAIT_RXWM;
            end
          end

          FWAIT_WAIT_RXWM: begin
            // Wait for flash status to be present in the rx_fifo before sending a pop request (check whether wm is reached)
            // This is why we set rx_wm to 1
            // Next state evaluation
            if (external_spi_host_hw2reg_status_i.rxwm.d) begin
              fwait_state_d = FWAIT_READ_FLASH_STATUS;
            end
          end

          FWAIT_READ_FLASH_STATUS: begin
            // Check flash status and go next if not busy, otherwise repeat FWAIT
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_RXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // Check BUSY bit: 0 = ready, 1 = busy
              if (spi_host_reg_rsp_i.rdata[0] == 1'b0) begin
                // Flash is READY , Proceed to next TOP_STATE
                case (fwait_cnt_q)
                  // After READ: Flash ready -> go to ERASE
                  2'h0: begin
                    fwait_cnt_d   = 2'h1;
                    fwait_state_d = FWAIT_IDLE;
                    top_state_d   = TOP_ERASE;
                  end
                  // After ERASE: Flash ready -> go to MODIFY
                  2'h1: begin
                    fwait_cnt_d = 2'h2;
                    fwait_state_d = FWAIT_IDLE;
                    top_state_d = TOP_MODIFY;
                  end
                  // After WRITE:
                  2'h2: begin
                    if (page_count_q < SE_PSIZE) begin
                      // There are still pages to program for the current beat : -> go to WRITE
                      fwait_state_d = FWAIT_IDLE;
                      top_state_d   = TOP_WRITE;
                    end else begin
                      // Current beat write is completed
                      fwait_cnt_d = 2'h0;
                      // Reset page counter
                      page_count_d = 0;
                      // Reset skip_write flag
                      skip_write_d = 1'b0;
                      // Increment beat counter
                      beat_count_d = beat_count_q + 1;
                      if (beat_count_d < beat_number_q) begin
                        // There are more beats to go for this AXI transmission : -> go to READ
                        /*

                        Evaluate address of next beat

                        If there are more beats to write then return to READ to proces the next one
                        This controller assumes to work only in INCR bursts
                        addr_0 = axi_addr
                        addr_0_alligned = INT(addr_0 / size) * size
                        addr_N = addr_0_alligned + size*N
                        */
                        beat_addr_d = ( (first_beat_addr_q / beat_size_q) * beat_size_q) + (beat_count_q + 1)*beat_size_q;

                        fwait_state_d = FWAIT_IDLE;
                        top_state_d = TOP_READ;
                      end else begin
                        // AXI transmission is over : -> go to AXIRESP
                        top_state_d = TOP_AXIRESP;
                        fwait_state_d = FWAIT_IDLE;
                      end
                    end
                  end
                  default: begin
                  end
                endcase
              end else begin
                // Flash is BUSY, repeat TOP_FWAIT
                fwait_state_d = FWAIT_SET_RXWM_R;
              end
            end
          end

          default: begin
            fwait_state_d = FWAIT_IDLE;
          end
        endcase
      end


    /*
                                                  ==========================================================
                                                  |                       ERASE SFM                        |
                                                  ==========================================================
    */
      TOP_ERASE: begin
        case (erase_state_q)
          ERASE_IDLE: begin
            logic [AddrWidth-1:0] next_beat_addr, next_sect_addr, curr_sect_addr;
            // In this state, before erasing we evaluate the possibility to postpone flash erase and program in the next beat if the sector involved would be the same
            // As these operations are the performance bottlenecks and it is better to share them between more beat instances.
            if (beat_count_q < beat_number_q - 1) begin
              // This is done if :
              // The current sector is not the first of two being written for the current signle beat (sector would change after)
              // The current sector is not the last one (would be the last call to write)
              // The next sector address would be the same as current
              next_beat_addr = ((first_beat_addr_q / beat_size_q) * beat_size_q) + (beat_count_q + 1)*beat_size_q;
              next_sect_addr = (next_beat_addr >> 12) << 12;
              curr_sect_addr = '0 | flash_addr_q;   // flash_addr_q in write is the current sector address, set in TOP_READ
              skip_write_d = (next_sect_addr == curr_sect_addr) ? 1'b1 : 1'b0; // This value is reset after each beat write or partial beat write
            end
            // Next state evaluation
            if(skip_write_d) begin
              erase_state_d = ERASE_IDLE;
              top_state_d = TOP_FWAIT;
            end else begin
              erase_state_d = ERASE_WE_CHECK_TX_FIFO;
            end
          end

          ERASE_WE_CHECK_TX_FIFO: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              erase_state_d = ERASE_WE_FILL_TX_FIFO;
            end
          end

          ERASE_WE_FILL_TX_FIFO: begin
            // Write "write enable" command in tx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'b0, FC_WE};
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              erase_state_d = ERASE_WE_WAIT_READY;
            end
          end

          ERASE_WE_WAIT_READY: begin
            // Wait for spi_host to be ready (command queue not busy) 
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              erase_state_d = ERASE_WE_SEND_CMD;
            end
          end

          ERASE_WE_SEND_CMD: begin
            // Send command to spi_host : send write enable command to flash
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (0 = release CS after, WE is standalone command)
            //   [23:0]  = Length-1 (0 = 1 byte)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              erase_state_d = ERASE_SE_CHECK_TX_FIFO;
            end
          end

          ERASE_SE_CHECK_TX_FIFO: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              erase_state_d = ERASE_SE_FILL_TX_FIFO;
            end
          end

          ERASE_SE_FILL_TX_FIFO: begin
            // Write sector erase command + address in tx_fifo
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata =  {
              (bitfield_byteswap32({ 8'h0 , flash_addr_q })) | {19'h0, FC_SE}
            };
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              erase_state_d = ERASE_SE_WAIT_READY;
            end
          end

          ERASE_SE_WAIT_READY: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              erase_state_d = ERASE_SE_SEND_CMD;
            end
          end

          ERASE_SE_SEND_CMD: begin
            //  Send command to spi_host : send sector erase command
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
            //   [23:0]  = Length-1 (3 = 4 bytes: 1 cmd + 3 addr bytes)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, 24'h3
            };  // Empty + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // Go to FWAIT FSM to poll status register until erase completes
              erase_state_d = ERASE_IDLE;
              top_state_d = TOP_FWAIT;
              fwait_state_d = FWAIT_IDLE; // Start polling
            end
          end

          default: begin
            erase_state_d = ERASE_IDLE;
          end
        endcase
      end


    /*
                                                  ==========================================================
                                                  |                       ERASE SFM                        |
                                                  ==========================================================
 
  
          * Address in the sector buffer scratchpad is not byte precise but word precise, unlike the flash
              - beat address and word address can be misaligned

          * one beat (up to one word of size) can cover more words in the sector buffer
              - datawidth_is_64_n32 = 0 : up to two adiacent words
              - datawidth_is_64_n32 = 1 : up to three adiacent words

          + there is one branch per Parallelism

          Each branch MODIFY_SECTOR_UPDATE has a state for each word that could be overwritten by the beat in the sector buffer
          32 bits : 2 words , 2 states
          64 bits : 3 words , 3 states
  
          32 bits:
                              word n+1       word n
                              3  2  1  0  |  3  2  1  0  
          beat bytes :           3  2  1     0
  
          missalignment = 3
  
  
          64 bits:
                                  word n+2      word n+1       word n
                              3  2  1  0  |  3  2  1  0  |  3  2  1  0 
          beat bytes :                 7     6  5  4  3     2  1  0  
  
          missalignment = 1
  
          if in a given state, the last word of the sector has been written, skip the next states.  
          
    */

      TOP_MODIFY: begin
        logic [AddrWidth-1:0] sector_relative_addr = '0;
        logic [1:0] misallignment;
        logic [95:0] buffer_beat_space_data;
        logic [11:0] buffer_beat_space_be;
        case (modify_state_q)

          MODIFY_IDLE: begin
            modify_state_d = MODIFY_BEAT_POP;
          end

          MODIFY_BEAT_POP: begin
            // pop write beat from wr_queue into a register
            if (spihost_wr_valid) begin
              spihost_wr_ready = 1'b1;
              wr_queue_buffer_data_d = spihost_wr_data;
              wr_queue_buffer_be_d = spihost_wr_be;
            end
            // Next state evaluation
            // Sector buffer, like flash, has a constant datawidth of 32, so we need separate SFM branches depending on AXI datawitdh
            if (spihost_wr_valid &&  datawidth_is_64_n32) modify_state_d = MODIFY_SECTOR_UPDATE_DW32_1;
            if (spihost_wr_valid && ~datawidth_is_64_n32) modify_state_d = MODIFY_SECTOR_UPDATE_DW64_1;
          end

          MODIFY_SECTOR_UPDATE_DW32_1: begin
            // Sector_relative_addr = beat_addr & 000fff
            sector_relative_addr[11:0] = beat_addr_q[11:0];
            // Sector buffer is word precise, so we remove the two LSB that indicate the 4 bytes inside the word
            sect_buffer_addr = sector_relative_addr >> 2;
            // Those two LSB indicate the miasslignment between flash address and sector buffer address
            misallignment = sector_relative_addr[1:0];
            
            // these two signals indicate the beat data how it covers the buffer slots
            buffer_beat_space_data = wr_queue_buffer_data_q << misallignment*8;
            buffer_beat_space_be = wr_queue_buffer_be_q << misallignment;

            // write word 1 of 2
            sect_buffer_wdata = buffer_beat_space_data[31:0];
            sect_buffer_be = buffer_beat_space_be[3:0];

            sect_buffer_req = 1;
            sect_buffer_we = 1;
            // Next state evaluation
            modify_state_d = MODIFY_SECTOR_UPDATE_DW32_2;
          end

        MODIFY_SECTOR_UPDATE_DW32_2: begin
          // Sector_relative_addr = beat_addr & 000fff
          sector_relative_addr[11:0] = beat_addr_q[11:0];
          // Sector buffer is word precise, so we remove the two LSB that indicate the 4 bytes inside the word, +1 being the next word
          sect_buffer_addr = (sector_relative_addr >> 2) + 1;
          // Those two LSB indicate the miasslignment between flash address and sector buffer address
          misallignment = sector_relative_addr[1:0];

          // if address would overflow, it means that the sector finished and so the beat. skip this state
          if (sect_buffer_addr[9:0] != 10'b0000000000) begin

            // these two signals indicate the beat data how it covers the buffer slots
            buffer_beat_space_data = wr_queue_buffer_data_q << misallignment*8;
            buffer_beat_space_be = wr_queue_buffer_be_q << misallignment;

            // write word 2 of 2
            sect_buffer_wdata = buffer_beat_space_data[63:32];
            sect_buffer_be = buffer_beat_space_be[7:4];

            sect_buffer_req = 1;
            sect_buffer_we = 1;
          end
          // Next state evaluation
          modify_state_d = MODIFY_IDLE;
          top_state_d = TOP_WRITE;
        end

        MODIFY_SECTOR_UPDATE_DW64_1: begin
          // Sector_relative_addr = beat_addr & 000fff
          sector_relative_addr[11:0] = beat_addr_q[11:0];
          // Sector buffer is word precise, so we remove the two LSB that indicate the 4 bytes inside the word
          sect_buffer_addr = sector_relative_addr >> 2;
          // Those two LSB indicate the miasslignment between flash address and sector buffer address
          misallignment = sector_relative_addr[1:0];
          
          // these two signals indicate the beat data how it covers the buffer slots
          buffer_beat_space_data = wr_queue_buffer_data_q << misallignment*8;
          buffer_beat_space_be = wr_queue_buffer_be_q << misallignment;

          // write word 1 of 3
          sect_buffer_wdata = buffer_beat_space_data[31:0];
          sect_buffer_be = buffer_beat_space_be[3:0];

          sect_buffer_req = 1;
          sect_buffer_we = 1;
          // Next state evaluation
          modify_state_d = MODIFY_SECTOR_UPDATE_DW64_2;
        end

        MODIFY_SECTOR_UPDATE_DW64_2: begin
          // Sector_relative_addr = beat_addr & 000fff
          sector_relative_addr[11:0] = beat_addr_q[11:0];
          // Sector buffer is word precise, so we remove the two LSB that indicate the 4 bytes inside the word, +1 being the next word
          sect_buffer_addr = (sector_relative_addr >> 2) + 1;
          // Those two LSB indicate the miasslignment between flash address and sector buffer address
          misallignment = sector_relative_addr[1:0];
          
          // if address would overflow, it means that the sector finished and so the beat. skip this state
          if (sect_buffer_addr[9:0] != 10'b0000000000) begin
            // these two signals indicate the beat data how it covers the buffer slots
            buffer_beat_space_data = wr_queue_buffer_data_q << misallignment*8;
            buffer_beat_space_be = wr_queue_buffer_be_q << misallignment;

            // write word 2 of 3
            sect_buffer_wdata = buffer_beat_space_data[63:32];
            sect_buffer_be = buffer_beat_space_be[7:4];

            sect_buffer_req = 1;
            sect_buffer_we = 1;
          end
          // Next state evaluation
          modify_state_d = MODIFY_SECTOR_UPDATE_DW64_3;
        end

        MODIFY_SECTOR_UPDATE_DW64_3: begin
          // Sector_relative_addr = beat_addr & 000fff
          sector_relative_addr[11:0] = beat_addr_q[11:0];
          // Sector buffer is word precise, so we remove the two LSB that indicate the 4 bytes inside the word, +1 being the next word
          sect_buffer_addr = (sector_relative_addr >> 2) + 2;
          // Those two LSB indicate the miasslignment between flash address and sector buffer address
          misallignment = sector_relative_addr[1:0];
          
          // if address would overflow, it means that the sector finished and so the beat. skip this state.
          // skip also if last state we skipped, for the same reason.
          if (sect_buffer_addr[9:0] != 10'b0000000001 && sect_buffer_addr[9:0] != 10'b0000000000) begin
            // these two signals indicate the beat data how it covers the buffer slots
            buffer_beat_space_data = wr_queue_buffer_data_q << misallignment*8;
            buffer_beat_space_be = wr_queue_buffer_be_q << misallignment;

             // write word 3 of 3
            sect_buffer_wdata = buffer_beat_space_data[95:64];
            sect_buffer_be = buffer_beat_space_be[11:8];

            sect_buffer_req = 1;
            sect_buffer_we = 1;
          end
          // Next state evaluation
          modify_state_d = MODIFY_IDLE;
          top_state_d = TOP_WRITE;
        end

        default: begin
        end
        endcase
      end


      /*

                                                  ==========================================================
                                                  |                       WRITE SFM                        |
                                                  ==========================================================


        Programs the modified sector buffer back to flash, page by page
        Flash page size is 256 bytes and a sector contains 16 pages resulting in 4096 bytes per sector
        For each page, the sequence is:
            1. Write Enable (WE): Required before each write/erase flash operation
            2. Page Program (PP): Send command + address, then data is transfered from local sector buffer to SPI Host TX FIFO
      */
      TOP_WRITE: begin
        case (write_state_q)

          WRITE_IDLE: begin
            // If we are skipping TOP_WRITE, then we assume that the sector does not have to be written by any more pages
            if (skip_write_q) page_count_d = SE_PSIZE;
            // Next state evaluation
            if (skip_write_q) begin
              write_state_d = WRITE_IDLE;
              top_state_d = TOP_FWAIT;
            end else begin
              write_state_d = WRITE_WE_CHECK_TX_FIFO;
            end
          end

          WRITE_WE_CHECK_TX_FIFO: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              write_state_d = WRITE_WE_FILL_TX_FIFO;
            end
          end

          WRITE_WE_FILL_TX_FIFO: begin
            // Write "write enable" command in tx_fifo
            spi_host_reg_req_offset  = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'b0, FC_WE};
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_WE_WAIT_READY;
            end
          end
          WRITE_WE_WAIT_READY: begin
            // Wait for spi_host to be ready (command queue not busy) 
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              write_state_d = WRITE_WE_SEND_CMD;
            end
          end

          WRITE_WE_SEND_CMD: begin
            // Send command to spi_host : send write enable command
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (0 = release CS after, WE is standalone command)
            //   [23:0]  = Length-1 (0 = 1 byte)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_PP_CHECK_TX_FIFO;
            end
          end

          WRITE_PP_CHECK_TX_FIFO: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              write_state_d = WRITE_PP_FILL_TX_FIFO;
            end
          end

          WRITE_PP_FILL_TX_FIFO: begin
            logic [12:0] OPCODE;
            // page program speed is decided by quadspi_en_i (from external top reg)
            OPCODE = quadspi_en_i ? FC_PPQ : FC_PP;
            // Write page program command + page address in tx_fifo
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            // Compute page address: sector base + sector offset + page offset
            spi_host_reg_req_o.wdata = bitfield_byteswap32(
											                      {8'h0 , flash_addr_q + (page_count_q << 8) }
										                        ) | {19'h0, OPCODE};
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_PP_WAIT_READY;
            end
          end

          WRITE_PP_WAIT_READY: begin
            // Wait for spi_host to be ready (command queue not busy) 
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              write_state_d = WRITE_PP_SEND_CMD;
            end
          end

          WRITE_PP_SEND_CMD: begin
            // Send command to spi_host : send page program command + address to flash 
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0 = standard)
            //   [24]    = CSAAT (1 = keep CS asserted for next command)
            //   [23:0]  = Length-1 (3 = 4 bytes: 1 cmd + 3 addr)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h1, 24'h3
            };  // Empty + Direction + Speed + Csaat + Length
            // Reset word counter
            word_count_d = 0;
            // Reset sector buffer latency cycles counter
            wait_latency_count_d = 0;
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_PP_PAGE_WRITE_1;
            end
          end

          WRITE_PP_PAGE_WRITE_1: begin
            // Send read request to the sector buffer and wait for its Latency cycles before sampling the read data in a buffer
            sect_buffer_req = 1'b1;
            sect_buffer_we = 1'b0;
            sect_buffer_addr = '0 + page_count_q * PAGE_WSIZE + word_count_q;
            // Count the latency to sample the rdata in the right cycle
            wait_latency_count_d = wait_latency_count_q + 1;
            // Next state evaluation
            if (wait_latency_count_q == SectorBufferLatency) begin
              write_state_d = WRITE_PP_PAGE_WRITE_2;
            end
          end

          WRITE_PP_PAGE_WRITE_2: begin
            wait_latency_count_d = 0; // Reset latency counter
            // Store read content in the sector buffer's buffer (single register)
            sec_buf_buffer_d = sect_buffer_rdata;
            // Next state evaluation
            write_state_d = WRITE_PP_PAGE_WRITE_3;
          end

          WRITE_PP_PAGE_WRITE_3: begin
            // Proceed only if tx_fifo is not full, exploit direct access to spi_host status
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              write_state_d = WRITE_PP_PAGE_WRITE_4;
            end
          end

          WRITE_PP_PAGE_WRITE_4: begin
            // send 32bit word to tx_fifo from the current page in the sector buffer
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = sec_buf_buffer_d;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              word_count_d = word_count_q + 1;
              if (word_count_d == PAGE_WSIZE) begin
                page_count_d = page_count_q + 1;
              end
            end

            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // complete page program
              if (word_count_d == PAGE_WSIZE) write_state_d = WRITE_PP_WAIT_READY_2;
              // load next word in tx_fifo
              if (word_count_d <  PAGE_WSIZE) write_state_d = WRITE_PP_PAGE_WRITE_1;
            end
          end

          WRITE_PP_WAIT_READY_2: begin
            // Wait for spi_host to be ready (command queue not busy)
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              write_state_d = WRITE_PP_SEND_CMD_2;
            end
          end

          WRITE_PP_SEND_CMD_2: begin
            logic [1:0] SPEED;
            SPEED = quadspi_en_i ? 2'h2 : 2'h0;
            // Send command to spi_host: send direction and length of write operation
            // COMMAND register format:
            //   [31:29] = Reserved
            //   [28:27] = Direction (2 = TX only)
            //   [26:25] = Speed (0/2 = standard/quad spi)
            //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
            //   [23:0]  = Length-1 (255 = 256 bytes = 1 page)
            spi_host_reg_req_offset = spi_host_reg_pkg::SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, SPEED, 1'h0, {11'b0, PAGE_BSIZE - 1'h1}
            };  // Empty + Direction + Speed + Csaat + Length
            // Next state evaluation
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
                top_state_d = TOP_FWAIT;
                write_state_d = WRITE_IDLE;
            end
          end

          default: begin
            write_state_d = WRITE_IDLE;
          end

        endcase
      end


      /*

      
                                                  ==========================================================
                                                  |                      AXIRESP SFM                       |
                                                  ==========================================================

      Create a response to the manager from its last request, either on R or B channel
      */
      TOP_AXIRESP: begin
        case(axiresp_state_q)

          AXIRESP_IDLE: begin
            // Reset beat counter
            beat_count_d = 0;
            // Next state evaluation
            if ( rnw_q) axiresp_state_d = AXIRESP_R;
            if (~rnw_q) axiresp_state_d = AXIRESP_B;
          end

          AXIRESP_B: begin
            // Respond to the  channel
            b_valid = 1'b1;
            // Next state evaluation
            if (b_ready) begin 
              axiresp_state_d = AXIRESP_IDLE;
              top_state_d = TOP_IDLE;
            end
          end

          AXIRESP_R: begin
            // Respond to the R channel
            // There needs to be handling done regarding the active byte lanes of the axi data bus
            int n;
            if (axi2fls_rd_valid) begin
              logic [AddrWidth-1:0]                 beat_addr_at_beat_count;
              logic [sizeInBits(DataBytes-1)-1:0]   lower_byte_lane, upper_byte_lane;
              logic [AddrWidth-1:0]                 alligned_beat_addr = (first_beat_addr_q / beat_size_q) * beat_size_q;

              if (beat_count_q == 0) begin
                lower_byte_lane = first_beat_addr_q - (first_beat_addr_q / DataBytes)*DataBytes;
                upper_byte_lane = alligned_beat_addr - (first_beat_addr_q / DataBytes)*DataBytes + (beat_size_q - 1);
              end
              if (beat_count_q > 0) begin
                beat_addr_at_beat_count = alligned_beat_addr + (beat_count_q)*beat_size_q;
                lower_byte_lane = beat_addr_at_beat_count - (first_beat_addr_q / DataBytes)*DataBytes;
                upper_byte_lane = lower_byte_lane + (beat_size_q - 1); 
              end
              r_valid = 1'b1;
              r_data = '0;
              n = 0;
              for (int i = lower_byte_lane ; i <= upper_byte_lane ; i++) begin
                // r_data[i*8+7:i*8] = axi2fls_rd_data[n*8+7:n*8];
                r_data[i*8 +: 8] = axi2fls_rd_data[n*8 +: 8];
                n++;
              end
              if (r_ready) begin
                beat_count_d = beat_count_q + 1;
                axi2fls_rd_ready = 1'b1;
                r_last = (beat_count_d == beat_number_q) ? 1'b1 : 1'b0;
              end
            end
            // Next state evaluation
            if ( axi2fls_rd_valid && r_ready && (beat_count_d == beat_number_q) ) begin
              top_state_d = TOP_IDLE;
              axiresp_state_d = AXIRESP_IDLE;
            end
          end

          default:begin
            axiresp_state_d = AXIRESP_IDLE;
          end

        endcase
      end
      default: begin
        top_state_d = TOP_IDLE;
      end
    endcase
  end

  // // AXI beat queues
  // Data from axi w channel is stored beat by beat inside the queue to be written separatedly
  
  logic [DataWidth-1:0] axi2fls_wr_data;
  logic [DataBytes-1:0] axi2fls_wr_be;
  logic                 axi2fls_wr_valid;
  logic                 axi2fls_wr_ready;

  logic [DataWidth-1:0] spihost_wr_data;
  logic [DataBytes-1:0] spihost_wr_be;
  logic                 spihost_wr_valid;
  logic                 spihost_wr_ready;

  logic [DataWidth-1:0] spihost_rd_data;
  logic                 spihost_rd_valid;
  logic                 spihost_rd_ready;

  logic [DataWidth-1:0] axi2fls_rd_data;
  logic                 axi2fls_rd_valid;
  logic                 axi2fls_rd_ready;

  logic [7:0] wr_qd, rd_qd;

  logic wr_empty, wr_full;
  logic rd_empty, rd_full;
  logic clear_queues;
  
  axi_to_flash_beat_queues #(
    .DataWidth,
    .WrDepth(MaxBeats),
    .RdDepth(MaxBeats),
    .SwapBytes(~ByteOrder)
  ) beat_queues_i (
    .clk_i,
    .rst_ni,

    .axi2fls_wr_data_i         (axi2fls_wr_data),
    .axi2fls_wr_be_i           (axi2fls_wr_be),
    .axi2fls_wr_valid_i        (axi2fls_wr_valid),
    .axi2fls_wr_ready_o        (axi2fls_wr_ready),

    .spihost_wr_data_o         (spihost_wr_data),
    .spihost_wr_be_o           (spihost_wr_be),
    .spihost_wr_valid_o        (spihost_wr_valid),
    .spihost_wr_ready_i        (spihost_wr_ready),

    .spihost_rd_data_i         (spihost_rd_data),
    .spihost_rd_valid_i        (spihost_rd_valid),
    .spihost_rd_ready_o        (spihost_rd_ready),

    .axi2fls_rd_data_o         (axi2fls_rd_data),
    .axi2fls_rd_valid_o        (axi2fls_rd_valid),
    .axi2fls_rd_ready_i        (axi2fls_rd_ready),

    .wr_watermark_i            (),
    .rd_watermark_i            (),

    .wr_empty_o                (wr_empty),
    .wr_full_o                 (wr_full),
    .wr_qd_o                   (wr_qd),
    .wr_wm_o                   (),
    .rd_empty_o                (rd_empty),
    .rd_full_o                 (rd_full),
    .rd_qd_o                   (rd_qd),
    .rd_wm_o                   (),

    .clear_i                  (clear_queues)
);

  // // Sector buffer scratchpad

  localparam int SectorBuffer_AddrWidth = sizeInBits(SE_WSIZE);
  localparam int SectorBuffer_DataWidth = 32;
  localparam int SectorBuffer_DataBytes = SectorBuffer_DataWidth/8;

  logic                              sect_buffer_req;
  logic                              sect_buffer_we;
  logic [SectorBuffer_DataWidth-1:0] sect_buffer_wdata;
  logic [SectorBuffer_DataBytes-1:0] sect_buffer_be;
  logic [AddrWidth-1:0]              sect_buffer_addr;
  logic [SectorBuffer_DataWidth-1:0] sect_buffer_rdata;

  logic [SectorBuffer_AddrWidth-1:0] sect_buffer_addr_resized;
  assign sect_buffer_addr_resized = sect_buffer_addr[SectorBuffer_AddrWidth-1:0];

  sram_wrapper #(
      .NumWords(SE_WSIZE),
      .DataWidth(SectorBuffer_DataWidth)
  ) sector_buffer_i (
      .clk_i,
      .rst_ni,
      .req_i(sect_buffer_req),
      .we_i(sect_buffer_we),
      .addr_i(sect_buffer_addr_resized),
      .wdata_i(sect_buffer_wdata),
      .be_i(sect_buffer_be),
      .rdata_o(sect_buffer_rdata)
  );

endmodule