/**
 * w25q128jw_controller.sv
 * Hardware controller for W25Q128JW flash memory.
 *
 * Uses DMA and SPI Flash peripherals to perform data transfers without CPU intervention.
 *
 * See "sw/application/example_spi_read/write" and "sw/device/bsp/w25q" for main source of inspiration to this module's design.
 *
 * See "sw/application/example_w25q128jw_read/write" for software usage examples (with polling-mode).
 * or "sw/application/example_w25q128jw_read_interrupt" for interrupt-mode usage.
 *
 * Author: Thomas Lenges   <thomas.lenges@epfl.ch> 
 *                         <thomas.lenges@hotmail.com>
 * Additional authors:  Davide Schiavone <davide.schiavone@epfl.ch>
 */
module w25q128jw_controller
  import core_v_mini_mcu_pkg::*;
  import dma_reg_pkg::*;
  import spi_host_reg_pkg::*;
#(
    parameter type reg_req_t = reg_pkg::reg_req_t,
    parameter type reg_rsp_t = reg_pkg::reg_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,

    // Register interface from system bus
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // Interrupt signal
    output logic w25q128jw_controller_intr_o,

    // Master ports to the SPI HOST
    output reg_req_t spi_host_reg_req_o,
    input  reg_rsp_t spi_host_reg_rsp_i,

    // DMA HW Controller 
    output dma_reg_pkg::dma_hw2reg_t external_dma_hw2reg_o,
    // SPI HW register
    input spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status_i,

    // DMA channel redy/done signals (directly from DMA IP)
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_ready_i,
    input logic [core_v_mini_mcu_pkg::DMA_CH_NUM-1:0] dma_done_i
);

  // ============== PACKAGE IMPORTS ==============
  import w25q128jw_controller_reg_pkg::*;

  // ============== REGISTER SIGNALS ==============
  w25q128jw_controller_reg2hw_t reg2hw;
  w25q128jw_controller_hw2reg_t hw2reg;

  // ============== LOCAL PARAMETERS ==============
  localparam int SPI_FLASH_TX_FIFO_DEPTH = spi_host_reg_pkg::TxDepth;

  // FLASH COMMANDS
  localparam logic [12:0] FC_RD = 13'h03,  // Read Data
  FC_RSR1 = 13'h05,  // Read Status Register 1
  FC_WE = 13'h06,  // Write Enable
  FC_SE = 13'h20,  // Sector Erase 4KB
  FC_PP = 13'h02,  // Page Program
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


  // ============================================================================
  // W25Q128JW CONTROLLER FSM
  // ============================================================================

  // -------- TOP FSM STATES --------
  // Top controller FSM
  typedef enum logic [2:0] {
    TOP_IDLE,     // Wait for start command
    TOP_READ,     // Read from flash to RAM sector buffer
    TOP_FWAIT,    // Wait for flash internal operation
    TOP_ERASE,    // Erase flash sector
    TOP_MODIFY,   // Modify RAM sector buffer with RAM data to write-back to flash
    TOP_WRITE,    // Write RAM sector buffer to flash
    TOP_DMA_INIT  // Initialize DMA registers
  } top_state_e;

  // -------- READ FSM STATES --------
  // Handles flash read operations via SPI & DMA
  typedef enum logic [3:0] {
    READ_IDLE,  // Lead to DMA initialization (necessary before every use of DMA)
    READ_SET_DMA,  // Set the DMA registers
    READ_SPI_CHECK_TX_FIFO,  // Check if TX FIFO has space
    READ_SPI_FILL_TX_FIFO,  // Write command + address to TX FIFO
    READ_SPI_WAIT_READY_1,  // Wait for SPI Host ready
    READ_SPI_SEND_CMD_1,  // Send command to specify action type and action location
    READ_SPI_WAIT_READY_2,  // Wait for SPI Host ready again
    READ_SPI_SEND_CMD_2,  // Send command to specify read action
    READ_TRANS  // Wait for DMA transfer complete
  } read_state_e;

  // -------- FLASH WAIT FSM STATES --------
  // Waits for flash internal operations to complete (erase/program)
  // by polling the flash status register (Read Status Register 1) (Not necessary in simulation)
  typedef enum logic [3:0] {
    FWAIT_IDLE,  // If in simulation, bypass wait. Else, go through FWAIT & ERASE FSMs
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
  // Uses DMA to transfer from ram_new_data to ram_buffer
  typedef enum logic [1:0] {
    MODIFY_IDLE,  // Leads to DMA initialization
    MODIFY_DMA_REGS, // Set the DMA registers (ram_new_data + offset (which sector we are now looking to write into + F_ADDRESS sector misalignment))
    MODIFY_TRANS  // Wait for DMA transfer complete and update offsets + remaining length to write
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
    WRITE_DMA_REGS,         // Set DMA source (ram_buffer + page offset)

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
  typedef enum logic [2:0] {
    RETURN_READ,    // Return to READ FSM (flash -> RAM sector buffer transfer)
    RETURN_MODIFY,  // Return to MODIFY FSM (RAM new data -> RAM sector buffer transfer)
    RETURN_WRITE    // Return to WRITE FSM (RAM sector buffer -> flash transfer)
  } dma_init_return_e;

  // FSM signals
  top_state_e top_state_q, top_state_d;
  read_state_e read_state_q, read_state_d;
  erase_state_e erase_state_q, erase_state_d;
  fwait_state_e fwait_state_q, fwait_state_d;
  modify_state_e modify_state_q, modify_state_d;
  write_state_e write_state_q, write_state_d;
  dma_init_state_e dma_init_state_q, dma_init_state_d;
  dma_init_return_e dma_init_return_q, dma_init_return_d;

  // Counter and Offset signals
  logic [1:0] fwait_cnt_q, fwait_cnt_d;
  logic [3:0] page_cnt_q, page_cnt_d;
  logic [31:0] sector_offset, sector_iter_offset_d, sector_iter_offset_q, md_offset_d, md_offset_q;

  // Simulation Bypass Signal
  logic pass_fwait;
  logic [31:0] dma_size;

  logic [31:0] flash_address;


  // In simulation (not FPGA_SYNTHESIS and not SYNTHESIS), we skip the flash wait and erase FSMs
  // This is mandatory as otherwise the controller will be stuck in FWAIT FSM in simulation
`ifndef FPGA_SYNTHESIS
`ifndef SYNTHESIS
  assign pass_fwait = 1'b1;
`else
  assign pass_fwait = 1'b0;
`endif
`else
  assign pass_fwait = 1'b0;
`endif

  // FSM sequential logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // -------- Reset: Initialize all FSMs to IDLE --------
      dma_init_state_q <= DMA_INIT_IDLE;
      dma_init_return_q <= RETURN_READ;
      top_state_q   <= TOP_IDLE;
      read_state_q  <= READ_IDLE;
      erase_state_q <= ERASE_IDLE;
      fwait_state_q <= FWAIT_IDLE;
      modify_state_q <= MODIFY_IDLE;
      write_state_q <= WRITE_IDLE;

      // -------- Reset: Clear counters and offsets --------
      fwait_cnt_q   <= 2'b0;
      page_cnt_q    <= 4'b0;
      sector_iter_offset_q <= 32'h0;
      md_offset_q <= 32'h0;
    end else begin
      dma_init_state_q <= dma_init_state_d;
      dma_init_return_q <= dma_init_return_d;
      top_state_q   <= top_state_d;
      read_state_q  <= read_state_d;
      erase_state_q <= erase_state_d;
      fwait_state_q <= fwait_state_d;
      modify_state_q <= modify_state_d;
      write_state_q <= write_state_d;
      fwait_cnt_q   <= fwait_cnt_d;
      page_cnt_q    <= page_cnt_d;
      sector_iter_offset_q <= sector_iter_offset_d;
      md_offset_q <= md_offset_d;
    end
  end

  logic [spi_host_reg_pkg::BlockAw-1:0] spi_host_reg_req_offset;

  assign spi_host_reg_req_o.addr = SPI_FLASH_START_ADDRESS + {{(32 - spi_host_reg_pkg::BlockAw){1'b0}}, spi_host_reg_req_offset};

  // FSM combinational logic
  always_comb begin
    dma_init_state_d = dma_init_state_q;
    dma_init_return_d = dma_init_return_q;
    top_state_d = top_state_q;
    read_state_d = read_state_q;
    erase_state_d = erase_state_q;
    fwait_state_d = fwait_state_q;
    modify_state_d = modify_state_q;
    write_state_d = write_state_q;
    fwait_cnt_d = fwait_cnt_q;
    page_cnt_d = page_cnt_q;
    sector_iter_offset_d = sector_iter_offset_q;
    md_offset_d = md_offset_q;

    sector_offset = 32'h0;

    hw2reg.control.start.de = 1'b0;
    hw2reg.control.start.d = 1'b0;
    hw2reg.control.rnw.de = 1'b0;
    hw2reg.control.rnw.d = 1'b0;
    hw2reg.length.de = 1'b0;
    hw2reg.length.d = 32'h0;
    hw2reg.intr_status.de   = 1'b0;
    hw2reg.intr_status.d    = 1'b0;

    external_dma_hw2reg_o   = '0;

    dma_size = '0;
    flash_address = '0;

    spi_host_reg_req_o.valid = '0;
    spi_host_reg_req_o.wstrb = 4'b1111;
    spi_host_reg_req_o.write = 1'b0;
    spi_host_reg_req_o.wdata = '0;
    spi_host_reg_req_offset  = '0;

    // ============================================================================
    // TOP FSM
    // ============================================================================
    // Orchestrates all sub-FSMs based on the requested operation:
    //   - Read (rnw=1):  TOP_IDLE -> TOP_READ -> TOP_IDLE
    //   - Write (rnw=0): TOP_IDLE -> TOP_READ -> TOP_FWAIT -> TOP_ERASE -> TOP_FWAIT -> 
    //                    TOP_MODIFY -> TOP_WRITE -> TOP_FWAIT -> TOP_IDLE
    //
    // Note that:
    //   - FWAIT AND ERASE are bypassed in SIM
    //   - Read operation is byte precise while Write operation is word precise
    //   - meaning that, if you write 5bytes, it writes 8 bytes (round to next word size)
    //   - this is because the MODIFY FSM (SRAM to SRAM) uses WORDs type transfers

    case (top_state_q)
      // -------- IDLE STATE --------
      // Wait for SW to set the START bit in CONTROL register
      TOP_IDLE: begin
        if (reg2hw.control.start.q) begin
          top_state_d = TOP_READ;  // Always start with READ (for both read and write operations)
        end
      end

      // ============================================================================
      // READ FSM
      // ============================================================================
      // For READ operation (rnw=1): Reads bytes from flash to RAM from f_address
      // For WRITE operation (rnw=0): Reads one entire sector (4KB) to RAM starting from sector containing f_address
      // and continues with following sectors if necessary on next TOP FSM iteration
      // ============================================================================

      TOP_READ: begin
        case (read_state_q)
          // -------- IDLE: Trigger DMA initialization --------
          READ_IDLE: begin
            top_state_d       = TOP_DMA_INIT;  // Go to DMA init FSM
            dma_init_return_d = RETURN_READ;  // Return here after DMA init
            read_state_d      = READ_SET_DMA;  // Next state after returning from DMA init
          end

          // ============== DMA CONFIGURATION ==============
          READ_SET_DMA: begin
            read_state_d = READ_SPI_CHECK_TX_FIFO;
            //Set DMA source pointer: SPI RX FIFO
            external_dma_hw2reg_o.src_ptr.de = 1'b1;
            external_dma_hw2reg_o.src_ptr.d  = SPI_FLASH_START_ADDRESS + {25'b0, SPI_HOST_RXDATA_OFFSET}; // SPI RX FIFO address;
            //Set DMA destination pointer: RAM sector buffer
            external_dma_hw2reg_o.dst_ptr.de = 1'b1;
            external_dma_hw2reg_o.dst_ptr.d = reg2hw.s_address.q; // RAM buffer address from S_ADDRESS register
            //Set source increment: 0 (stay at FIFO address)
            external_dma_hw2reg_o.src_ptr_inc_d1.de = 1'b1;
            external_dma_hw2reg_o.src_ptr_inc_d1.d  = '0; // No increment - always read from RX FIFO address
            //Set destination increment: +4 bytes per word
            external_dma_hw2reg_o.dst_ptr_inc_d1.de = 1'b1;
            external_dma_hw2reg_o.dst_ptr_inc_d1.d  = 'h04; // Increment by 4 bytes (32-bit word) in RAM
            //Set source data type: 32-bit word
            external_dma_hw2reg_o.src_data_type.de = 1'b1;
            external_dma_hw2reg_o.src_data_type.d = '0;  // 0 = 32-bit word
            //Set destination data type: 32-bit word
            external_dma_hw2reg_o.dst_data_type.de = 1'b1;
            external_dma_hw2reg_o.dst_data_type.d = '0;  // 0 = 32-bit word
            //Set DMA trigger slots
            external_dma_hw2reg_o.slot.rx_trigger_slot.de = 1'b1;
            external_dma_hw2reg_o.slot.rx_trigger_slot.d = 'h4;
            external_dma_hw2reg_o.slot.tx_trigger_slot.de = 1'b1;
            external_dma_hw2reg_o.slot.tx_trigger_slot.d = '0;
            //Set slot wait counter
            external_dma_hw2reg_o.slot_wait_counter.de = 1'b1;
            external_dma_hw2reg_o.slot_wait_counter.d   = reg2hw.dma_slot_wait_counter.q; // slot_wait_counter to write to DMA

            //Set transfer size and START DMA
            external_dma_hw2reg_o.size_d1.de = 1'b1;
            if (reg2hw.control.rnw.q) begin
              // READ operation: transfer user-specified length
              if (reg2hw.length.q[1:0] == 0) begin
                dma_size = reg2hw.length.q >> 2;  // Exact word count (length divisible by 4)
              end else begin
                dma_size = (reg2hw.length.q >> 2) + 1;  // Round up to next word
              end
            end else begin
              // WRITE operation: always read one sector (1024 words = 4KB)
              dma_size = {19'b0, SE_WSIZE};
            end
            external_dma_hw2reg_o.size_d1.d = dma_size[15:0];
          end

          // ============== SPI COMMAND SEQUENCE ==============

          // -------- Check if TX FIFO has space for command --------
          READ_SPI_CHECK_TX_FIFO: begin
            // STATUS[7:0] = TXQD (TX FIFO depth). Proceed if not full.
            // See hw/vendor/lowrisc_opentitan_spi_host/data/spi_host.hjson for status register bit mapping
            // See hw/vendor/lowrisc_opentitan_spi_host/rtl/spi_host_reg_pkg.sv for TXQD depth definition
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              read_state_d = READ_SPI_FILL_TX_FIFO;
            end
          end

          // -------- Write READ command + address to TX FIFO --------
          // Format: [31:8] = 24-bit flash address byte swapped, [7:0] = FC_RD command (0x03)
          // Inspiration from sw/device/bsp/w25q
          READ_SPI_FILL_TX_FIFO: begin
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;

            if (reg2hw.control.rnw.q) begin
              // READ: Use exact flash address from F_ADDRESS register
              flash_address = reg2hw.f_address.q & 32'h00ffffff;
              spi_host_reg_req_o.wdata = (((bitfield_byteswap32(flash_address)) >> 8) << 8) |
                  {19'h0, FC_RD};
            end else begin
              // WRITE: Use sector-aligned address + current sector iteration offset
              flash_address = (reg2hw.f_address.q & 32'h00fff000) + (sector_iter_offset_q);
              spi_host_reg_req_o.wdata = (((bitfield_byteswap32(flash_address)) >> 8) << 8) |
                  {19'h0, FC_RD};
            end
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_WAIT_READY_1;
            end
          end

          // -------- Wait for SPI Host ready (Send action type and location) --------
          READ_SPI_WAIT_READY_1: begin
            // STATUS[31] = READY bit. Proceed if ready.
            if (external_spi_host_hw2reg_status_i.ready.d) begin //TODO: update similar states checking this
              read_state_d = READ_SPI_SEND_CMD_1;
            end
          end

          // -------- Send command phase: Read operation from f_address --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (2 = TX only)
          //   [26:25] = Speed (0 = standard)
          //   [24]    = CSAAT (1 = keep CS asserted for next command)
          //   [23:0]  = Length-1 (3 = 4 bytes: 1 command + 3 address)
          READ_SPI_SEND_CMD_1: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h1, 24'h3
            };  // Reserved + Direction + Speed + Csaat + Length
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_WAIT_READY_2;
            end
          end

          // // -------- Wait for SPI Host ready (Specify read action) --------
          READ_SPI_WAIT_READY_2: begin
            // STATUS[31] = READY bit. Proceed if ready.
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_2;
            end
          end

          // -------- Send command phase: Direction and length of read operation --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (1 = RX only)
          //   [26:25] = Speed (0 = standard)
          //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
          //   [23:0]  = See comments below
          READ_SPI_SEND_CMD_2: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;

            if (reg2hw.control.rnw.q) begin
              // READ: receive user-specified number of bytes
              spi_host_reg_req_o.wdata = {
                3'h0, 2'h1, 2'h0, 1'h0, reg2hw.length.q[23:0] - 1'h1
              };  // Empty + Direction + Speed + Csaat + Length
            end else begin
              // WRITE: read full sector (4096 bytes)
              spi_host_reg_req_o.wdata = {
                3'h0, 2'h1, 2'h0, 1'h0, {11'b0, SE_BSIZE - 1'h1}
              };  // Empty + Direction + Speed + Csaat + Length
            end
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_TRANS;
            end
          end

          // ============== WAIT FOR DMA COMPLETION ==============
          READ_TRANS: begin
            if (dma_done_i[0]) begin  // DMA channel 0 done signal
              if (reg2hw.control.rnw.q) begin
                // ===== READ OPERATION COMPLETE =====
                read_state_d            = READ_IDLE;
                top_state_d             = TOP_IDLE;
                hw2reg.control.start.de = 1'b1;
                hw2reg.control.start.d  = 1'b0;
                hw2reg.intr_status.de   = 1'b1;
                hw2reg.intr_status.d    = reg2hw.intr_enable.q;
              end else begin
                // ===== WRITE OPERATION: Proceed to FWAIT =====
                read_state_d  = READ_IDLE;
                top_state_d   = TOP_FWAIT;
                fwait_state_d = FWAIT_IDLE;
              end
            end
          end

          default: begin
            read_state_d = READ_IDLE;
          end
        endcase
      end

      // ============================================================================
      // FWAIT FSM (Flash WAIT)
      // ============================================================================
      // Polls the flash Status Register 1 (SR1) to check if the flash is busy
      // The BUSY bit (bit 0) is set during erase/program operations
      //
      // This FSM is called multiple times during a write operation:
      // IN SIM:
      //   fwait_cnt = 0: After READ  -> bypass wait, go to MODIFY
      //   fwait_cnt = 1: After WRITE -> bypass wait, complete
      //
      // In NOT SIM:
      //   fwait_cnt = 0: After READ  -> wait for flash ready, then go to ERASE
      //   fwait_cnt = 1: After ERASE -> wait for flash ready, then go to MODIFY
      //   fwait_cnt = 2: After WRITE -> wait for flash ready, then complete
      //
      // Note: fwait_cnt is reset to 0 if total length has not been written yet and more sectors need to be processed
      // Hence the operation only finishes when all the data has been written back into flash
      // ============================================================================

      TOP_FWAIT: begin
        case (fwait_state_q)

          // -------- IDLE: Check for simulation bypass or start flash wait FSM --------
          FWAIT_IDLE: begin
            if (pass_fwait) begin
              // ===== SIMULATION MODE: Skip flash wait =====
              case (fwait_cnt_q)
                // After READ: Skip ERASE, go directly to MODIFY
                2'h0: begin
                  fwait_cnt_d   = 2'h1;
                  fwait_state_d = FWAIT_IDLE;
                  top_state_d   = TOP_MODIFY;
                end
                // After MODIFY+WRITE: Operation complete
                2'h1: begin
                  fwait_cnt_d = 2'h0;
                  fwait_state_d = FWAIT_IDLE;
                  top_state_d = TOP_IDLE;
                  md_offset_d = 32'h0;  // Reset MODIFY offset for next operation
                  sector_iter_offset_d = 32'h0;  // Reset sector iteration offset for next operation
                  hw2reg.control.start.de = 1'b1;  // Clear START bit so operation is only done once
                  hw2reg.control.start.d = 1'b0;
                  hw2reg.intr_status.de   = 1'b1;     // Set interrupt status (rise IRQ through assignements (see end of module))
                  hw2reg.intr_status.d = reg2hw.intr_enable.q;
                end

                default: begin
                end
              endcase
            end else begin
              // ===== SYNTHESIS/FPGA MODE: Start polling flash Status Register 1 =====
              fwait_state_d = FWAIT_SET_RXWM_R;
            end
          end

          // ============== CONFIGURE RX WATERMARK ==============
          // Set RX watermark to 1 word so we get notified when status byte arrives
          // See hw/vendor/lowrisc_opentitan_spi_host/data/spi_host.hjson for CONTROL register bit mapping
          // See sw/device/bsp/w25q/w25q.c for function flash_wait
          // See sw/device/lib/drivers/spi_host/spi_host.c for function spi_set_rx_watermark

          // -------- Read current CONTROL register value --------
          // We need to preserve other bits when modifying RXWM (preserved in read_value from OBI FSM)
          FWAIT_SET_RXWM_R: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              //we are sharing the sector_iter_offset_q register with the rdata from SPI to save resources
              sector_iter_offset_d = spi_host_reg_rsp_i.rdata;
              fwait_state_d = FWAIT_SET_RXWM_W;
            end
          end

          // -------- Write back with RX watermark = 1 --------
          FWAIT_SET_RXWM_W: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            //we are sharing the sector_iter_offset_q register with the rdata from SPI to save resources
            //in this state, the sector_iter_offset_q register represents the previous read value
            spi_host_reg_req_o.wdata = {
              sector_iter_offset_q[31:8], 8'h01
            };  // Keep upper CONTROL bits, set RXWM = 1
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_SPI_CHECK_TX_FIFO;
            end
          end

          // ============== SEND READ STATUS REGISTER COMMAND ==============

          // -------- Check if TX FIFO has space --------
          FWAIT_SPI_CHECK_TX_FIFO: begin
            // STATUS[7:0] = TXQD (TX FIFO depth)
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              fwait_state_d = FWAIT_SPI_FILL_TX_FIFO;
            end
          end

          // -------- Write Read Status Register 1 command to TX FIFO --------
          FWAIT_SPI_FILL_TX_FIFO: begin
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'b0, FC_RSR1};
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_SPI_WAIT_READY_1;
            end
          end

          // -------- Wait for SPI Host ready --------
          FWAIT_SPI_WAIT_READY_1: begin
            // STATUS[31] = READY bit
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              fwait_state_d = FWAIT_SPI_SEND_CMD_1;
            end
          end

          // -------- Send command phase: TX 1 byte (the RSR1 command) --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (2 = TX only)
          //   [24]    = CSAAT (1 = keep CS asserted for next command)
          //   [23:0]  = Length-1 (0 = 1 byte) (FC_RSR1 is 1 byte command)
          FWAIT_SPI_SEND_CMD_1: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h1, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_SPI_WAIT_READY_2;
            end
          end

          // -------- Wait for SPI Host ready --------
          FWAIT_SPI_WAIT_READY_2: begin
            // STATUS[31] = READY bit
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              fwait_state_d = FWAIT_SPI_SEND_CMD_2;
            end
          end

          // -------- Send command phase: RX 1 byte (the status register value) --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (1 = RX only)
          //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
          //   [23:0]  = Length-1 (0 = 1 byte)
          FWAIT_SPI_SEND_CMD_2: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h1, 2'h0, 1'h0, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              fwait_state_d = FWAIT_WAIT_RXWM;
            end
          end

          // ============== WAIT FOR AND READ STATUS BYTE ==============

          // -------- Wait for status byte received --------
          FWAIT_WAIT_RXWM: begin
            spi_host_reg_req_offset  = SPI_HOST_STATUS_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            // STATUS[20] = RXWM (RX watermark reached)
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error && spi_host_reg_rsp_i.rdata[20]) begin
              fwait_state_d = FWAIT_READ_FLASH_STATUS;
            end
          end

          // -------- Read flash status byte and check BUSY bit --------
          FWAIT_READ_FLASH_STATUS: begin
            spi_host_reg_req_offset  = SPI_HOST_RXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;

            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // Check BUSY bit: 0 = ready, 1 = busy
              if (spi_host_reg_rsp_i.rdata[0] == 1'b0) begin
                // ===== FLASH READY: Proceed to next operation =====
                case (fwait_cnt_q)
                  // After READ: Flash ready -> go to ERASE
                  2'h0: begin
                    fwait_cnt_d   = 2'h1;
                    fwait_state_d = FWAIT_IDLE;
                    top_state_d   = TOP_ERASE;
                    erase_state_d = ERASE_IDLE;
                  end
                  // After ERASE: Flash ready -> go to MODIFY
                  2'h1: begin
                    fwait_cnt_d = 2'h2;
                    fwait_state_d = FWAIT_IDLE;
                    top_state_d = TOP_MODIFY;
                    modify_state_d = MODIFY_IDLE;
                  end
                  // After WRITE: Flash ready -> operation complete
                  2'h2: begin
                    fwait_cnt_d = 2'h0;
                    fwait_state_d = FWAIT_IDLE;
                    top_state_d = TOP_IDLE;
                    md_offset_d = 32'h0;  // Reset MODIFY offset for next operation
                    sector_iter_offset_d = 32'h0; // Reset sector iteration offset for next operation
                    hw2reg.control.start.de = 1'b1;     // Clear START bit so operation is only done once
                    hw2reg.control.start.d = 1'b0;
                    hw2reg.intr_status.de   = 1'b1;     // Set interrupt status (rise IRQ through assignements (see end of module))
                    hw2reg.intr_status.d = reg2hw.intr_enable.q;
                  end

                  default: begin
                  end
                endcase
              end else begin
                // ===== FLASH STILL BUSY: Poll again =====
                fwait_state_d = FWAIT_SET_RXWM_R;
              end
            end
          end

          default: begin
            fwait_state_d = FWAIT_IDLE;
          end

        endcase
      end


      // ============================================================================
      // ERASE FSM
      // ============================================================================
      // Erases a 4KB sector in the flash memory
      // Flash memory requires erasing (setting all bits to 1) before programming as a switch from 0 to 1 is not possible for this technology
      //
      // The erase sequence consists of two SPI commands:
      //   1. Write Enable (WE): Required before any write/erase operation
      //   2. Sector Erase (SE): Erases 4KB sector at specified address
      //
      // See: sw/device/bsp/w25q/w25q.c w25q128jw_4k_erase function
      // ============================================================================

      TOP_ERASE: begin
        case (erase_state_q)
          // -------- IDLE: Start erase sequence --------
          ERASE_IDLE: begin
            erase_state_d = ERASE_WE_CHECK_TX_FIFO;
          end

          // ============== WRITE ENABLE COMMAND SEQUENCE ==============
          // Required before any write/erase operation

          // -------- Check if TX FIFO has space --------
          ERASE_WE_CHECK_TX_FIFO: begin
            // STATUS[7:0] = TXQD (TX FIFO depth)
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              erase_state_d = ERASE_WE_FILL_TX_FIFO;
            end
          end

          // -------- Write Write Enable command to TX FIFO --------
          ERASE_WE_FILL_TX_FIFO: begin
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'b0, FC_WE};
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              erase_state_d = ERASE_WE_WAIT_READY;
            end
          end

          // -------- Wait for SPI Host ready --------
          ERASE_WE_WAIT_READY: begin
            // STATUS[31] = READY bit
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              erase_state_d = ERASE_WE_SEND_CMD;
            end
          end

          // -------- Send Write Enable command --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (2 = TX only)
          //   [24]    = CSAAT (0 = release CS after, WE is standalone command)
          //   [23:0]  = Length-1 (0 = 1 byte)
          ERASE_WE_SEND_CMD: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              erase_state_d = ERASE_SE_CHECK_TX_FIFO;
            end
          end

          // ============== SECTOR ERASE COMMAND SEQUENCE ==============

          // -------- Check if TX FIFO has space --------
          ERASE_SE_CHECK_TX_FIFO: begin
            // STATUS[7:0] = TXQD (TX FIFO depth)
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              erase_state_d = ERASE_SE_FILL_TX_FIFO;
            end
          end

          // -------- Write Sector Erase command + address to TX FIFO --------

          ERASE_SE_FILL_TX_FIFO: begin
            spi_host_reg_req_offset = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            // Use sector-aligned address + current sector iteration offset + SECTOR ERASE command
            // Inspiration from sw/device/bsp/w25q
            flash_address = (reg2hw.f_address.q & 32'h00fff000) + (sector_iter_offset_q);
            spi_host_reg_req_o.wdata = ((bitfield_byteswap32(flash_address) >> 8) << 8) |
                {19'h0, FC_SE};
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              erase_state_d = ERASE_SE_WAIT_READY;
            end
          end

          // -------- Wait for SPI Host ready --------
          ERASE_SE_WAIT_READY: begin
            // STATUS[31] = READY bit
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              erase_state_d = ERASE_SE_SEND_CMD;
            end
          end

          // -------- Send Sector Erase command --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (2 = TX only)
          //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
          //   [23:0]  = Length-1 (3 = 4 bytes: 1 cmd + 3 addr bytes)
          ERASE_SE_SEND_CMD: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, 24'h3
            };  // Empty + Direction + Speed + Csaat + Length
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // Go to FWAIT FSM to poll status register until erase completes
              erase_state_d = ERASE_IDLE;
              top_state_d = TOP_FWAIT;
              fwait_state_d = FWAIT_SET_RXWM_R; // Start polling (skip FWAIT_IDLE since we know we need to wait: NO SIM)
            end
          end

          default: begin
            erase_state_d = ERASE_IDLE;
          end
        endcase
      end

      // ============================================================================
      // MODIFY FSM
      // ============================================================================
      // At this point, the sector buffer (at S_ADDRESS) already contains the original sector data
      // from flash (loaded by READ FSM). This FSM overlays the new data (at MD_ADDRESS) at the
      // correct position within the sector.
      //
      // For multi-sector write operations:
      //   - First sector: Data is placed at sector_offset (f_address & 0xFFF)
      //   - Subsequent sectors: Data starts at offset 0
      //
      // After MODIFY completes, the LENGTH register is updated and a new iteration will take place after the WRITE FSM
      // with the remaining bytes (if any).
      // ============================================================================
      TOP_MODIFY: begin

        // -------- Compute sector offset --------
        if (sector_iter_offset_q == 0) begin
          sector_offset = reg2hw.f_address.q & 32'h00000fff;  // Offset within sector for first iteration
        end else begin
          sector_offset = 32'h0;  // Begin from start of sector for next iterations
        end

        case (modify_state_q)
          // -------- IDLE: Trigger DMA initialization --------
          MODIFY_IDLE: begin
            top_state_d       = TOP_DMA_INIT;  // Go to DMA init FSM
            dma_init_return_d = RETURN_MODIFY;  // Return here after DMA init
            modify_state_d    = MODIFY_DMA_REGS;  // Next state after returning from DMA init
          end

          // ============== DMA CONFIGURATION ==============
          MODIFY_DMA_REGS: begin
            modify_state_d = MODIFY_TRANS;
            //Set DMA source pointer: RAM new data buffer (at MD_ADDRESS)
            external_dma_hw2reg_o.src_ptr.de = 1'b1;
            // Source = MD_ADDRESS + offset for current sector iteration (for multi-sector writes) 
            // F_ADDRESS not necessarily sector aligned and such case must be taken into consideration
            external_dma_hw2reg_o.src_ptr.d = reg2hw.md_address.q + md_offset_q;
            //Set DMA destination pointer: RAM sector buffer
            external_dma_hw2reg_o.dst_ptr.de = 1'b1;
            external_dma_hw2reg_o.dst_ptr.d = reg2hw.s_address.q + sector_offset;
            // Destination = S_ADDRESS + offset within sector (for first iteration only, otherwise sector_offset = 0)
            // F_ADDRESS not necessarily sector aligned and such case must be taken into consideration
            //Set source increment: +4 bytes per word
            external_dma_hw2reg_o.src_ptr_inc_d1.de = 1'b1;
            external_dma_hw2reg_o.src_ptr_inc_d1.d  = 'h4;  // Increment by 4 bytes (32-bit word) in RAM
            //Set destination increment: +4 bytes per word
            external_dma_hw2reg_o.dst_ptr_inc_d1.de = 1'b1;
            external_dma_hw2reg_o.dst_ptr_inc_d1.d  = 'h4;  // Increment by 4 bytes (32-bit word) in RAM
            //Set source data type: 32-bit word (See hw/ip/dma/data/dma.hjson for data type encoding)
            external_dma_hw2reg_o.src_data_type.de = 1'b1;
            external_dma_hw2reg_o.src_data_type.d = '0;  // 0 = 32-bit word
            //Set destination data type: 32-bit word
            external_dma_hw2reg_o.dst_data_type.de = 1'b1;
            external_dma_hw2reg_o.dst_data_type.d = '0;  // 0 = 32-bit word
            //Set DMA trigger slots (See sw/device/lib/drivers/dma/dma.h for trigger slot mapping)
            external_dma_hw2reg_o.slot.rx_trigger_slot.de = 1'b1;
            external_dma_hw2reg_o.slot.rx_trigger_slot.d = '0;
            external_dma_hw2reg_o.slot.tx_trigger_slot.de = 1'b1;
            external_dma_hw2reg_o.slot.tx_trigger_slot.d = '0;
            //Set slot wait counter
            external_dma_hw2reg_o.slot_wait_counter.de = 1'b1;
            external_dma_hw2reg_o.slot_wait_counter.d = '0;

            //Set transfer size and START DMA
            external_dma_hw2reg_o.size_d1.de = 1'b1;
            // Writing to SIZE_D1 register triggers DMA transaction (See hw/ip/dma/data/dma.hjson)
            // Compute how many words to transfer for this sector
            if (reg2hw.length.q < {19'h0, SE_BSIZE} - sector_offset) begin
              // Case 1: All remaining data fits in this sector
              if (reg2hw.length.q[1:0] == 0) begin
                dma_size = reg2hw.length.q >> 2;  // Exact word count
              end else begin
                dma_size = (reg2hw.length.q >> 2) + 1;  // Round up to next word
              end
            end else begin
              // Case 2: Data spans multiple sectors. Fill remaining sector space
              // Transfer (4KB - offset) bytes
              dma_size = (({19'h0, SE_BSIZE} - sector_offset) >> 2);
            end
            external_dma_hw2reg_o.size_d1.d = dma_size[15:0];
          end

          // ============== WAIT FOR DMA COMPLETION ==============
          MODIFY_TRANS: begin
            if (dma_done_i[0]) begin  // DMA channel 0 done signal
              // Update LENGTH register for next iteration (if any)
              hw2reg.length.de = 1'b1;
              if (reg2hw.length.q < {19'h0, SE_BSIZE} - sector_offset) begin
                // All remaining data has been transferred at this iteration: set length to 0 and reset md_offset
                hw2reg.length.d = 32'h0;
                md_offset_d = 32'h0;
              end else begin
                // More data remains: compute remaining length for next sector iteration and update md_offset
                hw2reg.length.d = reg2hw.length.q - ({19'h0, SE_BSIZE} - sector_offset);
                md_offset_d = md_offset_q + ({19'h0, SE_BSIZE} - sector_offset);
              end
              // Proceed with WRITE FSM to program modified sector (page by page (page: 256 bytes)) back to flash
              modify_state_d = MODIFY_IDLE;
              top_state_d = TOP_WRITE;
              write_state_d = WRITE_IDLE;
            end
          end

          default: begin
            modify_state_d = MODIFY_IDLE;
          end
        endcase
      end

      // ============================================================================
      // WRITE FSM
      // ============================================================================
      // Programs the modified sector buffer back to flash, page by page
      // Flash page size is 256 bytes and a sector contains 16 pages resulting in 4096 bytes per sector
      //
      // For each page, the sequence is:
      //   1. Write Enable (WE): Required before each write/erase flash operation
      //   2. Page Program (PP): Send command + address, then DMA transfers page data from RAM to SPI Host TX FIFO
      //
      // After all 16 pages are programmed:
      //   - If LENGTH = 0: Operation complete, go to FWAIT
      //   - If LENGTH > 0: More sectors to process, restart from READ for next sector
      // ============================================================================

      TOP_WRITE: begin
        case (write_state_q)
          // -------- IDLE: Start write sequence --------
          WRITE_IDLE: begin
            write_state_d = WRITE_WE_CHECK_TX_FIFO;
          end

          // ============== WRITE ENABLE COMMAND SEQUENCE ==============
          // Required before each Page Program operation

          // -------- Check if TX FIFO has space --------
          WRITE_WE_CHECK_TX_FIFO: begin
            // STATUS[7:0] = TXQD (TX FIFO depth)
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              write_state_d = WRITE_WE_FILL_TX_FIFO;
            end
          end

          // -------- Write Write Enable command to TX FIFO --------
          WRITE_WE_FILL_TX_FIFO: begin
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            // Required every time before issuing a write command
            spi_host_reg_req_o.wdata = {19'b0, FC_WE};
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_WE_WAIT_READY;
            end
          end

          // -------- Wait for SPI Host ready --------
          WRITE_WE_WAIT_READY: begin
            // STATUS[31] = READY bit
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              write_state_d = WRITE_WE_SEND_CMD;
            end
          end

          // -------- Send Write Enable command --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (2 = TX only)
          //   [24]    = CSAAT (0 = release CS after, WE is standalone command)
          //   [23:0]  = Length-1 (0 = 1 byte)
          WRITE_WE_SEND_CMD: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, 24'h0
            };  // Empty + Direction + Speed + Csaat + Length
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_PP_CHECK_TX_FIFO;
            end
          end

          // ============== PAGE PROGRAM COMMAND SEQUENCE ==============

          // -------- Check if TX FIFO has space --------
          WRITE_PP_CHECK_TX_FIFO: begin
            // STATUS[7:0] = TXQD (TX FIFO depth)
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              write_state_d = WRITE_PP_FILL_TX_FIFO;
            end
          end

          // -------- Write Page Program command + address to TX FIFO --------
          // Inspiration from sw/device/bsp/w25q
          WRITE_PP_FILL_TX_FIFO: begin
            spi_host_reg_req_offset = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            // Compute page address: sector base + sector offset + page offset
            spi_host_reg_req_o.wdata = (((bitfield_byteswap32(((reg2hw.f_address.q & 32'h00fff000) + (sector_iter_offset_q)) |
                                           ({28'h0, page_cnt_q} << 8))) >> 8) << 8) |
                {19'h0, FC_PP};
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_PP_WAIT_READY;
            end
          end

          // -------- Wait for SPI Host ready --------
          WRITE_PP_WAIT_READY: begin
            // STATUS[31] = READY bit
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              write_state_d = WRITE_PP_SEND_CMD;
            end
          end

          // -------- Send Page Program command (Send action type and location) --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (2 = TX only)
          //   [24]    = CSAAT (1 = keep CS asserted for next command)
          //   [23:0]  = Length-1 (3 = 4 bytes: 1 cmd + 3 addr)
          WRITE_PP_SEND_CMD: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h1, 24'h3
            };  // Empty + Direction + Speed + Csaat + Length
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              write_state_d = WRITE_DMA_CHECK_READY;
            end
          end

          // ============== DMA CONFIGURATION FOR PAGE PROGRAM ==============

          // -------- Trigger DMA initialization --------
          WRITE_DMA_CHECK_READY: begin
            top_state_d       = TOP_DMA_INIT;  // Go to DMA init FSM
            dma_init_return_d = RETURN_WRITE;  // Return here after DMA init
            write_state_d     = WRITE_DMA_REGS;  // Next state after returning from DMA init
          end

          // -------- Set DMA registers for WRITE Operations --------
          WRITE_DMA_REGS: begin
            write_state_d = WRITE_TRANS;
            //Set DMA source pointer: RAM sector buffer (at S_ADDRESS) with page offset
            external_dma_hw2reg_o.src_ptr.de = 1'b1;
            external_dma_hw2reg_o.src_ptr.d = reg2hw.s_address.q + ({28'h0, page_cnt_q} << 8);
            //Set DMA destination pointer: SPI Host TX FIFO 
            external_dma_hw2reg_o.dst_ptr.de = 1'b1;
            external_dma_hw2reg_o.dst_ptr.d = SPI_FLASH_START_ADDRESS + {25'b0, SPI_HOST_TXDATA_OFFSET};
            //Set source increment: +4 bytes per word
            external_dma_hw2reg_o.src_ptr_inc_d1.de = 1'b1;
            external_dma_hw2reg_o.src_ptr_inc_d1.d = 'h4;  // Increment through sector buffer
            //Set destination increment: 0 (stay at TX FIFO)
            external_dma_hw2reg_o.dst_ptr_inc_d1.de = 1'b1;
            external_dma_hw2reg_o.dst_ptr_inc_d1.d = 'h0;  // Keep aiming TX FIFO
            //Set source data type: 32-bit word
            external_dma_hw2reg_o.src_data_type.de = 1'b1;
            external_dma_hw2reg_o.src_data_type.d = '0;  // 0 = 32-bit word
            //Set destination data type: 32-bit word
            external_dma_hw2reg_o.dst_data_type.de = 1'b1;
            external_dma_hw2reg_o.dst_data_type.d = '0;  // 0 = 32-bit word
            //Set DMA trigger slots
            external_dma_hw2reg_o.slot.rx_trigger_slot.de = 1'b1;
            external_dma_hw2reg_o.slot.rx_trigger_slot.d = '0;
            external_dma_hw2reg_o.slot.tx_trigger_slot.de = 1'b1;
            external_dma_hw2reg_o.slot.tx_trigger_slot.d = 'h8;
            //Set slot wait counter
            external_dma_hw2reg_o.slot_wait_counter.de = 1'b1;
            external_dma_hw2reg_o.slot_wait_counter.d = reg2hw.dma_slot_wait_counter.q;
            //Set transfer size and START DMA
            external_dma_hw2reg_o.size_d1.de = 1'b1;
            external_dma_hw2reg_o.size_d1.d = {3'h0, PAGE_WSIZE};
          end

          // ============== WAIT FOR DMA COMPLETION ==============
          WRITE_TRANS: begin
            if (dma_done_i[0]) begin  // DMA channel 0 done signal
              write_state_d = WRITE_PP_WAIT_READY_2;
            end
          end

          // -------- Wait for SPI Host ready (finalize page program after DMA has transferred required data in SPI TX FIFO) --------
          WRITE_PP_WAIT_READY_2: begin
            // STATUS[31] = READY bit
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              write_state_d = WRITE_PP_SEND_CMD_2;
            end
          end

          // -------- Send command phase: Direction and length of write operation --------
          // COMMAND register format:
          //   [31:29] = Reserved
          //   [28:27] = Direction (2 = TX only)
          //   [24]    = CSAAT (0 = release CS after transfer, no more commands to send)
          //   [23:0]  = Length-1 (255 = 256 bytes = 1 page)
          WRITE_PP_SEND_CMD_2: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              3'h0, 2'h2, 2'h0, 1'h0, {11'b0, PAGE_BSIZE - 1'h1}
            };  // Empty + Direction + Speed + Csaat + Length

            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // ===== CHECK IF MORE PAGES/SECTORS TO PROCESS =====
              if (page_cnt_q == 4'hf) begin
                // All 16 pages in current sector programmed
                if (reg2hw.length.q == 0) begin
                  // ===== ALL DATA WRITTEN: Go to FWAIT then complete =====
                  write_state_d = WRITE_IDLE;
                  top_state_d = TOP_FWAIT;
                  fwait_state_d = FWAIT_IDLE;
                  page_cnt_d = 4'b0;  // Reset page counter for time you use the controller
                end else begin
                  // ===== MORE SECTORS TO PROCESS: Restart from READ =====
                  fwait_cnt_d = 2'h0;  // Reset FWAIT counter for next sector
                  page_cnt_d = 4'b0;  // Reset page counter for next sector
                  sector_iter_offset_d = sector_iter_offset_q + {19'b0, SE_BSIZE}; // Next sector (+4KB)
                  top_state_d = TOP_READ;  // Go back to read next sector
                  write_state_d = WRITE_IDLE;
                end
              end else begin
                // ===== MORE PAGES IN CURRENT SECTOR: Program next page =====
                page_cnt_d = page_cnt_q + 1'h1;
                write_state_d = WRITE_WE_CHECK_TX_FIFO;  // Restart WE + PP sequence
              end
            end
          end

          default: begin
            write_state_d = WRITE_IDLE;
          end
        endcase
      end

      // ============================================================================
      // DMA INIT FSM
      // ============================================================================
      // Resets all DMA registers to a clean state before each transfer.
      // This is necessary because the DMA peripheral retains its configuration
      // between transfers, and leftover settings could cause incorrect behavior.
      //
      // This FSM is called before every DMA usage:
      //   - Before READ: SPI RX FIFO-> RAM sector buffer
      //   - Before MODIFY: RAM new data -> RAM sector buffer
      //   - Before WRITE (each page): RAM sector buffer -> SPI TX FIFO
      //
      // See: sw/device/lib/drivers/dma/dma.c for inspiration source
      // ============================================================================

      TOP_DMA_INIT: begin
        case (dma_init_state_q)
          // -------- IDLE: Wait for DMA to be ready --------
          // Poll DMA STATUS register until READY bit is set
          // See: hw/ip/dma/data/dma.hjson for STATUS register description
          DMA_INIT_IDLE: begin
            // STATUS[0] = READY bit
            if (dma_ready_i[0]) begin
              dma_init_state_d = DMA_INIT_REGISTERS;
            end
          end

          // This states are used to clear all the DMA registers
          DMA_INIT_REGISTERS: begin
            dma_init_state_d                                       = DMA_INIT_REDIRECT;
            external_dma_hw2reg_o.src_ptr.de                       = 1'b1;
            external_dma_hw2reg_o.src_ptr.d                        = '0;
            external_dma_hw2reg_o.dst_ptr.de                       = 1'b1;
            external_dma_hw2reg_o.dst_ptr.d                        = '0;
            external_dma_hw2reg_o.size_d1.de                       = 1'b1;
            external_dma_hw2reg_o.size_d1.d                        = '0;
            external_dma_hw2reg_o.size_d2.de                       = 1'b1;
            external_dma_hw2reg_o.size_d2.d                        = '0;
            external_dma_hw2reg_o.src_ptr_inc_d1.de                = 1'b1;
            external_dma_hw2reg_o.src_ptr_inc_d1.d                 = '0;
            external_dma_hw2reg_o.src_ptr_inc_d2.de                = 1'b1;
            external_dma_hw2reg_o.src_ptr_inc_d2.d                 = '0;
            external_dma_hw2reg_o.dst_ptr_inc_d1.de                = 1'b1;
            external_dma_hw2reg_o.dst_ptr_inc_d1.d                 = '0;
            external_dma_hw2reg_o.dst_ptr_inc_d2.de                = 1'b1;
            external_dma_hw2reg_o.dst_ptr_inc_d2.d                 = '0;
            external_dma_hw2reg_o.slot.rx_trigger_slot.de          = 1'b1;
            external_dma_hw2reg_o.slot.rx_trigger_slot.d           = '0;
            external_dma_hw2reg_o.slot.tx_trigger_slot.de          = 1'b1;
            external_dma_hw2reg_o.slot.tx_trigger_slot.d           = '0;
            external_dma_hw2reg_o.src_data_type.de                 = 1'b1;
            external_dma_hw2reg_o.src_data_type.d                  = '0;
            external_dma_hw2reg_o.dst_data_type.de                 = 1'b1;
            external_dma_hw2reg_o.dst_data_type.d                  = '0;
            external_dma_hw2reg_o.sign_ext.de                      = 1'b1;
            external_dma_hw2reg_o.sign_ext.d                       = '0;
            external_dma_hw2reg_o.mode.de                          = 1'b1;
            external_dma_hw2reg_o.mode.d                           = '0;
            external_dma_hw2reg_o.dim_config.de                    = 1'b1;
            external_dma_hw2reg_o.dim_config.d                     = '0;
            external_dma_hw2reg_o.mode.de                          = 1'b1;
            external_dma_hw2reg_o.mode.d                           = '0;
            external_dma_hw2reg_o.dim_inv.de                       = 1'b1;
            external_dma_hw2reg_o.dim_inv.d                        = '0;
            external_dma_hw2reg_o.interrupt_en.transaction_done.de = 1'b1;
            external_dma_hw2reg_o.interrupt_en.transaction_done.d  = '0;
            external_dma_hw2reg_o.interrupt_en.window_done.de      = 1'b1;
            external_dma_hw2reg_o.interrupt_en.window_done.d       = '0;
            external_dma_hw2reg_o.slot_wait_counter.de             = 1'b1;
            external_dma_hw2reg_o.slot_wait_counter.d              = '0;
`ifdef ZERO_PADDING_EN
            external_dma_hw2reg_o.pad_top.de    = 1'b1;
            external_dma_hw2reg_o.pad_top.d     = '0;
            external_dma_hw2reg_o.pad_bottom.de = 1'b1;
            external_dma_hw2reg_o.pad_bottom.d  = '0;
            external_dma_hw2reg_o.pad_right.de  = 1'b1;
            external_dma_hw2reg_o.pad_right.d   = '0;
            external_dma_hw2reg_o.pad_left.de   = 1'b1;
            external_dma_hw2reg_o.pad_left.d    = '0;
`endif
`ifdef ADDR_MODE_EN
            external_dma_hw2reg_o.addr_ptr.de = 1'b1;
            external_dma_hw2reg_o.addr_ptr.d  = '0;
`endif
          end

          // ============== REDIRECT TO CALLING FSM ==============

          DMA_INIT_REDIRECT: begin
            dma_init_state_d = DMA_INIT_IDLE;
            case (dma_init_return_q)
              RETURN_READ: begin
                top_state_d = TOP_READ;  // Continue with flash read operation
              end
              RETURN_MODIFY: begin
                top_state_d = TOP_MODIFY;  // Continue with sector buffer modification
              end
              RETURN_WRITE: begin
                top_state_d = TOP_WRITE;  // Continue with flash page programming
              end
              default: begin
                top_state_d = TOP_IDLE;
              end
            endcase
          end

          default: begin
            dma_init_state_d = DMA_INIT_IDLE;
          end
        endcase
      end

      default: begin
        top_state_d = TOP_IDLE;
      end
    endcase
  end

  // Assignments
  assign hw2reg.status.d = (top_state_q == TOP_IDLE); // READY = 1 when TOP FSM is in IDLE state, 0 otherwise
  assign hw2reg.status.de = 1'b1;  // Always update status register
  assign w25q128jw_controller_intr_o = reg2hw.intr_status.q; // ISR Handler lowers interrupt status register (interrupt register is risen in hw2reg by FSM when done)

  // Registers 
  w25q128jw_controller_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) w25q128jw_controller_reg_top_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .reg_req_i,
      .reg_rsp_o,
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );
endmodule


