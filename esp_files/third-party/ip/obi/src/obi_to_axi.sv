// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

// customized for integrating X-Heep by EPFL into the Embedded Scalable Platform (ESP) by Columbia University
// Adaptations: Francesco Poluzzi (francesco.poluzzi@epfl.ch)

`include "common_cells/registers.svh"

// OBI to AXI bridge used for connecting X-Heep's OBI master port
// to the AXI bus in the ESP SoC.
module obi_to_axi #(
  /// The configuration of the OBI port (input port).
  parameter obi_pkg::obi_cfg_t ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct of the OBI port
  parameter type               obi_req_t = logic,
  /// The response struct of the OBI port
  parameter type               obi_rsp_t = logic,
  /// Output is AXI lite when set to 1'b1
  parameter bit                AxiLite      = 1'b0,
  /// AXI Address Width
  parameter int unsigned       AxiAddrWidth = 32,
  /// AXI Data Width
  parameter int unsigned       AxiDataWidth = 32,
  /// AXI Burst Type (burst unused but may be required for IP compatibility)
  parameter int unsigned       AxiBurstType = axi_pkg::BURST_INCR,
  /// The request struct of the AXI port
  parameter type               axi_req_t = logic,
  /// The response struct of the AXI port
  parameter type               axi_rsp_t = logic,
  parameter int unsigned       MaxRequests = 0
) (
  input  logic     clk_i,
  input  logic     rst_ni,

  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  output axi_req_t axi_req_o,
  input  axi_rsp_t axi_rsp_i,

  // Signals for manual user reassignment of response
  output logic [1:0]              axi_rsp_channel_sel // [ATOP , WE]
);

  localparam int unsigned AxiSize = axi_pkg::size_t'($unsigned($clog2(ObiCfg.DataWidth/8)));
  localparam bit [2:0] DefaultProt = 3'b100; // OBI default is 3'b111

  typedef logic [AxiAddrWidth-1:0] axi_addr_t;

  logic [$clog2(AxiDataWidth/ObiCfg.DataWidth)-1:0] data_offset, rdata_offset;

  // Response FIFO control signals.
  logic fifo_full, fifo_empty;
  // Bookkeeping for sent write beats.
  logic aw_sent_q, aw_sent_d;
  logic w_sent_q,  w_sent_d;

  // Address correction based on byte enables
  logic [1:0] addr_correction;

  logic [2:0] axi_obi_prot;
  logic       axi_obi_lock;
  logic [5:0] axi_obi_atop;
  logic [ObiCfg.DataWidth-1:0] axi_obi_wdata;
  logic [3:0] axi_obi_cache;

  if (ObiCfg.OptionalCfg.UseProt) begin : gen_prot
    // User mode is unpriviledged
    assign axi_obi_prot[0]  = DefaultProt[0];
    // Always secure?
    assign axi_obi_prot[1]  = 1'b0;
    // Instr / Data access
    assign axi_obi_prot[2]  = DefaultProt[2];
  end else begin : gen_default_prot
    assign axi_obi_prot = DefaultProt;
  end

  if (ObiCfg.OptionalCfg.UseAtop) begin : gen_atop
    always_comb begin : proc_atop_translate
      axi_obi_lock = 1'b0;
      axi_obi_atop = '0;
      axi_obi_wdata = obi_req_i.wdata;
      case (6'b000000)
        obi_pkg::ATOPLR:  axi_obi_lock = 1'b1;
        obi_pkg::ATOPSC:  axi_obi_lock = 1'b1;
        obi_pkg::AMOSWAP: axi_obi_atop = {axi_pkg::ATOP_ATOMICSWAP};
        obi_pkg::AMOADD:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_ADD};
        obi_pkg::AMOXOR:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_EOR};
        obi_pkg::AMOAND: begin
          axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                          axi_pkg::ATOP_LITTLE_END,
                          axi_pkg::ATOP_CLR};
          axi_obi_wdata = ~obi_req_i.wdata;
        end
        obi_pkg::AMOOR:   axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_SET};
        obi_pkg::AMOMIN:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_SMIN};
        obi_pkg::AMOMAX:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_SMAX};
        obi_pkg::AMOMINU: axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_UMIN};
        obi_pkg::AMOMAXU: axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_UMAX};
        default:;
      endcase
    end
  end else begin : gen_tie_atop
    assign axi_obi_lock = '0;
    assign axi_obi_atop = '0;
    assign axi_obi_wdata = obi_req_i.wdata;
  end
  if (ObiCfg.OptionalCfg.UseMemtype) begin : gen_memtype
    always_comb begin : proc_memtype_translate
      axi_obi_cache = 4'b0010;
      if (1'b0) begin // Bufferable
        axi_obi_cache[0] = 1'b1;
      end
      if (1'b0) begin // Cacheable
        axi_obi_cache[1] = 1'b0;
      end
    end
  end else begin : gen_tie_memtype
    assign axi_obi_cache = 4'b0010;
  end

  // Compute address correction based on byte enables
  // This aligns the address to where the actual valid data starts
  always_comb begin : proc_addr_correction
    addr_correction = 2'b00;
    unique case (obi_req_i.be)
      4'b0001: addr_correction = 2'b00; // Byte at offset 0
      4'b0010: addr_correction = 2'b01; // Byte at offset 1
      4'b0100: addr_correction = 2'b10; // Byte at offset 2
      4'b1000: addr_correction = 2'b11; // Byte at offset 3
      4'b0011: addr_correction = 2'b00; // Halfword at offset 0
      4'b0110: addr_correction = 2'b01; // Halfword at offset 1 (unaligned)
      4'b1100: addr_correction = 2'b10; // Halfword at offset 2
      4'b1111: addr_correction = 2'b00; // Word (full width)
      default: addr_correction = 2'b00; // Default to no correction
    endcase
  end

  // AW Assignment
  if (AxiLite) begin : gen_axi_lite_aw
    always_comb begin : proc_aw_lite_assign
      // Default assignments.
      axi_req_o.aw       = '0;
      axi_req_o.aw.addr  = axi_addr_t'(obi_req_i.addr);
      axi_req_o.aw.addr[1:0] = addr_correction;
      axi_req_o.aw.prot  = axi_obi_prot;
    end
  end else begin : gen_axi_full_aw
    always_comb begin : proc_aw_assign
      // Default assignments.
      axi_req_o.aw       = '0;
      axi_req_o.aw.addr  = axi_addr_t'(obi_req_i.addr);
      axi_req_o.aw.addr[1:0] = addr_correction;
      axi_req_o.aw.prot  = axi_obi_prot;
      // AXI-Lite assignments.
      // Dynamically set size from OBI byte enables to support 8/16/32-bit writes
      axi_req_o.aw.size  = AxiSize; // default = 32-bit for OBI=32
      unique case (obi_req_i.be)
        4'b0001, 4'b0010, 4'b0100, 4'b1000: axi_req_o.aw.size = 3'd0; // 1 byte
        4'b0011, 4'b0110, 4'b1100        : axi_req_o.aw.size = 3'd1; // 2 bytes
        4'b1111                          : axi_req_o.aw.size = 3'd2; // 4 bytes
        default                          : /* leave default for non-contiguous masks */;
      endcase      
      axi_req_o.aw.burst = AxiBurstType;
      axi_req_o.aw.lock  = axi_obi_lock;
      axi_req_o.aw.atop  = axi_obi_atop;
      axi_req_o.aw.cache = axi_obi_cache;
    end
  end

  // W Assignment
  if (AxiLite) begin : gen_axi_lite_w
    always_comb begin : proc_w_lite_assign
      axi_req_o.w        = '0;
      // Data goes in lower bits (no address-based shifting needed since address is corrected)
      axi_req_o.w.data[ObiCfg.DataWidth*data_offset+:ObiCfg.DataWidth] = axi_obi_wdata;
      axi_req_o.w.strb[ObiCfg.DataWidth/8*data_offset+:ObiCfg.DataWidth/8] = obi_req_i.be;
    end
  end else begin : gen_axi_full_w
    always_comb begin : proc_w_assign
      axi_req_o.w        = '0;
      // Data goes in lower bits (no address-based shifting needed since address is corrected)
      axi_req_o.w.data[ObiCfg.DataWidth*data_offset+:ObiCfg.DataWidth] = axi_obi_wdata;
      axi_req_o.w.strb[ObiCfg.DataWidth/8*data_offset+:ObiCfg.DataWidth/8] = obi_req_i.be;
      axi_req_o.w.last = 1'b1;
    end
  end

  // AR Assignment
  if (AxiLite) begin : gen_axi_lite_ar
    always_comb begin : proc_ar_lite_assign
      axi_req_o.ar       = '0;
      axi_req_o.ar.addr  = axi_addr_t'(obi_req_i.addr);
      axi_req_o.ar.addr[1:0] = addr_correction;
      axi_req_o.ar.prot  = axi_obi_prot;
    end
  end else begin : gen_axi_full_ar
    always_comb begin : proc_ar_assign
      axi_req_o.ar       = '0;
      axi_req_o.ar.addr  = axi_addr_t'(obi_req_i.addr);
      axi_req_o.ar.addr[1:0] = addr_correction;
      axi_req_o.ar.prot  = axi_obi_prot;
      axi_req_o.ar.size  = AxiSize;
      unique case (obi_req_i.be)
        4'b0001, 4'b0010, 4'b0100, 4'b1000: axi_req_o.ar.size = 3'd0; // 1 byte
        4'b0011, 4'b0110, 4'b1100        : axi_req_o.ar.size = 3'd1; // 2 bytes
        4'b1111                          : axi_req_o.ar.size = 3'd2; // 4 bytes
        default                          : /* leave default for non-contiguous masks */;
      endcase      
      axi_req_o.ar.burst = AxiBurstType;
      axi_req_o.ar.lock  = axi_obi_lock;
      axi_req_o.ar.cache = axi_obi_cache;
    end
  end

  // Control for translating request to the AXI4-Lite `AW`, `W` and `AR` channels.
  always_comb begin : proc_request_control
    data_offset = '0;
    if (AxiDataWidth > ObiCfg.DataWidth) begin
      data_offset = obi_req_i.addr[$clog2(ObiCfg.DataWidth/8)+:
                                     $clog2(AxiDataWidth/ObiCfg.DataWidth)];
    end
    axi_req_o.aw_valid = 1'b0;
    axi_req_o.w_valid  = 1'b0;
    axi_req_o.ar_valid = 1'b0;
    // This is also the push signal for the response FIFO.
    obi_rsp_o.gnt      = 1'b0;
    // Bookkeeping about sent write channels.
    aw_sent_d          = aw_sent_q;
    w_sent_d           = w_sent_q;

    // Control for Request to AXI4-Lite translation.
    if (obi_req_i.req && !fifo_full) begin
      if (!obi_req_i.we) begin // Read request
        axi_req_o.ar_valid = 1'b1;
        obi_rsp_o.gnt          = axi_rsp_i.ar_ready;
      end else begin // Write request, decouple `AW` and `W` channels.
        unique case ({aw_sent_q, w_sent_q})
          2'b00 : begin // None of the AXI4-Lite writes have been sent yet.
            axi_req_o.aw_valid = 1'b1;
            axi_req_o.w_valid  = 1'b1;
            unique case ({axi_rsp_i.aw_ready, axi_rsp_i.w_ready})
              2'b01 : begin // W is sent, still needs AW.
                w_sent_d = 1'b1;
              end
              2'b10 : begin // AW is sent, still needs W.
                aw_sent_d = 1'b1;
              end
              2'b11 : begin // Both are transmitted, grant the write request.
                obi_rsp_o.gnt = 1'b1;
              end
              default : /* do nothing */;
            endcase
          end
          2'b10 : begin
            // W has to be sent.
            axi_req_o.w_valid = 1'b1;
            if (axi_rsp_i.w_ready) begin
              aw_sent_d = 1'b0;
              obi_rsp_o.gnt = 1'b1;
            end
          end
          2'b01 : begin
            // AW has to be sent.
            axi_req_o.aw_valid = 1'b1;
            if (axi_rsp_i.aw_ready) begin
              w_sent_d  = 1'b0;
              obi_rsp_o.gnt = 1'b1;
            end
          end
          default : begin
            // Failsafe go to IDLE.
            aw_sent_d = 1'b0;
            w_sent_d  = 1'b0;
          end
        endcase
      end
    end
  end

  `FFARN(aw_sent_q, aw_sent_d, 1'b0, clk_i, rst_ni)
  `FFARN(w_sent_q, w_sent_d, 1'b0, clk_i, rst_ni)

  // Select which response should be forwarded. `01` write response, `00` read response, `11` for atomics.
  logic [1:0] rsp_sel;

  fifo_v3 #(
    .FALL_THROUGH ( 1'b0        ), // No fallthrough for one cycle delay before ready on AXI.
    .DEPTH        ( MaxRequests ),
    .dtype        ( logic[1:0]  )
  ) i_fifo_rsp_mux (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0             ),
    .testmode_i ( 1'b0             ),
    .full_o     ( fifo_full        ),
    .empty_o    ( fifo_empty       ),
    .usage_o    ( /*not used*/     ),
    .data_i     ( {|axi_obi_atop, obi_req_i.we} ),
    .push_i     ( obi_rsp_o.gnt    ),
    .data_o     ( rsp_sel          ),
    .pop_i      ( obi_rsp_o.rvalid )
  );

  

  localparam int unsigned NumObiChans = AxiDataWidth/ObiCfg.DataWidth;
  localparam int unsigned NumObiChanWidth = $clog2(NumObiChans);

  typedef logic[NumObiChanWidth-1:0] obi_chan_sel_t;


  if (AxiDataWidth > ObiCfg.DataWidth) begin : gen_datawidth_offset_fifo
    fifo_v3 #(
      .FALL_THROUGH ( 1'b0        ), // No fallthrough for one cycle delay before ready on AXI.
      .DEPTH        ( MaxRequests ),
      .dtype        ( obi_chan_sel_t  )
    ) i_fifo_size (
      .clk_i,
      .rst_ni,
      .flush_i    ( 1'b0             ),
      .testmode_i ( 1'b0             ),
      .full_o     (),// rsp_mux flow control used
      .empty_o    (),// rsp_mux flow control used
      .usage_o    (),// rsp_mux flow control used
      .data_i     ( data_offset      ),
      .push_i     ( obi_rsp_o.gnt    ),// rsp_mux flow control used
      .data_o     ( rdata_offset     ),
      .pop_i      ( obi_rsp_o.rvalid )// rsp_mux flow control used
    );
  end else begin : gen_no_datawidth_offset
    assign rdata_offset = '0;
  end

  // Response selection control.
  // If something is in the FIFO, the corresponding channel is ready.
  assign axi_req_o.b_ready = ~fifo_empty &
                             (( rsp_sel[0] & ~rsp_sel[1]) | (rsp_sel[1] & axi_rsp_i.r_valid));
  assign axi_req_o.r_ready = ~fifo_empty &
                             ((~rsp_sel[0] & ~rsp_sel[1]) | (rsp_sel[1] & axi_rsp_i.b_valid));
  // Read data is directly forwarded.
  assign obi_rsp_o.rdata = axi_rsp_i.r.data[ObiCfg.DataWidth*rdata_offset+:ObiCfg.DataWidth];
  // Error is taken from the respective channel.
  // EXOKAY if needed is passed
  assign axi_rsp_channel_sel = rsp_sel;
  // Mem response is valid if the handshaking on the respective channel occurs.
  // Can not happen at the same time as ready is set from the FIFO.
  // This serves as the pop signal for the FIFO.
  assign obi_rsp_o.rvalid = (axi_rsp_i.b_valid & axi_req_o.b_ready) |
                           (axi_rsp_i.r_valid & axi_req_o.r_ready);

  // // pragma translate_off
  // `ifndef SYNTHESIS
  // `ifndef VERILATOR
  //   initial begin : proc_assert
  //     if (AxiLite) begin
  //       assert (ObiCfg.OptionalCfg.UseAtop == 0) else $fatal(1, "ATOP not supported in AXI lite");
  //       assert (ObiCfg.OptionalCfg.UseMemtype == 0) else
  //         $fatal(1, "Memtype/cache not supported in AXI lite");
  //     end
  //     assert (ObiCfg.AddrWidth > 32'd0) else $fatal(1, "OBI AddrWidth has to be greater than 0!");
  //     assert (AxiAddrWidth > 32'd0) else $fatal(1, "AxiAddrWidth has to be greater than 0!");
  //     assert (ObiCfg.DataWidth <= AxiDataWidth && AxiDataWidth % ObiCfg.DataWidth == 0) else
  //         $fatal(1, "DataWidth has to be proper divisor of and <= AxiDataWidth!");
  //     assert (MaxRequests > 32'd0) else $fatal(1, "MaxRequests has to be greater than 0!");
  //     assert (AxiAddrWidth == $bits(axi_req_o.aw.addr)) else
  //         $fatal(1, "AxiAddrWidth has to match axi_req_o.aw.addr!");
  //     assert (AxiAddrWidth == $bits(axi_req_o.ar.addr)) else
  //         $fatal(1, "AxiAddrWidth has to match axi_req_o.ar.addr!");
  //     // assert (DataWidth == $bits(axi_req_o.w.data)) else
  //     //     $fatal(1, "DataWidth has to match axi_req_o.w.data!");
  //     // assert (DataWidth/8 == $bits(axi_req_o.w.strb)) else
  //     //     $fatal(1, "DataWidth / 8 has to match axi_req_o.w.strb!");
  //     // assert (DataWidth == $bits(axi_rsp_i.r.data)) else
  //     //     $fatal(1, "DataWidth has to match axi_rsp_i.r.data!");
  //   end
  //   default disable iff (~rst_ni);
  //   assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=> obi_req_i.req) else
  //       $fatal(1, "It is not allowed to deassert the request if it was not granted!");
  //   assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
  //                                      $stable(obi_req_i.addr)) else
  //       $fatal(1, "obi_req_i.addr has to be stable if request is not granted!");
  //   assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
  //                                      $stable(obi_req_i.we)) else
  //       $fatal(1, "obi_req_i.we has to be stable if request is not granted!");
  //   assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
  //                                      $stable(obi_req_i.wdata)) else
  //       $fatal(1, "obi_req_i.wdata has to be stable if request is not granted!");
  //   assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
  //                                      $stable(obi_req_i.be)) else
  //       $fatal(1, "obi_req_i.be has to be stable if request is not granted!");
  // `endif
  // `endif
  // pragma translate_on
endmodule
