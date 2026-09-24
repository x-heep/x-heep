// Copyright 2025 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Authors: Pierre Guillod <pierre.guillod@epfl.ch> ,EPFL, STI-SEL
//          Jérémie Moullet<jeremie.moullet@epfl.ch>,EPFL, STI-SEL
//
// Date: 06.2025
//
// Description: This is the top-level wrapper for the PDM2PCM (Pulse Density Modulation to Pulse Code Modulation) peripheral.
//              It implements runtime-configurable decimation filters (CIC, half-band, and FIR), supports clock division,
//              and interfaces with a register map and CDC FIFO for data transfer between clock domains.
//
// Modes:
//   - CIC-only mode                   : Minimal configuration using only a CIC filter.
//   - CIC + 2×(HB + Decim) + FIR mode : Full pipeline with cascaded half-band filters and FIR post-processing.
//
//┌───────────────────────┐
//│       CIC Filter      │
//│┌─────┐ ┌─────┐ ┌─────┐│┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
//││Intgs├─►Decim├─►Combs├│►Hlfbd├─►Decim├─►Hlfbd├─►Decim├─► FIR │
//│└─────┘ └─────┘ └─────┘│└─────┘ └─────┘ └─────┘ └─────┘ └─────┘
//└───────────────────────┘
// (made with asciiflow.com)
//
// NOTE: In CIC-only mode, the additional filter stages are fully excluded from synthesis,
//       reducing both power consumption and area.
//
// Compile-Time Parameters (RTL):
//   - FIFO_DEPTH : Number of entries in the clock domain crossing FIFO.
//   - FIFO_WIDTH : Bit-width of the data path.
//
// Runtime Configuration (via register interface):
//   - CLKDIVIDX            : Clock divider from system clock to sampling frequency (must be even).
//   - DECIMCIC             : Decimation factor from sampling frequency to CIC output frequency.
//   - cic_delay_comb       : Delay parameter (D) in the CIC comb stage.
//   - cic_activated_stages : Thermometric, right-aligned encoding of the number of active CIC stages.
//                            (e.g., 4'b1111 means 4 stages are active).
//
// NOTE: This list includes runtime configuration for the CIC block only.
//       The full PDM2PCM register map is defined in `pdm2pcm.hjson`.
//
// NOTE: The maximum value for each configuration parameter is determined
//       by the bit-width defined in `pdm2pcm.hjson`.
//
// Ports:
//   - clk_i     : Main system clock.
//   - rst_ni    : Active-low reset.
//   - reg_req_i : Register interface request input.
//   - reg_rsp_o : Register interface response output.
//   - pdm_i     : 1-bit digital input from the PDM source.
//   - pdm_clk_o : Output clock signal that samples `pdm_i`.
//                 (One sample per rising edge of `pdm_clk_o`.)
//
// Control and status registers:
//   - control :
//      - bit 0 : Starts PDM data processing. The FIFO starts to fill with PCM data.
//      - bit 1 : Clears the FIFO buffer.
//   - status  :
//      - bit 0 : The FIFO buffer is empty.
//      - bit 1 : The FIFO buffer is full.
//
// Output:
//   - rxdata (via FIFO window)
//
// Features:
//   - Configurable CIC filter: number of stages, decimation, and comb delay.
//   - Optional post-processing: Half-band and FIR filters (when `cic_mode == 0`).
//   - Integer-based dynamic clock division for sampling control.
//   - CDC FIFO for safe data transfer between clock domains.
//   - Standardized register and window interface integration for memory-mapped access.

<%
    _dom = xheep.get_user_peripheral_domain()
    pdm2pcm = _dom.get_peripheral("pdm2pcm") if _dom is not None and _dom.contains_peripheral("pdm2pcm") else None
    if pdm2pcm is None :
        cic_mode = -1
    else :
        if pdm2pcm.get_cic_mode() :
            cic_mode = 1
        else :
            cic_mode = 0
%>

module pdm2pcm #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    parameter int unsigned FIFO_DEPTH = 4,
    parameter int unsigned FIFO_WIDTH = 18,
    localparam int unsigned FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH)
) (
    input logic clk_i,
    input logic rst_ni,

    // Register interface
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // PDM interface
    input  logic pdm_i,
    output logic pdm_clk_o
);

  import pdm2pcm_reg_pkg::*;

  // Interface signals
  pdm2pcm_reg2hw_t                             reg2hw;
  pdm2pcm_hw2reg_t                             hw2reg;

  //Compile time operation
  localparam integer CicMaxStageNumber = $bits(reg2hw.cic_activated_stages.q);
  localparam integer DecimCicWidth     = $bits(reg2hw.decimcic.q);
  localparam integer ClkDivIdxWidth    = $bits(reg2hw.clkdividx.q);
  localparam integer DelayCombWidth    = $bits(reg2hw.cic_delay_comb.q);


  logic              [ ClkDivIdxWidth-1:0]     par_clkdiv_idx;
  logic              [  DecimCicWidth-1:0]     par_decim_idx_combs;
  logic              [ CicMaxStageNumber-1:0]  par_cic_activated_stages;
  logic              [ DelayCombWidth-1:0]     par_delay_combs;
% if cic_mode == 0:
  logic              [                4:0]     par_decim_idx_hfbd2;
  logic              [                5:0]     par_decim_idx_fir;
  logic              [     FIFO_WIDTH-1:0]     coeffs_hb1          [ 0:3];
  logic              [     FIFO_WIDTH-1:0]     coeffs_hb2          [ 0:6];
  logic              [     FIFO_WIDTH-1:0]     coeffs_fir          [0:13];
% endif

  logic                                        pcm_data_valid;

  logic                                        rx_ready;

  logic              [     FIFO_WIDTH-1:0]     pcm;

  // FIFO/window related signals
  logic              [               31:0]     rx_data;
  logic              [     FIFO_WIDTH-1:0]     rx_fifo;

  reg_req_t          [                0:0]    fifo_win_h2d;
  reg_rsp_t          [                0:0]    fifo_win_d2h;

  logic div_clk;

  logic cdc_fifo_src_ready;
  logic cdc_fifo_src_valid;
  logic cdc_fifo_dst_valid;

  assign rx_data = ({{{32 - FIFO_WIDTH} {1'b0}}, rx_fifo});

  assign hw2reg.status.fulll.de = 1;
  assign hw2reg.status.empty.de = 1;
  assign par_clkdiv_idx = reg2hw.clkdividx.q;
  assign par_decim_idx_combs = reg2hw.decimcic.q;
  assign par_cic_activated_stages = reg2hw.cic_activated_stages.q;
  assign par_delay_combs = reg2hw.cic_delay_comb.q;

% if cic_mode == 0:
  assign par_decim_idx_hfbd2 = reg2hw.decimhb1.q;
  assign par_decim_idx_fir = reg2hw.decimhb2.q;

  assign coeffs_hb1 = '{
          reg2hw.hb1coef00.q,
          reg2hw.hb1coef01.q,
          reg2hw.hb1coef02.q,
          reg2hw.hb1coef03.q
      };

  assign coeffs_hb2 = '{
          reg2hw.hb2coef00.q,
          reg2hw.hb2coef01.q,
          reg2hw.hb2coef02.q,
          reg2hw.hb2coef03.q,
          reg2hw.hb2coef04.q,
          reg2hw.hb2coef05.q,
          reg2hw.hb2coef06.q
      };

  assign coeffs_fir = '{
          reg2hw.fircoef00.q,
          reg2hw.fircoef01.q,
          reg2hw.fircoef02.q,
          reg2hw.fircoef03.q,
          reg2hw.fircoef04.q,
          reg2hw.fircoef05.q,
          reg2hw.fircoef06.q,
          reg2hw.fircoef07.q,
          reg2hw.fircoef08.q,
          reg2hw.fircoef09.q,
          reg2hw.fircoef10.q,
          reg2hw.fircoef11.q,
          reg2hw.fircoef12.q,
          reg2hw.fircoef13.q
      };
% endif

  // The following factor compensates for the effective frequency reduction caused by the 
  // use of `r_send` as an enable signal in the integrator and decimation stage of `pdm_core`. 
  // Since `r_send` toggles at half the rate of `div_clk`, the downstream processing 
  // operates at half the expected frequency unless this correction is applied.
  // 
  // Without this factor, the actual sampling frequency would be incorrectly 
  // calculated as half the intended value. With this, we can also reduce the width of the 
  // decimation counter by 1 bit.
  //
  // Corrected frequency relationships:
  //   actual_sampling_frequency = freq(clk_i) / clkdividx
  //   actual_output_frequency   = freq(clk_i) / (clkdividx * decimcic)
  //
  // WATCH OUT : -clkdividx need to be an event number. If not, it will be rounded down. (ex : 15->14, but 16->16)
  //             -decimcic don't have this requirement.
  
  localparam integer CLK_DIV_CORRECTION_FACTOR = 1;
  localparam integer correctedClkDivIdxWidth = ClkDivIdxWidth-CLK_DIV_CORRECTION_FACTOR;

  logic [ClkDivIdxWidth-1:0] corrected_par_clkdiv_idx;
  assign corrected_par_clkdiv_idx = (par_clkdiv_idx >> CLK_DIV_CORRECTION_FACTOR);
  
  logic [correctedClkDivIdxWidth-1:0] reduced_par_clkdiv_idx;
  assign reduced_par_clkdiv_idx = corrected_par_clkdiv_idx[correctedClkDivIdxWidth-1:0];


  clk_int_div #(
      .DIV_VALUE_WIDTH(correctedClkDivIdxWidth),
      .DEFAULT_DIV_VALUE(2)
  ) clk_int_div_inst (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .en_i(reg2hw.control.enabl.q),
      .test_mode_en_i(1'b0),
      .clk_o(div_clk),
      .div_i(reduced_par_clkdiv_idx),
      .div_valid_i(1'b1),
      .div_ready_o(),
      .cycl_count_o()
  );

  pdm_core #(
      .MAX_STAGE_CIC(CicMaxStageNumber),
      .WIDTH(FIFO_WIDTH),
      .DECIM_COMBS_CNT_W(DecimCicWidth),
      .DELAYCOMBWIDTH(DelayCombWidth)
  ) pdm_core_i (
      .div_clk_i(div_clk),
      .rstn_i(rst_ni),
      .en_i(reg2hw.control.enabl.q),
      .par_cic_activated_stages,
      .par_decim_idx_combs,
      .par_delay_combs,
% if cic_mode == 0:
      .par_decim_idx_hfbd2,
      .par_decim_idx_fir,
      .coeffs_hb1,
      .coeffs_hb2,
      .coeffs_fir,
% endif
      .pdm_clk_o,
      .pdm_i,
      .pcm_o(pcm),
      .pcm_data_valid_o(pcm_data_valid)
  );

  assign cdc_fifo_src_valid = pcm_data_valid & cdc_fifo_src_ready;

  assign hw2reg.status.fulll.d = ~cdc_fifo_src_ready;
  assign hw2reg.status.empty.d = ~cdc_fifo_dst_valid;

  // Clock domain crossing FIFO
  cdc_fifo_gray #(
      .T(logic [FIFO_WIDTH-1:0]),
      .LOG_DEPTH(FIFO_ADDR_WIDTH)
  ) pdm2pcm_fifo_i (
      .src_clk_i  (div_clk),
      .src_rst_ni (rst_ni),
      .src_ready_o(cdc_fifo_src_ready),
      .src_data_i (pcm),
      .src_valid_i(cdc_fifo_src_valid),

      .dst_rst_ni (rst_ni),
      .dst_clk_i  (clk_i),
      .dst_data_o (rx_fifo),
      .dst_valid_o(cdc_fifo_dst_valid),
      .dst_ready_i(rx_ready)
  );

  pdm2pcm_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) pdm2pcm_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_win_o(fifo_win_h2d),
      .reg_rsp_win_i(fifo_win_d2h),
      .reg_req_i,
      .reg_rsp_o,
      .reg2hw,
      .hw2reg,
      .devmode_i(1'b1)
  );

  pdm2pcm_window #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) u_window (
      .rx_win_i  (fifo_win_h2d),
      .rx_win_o  (fifo_win_d2h),
      .rx_data_i (rx_data),
      .rx_ready_o(rx_ready)
  );

endmodule : pdm2pcm
