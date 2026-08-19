/**
 * w25q128jw_controller.sv
 * Hardware controller for W25Q128JW flash memory.
 *
 * Uses DMA and SPI Flash peripherals to perform data transfers without CPU intervention.
 *
 * See "sw/application/example_spi_read/write" and "sw/device/bsp/w25q" for main source of inspiration to this module's design.
 *
 * See "sw/application/example_w25q128jw_read/write" for software usage examples.
 *
 * Author: Thomas Lenges   <thomas.lenges@epfl.ch>
 *                         <thomas.lenges@hotmail.com>
 * Additional authors:  Davide Schiavone <davide.schiavone@epfl.ch>
 *                      Patrick Pataky <patrick.pataky@epfl.ch>
 *                                     <patdb10@gmail.com>
 *                      Alain Girard <alain.girard@epfl.ch>
 *                                   <alaingirardvd@gmail.com>
 */

module w25q128jw_controller
  import dma_reg_pkg::*;
  import power_manager_pkg::*;
  import spi_host_reg_pkg::*;
  import flash_llc_cache_reg_pkg::*;
#(
    // SPI host memory address
    parameter logic [31:0] SPI_FLASH_START_ADDRESS = 'h0,
    parameter logic [31:0] W25Q128JW_CONTROLLER_START_ADDRESS = 'h0,
    // External DMA number of channels
    parameter int unsigned DMA_CH_NUM = 'd1,

    // Cache enable
    parameter bit  CACHE_EN  = 1'b0,
    // Register Interface data types
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    // OBI Interface data types
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // Register interface from system bus
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // Memory mapped SPI
    input  obi_req_t spimemio_req_i,
    output obi_rsp_t spimemio_resp_o,

    // Interrupt signal
    output logic w25q128jw_controller_intr_o,

    // Master ports to the SPI HOST
    output reg_req_t spi_host_reg_req_o,
    input  reg_rsp_t spi_host_reg_rsp_i,

    // DMA HW Controller
    output dma_reg_pkg::dma_hw2reg_t external_dma_hw2reg_o,
    // SPI HW register
    input spi_host_reg_pkg::spi_host_hw2reg_status_reg_t external_spi_host_hw2reg_status_i,

    //LLC cache power
    input  power_manager_out_t llc_cache_pwr_ctrl_i,
    output power_manager_in_t  llc_cache_pwr_ctrl_o,


    // DMA channel redy/done signals (directly from DMA IP)
    input logic [DMA_CH_NUM-1:0] dma_ready_i,
    input logic [DMA_CH_NUM-1:0] dma_done_i
);

  // ============== PACKAGE IMPORTS ==============
  import w25q128jw_controller_reg_pkg::*;
  import w25q128jw_controller_pkg::*;

  // ============== REGISTER SIGNALS ==============
  w25q128jw_controller_reg2hw_t reg2hw;
  w25q128jw_controller_hw2reg_t hw2reg;

  // ============== LOCAL PARAMETERS ==============
  localparam logic [31:0] CACHE_DATA_ADDR = W25Q128JW_CONTROLLER_START_ADDRESS
                            + {{(32-w25q128jw_controller_reg_pkg::BlockAw){1'b0}}, W25Q128JW_CONTROLLER_CACHE_DATA_OFFSET};

  // ============== PACKAGE FUNCTIONS ==============
  function automatic void set_dma_regs(
      input logic [31:0] src_ptr, input logic [31:0] dst_ptr, input logic [31:0] src_ptr_inc,
      input logic [31:0] dst_ptr_inc, input logic [1:0] src_data_type, dst_data_type,
      input logic [31:0] rx_trigger_slot, input logic [31:0] tx_trigger_slot,
      input logic [31:0] slot_wait_counter, input logic [15:0] size_d1);
    // Set DMA source pointer
    external_dma_hw2reg_o.src_ptr.de = 1'b1;
    external_dma_hw2reg_o.src_ptr.d = src_ptr;
    // Set DMA destination pointer
    external_dma_hw2reg_o.dst_ptr.de = 1'b1;
    external_dma_hw2reg_o.dst_ptr.d = dst_ptr;
    // Set source increment
    external_dma_hw2reg_o.src_ptr_inc_d1.de = 1'b1;
    external_dma_hw2reg_o.src_ptr_inc_d1.d = src_ptr_inc;
    // Set destination increment
    external_dma_hw2reg_o.dst_ptr_inc_d1.de = 1'b1;
    external_dma_hw2reg_o.dst_ptr_inc_d1.d = dst_ptr_inc;
    // Set source data type (See hw/vendor/xheep_dma/data/dma.hjson for encoding)
    external_dma_hw2reg_o.src_data_type.de = 1'b1;
    external_dma_hw2reg_o.src_data_type.d = src_data_type;
    // Set destination data type: 1 byte
    external_dma_hw2reg_o.dst_data_type.de = 1'b1;
    external_dma_hw2reg_o.dst_data_type.d = dst_data_type;
    // Set DMA trigger slots (See sw/device/lib/drivers/dma/dma.h for trigger slot mapping)
    external_dma_hw2reg_o.slot.rx_trigger_slot.de = 1'b1;
    external_dma_hw2reg_o.slot.rx_trigger_slot.d = rx_trigger_slot;
    external_dma_hw2reg_o.slot.tx_trigger_slot.de = 1'b1;
    external_dma_hw2reg_o.slot.tx_trigger_slot.d = tx_trigger_slot;
    // Set slot wait counter
    external_dma_hw2reg_o.slot_wait_counter.de = 1'b1;
    external_dma_hw2reg_o.slot_wait_counter.d = slot_wait_counter;

    // Set transfer size and START DMA
    // Writing to SIZE_D1 register triggers DMA transaction (See hw/ip/dma/data/dma.hjson)
    external_dma_hw2reg_o.size_d1.de = 1'b1;
    external_dma_hw2reg_o.size_d1.d = size_d1;
  endfunction

  // ============================================================================
  // W25Q128JW CONTROLLER FSM
  // ============================================================================

  // FSM signals
  top_state_e top_state_q, top_state_d;
  read_state_e read_state_q, read_state_d;
  erase_state_e erase_state_q, erase_state_d;
  fwait_state_e fwait_state_q, fwait_state_d;
  fwait_return_e fwait_return_q, fwait_return_d;
  modify_state_e modify_state_q, modify_state_d;
  write_state_e write_state_q, write_state_d;
  dma_init_state_e dma_init_state_q, dma_init_state_d;
  dma_init_return_e dma_init_return_q, dma_init_return_d;

  // If cache enabled
  check_cache_state_e check_cache_state_q, check_cache_state_d;
  read_cache_state_e read_cache_state_q, read_cache_state_d;

  // Counter and Offset signals
  logic [3:0] page_cnt_q, page_cnt_d;
  logic [11:0] sector_offset_q, sector_offset_d;
  logic [12:0] sector_written_bytes_q, sector_written_bytes_d;
  logic [31:0] sector_iter_offset_d, sector_iter_offset_q;
  logic [11:0] transfer_byte_offset_d, transfer_byte_offset_q;
  logic [31:0] read_remaining_bytes_d, read_remaining_bytes_q;
  logic [31:0] spi_control_q, spi_control_d;

  // If cache enabled, keep in memory the victim's sector to writeback
  logic [11:0] victim_sector_offset_d, victim_sector_offset_q;

  logic [31:0] dma_size_q, dma_size_d;

  logic       [31:0] flash_address;

  // Cache signals
  cache_req_t        cache_ctrl_req;
  cache_res_t        cache_ctrl_resp;
  addr_t             cache_lookup_addr;
  obi_req_t          cache_dma_req;
  obi_rsp_t          cache_dma_resp;
  logic              cache_req;
  data_t             cache_rdata;
  logic              cache_valid;
  logic cache_data_bus_we, cache_data_bus_re;

  // Intermediate signals
  reg_rsp_t reg_rsp_int;

  // memio fast-path
  logic [31:0] memio_addr_q, memio_addr_d;
  logic [31:0] memio_data;
  logic [ 3:0] memio_be;
  logic [31:0] memio_write_offset_q, memio_write_offset_d;
  memio_state_e memio_state_q, memio_state_d;

  /* Register interface signals */
  reg_req_t reg_req_param;
  reg_rsp_t reg_rsp_param;

  // FSM sequential logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // -------- Reset: Initialize all FSMs to IDLE --------
      dma_init_state_q <= DMA_INIT_IDLE;
      dma_init_return_q <= RETURN_READ;
      top_state_q <= TOP_IDLE;
      read_state_q <= READ_IDLE;
      erase_state_q <= ERASE_IDLE;
      fwait_state_q <= FWAIT_IDLE;
      modify_state_q <= MODIFY_IDLE;
      write_state_q <= WRITE_IDLE;

      if (CACHE_EN) begin
        check_cache_state_q <= CHECK_CACHE_IDLE;
        read_cache_state_q  <= READ_CACHE_IDLE;
      end

      // -------- Reset: Clear counters and offsets --------
      fwait_return_q   <= FWAIT_RETURN_IDLE;
      page_cnt_q    <= 4'b0;
      sector_offset_q <= 12'h0;
      sector_written_bytes_q <= 13'h0;
      sector_iter_offset_q <= 32'h0;
      transfer_byte_offset_q <= 12'h0;
      read_remaining_bytes_q <= 32'h0;
      spi_control_q <= 32'h0;
      dma_size_q <= 32'h0;
      memio_addr_q <= 32'h0;
      memio_state_q <= MEMIO_IDLE;
      memio_write_offset_q <= 32'h0;

      if (CACHE_EN) begin
        victim_sector_offset_q <= 12'h0;
      end

    end else begin
      // FSM signals
      dma_init_state_q <= dma_init_state_d;
      dma_init_return_q <= dma_init_return_d;
      top_state_q <= top_state_d;
      read_state_q <= read_state_d;
      erase_state_q <= erase_state_d;
      fwait_state_q <= fwait_state_d;
      modify_state_q <= modify_state_d;
      write_state_q <= write_state_d;

      if (CACHE_EN) begin
        check_cache_state_q <= check_cache_state_d;
        read_cache_state_q  <= read_cache_state_d;
      end

      // Counters and offsets
      fwait_return_q <= fwait_return_d;
      page_cnt_q    <= page_cnt_d;
      sector_offset_q <= sector_offset_d;
      sector_written_bytes_q <= sector_written_bytes_d;
      sector_iter_offset_q <= sector_iter_offset_d;
      transfer_byte_offset_q <= transfer_byte_offset_d;
      read_remaining_bytes_q <= read_remaining_bytes_d;
      spi_control_q <= spi_control_d;
      memio_addr_q <= memio_addr_d;
      memio_state_q <= memio_state_d;
      memio_write_offset_q <= memio_write_offset_d;

      dma_size_q <= dma_size_d;

      if (CACHE_EN) begin
        victim_sector_offset_q <= victim_sector_offset_d;
      end
    end
  end

  logic [spi_host_reg_pkg::BlockAw-1:0] spi_host_reg_req_offset;

  assign spi_host_reg_req_o.addr = SPI_FLASH_START_ADDRESS + {{(32 - spi_host_reg_pkg::BlockAw){1'b0}}, spi_host_reg_req_offset};

  logic quad_select;
  assign quad_select = (reg2hw.control.quad.q && QUAD_AVAILABLE) || (memio_state_q != MEMIO_IDLE && QUAD_AVAILABLE);

  assign hw2reg.status.cache.de = 1'b1;
  assign hw2reg.status.cache.d = CACHE_EN;

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
    fwait_return_d = fwait_return_q;
    page_cnt_d = page_cnt_q;
    sector_offset_d = sector_offset_q;
    sector_written_bytes_d = sector_written_bytes_q;
    sector_iter_offset_d = sector_iter_offset_q;
    transfer_byte_offset_d = transfer_byte_offset_q;
    read_remaining_bytes_d = read_remaining_bytes_q;
    spi_control_d = spi_control_q;
    memio_addr_d = memio_addr_q;
    memio_state_d = memio_state_q;
    memio_write_offset_d = memio_write_offset_q;

    dma_size_d = dma_size_q;

    if (CACHE_EN) begin
      check_cache_state_d = check_cache_state_q;
      read_cache_state_d = read_cache_state_q;

      cache_ctrl_req = '0;
      victim_sector_offset_d = victim_sector_offset_q;
      cache_req = '0;
    end

    hw2reg.control.start.de = 1'b0;
    hw2reg.control.start.d = 1'b0;
    hw2reg.control.rnw.de = 1'b0;
    hw2reg.control.rnw.d = 1'b0;
    hw2reg.length.de = 1'b0;
    hw2reg.length.d = 32'h0;
    hw2reg.intr_status.de   = 1'b0;
    hw2reg.intr_status.d    = 1'b0;

    external_dma_hw2reg_o   = '0;

    flash_address = '0;

    spi_host_reg_req_o.valid = '0;
    spi_host_reg_req_o.wstrb = 4'b1111;
    spi_host_reg_req_o.write = 1'b0;
    spi_host_reg_req_o.wdata = '0;
    spi_host_reg_req_offset  = '0;

    spimemio_resp_o.rvalid = 1'b0;
    spimemio_resp_o.rdata = '0;
    spimemio_resp_o.gnt = 1'b0;

    // ============================================================================
    // TOP FSM
    // ============================================================================
    // Orchestrates all sub-FSMs based on the requested operation:
    //   - Read (rnw=1):  TOP_IDLE -> TOP_READ -> TOP_IDLE
    //   - Write (rnw=0): TOP_IDLE -> TOP_READ -> TOP_FWAIT -> TOP_ERASE -> TOP_FWAIT ->
    //                    TOP_MODIFY -> TOP_WRITE -> TOP_FWAIT -> TOP_IDLE
    //

    case (top_state_q)
      // -------- IDLE STATE --------
      // Wait for SW to set the START bit in CONTROL register
      TOP_IDLE: begin
        if (reg2hw.control.start.q) begin
          read_remaining_bytes_d = reg2hw.length.q;
          transfer_byte_offset_d = 12'h0;
          sector_iter_offset_d = 32'h0;
          sector_offset_d = reg2hw.f_address.q[11:0];
          sector_written_bytes_d = 13'h0;

          if (CACHE_EN) begin
            // If cache enabled, first check if data is already in cache before deciding to read from flash or not
            top_state_d = TOP_CHECK_CACHE;
          end else begin
            // If no cache, always start with READ (for both read and write operations)
            top_state_d = TOP_READ;
          end
        end else if (CACHE_EN && spimemio_req_i.req) begin
          memio_addr_d = spimemio_req_i.addr;
          memio_data = spimemio_req_i.wdata;
          memio_be = spimemio_req_i.be;
          spimemio_resp_o.gnt = 1'b1;

          memio_state_d = spimemio_req_i.we ? MEMIO_WRITE : MEMIO_READ;
          top_state_d = TOP_CHECK_CACHE;

          cache_ctrl_req.req = 1'b1;
          cache_ctrl_req.op = CACHE_CHECK;
          cache_ctrl_req.addr.exposed = {8'h0, memio_addr_d & 32'h00ffffff};

          if (cache_ctrl_resp.hit) begin  //hit
            if (memio_state_d == MEMIO_READ) begin
              top_state_d = TOP_READ_CACHE;
              // Reset offset for first sector
              if (sector_iter_offset_q != 32'h0) begin
                transfer_byte_offset_d = 12'h0;
              end
              cache_ctrl_req.req = 1'b1;
              cache_ctrl_req.op = CACHE_READ;
              cache_ctrl_req.addr.exposed = {memio_addr_d & 32'h00ffffff};

              cache_req = 1'b1;
              read_cache_state_d = READ_CACHE_MEMIO_REQ;

            end else begin
              top_state_d = TOP_MODIFY;
              cache_ctrl_req.req = 1'b1;
              cache_ctrl_req.op = CACHE_WRITE;
              cache_ctrl_req.addr.exposed = {memio_addr_d & 32'h00ffffff};
              cache_ctrl_req.dirty = 1'b1;

              cache_req = 1'b1;
              modify_state_d = MODIFY_MEMIO_REQ;  // MEMIO Write
            end

          end else begin
            if (cache_ctrl_resp.miss_info.dirty) begin  // miss dirty
              // Keep in memory victim to write-back in TOP_ERASE/TOP_WRITE
              victim_sector_offset_d = cache_ctrl_resp.miss_info.victim_sector_address;

              top_state_d = TOP_ERASE;
              check_cache_state_d = CHECK_CACHE_IDLE;
            end else begin  // miss clean
              top_state_d = TOP_READ;
              check_cache_state_d = CHECK_CACHE_IDLE;
            end
          end
        end
      end


      // ============================================================================
      // CHECK_CACHE FSM
      // ============================================================================
      // If cache enabled: Check if the requested data is already in cache (cache hit) or not (cache miss)
      //   if hit:
      //     if read: redirect to TOP_READ_CACHE to read from cache to RAM via DMA
      //     if write: redirect to TOP_MODIFY to write new data from RAM to cache
      //   if miss:
      //     if victim clean: redirect to TOP_READ to read new sector data from flash to cache
      //     if victim dirty: redirect to TOP_ERASE, TOP_WRITE to write the dirty sector back to flash
      // ============================================================================

      TOP_CHECK_CACHE: begin
        case (check_cache_state_q)
          // -------- IDLE: Trigger Cache request --------
          CHECK_CACHE_IDLE: begin
            cache_ctrl_req.req = 1'b1;
            cache_ctrl_req.op  = CACHE_CHECK;

            if (memio_state_q == MEMIO_IDLE) begin
              cache_ctrl_req.addr.exposed = {
                8'h0, (reg2hw.f_address.q + sector_iter_offset_q) & 32'h00ffffff
              };
            end else begin
              cache_ctrl_req.addr.exposed = {8'h0, memio_addr_q & 32'h00ffffff};
            end

            if (cache_ctrl_resp.hit) begin  //hit
              if (reg2hw.control.rnw.q || memio_state_q == MEMIO_READ) begin
                top_state_d = TOP_READ_CACHE;
                // Skip idle, faster
                // Reset offset for first sector
                if (sector_iter_offset_q != 32'h0) begin
                  transfer_byte_offset_d = 12'h0;
                end

                // Next state after returning from DMA reset
                if (memio_state_q == MEMIO_IDLE) begin
                  top_state_d        = TOP_DMA_INIT;
                  dma_init_return_d  = RETURN_READ_CACHE;
                  read_cache_state_d = READ_CACHE_REGS;
                end else begin  // MEMIO_READ
                  cache_ctrl_req.req = 1'b1;
                  cache_ctrl_req.op = CACHE_READ;
                  cache_ctrl_req.addr.exposed = {memio_addr_q & 32'h00ffffff};

                  cache_req = 1'b1;
                  read_cache_state_d = READ_CACHE_MEMIO_REQ;
                end
              end else begin
                top_state_d = TOP_MODIFY;
                cache_ctrl_req.req = 1'b1;
                cache_ctrl_req.op = CACHE_WRITE;
                cache_ctrl_req.addr.exposed = {memio_addr_q & 32'h00ffffff};
                cache_ctrl_req.dirty = 1'b1;

                if (memio_state_q == MEMIO_WRITE) begin
                  cache_req = 1'b1;
                  modify_state_d = MODIFY_MEMIO_REQ;
                end else begin
                  modify_state_d = MODIFY_IDLE;
                end
              end

              check_cache_state_d = CHECK_CACHE_IDLE;
            end else begin
              if (cache_ctrl_resp.miss_info.dirty) begin  // miss dirty
                // Keep in memory victim to write-back in TOP_ERASE/TOP_WRITE
                victim_sector_offset_d = cache_ctrl_resp.miss_info.victim_sector_address;

                top_state_d = TOP_ERASE;
                check_cache_state_d = CHECK_CACHE_IDLE;
              end else begin  // miss clean
                top_state_d = TOP_READ;
                check_cache_state_d = CHECK_CACHE_IDLE;
              end
            end
          end

          default: begin
            check_cache_state_d = CHECK_CACHE_IDLE;
          end
        endcase
      end

      // ============================================================================
      // READ_CACHE FSM
      // ============================================================================
      // If cache enabled and data is in cache (hit), read directly from cache to RAM sector buffer via DMA
      // ============================================================================
      TOP_READ_CACHE: begin
        case (read_cache_state_q)

          // -------- IDLE: Trigger DMA initialization --------
          READ_CACHE_IDLE: begin
            // Reset offset for first sector
            if (sector_iter_offset_q != 32'h0) begin
              transfer_byte_offset_d = 12'h0;
            end

            // Next state after returning from DMA reset
            if (memio_state_q == MEMIO_IDLE) begin
              top_state_d        = TOP_DMA_INIT;
              dma_init_return_d  = RETURN_READ_CACHE;
              read_cache_state_d = READ_CACHE_REGS;
            end else begin  // MEMIO_READ
              cache_ctrl_req.req = 1'b1;
              cache_ctrl_req.op = CACHE_READ;
              cache_ctrl_req.addr.exposed = {memio_addr_q & 32'h00ffffff};

              cache_req = 1'b1;
              read_cache_state_d = READ_CACHE_MEMIO_REQ;
            end
          end

          READ_CACHE_REGS: begin
            // Compute how many words to transfer for this sector
            if (read_remaining_bytes_q < {19'h0, SE_BSIZE} - {20'h0, sector_offset_q}) begin
              // Case 1: All remaining data fits in this sector
              dma_size_d = (read_remaining_bytes_q) >> 2;
            end else begin
              // Case 2: Data spans multiple sectors. Fill remaining sector space
              // Transfer (4KB - offset) bytes
              dma_size_d = (({19'h0, SE_BSIZE} - {20'h0, sector_offset_q}) >> 2);
            end

            if (dma_size_d != 0) begin
              // Cache request
              cache_ctrl_req.req = 1'b1;
              cache_ctrl_req.op = CACHE_READ;
              // Source: read from within the cached sector starting at sector_offset.
              // For the first sector sector_offset = f_address[11:0] (misaligned start),
              // for subsequent sectors sector_offset = 0. The cache uses the address'
              // byte_offset field to pick the starting word within the sector.
              cache_ctrl_req.addr.exposed = {
                8'h0,
                ((reg2hw.f_address.q & 32'h00fff000) + sector_iter_offset_q + {20'h0, sector_offset_q}) & 32'h00ffffff
              };
              cache_ctrl_req.word_count = dma_size_d[15:0];

              // Destination: RAM must stay contiguous. Total bytes already written =
              // sector_iter_offset + sector_offset - initial misalignment (f_address[11:0]),
              // so subtract the first-sector offset to avoid leaving a gap between sectors.
              set_dma_regs(CACHE_DATA_ADDR,
                           reg2hw.s_address.q + sector_iter_offset_q + {20'h0, sector_offset_q} - {20'h0, reg2hw.f_address.q[11:0]},
                           32'h0, 32'h4,  // src_inc=0 (FIFO), dst_inc=4 (word)
                           2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                           'h0, 'h0,
                           reg2hw.dma_slot_wait_counter.q,  // slot_wait_counter to write to DMA
                           dma_size_d[15:0]);  // size (in words)

              read_cache_state_d = READ_CACHE_TRANS;
            end
          end

          READ_CACHE_TRANS: begin
            if (dma_done_i[0]) begin
              transfer_byte_offset_d = transfer_byte_offset_q + (dma_size_q << 2);
              sector_offset_d        = sector_offset_q + (dma_size_q << 2);
              sector_written_bytes_d = sector_written_bytes_q + (dma_size_q << 2);

              if (read_remaining_bytes_q <= {19'h0, sector_written_bytes_d}) begin
                // All remaining data has been transferred at this iteration

                top_state_d = TOP_DONE;
              end else if (read_remaining_bytes_q > {19'h0, sector_written_bytes_d}) begin
                // More data remains in next sector(s): compute remaining length for next sector iteration
                read_remaining_bytes_d = read_remaining_bytes_q - {19'h0, sector_written_bytes_d};

                sector_iter_offset_d   = sector_iter_offset_q + {19'b0, SE_BSIZE};
                sector_offset_d        = 12'h0;
                sector_written_bytes_d = 13'h0;

                top_state_d            = TOP_CHECK_CACHE;
              end
              read_cache_state_d = READ_CACHE_IDLE;
            end
          end

          READ_CACHE_MEMIO_REQ: begin
            if (cache_valid) begin
              spimemio_resp_o.rdata = cache_rdata;
              spimemio_resp_o.rvalid = 1'b1;

              // Clear memio flag and finish transaction
              memio_state_d = MEMIO_IDLE;
              memio_addr_d = 'h0;
              memio_be = 4'h0;
              read_cache_state_d = READ_CACHE_IDLE;
              // Check for memio request (skip idle)
              if (spimemio_req_i.req) begin
                memio_addr_d = spimemio_req_i.addr;
                memio_data = spimemio_req_i.wdata;
                memio_be = spimemio_req_i.be;
                spimemio_resp_o.gnt = 1'b1;

                memio_state_d = spimemio_req_i.we ? MEMIO_WRITE : MEMIO_READ;
                top_state_d = TOP_CHECK_CACHE;

                cache_ctrl_req.req = 1'b1;
                cache_ctrl_req.op = CACHE_CHECK;
                cache_ctrl_req.addr.exposed = {8'h0, memio_addr_d & 32'h00ffffff};

                if (cache_ctrl_resp.hit) begin  //hit
                  if (memio_state_d == MEMIO_READ) begin
                    top_state_d = TOP_READ_CACHE;
                    // Reset offset for first sector
                    if (sector_iter_offset_q != 32'h0) begin
                      transfer_byte_offset_d = 12'h0;
                    end
                    cache_ctrl_req.req = 1'b1;
                    cache_ctrl_req.op = CACHE_READ;
                    cache_ctrl_req.addr.exposed = {memio_addr_d & 32'h00ffffff};

                    cache_req = 1'b1;
                    read_cache_state_d = READ_CACHE_MEMIO_REQ;

                  end else begin
                    top_state_d = TOP_MODIFY;
                    cache_ctrl_req.req = 1'b1;
                    cache_ctrl_req.op = CACHE_WRITE;
                    cache_ctrl_req.addr.exposed = {memio_addr_d & 32'h00ffffff};
                    cache_ctrl_req.dirty = 1'b1;

                    cache_req = 1'b1;
                    modify_state_d = MODIFY_MEMIO_REQ;  // MEMIO Write
                  end

                end else begin
                  if (cache_ctrl_resp.miss_info.dirty) begin  // miss dirty
                    // Keep in memory victim to write-back in TOP_ERASE/TOP_WRITE
                    victim_sector_offset_d = cache_ctrl_resp.miss_info.victim_sector_address;

                    top_state_d = TOP_ERASE;
                    check_cache_state_d = CHECK_CACHE_IDLE;
                  end else begin  // miss clean
                    top_state_d = TOP_READ;
                    check_cache_state_d = CHECK_CACHE_IDLE;
                  end
                end
              end else begin
                top_state_d = TOP_IDLE;  // Skip TOP_DONE
              end
            end
          end

          default: begin
            read_cache_state_d = READ_CACHE_IDLE;
          end
        endcase
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
            if (!CACHE_EN) begin
              // When no cache, every read request is independent, needs to reset offset
              if (reg2hw.control.rnw.q) begin
                transfer_byte_offset_d = 12'h0;
              end
            end

            // Reset offset for first sector of a new write
            if (sector_iter_offset_q == 32'h0) begin
              transfer_byte_offset_d = 12'h0;
            end

            // Next state after returning from DMA reset
            top_state_d       = TOP_DMA_INIT;
            dma_init_return_d = RETURN_READ;
            read_state_d      = READ_SET_DMA;
          end

          // ============== DMA CONFIGURATION ==============
          READ_SET_DMA: begin
            read_state_d = READ_SPI_CHECK_TX_FIFO;

            if (CACHE_EN) begin
              // Always read an entire sector into the cache
              dma_size_d = {19'b0, SE_WSIZE};

              // Set the cache to fill the data
              cache_ctrl_req.req = 1'b1;
              cache_ctrl_req.op = CACHE_WRITE;
              if (memio_state_q == MEMIO_IDLE)
                cache_ctrl_req.addr.exposed = {
                  8'h0, ((reg2hw.f_address.q & 32'h00fff000) + sector_iter_offset_q) & 32'h00ffffff
                };
              else  //MEMIO
                cache_ctrl_req.addr.exposed = {8'h0, (memio_addr_q & 32'h00fff000)};
              cache_ctrl_req.word_count = dma_size_d[15:0];
              cache_ctrl_req.dirty = 1'b0;

              set_dma_regs(SPI_FLASH_START_ADDRESS + {25'b0, SPI_HOST_RXDATA_OFFSET},
                           CACHE_DATA_ADDR, 32'h0, 32'h0,  // src_inc=0 (FIFO), dst_inc=0 (FIFO)
                           2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                           'h4, 'h0,
                           reg2hw.dma_slot_wait_counter.q,  // slot_wait_counter to write to DMA
                           dma_size_d[15:0]);
            end else begin
              // No cache
              if (reg2hw.control.rnw.q) begin
                // READ: Set DMA for flash -> RAM transfer
                dma_size_d = reg2hw.length.q >> 2;

                if (dma_size_d != 0) begin
                  // BODY: word-aligned transfer, 4 bytes at a time
                  set_dma_regs(SPI_FLASH_START_ADDRESS + {25'b0, SPI_HOST_RXDATA_OFFSET},
                               reg2hw.s_address.q, 32'h0,
                               32'h4,  // src_inc=0 (FIFO), dst_inc=4 (word)
                               2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                               'h4, 'h0,
                               reg2hw.dma_slot_wait_counter.q,  // slot_wait_counter to write to DMA
                               dma_size_d[15:0]);
                end
              end else begin
                // WRITE operation: always read one sector (1024 words = 4KB)
                dma_size_d = {19'b0, SE_WSIZE};

                set_dma_regs(
                    SPI_FLASH_START_ADDRESS + {25'b0, SPI_HOST_RXDATA_OFFSET}, reg2hw.s_address.q,
                    32'h0, 32'h4,  // src_inc=0 (FIFO), dst_inc=4 (word)
                    2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                    'h4, 'h0, reg2hw.dma_slot_wait_counter.q,  // slot_wait_counter to write to DMA
                    dma_size_d[15:0]);
              end
            end
          end

          // ============== SPI COMMAND SEQUENCE ==============

          // -------- Check if TX FIFO has space for command --------
          READ_SPI_CHECK_TX_FIFO: begin
            // STATUS[7:0] = TXQD (TX FIFO depth). Proceed if not full.
            // See hw/vendor/xheep/spi/vendor/lowrisc_opentitan_spi_host/data/spi_host.hjson for status register bit mapping
            // See hw/vendor/xheep/spi/vendor/lowrisc_opentitan_spi_host/rtl/spi_host_reg_pkg.sv for TXQD depth definition
            if (external_spi_host_hw2reg_status_i.txqd.d < SPI_FLASH_TX_FIFO_DEPTH[7:0]) begin
              read_state_d = quad_select ? READ_SPI_SEND_CMD_1_QUAD : READ_SPI_FILL_TX_FIFO;
            end
          end

          // -------- Write READ command + address to TX FIFO --------
          // Format: [31:8] = 24-bit flash address byte swapped, [7:0] = FC_RD command (0x03)
          // Inspiration from sw/device/bsp/w25q
          READ_SPI_FILL_TX_FIFO: begin
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;

            if (CACHE_EN && memio_state_q != MEMIO_IDLE) begin
              flash_address = (memio_addr_q & 32'h00fff000);
            end else if (CACHE_EN || !reg2hw.control.rnw.q) begin
              // WRITE or cache enable: whole sector
              flash_address = (reg2hw.f_address.q & 32'h00fff000) + (sector_iter_offset_q);
            end else begin
              // READ without cache
              flash_address = reg2hw.f_address.q & 32'h00ffffff;
            end

            spi_host_reg_req_o.wdata = (((bitfield_byteswap32(flash_address)) >> 8) << 8) |
                {19'h0, FC_RD};

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
          //   Direction TX only
          //   Speed standard
          //   CSAAT 1
          //   Length-1 (3 = 4 bytes: 1 command + 3 address)
          READ_SPI_SEND_CMD_1: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_STD, 1'b1, 24'h3);
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
          //   Direction RX only,
          //   Speed standard,
          //   CSAAT 0,
          //   Length-1
          READ_SPI_SEND_CMD_2: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;

            if (CACHE_EN) begin
              // If cache enabled, always read a full sector (4096 bytes)
              spi_host_reg_req_o.wdata =
                  spi_cmd_pack(SPI_DIR_RX, SPI_SPEED_STD, 1'b0, {11'b0, SE_BSIZE - 1'h1});
            end else if (reg2hw.control.rnw.q) begin
              // If no cache, either READ: read bytes or WRITE: read a full sector
              if (dma_size_q != 0) begin
                // If we have a body (word-aligned transfer)
                spi_host_reg_req_o.wdata = spi_cmd_pack(
                  SPI_DIR_RX,
                  SPI_SPEED_STD,
                  0,  // No new command
                  ((dma_size_q << 2) - 1'h1)
                );
              end
            end else begin
              // WRITE: read full sector (4096 bytes)
              spi_host_reg_req_o.wdata =
                  spi_cmd_pack(SPI_DIR_RX, SPI_SPEED_STD, 1'b0, {11'b0, SE_BSIZE - 1'h1});
            end

            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_TRANS;
            end
          end

          READ_SPI_SEND_CMD_1_QUAD: begin
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {19'h0, FC_RDQIO};
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_QUAD_WAIT_READY_1;
            end
          end

          READ_SPI_QUAD_WAIT_READY_1: begin
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_2_QUAD;
            end
          end

          READ_SPI_SEND_CMD_2_QUAD: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_STD, 1'b1, 24'h0);
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_QUAD_WAIT_READY_2;
            end
          end

          READ_SPI_QUAD_WAIT_READY_2: begin
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_3_QUAD;
            end
          end

          READ_SPI_SEND_CMD_3_QUAD: begin
            // For quad read, we need to send the command in a different format to specify quad mode and length for the second command
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;

            if (CACHE_EN && memio_state_q != MEMIO_IDLE) begin
              flash_address = (memio_addr_q & 32'h00fff000);
            end else if (CACHE_EN || !reg2hw.control.rnw.q) begin
              // Cache enabled or WRITE: use sector-aligned address + current sector iteration offset
              flash_address = (reg2hw.f_address.q & 32'h00fff000) + (sector_iter_offset_q);
            end else begin
              // READ without cache: use exact flash address from F_ADDRESS register
              flash_address = reg2hw.f_address.q & 32'h00ffffff;
            end

            spi_host_reg_req_o.wdata = (bitfield_byteswap32(flash_address) >> 8) |
                32'hff000000;  // Address with all 4 bytes to be sent (quad mode)
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_QUAD_WAIT_READY_3;
            end
          end

          READ_SPI_QUAD_WAIT_READY_3: begin
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_4_QUAD;
            end
          end

          READ_SPI_SEND_CMD_4_QUAD: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_QUAD, 1'b1, 24'h3);
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_QUAD_WAIT_READY_4;
            end
          end

          READ_SPI_QUAD_WAIT_READY_4: begin
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_DUMMY_QUAD;
            end
          end

          READ_SPI_SEND_CMD_DUMMY_QUAD: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata =
                spi_cmd_pack(SPI_DIR_DUMMY, SPI_SPEED_QUAD, 1'b1, SPI_DUMMY_CYCLES_WAIT);
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_SPI_QUAD_WAIT_READY_DUMMY;
            end
          end

          READ_SPI_QUAD_WAIT_READY_DUMMY: begin
            if (external_spi_host_hw2reg_status_i.ready.d) begin
              read_state_d = READ_SPI_SEND_CMD_5_QUAD;
            end
          end

          READ_SPI_SEND_CMD_5_QUAD: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;

            if (reg2hw.control.rnw.q) begin
              // READ
              if (dma_size_q != 0) begin
                // If we have a body (word-aligned transfer)
                spi_host_reg_req_o.wdata = spi_cmd_pack(
                  SPI_DIR_RX,
                  SPI_SPEED_QUAD,
                  0,  // No new command
                  ((dma_size_q << 2) - 1'h1)
                );
              end
            end else begin
              // WRITE: read full sector (4096 bytes)
              spi_host_reg_req_o.wdata =
                  spi_cmd_pack(SPI_DIR_RX, SPI_SPEED_QUAD, 1'b0, {11'b0, SE_BSIZE - 1'h1});
            end

            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              read_state_d = READ_TRANS;
            end
          end

          // ============== WAIT FOR DMA COMPLETION ==============
          READ_TRANS: begin
            if (dma_done_i[0]) begin  // DMA channel 0 done signal
              read_state_d = READ_IDLE;
              if (reg2hw.control.rnw.q) begin
                transfer_byte_offset_d = transfer_byte_offset_q + (dma_size_q << 2);
              end

              if (CACHE_EN) begin
                // ===== CACHE FILLED, proceed to CHECK_CACHE (hit) =====
                if (reg2hw.control.rnw.q || memio_state_q == MEMIO_READ) begin
                  top_state_d = TOP_READ_CACHE;
                end else begin
                  top_state_d = TOP_MODIFY;
                end
              end else if (reg2hw.control.rnw.q) begin
                top_state_d       = TOP_DONE;
                dma_init_return_d = RETURN_READ;
              end else begin
                // ===== WRITE OPERATION: Proceed to FWAIT =====
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
      // Note: fwait_return is reset to IDLE if total length has not been written yet and more sectors need to be processed
      // Hence the operation only finishes when all the data has been written back into flash
      // ============================================================================

      TOP_FWAIT: begin
        case (fwait_state_q)

          // -------- Start polling flash Status Register 1 --------
          FWAIT_IDLE: begin
            fwait_state_d = FWAIT_SET_RXWM_R;
          end

          // ============== CONFIGURE RX WATERMARK ==============
          // Set RX watermark to 1 word so we get notified when status byte arrives
          // See hw/vendor/lowrisc_opentitan_spi_host/data/spi_host.hjson for CONTROL register bit mapping
          // See sw/device/bsp/w25q/w25q.c for function flash_wait
          // See sw/device/lib/drivers/spi_host/spi_host.c for function spi_set_rx_watermark

          // -------- Read current CONTROL register value --------
          // We need to preserve other bits when modifying RXWM (preserved in read_value from OBI FSM)
          FWAIT_SET_RXWM_R: begin
            spi_host_reg_req_offset  = SPI_HOST_CONTROL_OFFSET;
            spi_host_reg_req_o.write = 1'b0;
            spi_host_reg_req_o.valid = 1'b1;
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              spi_control_d = spi_host_reg_rsp_i.rdata;
              fwait_state_d = FWAIT_SET_RXWM_W;
            end
          end

          // -------- Write back with RX watermark = 1 --------
          FWAIT_SET_RXWM_W: begin
            spi_host_reg_req_offset = SPI_HOST_CONTROL_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = {
              spi_control_q[31:8], 8'h01
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
          //   Direction TX only
          //   CSAAT 1
          //   Length-1 (0 = 1 byte) (FC_RSR1 is 1 byte command)
          FWAIT_SPI_SEND_CMD_1: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_STD, 1'b1, 24'h0);
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
          //   Direction RX only
          //   Speed standard
          //   CSAAT 0
          //   Length-1 (0 = 1 byte)
          FWAIT_SPI_SEND_CMD_2: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_RX, SPI_SPEED_STD, 1'b0, 24'h0);
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
                fwait_state_d = FWAIT_IDLE;
                case (fwait_return_q)

                  FWAIT_RETURN_IDLE: begin
                    if (CACHE_EN) begin
                      // If cache enabled, after READ: Flash ready -> go to CHECK CACHE (is a hit)
                      if (reg2hw.control.rnw.q || memio_state_q == MEMIO_READ) begin
                        top_state_d = TOP_READ_CACHE;
                      end else begin
                        top_state_d = TOP_MODIFY;
                      end
                    end else begin
                      // Otherwise: Flash ready -> go to ERASE (if write operation)
                      fwait_return_d = FWAIT_RETURN_ERASE;
                      top_state_d = TOP_ERASE;
                    end
                  end

                  FWAIT_RETURN_ERASE: begin
                    if (CACHE_EN) begin
                      // After ERASE: Flash ready -> go to WRITE (writeback modified sector from cache to flash)
                      fwait_return_d = FWAIT_RETURN_WRITE;
                      top_state_d = TOP_WRITE;
                    end else begin
                      // After ERASE: Flash ready -> go to MODIFY
                      fwait_return_d = FWAIT_RETURN_MODIFY;
                      top_state_d = TOP_MODIFY;
                    end
                  end

                  // If WRITE has multiple pages to modify, continue with next page
                  FWAIT_RETURN_WRITE: begin
                    top_state_d = TOP_WRITE;
                  end
                  // If WRITE completed all pages: either complete or continue with next sector
                  FWAIT_RETURN_SECTOR_DONE: begin
                    fwait_return_d = FWAIT_RETURN_IDLE;
                    if (reg2hw.length.q == 0) begin
                      // All sectors done
                      if (memio_state_q != MEMIO_IDLE) begin  //Cache enable
                        top_state_d = TOP_READ;
                      end else begin
                        top_state_d = TOP_DONE;
                      end
                    end else begin
                      if (CACHE_EN) begin
                        // Victim cache line is now clean, can now load requested cache line
                        top_state_d = TOP_READ;
                      end else begin
                        // More sectors to write
                        top_state_d = TOP_READ;
                      end
                    end
                  end

                  default: begin
                    fwait_return_d = FWAIT_RETURN_IDLE;
                    top_state_d    = TOP_DONE;
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
          //   Direction TX only
          //   Speed standard
          //   CSAAT 0
          //   Length-1 (0 = 1 byte)
          ERASE_WE_SEND_CMD: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_STD, 1'b0, 24'h0);
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
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            // Use sector-aligned address + current sector iteration offset + SECTOR ERASE command
            // Inspiration from sw/device/bsp/w25q

            if (CACHE_EN) begin
              // If cache enabled, erase victim sector
              flash_address = {8'h0, victim_sector_offset_q, 12'h0};
            end else begin
              // If no cache, write-back directly the result at the correct address
              flash_address = (reg2hw.f_address.q & 32'h00fff000) + (sector_iter_offset_q);
            end

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
          //   Direction TX only
          //   Speed standard
          //   CSAAT 0
          //   Length-1 (3 = 4 bytes: 1 cmd + 3 addr bytes)
          ERASE_SE_SEND_CMD: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_STD, 1'b0, 24'h3);
            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // Go to FWAIT FSM to poll status register until erase completes
              erase_state_d = ERASE_IDLE;
              top_state_d = TOP_FWAIT;
              fwait_state_d = FWAIT_SET_RXWM_R;  // Start polling (skip FWAIT_IDLE)
              fwait_return_d = FWAIT_RETURN_ERASE;
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
      // If cache enabled:
      //   At this point, the data is in the cache. We need to set a new cache request,
      //   which will set the cache line as dirty, and set a DMA transaction to copy
      //   the modified sector from cache to flash.
      // Otherwise:
      //   At this point, the sector buffer (at S_ADDRESS) already contains the original sector data
      //   from flash (loaded by READ FSM). This FSM overlays the new data (at MD_ADDRESS) at the
      //   correct position within the sector.
      //
      //   For multi-sector write operations:
      //     - First sector: Data is placed at sector_offset (f_address & 0xFFF)
      //     - Subsequent sectors: Data starts at offset 0
      //
      //   After MODIFY completes, the LENGTH register is updated and a new iteration will take place after the WRITE FSM
      //   with the remaining bytes (if any).
      // ============================================================================
      TOP_MODIFY: begin
        case (modify_state_q)
          // -------- IDLE: Trigger DMA initialization --------
          MODIFY_IDLE: begin
            if (memio_state_q == MEMIO_IDLE) begin
              // Compute sector offset
              if (sector_iter_offset_q == 0) begin
                sector_offset_d = reg2hw.f_address.q[11:0]; // Offset within sector for first iteration
              end else begin
                sector_offset_d = 12'h0;  // Begin from start of sector for next iterations
              end

              // Count number of bytes already written in this sector
              sector_written_bytes_d = 13'h0;

              top_state_d            = TOP_DMA_INIT;
              dma_init_return_d      = RETURN_MODIFY;

              modify_state_d         = MODIFY_REGS;
            end else if (CACHE_EN) begin  //MEMIO
              cache_ctrl_req.req = 1'b1;
              cache_ctrl_req.op = CACHE_WRITE;
              cache_ctrl_req.addr.exposed = {memio_addr_q & 32'h00ffffff};
              cache_ctrl_req.dirty = 1'b1;

              cache_req = 1'b1;
              modify_state_d = MODIFY_MEMIO_REQ;
            end
          end

          // ============== DMA CONFIGURATION ==============
          MODIFY_REGS: begin
            // Compute how many words to transfer for this sector
            if (reg2hw.length.q - {19'h0, sector_written_bytes_q} < {19'h0, SE_BSIZE} - {20'h0, sector_offset_q}) begin
              // Case 1: All remaining data fits in this sector
              dma_size_d = (reg2hw.length.q - {19'h0, sector_written_bytes_q}) >> 2;
            end else begin
              // Case 2: Data spans multiple sectors. Fill remaining sector space
              // Transfer (4KB - offset) bytes
              dma_size_d = (({19'h0, SE_BSIZE} - {20'h0, sector_offset_q}) >> 2);
            end

            if (dma_size_d != 0) begin
              if (CACHE_EN) begin
                // Cache request: modify line from SRAM to cache (will set line as dirty)
                cache_ctrl_req.req = 1'b1;
                cache_ctrl_req.op = CACHE_WRITE;
                cache_ctrl_req.addr.exposed = {
                  8'h0,
                  ((reg2hw.f_address.q & 32'h00fff000)
                    + sector_iter_offset_q
                    + {20'h0, sector_offset_q}) & 32'h00ffffff
                };
                cache_ctrl_req.word_count = dma_size_d[15:0];
                cache_ctrl_req.dirty = 1'b1;  // Mark line as dirty since we're modifying it

                set_dma_regs(reg2hw.md_address.q + transfer_byte_offset_q, CACHE_DATA_ADDR, 32'h4,
                             32'h0,  // src_inc=4 (word), dst_inc=0 (FIFO)
                             2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                             'h0, 'h0, 'h0, dma_size_d[15:0]);
              end else begin
                set_dma_regs(reg2hw.md_address.q + transfer_byte_offset_q,
                             reg2hw.s_address.q + {20'h0, sector_offset_q}, 32'h4,
                             32'h4,  // 4-byte increment for word transfers
                             2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                             'h0, 'h0, 'h0, dma_size_d[15:0]);
              end

              modify_state_d = MODIFY_TRANS;
            end
          end

          // ============== WAIT FOR DMA COMPLETION ==============
          MODIFY_TRANS: begin
            if (dma_done_i[0]) begin  // DMA channel 0 done signal
              transfer_byte_offset_d = transfer_byte_offset_q + (dma_size_q << 2);
              sector_offset_d = sector_offset_q + (dma_size_q << 2);
              sector_written_bytes_d = sector_written_bytes_q + (dma_size_q << 2);

              // Update LENGTH register for next iteration (if any)
              hw2reg.length.de = 1'b1;

              if (reg2hw.length.q <= {19'h0, sector_written_bytes_d}) begin
                // All remaining data has been transferred at this iteration: set length to 0 and reset md_offset
                hw2reg.length.d = 32'h0;
                transfer_byte_offset_d = 12'h0;

                if (CACHE_EN) begin
                  // Finish if cache enabled
                  top_state_d = TOP_DONE;
                end
              end else begin
                // More data remains: compute remaining length for next sector iteration
                hw2reg.length.d = reg2hw.length.q - {19'h0, sector_written_bytes_d};

                if (CACHE_EN) begin
                  // Start again with next sector if cache enabled
                  sector_iter_offset_d = sector_iter_offset_q + {19'h0, SE_BSIZE};

                  top_state_d = TOP_CHECK_CACHE;
                  check_cache_state_d = CHECK_CACHE_IDLE;
                end
              end

              if (!CACHE_EN) begin
                // Proceed with WRITE FSM to program modified sector (page by page (page: 256 bytes)) back to flash
                top_state_d   = TOP_WRITE;
                write_state_d = WRITE_IDLE;
              end

              modify_state_d = MODIFY_IDLE;
            end
          end

          MODIFY_MEMIO_REQ: begin
            if (cache_valid) begin
              spimemio_resp_o.rdata = memio_data;
              spimemio_resp_o.rvalid = 1'b1;

              // Clear memio flag and finish transaction
              memio_state_d = MEMIO_IDLE;
              memio_be = 4'h0;
              modify_state_d = MODIFY_IDLE;

              // Check for memio request (skip idle)
              if (spimemio_req_i.req) begin
                memio_addr_d = spimemio_req_i.addr;
                memio_data = spimemio_req_i.wdata;
                memio_be = spimemio_req_i.be;
                spimemio_resp_o.gnt = 1'b1;

                memio_state_d = spimemio_req_i.we ? MEMIO_WRITE : MEMIO_READ;
                top_state_d = TOP_CHECK_CACHE;

                cache_ctrl_req.req = 1'b1;
                cache_ctrl_req.op = CACHE_CHECK;
                cache_ctrl_req.addr.exposed = {8'h0, memio_addr_d & 32'h00ffffff};

                if (cache_ctrl_resp.hit) begin  //hit
                  if (memio_state_d == MEMIO_READ) begin
                    top_state_d = TOP_READ_CACHE;
                    // Reset offset for first sector
                    if (sector_iter_offset_q != 32'h0) begin
                      transfer_byte_offset_d = 12'h0;
                    end
                    cache_ctrl_req.req = 1'b1;
                    cache_ctrl_req.op = CACHE_READ;
                    cache_ctrl_req.addr.exposed = {memio_addr_d & 32'h00ffffff};

                    cache_req = 1'b1;
                    read_cache_state_d = READ_CACHE_MEMIO_REQ;

                  end else begin
                    top_state_d = TOP_MODIFY;
                    cache_ctrl_req.req = 1'b1;
                    cache_ctrl_req.op = CACHE_WRITE;
                    cache_ctrl_req.addr.exposed = {memio_addr_d & 32'h00ffffff};
                    cache_ctrl_req.dirty = 1'b1;

                    cache_req = 1'b1;
                    modify_state_d = MODIFY_MEMIO_REQ;  // MEMIO Write
                  end

                end else begin
                  if (cache_ctrl_resp.miss_info.dirty) begin  // miss dirty
                    // Keep in memory victim to write-back in TOP_ERASE/TOP_WRITE
                    victim_sector_offset_d = cache_ctrl_resp.miss_info.victim_sector_address;

                    top_state_d = TOP_ERASE;
                    check_cache_state_d = CHECK_CACHE_IDLE;
                  end else begin  // miss clean
                    top_state_d = TOP_READ;
                    check_cache_state_d = CHECK_CACHE_IDLE;
                  end
                end
              end else begin
                top_state_d = TOP_IDLE;
              end
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
          //   Direction TX only
          //   Speed standard
          //   CSAAT 0
          //   Length-1 (0 = 1 byte)
          WRITE_WE_SEND_CMD: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_STD, 1'b0, 24'h0);
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
            spi_host_reg_req_offset  = SPI_HOST_TXDATA_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;

            if (CACHE_EN) begin
              // If cache enabled, write-back the victim sector + page offset
              flash_address = {8'h0, victim_sector_offset_q, page_cnt_q, 8'h0};
            end else begin
              // Compute page address: sector base + sector offset + page offset
              flash_address = ((reg2hw.f_address.q & 32'h00fff000) + sector_iter_offset_q) |
                    ({28'h0, page_cnt_q} << 8);
            end

            if (quad_select) begin
              spi_host_reg_req_o.wdata = (bitfield_byteswap32(flash_address) & 32'hffffff00) |
                  {19'h0, FC_PPQ};
            end else begin
              spi_host_reg_req_o.wdata = (bitfield_byteswap32(flash_address) & 32'hffffff00) |
                  {19'h0, FC_PP};
            end
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
          //   Direction TX only
          //   Speed standard
          //   CSAAT 1
          //   Length-1 (3 = 4 bytes: 1 cmd + 3 addr)
          WRITE_PP_SEND_CMD: begin
            spi_host_reg_req_offset  = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(SPI_DIR_TX, SPI_SPEED_STD, 1'b1, 24'h3);
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

            if (CACHE_EN) begin
              // Cache request: send line from cache to FLASH (writeback)
              if (page_cnt_q == 4'h0) begin
                // Make cache request for whole sector in the first page
                cache_ctrl_req.req = 1'b1;
                cache_ctrl_req.op = CACHE_READ;
                cache_ctrl_req.addr.exposed = {8'h0, victim_sector_offset_q, 12'h0};
                cache_ctrl_req.word_count = SE_WSIZE;
              end

              set_dma_regs(CACHE_DATA_ADDR,
                           SPI_FLASH_START_ADDRESS + {25'b0, SPI_HOST_TXDATA_OFFSET}, 32'h0,
                           32'h0,  // src_inc=0 (FIFO), dst_inc=0 (FIFO)
                           2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                           'h0, 'h8, reg2hw.dma_slot_wait_counter.q,  // slot_wait_counter
                           {3'h0, PAGE_WSIZE});
            end else begin
              set_dma_regs(reg2hw.s_address.q + ({28'h0, page_cnt_q} << 8),
                           SPI_FLASH_START_ADDRESS + {25'b0, SPI_HOST_TXDATA_OFFSET}, 32'h4,
                           32'h0,  // src_inc=4 (word), dst_inc=0 (FIFO)
                           2'h0, 2'h0,  // src_data_type=32-bit, dst_data_type=32-bit
                           'h0, 'h8, reg2hw.dma_slot_wait_counter.q,  // slot_wait_counter
                           {3'h0, PAGE_WSIZE});
            end
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
          //   Direction TX only
          //   Speed standard
          //   CSAAT 0
          //   Length-1 (255 = 256 bytes = 1 page)
          WRITE_PP_SEND_CMD_2: begin
            spi_host_reg_req_offset = SPI_HOST_COMMAND_OFFSET;
            spi_host_reg_req_o.write = 1'b1;
            spi_host_reg_req_o.valid = 1'b1;
            spi_host_reg_req_o.wdata = spi_cmd_pack(
              SPI_DIR_TX,
              quad_select ? SPI_SPEED_QUAD : SPI_SPEED_STD,
              1'b0,
              {
                11'b0, PAGE_BSIZE - 1'h1
              }
            );

            if (spi_host_reg_rsp_i.ready && ~spi_host_reg_rsp_i.error) begin
              // ===== CHECK IF MORE PAGES/SECTORS TO PROCESS =====
              top_state_d   = TOP_FWAIT;
              write_state_d = WRITE_IDLE;
              if (page_cnt_q == 4'hf) begin
                // All 16 pages in current sector programmed
                // Always wait until flash is not busy before finalizing or moving to next sector.
                fwait_return_d = FWAIT_RETURN_SECTOR_DONE;
                page_cnt_d = 4'b0;  // Reset page counter for next sector / next operation

                if (CACHE_EN) begin
                  // If cache enabled, we are evicting the sector from cache
                  cache_ctrl_req.req = 1'b1;
                  cache_ctrl_req.op = CACHE_EVICT;
                  cache_ctrl_req.addr.exposed = {8'h0, victim_sector_offset_q, 12'h0};
                end else if (reg2hw.length.q != 0) begin
                  // If no cache and more sectors to process, move to next sector
                  sector_iter_offset_d = sector_iter_offset_q + {19'b0, SE_BSIZE}; // Next sector (+4KB)
                end

              end else begin
                // ===== MORE PAGES IN CURRENT SECTOR: Program next page =====
                // Restart WE + PP sequence after waiting for BUSY bit
                page_cnt_d = page_cnt_q + 1'h1;
                fwait_return_d = FWAIT_RETURN_WRITE;
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

              // Only reachable if cache enabled
              RETURN_READ_CACHE: begin
                top_state_d = TOP_READ_CACHE;  // Continue with flash read operation with cache
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

      TOP_DONE: begin
        transfer_byte_offset_d = 32'h0;
        read_remaining_bytes_d = 32'h0;
        sector_iter_offset_d = 32'h0;
        sector_offset_d = 12'h0;
        sector_written_bytes_d = 13'h0;

        hw2reg.control.start.de = 1'b1;
        hw2reg.control.start.d  = 1'b0;
        hw2reg.intr_status.de   = 1'b1;
        hw2reg.intr_status.d    = reg2hw.intr_enable.q;
        hw2reg.length.de = 1'b1;
        hw2reg.length.de = '0;

        top_state_d = TOP_IDLE;
      end

      default: begin
        top_state_d = TOP_IDLE;
      end
    endcase
  end

  // Assignments
  assign hw2reg.status.ready.d = (top_state_q == TOP_IDLE); // READY = 1 when TOP FSM is in IDLE state, 0 otherwise
  assign hw2reg.status.ready.de = 1'b1;  // Always update status register
  assign w25q128jw_controller_intr_o = reg2hw.intr_status.q; // ISR Handler lowers interrupt status register (interrupt register is risen in hw2reg by FSM when done)


  generate
    if (CACHE_EN) begin : gen_cache_reg
      assign hw2reg.cache_data.de = cache_dma_resp.rvalid;
      assign hw2reg.cache_data.d  = cache_dma_resp.rdata;
    end
  endgenerate

  always_comb begin
    if (!reg2hw.control.start.q && spimemio_req_i.req) begin
      // memio fast path: request being granted in TOP_IDLE this cycle
      cache_lookup_addr.exposed = spimemio_req_i.addr & 32'h00ffffff;
    end else if (memio_state_q == MEMIO_IDLE) begin
      // register-driven (DMA) transfer: current sector iteration
      cache_lookup_addr.exposed = (reg2hw.f_address.q + sector_iter_offset_q) & 32'h00ffffff;
    end else begin
      // memio transaction in flight: re-check the latched memio address
      cache_lookup_addr.exposed = memio_addr_q & 32'h00ffffff;
    end
  end

  // ============== CACHE INSTANTIATION ==============
  always_comb begin
    if (CACHE_EN) begin
      cache_data_bus_we = reg_req_i.valid
                              & reg_req_i.write
                              & (reg_req_i.addr[w25q128jw_controller_reg_pkg::BlockAw-1:0] == W25Q128JW_CONTROLLER_CACHE_DATA_OFFSET);
      cache_data_bus_re = reg_req_i.valid
                              & ~reg_req_i.write
                              & (reg_req_i.addr[w25q128jw_controller_reg_pkg::BlockAw-1:0] == W25Q128JW_CONTROLLER_CACHE_DATA_OFFSET);

      cache_dma_req = '0;

      if (cache_data_bus_we) begin
        cache_dma_req.req   = 1'b1;
        cache_dma_req.we    = 1'b1;
        cache_dma_req.wdata = reg_req_i.wdata;
        cache_dma_req.be    = reg_req_i.wstrb;
      end else if (cache_data_bus_re && !cache_dma_resp.rvalid) begin
        cache_dma_req.req = 1'b1;
        cache_dma_req.we  = 1'b0;
      end
    end else begin
      cache_data_bus_we = 1'b0;
      cache_data_bus_re = 1'b0;
      cache_dma_req = '0;
    end
  end

  generate
    if (CACHE_EN) begin : gen_cache
      flash_llc_cache #(
          .obi_req_t(obi_req_t),
          .obi_rsp_t(obi_rsp_t)
      ) flash_llc_cache_i (
          .clk_i            (clk_i),
          .rst_ni           (rst_ni),
          .pwr_ctrl_i       (llc_cache_pwr_ctrl_i),
          .pwr_ctrl_o       (llc_cache_pwr_ctrl_o),
          .dma_req_i        (cache_dma_req),
          .dma_resp_o       (cache_dma_resp),
          .controller_req_i (cache_ctrl_req),
          .controller_resp_o(cache_ctrl_resp),
          .lookup_addr_i    (cache_lookup_addr),
          .mem_man_req_i    (cache_req),
          .memio_wdata_i    (memio_data),
          .memio_be_i       (memio_be),
          .valid_bridge_o   (cache_valid),
          .mem_rdata_o      (cache_rdata)
      );
    end else begin : gen_no_cache
      assign cache_dma_resp = '0;
      assign cache_ctrl_resp = '0;
      assign cache_rdata = '0;
      assign cache_valid = '0;
      assign llc_cache_pwr_ctrl_o = '0;
    end
  endgenerate

  // Registers
  w25q128jw_controller_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) w25q128jw_controller_reg_top_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .reg_req_i(reg_req_param),
      .reg_rsp_o(reg_rsp_int),
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );



  // If cache read requested, delay ready until cache response is valid
  assign reg_rsp_param.ready = reg_rsp_int.ready
                            & ~(CACHE_EN & cache_data_bus_re & ~cache_dma_resp.rvalid);
  assign reg_rsp_param.rdata = (CACHE_EN & cache_dma_resp.rvalid & cache_data_bus_re)
                            ? cache_dma_resp.rdata : reg_rsp_int.rdata;
  assign reg_rsp_param.error = reg_rsp_int.error;

  always_comb begin
    reg_req_param = reg_req_i;
    reg_rsp_o     = reg_rsp_param;
    if (reg_req_i.valid) begin
      case (reg_req_i.addr[w25q128jw_controller_reg_pkg::BlockAw-1:0])
        W25Q128JW_CONTROLLER_CACHE_DATA_OFFSET: begin
          if (CACHE_EN == 1'b0) begin
            reg_req_param   = 'b0;
            reg_rsp_o.error = 1'b1;
            reg_rsp_o.ready = 1'b1;
            reg_rsp_o.rdata = 'b0;
          end
        end
        default: ;
      endcase
    end
  end

endmodule
