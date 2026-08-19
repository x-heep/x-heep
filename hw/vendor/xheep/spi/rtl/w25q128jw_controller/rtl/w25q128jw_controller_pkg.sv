/**
 * w25q128jw_controller_pkg.sv
 * Package containing types and utility functions for W25Q128JW flash controller.
 *
 * Author: Thomas Lenges   <thomas.lenges@epfl.ch>
 *                         <thomas.lenges@hotmail.com>
 * Additional authors:  Davide Schiavone <davide.schiavone@epfl.ch>
 *                      Patrick Pataky <patrick.pataky@epfl.ch>
 *                                     <patdb10@gmail.com>
 *                      Alain Girard <alain.girard@epfl.ch>
 *                                   <alaingirardvd@gmail.com>
 */

package w25q128jw_controller_pkg;

  // -------- TOP FSM STATES --------
  // Top controller FSM
  typedef enum logic [3:0] {
    TOP_IDLE,         // Wait for start command
    TOP_CHECK_CACHE,  // Check if data is already within the cache
    TOP_READ_CACHE,   // Read from cache to RAM
    TOP_MODIFY,       // Write from RAM to cache
    TOP_READ,         // Read from flash to cache sector buffer
    TOP_FWAIT,        // Wait for flash internal operation
    TOP_ERASE,        // Erase flash sector
    TOP_WRITE,        // Write a cache sector buffer to flash
    TOP_DMA_INIT,     // Initialize DMA registers
    TOP_DONE          // Complete operation and go back to IDLE
  } top_state_e;

  // -------- CHECK_CACHE FSM STATES --------
  // Check if requested data is already in cache (cache hit) or not (cache miss)
  typedef enum logic [1:0] {
    CHECK_CACHE_IDLE,
    CHECK_CACHE_RESPONSE
  } check_cache_state_e;

  typedef enum logic [1:0] {
    READ_CACHE_IDLE,  // Cache request sent
    READ_CACHE_REGS,  // Configure DMA for transfer
    READ_CACHE_TRANS,  // Wait for DMA transfer complete
    READ_CACHE_MEMIO_REQ  // memio: registered CACHE_READ valid
  } read_cache_state_e;

  // -------- READ FSM STATES --------
  // Handles flash read operations via SPI & DMA
  // If cache enabled, always read a single sector to cache
  typedef enum logic [4:0] {
    READ_IDLE,               // Lead to DMA initialization (necessary before every use of DMA)
    READ_SET_DMA,            // Set the DMA registers
    READ_SPI_CHECK_TX_FIFO,  // Check if TX FIFO has space
    READ_SPI_FILL_TX_FIFO,   // Write command + address to TX FIFO (standard mode)
    READ_SPI_WAIT_READY_1,   // Wait for SPI Host ready
    READ_SPI_SEND_CMD_1,     // Send command (1st phase, standard mode)
    READ_SPI_WAIT_READY_2,   // Wait for SPI Host ready again
    READ_SPI_SEND_CMD_2,     // Send command (2nd phase, standard mode)

    READ_SPI_SEND_CMD_1_QUAD,        // Send Quad Read command (1st phase, standard mode)
    READ_SPI_QUAD_WAIT_READY_1,      // Wait for SPI Host
    READ_SPI_SEND_CMD_2_QUAD,        // Write Quad Read command (2nd phase, standard mode)
    READ_SPI_QUAD_WAIT_READY_2,      // Wait for SPI Host
    READ_SPI_SEND_CMD_3_QUAD,        // Send address command (1st phase, quad mode)
    READ_SPI_QUAD_WAIT_READY_3,      // Wait for SPI Host
    READ_SPI_SEND_CMD_4_QUAD,        // Send address command (2nd phase, quad mode)
    READ_SPI_QUAD_WAIT_READY_4,      // Wait for SPI Host
    READ_SPI_SEND_CMD_DUMMY_QUAD,    // Send dummy cycles command (quad mode)
    READ_SPI_QUAD_WAIT_READY_DUMMY,  // Wait for SPI Host
    READ_SPI_SEND_CMD_5_QUAD,        // Send RX command (quad mode)

    READ_TRANS  // Wait for DMA transfer complete
  } read_state_e;

  // -------- FLASH WAIT FSM STATES --------
  // Waits for flash internal operations to complete (erase/program)
  // by polling the flash status register (Read Status Register 1)
  typedef enum logic [3:0] {
    FWAIT_IDLE,  // Go through FWAIT & ERASE FSMs
    FWAIT_SET_RXWM_R,  // Read current RX watermark setting (within SPI Host Control Register)
    FWAIT_SET_RXWM_W,  // Set RX watermark to 1 (for single word read: flash status register 1)
    FWAIT_SPI_CHECK_TX_FIFO,  // Check if TX FIFO has space
    FWAIT_SPI_FILL_TX_FIFO,  // Write Read Status Register 1 command (FC_RSR1)
    FWAIT_SPI_WAIT_READY_1,  // Wait for SPI Host ready
    FWAIT_SPI_SEND_CMD_1,  // Send FC_RSR1 command
    FWAIT_SPI_WAIT_READY_2,  // Wait for SPI Host ready
    FWAIT_SPI_SEND_CMD_2,  // Send command for flash to send status byte
    FWAIT_WAIT_RXWM,  // Wait for RX watermark to be passed (status byte received)
    FWAIT_READ_FLASH_STATUS  // Read status byte and check BUSY bit (bit 0). If busy then repeat process, else redirect to correct FSM/complete operation
  } fwait_state_e;

  // -------- FLASH WAIT RETURN STATES --------
  // Reset wait status and redirect to correct FSM after flash is ready
  // depending on which operation we were waiting for
  // Note: only used for WRITE operation
  typedef enum logic [2:0] {
    FWAIT_RETURN_IDLE,  // After READ: -> ERASE
    FWAIT_RETURN_ERASE,  // After ERASE: -> MODIFY
    FWAIT_RETURN_MODIFY,  // After ERASE (no cache): -> MODIFY
    FWAIT_RETURN_WRITE,  // After page < 15: -> WRITE (next page)
    FWAIT_RETURN_SECTOR_DONE  // After page 15: check if more sectors to write
  } fwait_return_e;

  // -------- ERASE FSM STATES --------
  // Erases a 4KB sector before writing new data
  // Sequence: Write Enable (WE) -> Sector Erase (SE)
  typedef enum logic [3:0] {
    ERASE_IDLE,  // Idle state (simply redirects to WE and SE sequences)

    // Write Enable command sequence (required before any write/erase)
    ERASE_WE_CHECK_TX_FIFO,  // Check if TX FIFO has space
    ERASE_WE_FILL_TX_FIFO,   // Write Write Enable command (FC_WE)
    ERASE_WE_WAIT_READY,     // Wait for SPI Host ready
    ERASE_WE_SEND_CMD,       // Send Write Enable command

    // Sector Erase command sequence
    ERASE_SE_CHECK_TX_FIFO,  // Check if TX FIFO has space
    ERASE_SE_FILL_TX_FIFO,   // Write Sector Erase command + address (FC_SE)
    ERASE_SE_WAIT_READY,     // Wait for SPI Host ready
    ERASE_SE_SEND_CMD        // Send Sector Erase command
  } erase_state_e;

  // -------- MODIFY FSM STATES --------
  // Copies new data into the sector buffer (RAM) at the correct offset
  // Uses DMA to transfer from ram_new_data to ram_buffer (or from cache if enabled)
  typedef enum logic [1:0] {
    MODIFY_IDLE,  // Leads to DMA initialization
    MODIFY_REGS, // Set the DMA registers (ram_new_data + offset (which sector we are now looking to write into + F_ADDRESS sector misalignment))
    MODIFY_TRANS,  // Wait for DMA transfer complete and update offsets + remaining length to write
    MODIFY_MEMIO_REQ
  } modify_state_e;

  // -------- WRITE FSM STATES --------
  // Programs sector buffer to flash, page by page (256 bytes per page)
  // Sequence: Write Enable -> Page Program command -> DMA data -> repeat for 16 pages
  typedef enum logic [3:0] {
    WRITE_IDLE,  // Idle state (simply redirects to WE and PP sequences)

    // Write Enable command sequence (required before each page program)
    WRITE_WE_CHECK_TX_FIFO,  // Check if TX FIFO has space
    WRITE_WE_FILL_TX_FIFO,   // Write Write Enable command (FC_WE)
    WRITE_WE_WAIT_READY,     // Wait for SPI Host ready
    WRITE_WE_SEND_CMD,       // Send Write Enable command

    // Page Program command sequence
    WRITE_PP_CHECK_TX_FIFO,  // Check if TX FIFO has space
    WRITE_PP_FILL_TX_FIFO,   // Write Page Program command + address (FC_PP)
    WRITE_PP_WAIT_READY,     // Wait for SPI Host ready
    WRITE_PP_SEND_CMD,       // Send Page Program command

    // DMA configuration for page data transfer
    WRITE_DMA_CHECK_READY,  // Leads to DMA initialization
    WRITE_DMA_REGS,         // Set DMA source (ram_buffer + page offset, or cache if enabled)

    // Finalize page write
    WRITE_TRANS,            // Wait for DMA transfer complete
    WRITE_PP_WAIT_READY_2,  // Wait for SPI Host ready
    WRITE_PP_SEND_CMD_2     // Send final command to release CS (ends page program)
    //and redirect depending on number of pages programmed and if more sectors need to be written
  } write_state_e;

  // -------- DMA INIT FSM STATES --------
  // Resets all DMA registers before each transfer
  // This ensures clean state regardless of previous DMA operations
  typedef enum logic [1:0] {
    DMA_INIT_IDLE,  // Wait for DMA to be ready (check status)
    DMA_INIT_REGISTERS,  // Clear all registers
    DMA_INIT_REDIRECT  // Return to calling FSM
  } dma_init_state_e;

  // -------- DMA INIT RETURN TYPE --------
  // Indicates which sub-FSM to return to after DMA initialization
  typedef enum logic [1:0] {
    RETURN_READ,  // Return to READ FSM (flash -> RAM sector buffer transfer)
    RETURN_MODIFY,  // Return to MODIFY FSM (RAM new data -> RAM sector buffer transfer)
    RETURN_WRITE,  // Return to WRITE FSM (RAM sector buffer -> flash transfer)
    // If cache enabled:
    RETURN_READ_CACHE  // Return to CHECK_CACHE FSM (cache -> RAM sector buffer transfer)
  } dma_init_return_e;

  // -------- MEMIO FAST-PATH STATES --------
  typedef enum logic [1:0] {
    MEMIO_IDLE,
    MEMIO_READ,
    MEMIO_WRITE
  } memio_state_e;

  // ============== LOCAL PARAMETERS ==============
  localparam int SPI_FLASH_TX_FIFO_DEPTH = spi_host_reg_pkg::TxDepth;
  localparam logic [1:0] SPI_DIR_DUMMY = 2'h0;
  localparam logic [1:0] SPI_DIR_RX = 2'h1;
  localparam logic [1:0] SPI_DIR_TX = 2'h2;
  localparam logic [1:0] SPI_SPEED_STD = 2'h0;
  localparam logic [1:0] SPI_SPEED_QUAD = 2'h2;

  localparam logic [23:0] SPI_DUMMY_CYCLES_WAIT = 24'h03;

`ifdef VERILATOR
  localparam QUAD_AVAILABLE = 0;
`else
  localparam QUAD_AVAILABLE = 1;
`endif

  // FLASH COMMANDS
  localparam logic [12:0] FC_RD = 13'h03,  // Read Data
  FC_RDQIO = 13'heb,  // Read Data Quad I/O
  FC_RSR1 = 13'h05,  // Read Status Register 1
  FC_WE = 13'h06,  // Write Enable
  FC_SE = 13'h20,  // Sector Erase 4KB
  FC_PP = 13'h02,  // Page Program
  FC_PPQ = 13'h32,  // Page Program Quad
  // W25Q128JW SIZE CONSTANTS
  SE_WSIZE = 13'h400,  // Sector size in words
  SE_BSIZE = 13'h1000,  // Sector size in bytes
  PAGE_WSIZE = 13'h40,  // Page size in words
  PAGE_BSIZE = 13'h100;  // Page size in bytes

  // ============== BYTE SWAP FUNCTION ==============
  function automatic [31:0] bitfield_byteswap32(input [31:0] adress_to_swap);
    bitfield_byteswap32 = {
      adress_to_swap[7:0],  // Byte 0 -> Byte 3
      adress_to_swap[15:8],  // Byte 1 -> Byte 2
      adress_to_swap[23:16],  // Byte 2 -> Byte 1
      adress_to_swap[31:24]  // Byte 3 -> Byte 0
    };
  endfunction

  // verilog_format: off
  function automatic logic [31:0] spi_cmd_pack(
      input logic [1:0]  direction,
      input logic [1:0]  speed,
      input logic        csaat,
      input logic [23:0] len_m1
  );
    spi_cmd_pack = {3'b000, direction, speed, csaat, len_m1};
  endfunction
  // verilog_format: on

endpackage
