// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module obi_to_axi #(
  /// The configuration of the OBI port (input port).
  parameter pulp_obi_pkg::obi_cfg_t ObiCfg      = pulp_obi_pkg::ObiDefaultConfig,
  /// The request struct of the OBI port
  parameter type               obi_req_t = logic,
  /// The response struct of the OBI port
  parameter type               obi_rsp_t = logic,
  /// Output is AXI lite when set to 1'b1
  parameter bit                AxiLite      = 1'b0,
  /// AXI Address Width
  parameter int unsigned       AxiAddrWidth = ObiCfg.AddrWidth,
  /// AXI Data Width
  parameter int unsigned       AxiDataWidth = ObiCfg.DataWidth,
  /// AXI User Width, manually assigned from the outside, applied to Ax
  parameter int unsigned       AxiUserWidth = 0,
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
  input  logic [AxiUserWidth-1:0] user_i,

  output axi_req_t axi_req_o,
  input  axi_rsp_t axi_rsp_i,

  // Signals for manual user reassignment of response
  output logic [1:0]              axi_rsp_channel_sel, // [ATOP , WE]
  output logic [AxiUserWidth-1:0] axi_rsp_b_user_o,
  output logic [AxiUserWidth-1:0] axi_rsp_r_user_o,
  input  logic [ObiCfg.OptionalCfg.RUserWidth-1:0] obi_rsp_user_i // If unused tie to '0
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

  logic [2:0] axi_obi_prot;
  logic       axi_obi_lock;
  logic [5:0] axi_obi_atop;
  logic [ObiCfg.DataWidth-1:0] axi_obi_wdata;
  logic [3:0] axi_obi_cache;

  if (ObiCfg.OptionalCfg.UseProt) begin : gen_prot
    // User mode is unpriviledged
    assign axi_obi_prot[0]  = obi_req_i.a.a_optional.prot[2:1] != 2'b00;
    // Always secure?
    assign axi_obi_prot[1]  = 1'b0;
    // Instr / Data access
    assign axi_obi_prot[2]  = ~obi_req_i.a.a_optional.prot[0];
  end else begin : gen_default_prot
    assign axi_obi_prot = DefaultProt;
  end

  if (ObiCfg.OptionalCfg.UseAtop) begin : gen_atop
    always_comb begin : proc_atop_translate
      axi_obi_lock = 1'b0;
      axi_obi_atop = '0;
      axi_obi_wdata = obi_req_i.a.wdata;
      case (obi_req_i.a.a_optional.atop)
        pulp_obi_pkg::ATOPLR:  axi_obi_lock = 1'b1;
        pulp_obi_pkg::ATOPSC:  axi_obi_lock = 1'b1;
        pulp_obi_pkg::AMOSWAP: axi_obi_atop = {axi_pkg::ATOP_ATOMICSWAP};
        pulp_obi_pkg::AMOADD:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_ADD};
        pulp_obi_pkg::AMOXOR:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_EOR};
        pulp_obi_pkg::AMOAND: begin
          axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                          axi_pkg::ATOP_LITTLE_END,
                          axi_pkg::ATOP_CLR};
          axi_obi_wdata = ~obi_req_i.a.wdata;
        end
        pulp_obi_pkg::AMOOR:   axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_SET};
        pulp_obi_pkg::AMOMIN:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_SMIN};
        pulp_obi_pkg::AMOMAX:  axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_SMAX};
        pulp_obi_pkg::AMOMINU: axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_UMIN};
        pulp_obi_pkg::AMOMAXU: axi_obi_atop = {axi_pkg::ATOP_ATOMICLOAD,
                                          axi_pkg::ATOP_LITTLE_END,
                                          axi_pkg::ATOP_UMAX};
        default:;
      endcase
    end
  end else begin : gen_tie_atop
    assign axi_obi_lock = '0;
    assign axi_obi_atop = '0;
    assign axi_obi_wdata = obi_req_i.a.wdata;
  end
  if (ObiCfg.OptionalCfg.UseMemtype) begin : gen_memtype
    always_comb begin : proc_memtype_translate
      axi_obi_cache = 4'b0010;
      if (obi_req_i.a.a_optional.memtype[0]) begin // Bufferable
        axi_obi_cache[0] = 1'b1;
      end
      if (obi_req_i.a.a_optional.memtype[1]) begin // Cacheable
        axi_obi_cache[1] = 1'b0;
      end
    end
  end else begin : gen_tie_memtype
    assign axi_obi_cache = 4'b0010;
  end

  // AW Assignment
  if (AxiLite) begin : gen_axi_lite_aw
    always_comb begin : proc_aw_lite_assign
      // Default assignments.
      axi_req_o.aw       = '0;
      axi_req_o.aw.addr  = axi_addr_t'(obi_req_i.a.addr);
      axi_req_o.aw.prot  = axi_obi_prot;
    end
  end else begin : gen_axi_full_aw
    always_comb begin : proc_aw_assign
      // Default assignments.
      axi_req_o.aw       = '0;
      axi_req_o.aw.addr  = axi_addr_t'(obi_req_i.a.addr);
      axi_req_o.aw.prot  = axi_obi_prot;
      // AXI-Lite assignments.
      axi_req_o.aw.size  = AxiSize;
      axi_req_o.aw.burst = AxiBurstType;
      axi_req_o.aw.lock  = axi_obi_lock;
      axi_req_o.aw.atop  = axi_obi_atop;
      axi_req_o.aw.cache = axi_obi_cache;
      axi_req_o.aw.user  = user_i;
    end
  end

  // W Assignment
  if (AxiLite) begin : gen_axi_lite_w
    always_comb begin : proc_w_lite_assign
      axi_req_o.w        = '0;
      axi_req_o.w.data[ObiCfg.DataWidth*data_offset+:ObiCfg.DataWidth] = axi_obi_wdata;
      axi_req_o.w.strb[ObiCfg.DataWidth/8*data_offset+:ObiCfg.DataWidth/8] = obi_req_i.a.be;
    end
  end else begin : gen_axi_full_w
    always_comb begin : proc_w_assign
      axi_req_o.w        = '0;
      axi_req_o.w.data[ObiCfg.DataWidth*data_offset+:ObiCfg.DataWidth] = axi_obi_wdata;
      axi_req_o.w.strb[ObiCfg.DataWidth/8*data_offset+:ObiCfg.DataWidth/8] = obi_req_i.a.be;
      axi_req_o.w.last = 1'b1;
    end
  end

  // AR Assignment
  if (AxiLite) begin : gen_axi_lite_ar
    always_comb begin : proc_ar_lite_assign
      axi_req_o.ar       = '0;
      axi_req_o.ar.addr  = axi_addr_t'(obi_req_i.a.addr);
      axi_req_o.ar.prot  = axi_obi_prot;
    end
  end else begin : gen_axi_full_ar
    always_comb begin : proc_ar_assign
      axi_req_o.ar       = '0;
      axi_req_o.ar.addr  = axi_addr_t'(obi_req_i.a.addr);
      axi_req_o.ar.prot  = axi_obi_prot;
      axi_req_o.ar.size  = AxiSize;
      axi_req_o.ar.burst = AxiBurstType;
      axi_req_o.ar.lock  = axi_obi_lock;
      axi_req_o.ar.cache = axi_obi_cache;
      // User signals?
    end
  end

  if (AxiDataWidth > ObiCfg.DataWidth) begin : gen_data_offset
    assign data_offset = obi_req_i.a.addr[$clog2(ObiCfg.DataWidth/8)+:$clog2(AxiDataWidth/ObiCfg.DataWidth)];
  end else begin : gen_no_data_offset
    assign data_offset = '0;
  end

  // Control for translating request to the AXI4-Lite `AW`, `W` and `AR` channels.
  always_comb begin : proc_request_control
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
      if (!obi_req_i.a.we) begin
        // It is a read request.
        axi_req_o.ar_valid = 1'b1;
        obi_rsp_o.gnt          = axi_rsp_i.ar_ready;
      end else begin
        // Is is a write request, decouple `AW` and `W` channels.
        unique case ({aw_sent_q, w_sent_q})
          2'b00 : begin
            // None of the AXI4-Lite writes have been sent jet.
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
    .data_i     ( {|axi_obi_atop, obi_req_i.a.we} ),
    .push_i     ( obi_rsp_o.gnt    ),
    .data_o     ( rsp_sel          ),
    .pop_i      ( obi_rsp_o.rvalid )
  );

  fifo_v3 #(
    .FALL_THROUGH ( 1'b0        ), // No fallthrough for one cycle delay before ready on AXI.
    .DEPTH        ( MaxRequests ),
    .dtype        ( logic[ObiCfg.IdWidth-1:0] )
  ) i_fifo_rid (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0             ),
    .testmode_i ( 1'b0             ),
    .full_o     (),// rsp_mux flow control used
    .empty_o    (),// rsp_mux flow control used
    .usage_o    (),// rsp_mux flow control used
    .data_i     ( obi_req_i.a.aid  ),
    .push_i     ( obi_rsp_o.gnt    ),// rsp_mux flow control used
    .data_o     ( obi_rsp_o.r.rid  ),
    .pop_i      ( obi_rsp_o.rvalid )// rsp_mux flow control used
  );

  localparam int unsigned NumObiChans = AxiDataWidth/ObiCfg.DataWidth;
  localparam int unsigned NumObiChanWidth = NumObiChans > 1 ? $clog2(NumObiChans) : 1;

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
  assign obi_rsp_o.r.rdata = axi_rsp_i.r.data[ObiCfg.DataWidth*rdata_offset+:ObiCfg.DataWidth];
  // Error is taken from the respective channel.
  assign obi_rsp_o.r.err = rsp_sel[1] ?
      (axi_rsp_i.b.resp inside {axi_pkg::RESP_SLVERR, axi_pkg::RESP_DECERR}) |
      (axi_rsp_i.r.resp inside {axi_pkg::RESP_SLVERR, axi_pkg::RESP_DECERR}) :
      rsp_sel[0] ?
          (axi_rsp_i.b.resp inside {axi_pkg::RESP_SLVERR, axi_pkg::RESP_DECERR}) :
          (axi_rsp_i.r.resp inside {axi_pkg::RESP_SLVERR, axi_pkg::RESP_DECERR});
  // EXOKAY if needed is passed
  if (ObiCfg.OptionalCfg.UseAtop) begin : gen_atop_exokay
    assign obi_rsp_o.r.r_optional.exokay = rsp_sel[0] ?
      (axi_rsp_i.b.resp == axi_pkg::RESP_EXOKAY) :
      (axi_rsp_i.r.resp == axi_pkg::RESP_EXOKAY);
  end
  // User signal concatenation is handled outside
  assign axi_rsp_b_user_o = axi_rsp_i.b.user;
  assign axi_rsp_r_user_o = axi_rsp_i.r.user;
  assign axi_rsp_channel_sel = rsp_sel;
  if (ObiCfg.OptionalCfg.RUserWidth) begin : gen_ruser
    assign obi_rsp_o.r.r_optional.ruser = obi_rsp_user_i;
  end
  // Mem response is valid if the handshaking on the respective channel occurs.
  // Can not happen at the same time as ready is set from the FIFO.
  // This serves as the pop signal for the FIFO.
  assign obi_rsp_o.rvalid = (axi_rsp_i.b_valid & axi_req_o.b_ready) |
                           (axi_rsp_i.r_valid & axi_req_o.r_ready);

  // pragma translate_off
  `ifndef SYNTHESIS
  `ifndef VERILATOR
    initial begin : proc_assert
      if (AxiLite) begin
        assert (ObiCfg.OptionalCfg.UseAtop == 0) else $fatal(1, "ATOP not supported in AXI lite");
        assert (ObiCfg.OptionalCfg.UseMemtype == 0) else
          $fatal(1, "Memtype/cache not supported in AXI lite");
      end
      assert (ObiCfg.AddrWidth > 32'd0) else $fatal(1, "OBI AddrWidth has to be greater than 0!");
      assert (AxiAddrWidth > 32'd0) else $fatal(1, "AxiAddrWidth has to be greater than 0!");
      assert (ObiCfg.DataWidth <= AxiDataWidth && AxiDataWidth % ObiCfg.DataWidth == 0) else
          $fatal(1, "DataWidth has to be proper divisor of and <= AxiDataWidth!");
      assert (MaxRequests > 32'd0) else $fatal(1, "MaxRequests has to be greater than 0!");
      assert (AxiAddrWidth == $bits(axi_req_o.aw.addr)) else
          $fatal(1, "AxiAddrWidth has to match axi_req_o.aw.addr!");
      assert (AxiAddrWidth == $bits(axi_req_o.ar.addr)) else
          $fatal(1, "AxiAddrWidth has to match axi_req_o.ar.addr!");
      // assert (DataWidth == $bits(axi_req_o.w.data)) else
      //     $fatal(1, "DataWidth has to match axi_req_o.w.data!");
      // assert (DataWidth/8 == $bits(axi_req_o.w.strb)) else
      //     $fatal(1, "DataWidth / 8 has to match axi_req_o.w.strb!");
      // assert (DataWidth == $bits(axi_rsp_i.r.data)) else
      //     $fatal(1, "DataWidth has to match axi_rsp_i.r.data!");
    end
    default disable iff (~rst_ni);
    assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=> obi_req_i.req) else
        $fatal(1, "It is not allowed to deassert the request if it was not granted!");
    assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
                                       $stable(obi_req_i.a.addr)) else
        $fatal(1, "obi_req_i.a.addr has to be stable if request is not granted!");
    assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
                                       $stable(obi_req_i.a.we)) else
        $fatal(1, "obi_req_i.a.we has to be stable if request is not granted!");
    assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
                                       $stable(obi_req_i.a.wdata)) else
        $fatal(1, "obi_req_i.a.wdata has to be stable if request is not granted!");
    assert property (@(posedge clk_i) (obi_req_i.req && !obi_rsp_o.gnt) |=>
                                       $stable(obi_req_i.a.be)) else
        $fatal(1, "obi_req_i.a.be has to be stable if request is not granted!");
  `endif
  `endif
  // pragma translate_on
endmodule
