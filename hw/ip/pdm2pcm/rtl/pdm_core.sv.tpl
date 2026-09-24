// Copyright 2025 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Authors: Pierre Guillod <pierre.guillod@epfl.ch> ,EPFL, STI-SEL
//          Jérémie Moullet<jeremie.moullet@epfl.ch>,EPFL, STI-SEL
//
// Date: 06.2025
//
// Description: Core logic of the PDM-to-PCM conversion pipeline.
//              This module captures a 1-bit Pulse Density Modulated (PDM) signal
//              and converts it into a multi-bit Pulse Code Modulated (PCM) signal.
//
// Filter Chain:
//┌───────────────────────┐
//│       CIC Filter      │
//│┌─────┐ ┌─────┐ ┌─────┐│┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
//││Intgs├─►Decim├─►Combs├│►Hlfbd├─►Decim├─►Hlfbd├─►Decim├─► FIR │
//│└─────┘ └─────┘ └─────┘│└─────┘ └─────┘ └─────┘ └─────┘ └─────┘
//└───────────────────────┘
// (made with asciiflow.com)
//
// Parameters (compile-time):
//   - MAX_STAGE_CIC       : Maximal Number of stages in the CIC filter.
//   - WIDTH               : Bit-width of internal datapath and output PCM value.
//   - DECIM_COMBS_CNT_W   : Width of the decimation factor input for the CIC decimator.
//   - DELAYCOMBWIDTH      : Width of the comb delay parameter.
//
// Ports:
//   - div_clk_i, rstn_i        : Decimated clock and active-low reset.
//   - en_i                     : Enables sampling and filtering.
//   - pdm_clk_o                : Output clock signal that samples `pdm_i`.
//   - pdm_i                    : 1-bit PDM input signal.
//   - par_cic_activated_stages : Thermometric input selecting active CIC stages (e.g., 4 stages = 4'b1111).
//   - par_decim_idx_combs      : Decimation factor applied after integrators.
//   - par_delay_combs          : Delay D used in all comb stages.
//   - pcm_o                    : Output PCM signal.
//   - pcm_data_valid_o         : Pulse indicating `pcm_o` contains valid data.
//
// Notes:
//   - Converts binary PDM to signed representation (1 → +1, 0 → -1).
//   - Internally consists of integrator stages, a programmable decimator,
//     and comb stages.
//   - When full filtering is enabled (not in CIC-only mode), additional
//     halfband and FIR filters are appended downstream.
//   - Output is synchronized with the last active decimation stage.

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

module pdm_core #(
% if cic_mode == 0:
    // Second decimator internal counter width
    localparam DECIM_HFBD1_CNT_W = 5,
    // Third decimator internal counter width
    localparam DECIM_HFBD2_CNT_W = 6,
    // Number of stages of the first halfband filter
    localparam STAGES_HB1 = 10,
    localparam COEFFS_HB1 = 4,
    // Number of stages of the second halfband filter
    localparam STAGES_HB2 = 22,
    localparam COEFFS_HB2 = 7,
    // Number of stages of the FIR filter
    localparam STAGES_FIR = 26,
    localparam COEFFS_FIR = 14,
    // Width of the filter coefficients (Halfbands and FIR)
    localparam COEFFSWIDTH = 18,
% endif
    // Number of stages of the CIC filter
    parameter integer MAX_STAGE_CIC = 4,
    // Width of the datapath
    parameter integer WIDTH = 18,
    // First decimator internal counter width
    parameter integer DECIM_COMBS_CNT_W = 4,
    // Widht of the comb delay parameter
    parameter integer DELAYCOMBWIDTH = 5

) (
    // Clock input
    input logic div_clk_i,
    // Reset input
    input logic rstn_i,
    // Enable input
    input logic en_i,
    // Clock output to the microphone
    output logic pdm_clk_o,
    // Which/How many CIC stage are activated (Thermometric, right-aligned)
    input logic [MAX_STAGE_CIC-1:0] par_cic_activated_stages,
    // First decimator decimation index
    input logic [DECIM_COMBS_CNT_W-1:0] par_decim_idx_combs,
    //Delay D in the combs stage
    input logic [DELAYCOMBWIDTH-1:0] par_delay_combs,
% if cic_mode == 0:
    // Second decimator decimation index
    input logic [DECIM_HFBD1_CNT_W-1:0] par_decim_idx_hfbd2,
    // Third decimator decimation index
    input logic [DECIM_HFBD2_CNT_W-1:0] par_decim_idx_fir,
    // First halfband filter coefficients array
    input logic [COEFFSWIDTH-1:0] coeffs_hb1[0:COEFFS_HB1-1],
    // Second halfband filter coefficients array
    input logic [COEFFSWIDTH-1:0] coeffs_hb2[0:COEFFS_HB2-1],
    // FIR filter coefficients array
    input logic [COEFFSWIDTH-1:0] coeffs_fir[0:COEFFS_FIR-1],
% endif

    // Input signal (PDM)
    input logic pdm_i,
    // Output signal (PCM)
    output logic [WIDTH-1:0] pcm_o,
    // Valid output data flag
    output logic pcm_data_valid_o
);

  logic             r_store;
  logic             r_send;
  logic             r_data;

  // Auxiliary signals to link the filter blocks
  logic [WIDTH-1:0] data;
  logic [WIDTH-1:0] integr_to_comb;
  logic [WIDTH-1:0] combs_to_hb1;
% if cic_mode == 0:
  logic [WIDTH-1:0] hb1_to_hb2;
  logic [WIDTH-1:0] hb2_to_fir;
%endif

  logic             r_en;
  logic             s_clr;

  // Decimators output signals
  logic             combs_en;
% if cic_mode == 0:
  logic             hb2_en;
  logic             fir_en;
% endif

  // Output synchronized with the last decimator
  % if cic_mode == 0:
    assign pcm_data_valid_o =  fir_en;
  % else:
    assign pcm_data_valid_o =  combs_en;
  % endif

  ///////////////////////////////////////////////////////////////////////////
  //////////// PIECE OF CODE I NEED TO MAKE EASIER TO UNDERSTAND ////////////
  ///////////////////////////////////////////////////////////////////////////

  always_ff @(posedge div_clk_i or negedge rstn_i) begin : proc_r_store
    if (~rstn_i) begin
      r_store   <= 1;
      r_send    <= 0;
      r_data    <= 0;
      pdm_clk_o <= 0;
    end else begin
      if (en_i) begin
        r_store <= ~r_store;
        r_send  <= ~r_send;
        if (r_store) begin
          r_data    <= pdm_i;
          pdm_clk_o <= ~pdm_clk_o;
        end else begin
          r_store   <= 1'b1;
          r_send    <= 0;
          pdm_clk_o <= 0;
        end
      end
    end
  end

  assign s_clr = en_i & !r_en;

  always_ff @(posedge div_clk_i or negedge rstn_i) begin
    if (~rstn_i) r_en <= 'h0;
    else r_en <= en_i;
  end

  ///////////////////////////////////////////////////////////////////////////
  ////// END OF THE PIECE OF CODE I NEED TO MAKE EASIER TO UNDERSTAND ///////
  ///////////////////////////////////////////////////////////////////////////

  // Converts binary PDM {0,1} to bipolar PDM {-1,1}
  assign data = r_data ? 'h1 : {WIDTH{1'b1}};

  cic_integrators #(MAX_STAGE_CIC, WIDTH) cic_integrators_inst (
      .clk_i (div_clk_i),
      .rstn_i(rstn_i),
      .clr_i (s_clr),
      .en_i  (r_send),
      .par_cic_activated_stages,
      .data_i(data),
      .data_o(integr_to_comb)
  );

  decimator #(DECIM_COMBS_CNT_W) decimator_before_hb1 (
      .clk_i(div_clk_i),
      .rst_i(rstn_i),
      .clr_i(s_clr),
      .par_decimation_index(par_decim_idx_combs),
      .en_i(r_send),
      .en_o(combs_en)
  );

  cic_combs #(MAX_STAGE_CIC, WIDTH, DELAYCOMBWIDTH) cic_combs_inst (
      .clk_i (div_clk_i),
      .rstn_i(rstn_i),
      .clr_i (s_clr),
      .en_i  (combs_en),
      .par_cic_activated_stages,
      .par_delay_combs,
      .data_i(integr_to_comb),
      .data_o(combs_to_hb1)
  );

% if cic_mode == 0:
    halfband #(WIDTH, COEFFSWIDTH, STAGES_HB1) halfband_inst1 (
        .clk_i(div_clk_i),
        .rstn_i(rstn_i),
        .clr_i(s_clr),
        .en_i(combs_en),
        .data_i(combs_to_hb1),
        .data_o(hb1_to_hb2),
        .freecoeffs(coeffs_hb1)
    );

    decimator #(DECIM_HFBD1_CNT_W) decimator_before_hb2 (
        .clk_i(div_clk_i),
        .rst_i(rstn_i),
        .clr_i(s_clr),
        .par_decimation_index(par_decim_idx_hfbd2),
        .en_i(r_send),
        .en_o(hb2_en)
    );

    halfband #(WIDTH, COEFFSWIDTH, STAGES_HB2) halfband_inst2 (
        .clk_i(div_clk_i),
        .rstn_i(rstn_i),
        .clr_i(s_clr),
        .en_i(hb2_en),
        .data_i(hb1_to_hb2),
        .data_o(hb2_to_fir),
        .freecoeffs(coeffs_hb2)
    );

    decimator #(DECIM_HFBD2_CNT_W) decimator_before_fir (
        .clk_i(div_clk_i),
        .rst_i(rstn_i),
        .clr_i(s_clr),
        .par_decimation_index(par_decim_idx_fir),
        .en_i(r_send),
        .en_o(fir_en)
    );

    fir #(WIDTH, COEFFSWIDTH, STAGES_FIR) fir_inst (
        .clk_i(div_clk_i),
        .rstn_i(rstn_i),
        .clr_i(s_clr),
        .en_i(fir_en),
        .data_i(hb2_to_fir),
        .data_o(pcm_o),
        .freecoeffs(coeffs_fir)
    );
% else:
      assign pcm_o = combs_to_hb1;
% endif

endmodule
