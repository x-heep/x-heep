// Copyright 2021 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Scrubber for ecc
//   - iteratively steps through memory bank
//   - corrects *only* correctable errors

module ecc_scrubber #(
  parameter int unsigned BankSize       = 256,
  parameter bit          UseExternalECC = 0,
  parameter int unsigned DataWidth      = 39,
  parameter int unsigned ProtWidth      = 7,
  parameter bit          CorrectRead    = 1'b0,
  parameter bit          TmrHs          = 1'b0,
  parameter int unsigned TmrHsWidth     = TmrHs ? 3 : 1
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,

  input  logic                        scrub_trigger_i, // Set to 1'b0 to disable
  output logic                        bit_corrected_o,
  output logic                        uncorrectable_o,

  // Input signals from others accessing memory bank
  input  logic [TmrHsWidth-1:0]                       intc_req_i,
  output logic [TmrHsWidth-1:0]                       intc_gnt_o,
  input  logic [TmrHsWidth-1:0]                       intc_we_i,
  input  logic [TmrHsWidth-1:0][$clog2(BankSize)-1:0] intc_add_i,
  input  logic                 [       DataWidth-1:0] intc_wdata_i,
  output logic                 [       DataWidth-1:0] intc_rdata_o,

  // Output directly to bank
  output logic [TmrHsWidth-1:0]                       bank_req_o,
  input  logic [TmrHsWidth-1:0]                       bank_gnt_i,
  output logic [TmrHsWidth-1:0]                       bank_we_o,
  output logic [TmrHsWidth-1:0][$clog2(BankSize)-1:0] bank_add_o,
  output logic                 [       DataWidth-1:0] bank_wdata_o,
  input  logic                 [       DataWidth-1:0] bank_rdata_i,

  // If using external ECC
  output logic [       DataWidth-1:0] ecc_out_o,
  input  logic [       DataWidth-1:0] ecc_in_i,
  input  logic [                 2:0] ecc_err_i,

  output logic fault_o
);

  logic [                 1:0] ecc_err;

  logic                 [       DataWidth-1:0] scrub_wdata;
  logic                 [       DataWidth-1:0] scrub_rdata;
  logic [TmrHsWidth-1:0]                       bit_corrected;
  logic [TmrHsWidth-1:0]                       uncorrectable;
  logic [TmrHsWidth-1:0][       DataWidth-1:0] bank_wdata_use_scrub;

  logic [TmrHsWidth-1:0][2:0] state_sync;
  logic [TmrHsWidth-1:0][1:0][2:0] alt_state_sync;
  logic [TmrHsWidth-1:0][$clog2(BankSize)-1:0] working_add_sync;
  logic [TmrHsWidth-1:0][1:0][$clog2(BankSize)-1:0] alt_working_add_sync;

  logic [DataWidth+3-1:0] faults;
  assign fault_o = |faults;

  assign bit_corrected_o = |bit_corrected;
  assign uncorrectable_o = |uncorrectable;

  assign intc_rdata_o = bank_rdata_i;
  assign scrub_rdata  = bank_rdata_i;


  for (genvar i = 0; i < TmrHsWidth; i++) begin : gen_tmr_parts
    for (genvar j = 0; j < 2; j++) begin : gen_alt_sync
      assign alt_state_sync[i][j]       = state_sync[(i + j + 1) % TmrHsWidth];
      assign alt_working_add_sync[i][j] = working_add_sync[(i + j + 1) % TmrHsWidth];
    end
    ecc_scrubber_tmr_part #(
      .BankSize  ( BankSize  ),
      .DataWidth ( DataWidth ),
      .CorrectRead ( CorrectRead )
    ) tmr_part (
      .clk_i               ( clk_i                ),
      .rst_ni              ( rst_ni               ),
      .scrub_trigger_i     ( scrub_trigger_i      ),
      .bit_corrected_o     ( bit_corrected[i]     ),
      .uncorrectable_o     ( uncorrectable[i]     ),
      .ecc_err_i           ( ecc_err              ),
      .intc_req_i          ( intc_req_i[i]        ),
      .intc_gnt_o          ( intc_gnt_o[i]       ),
      .intc_we_i           ( intc_we_i[i]         ),
      .intc_add_i          ( intc_add_i[i]        ),
      .intc_wdata_i        ( intc_wdata_i         ),
      .bank_req_o          ( bank_req_o[i]        ),
      .bank_gnt_i          ( bank_gnt_i[i]        ),
      .bank_we_o           ( bank_we_o[i]         ),
      .bank_add_o          ( bank_add_o[i]        ),
      .bank_wdata_use_scrub_o ( bank_wdata_use_scrub[i] ),


      .state_sync_o           (state_sync[i]),
      .alt_state_sync_i       (alt_state_sync[i]),
      .working_add_sync_o     (working_add_sync[i]),
      .alt_working_add_sync_i (alt_working_add_sync[i]),
      .fault_o             (faults[i])
    );
  end

  if (UseExternalECC) begin : gen_external_ecc
    assign ecc_err = ecc_err_i;
    assign ecc_out_o = scrub_rdata;
    assign scrub_wdata = ecc_in_i;
  end else begin : gen_internal_ecc
    assign ecc_out_o = '0;
    hsiao_ecc_cor #(
      .DataWidth (DataWidth-ProtWidth),
      .ProtWidth (ProtWidth)
    ) ecc_corrector (
      .in        ( scrub_rdata ),
      .out       ( scrub_wdata ),
      .syndrome_o(),
      .err_o     ( ecc_err     )
    );
  end

  if (TmrHs) begin : gen_tmr_wdata
    for (genvar i = 0; i < DataWidth; i++) begin : gen_wdata_sel
      logic sel;
      TMR_voter_fail #(
        .VoterType (1) // KP_MV
      ) wdata_voter (
        .a_i            ( bank_wdata_use_scrub[0][i] ),
        .b_i            ( bank_wdata_use_scrub[1][i] ),
        .c_i            ( bank_wdata_use_scrub[2][i] ),
        .majority_o     ( sel                        ),
        .fault_detected_o ( faults[i+3]                       )
      );
      assign bank_wdata_o[i] = sel ? scrub_wdata[i] : intc_wdata_i[i];
    end
  end else begin : gen_non_tmr_wdata
    assign bank_wdata_o = bank_wdata_use_scrub[0] ? scrub_wdata : intc_wdata_i;
  end

endmodule

module ecc_scrubber_tmr_part #(
  parameter int unsigned BankSize       = 256,
  parameter int unsigned DataWidth      = 39,
  parameter bit          CorrectRead    = 1'b0
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,

  input  logic                        scrub_trigger_i, // Set to 1'b0 to disable
  output logic                        bit_corrected_o,
  output logic                        uncorrectable_o,

  input  logic [1:0]                  ecc_err_i,

  input  logic                        intc_req_i,
  output logic                        intc_gnt_o,
  input  logic                        intc_we_i,
  input  logic [$clog2(BankSize)-1:0] intc_add_i,
  input  logic [       DataWidth-1:0] intc_wdata_i,

  output logic                        bank_req_o,
  input  logic                        bank_gnt_i,
  output logic                        bank_we_o,
  output logic [$clog2(BankSize)-1:0] bank_add_o,
  output logic [       DataWidth-1:0] bank_wdata_use_scrub_o,

  output logic      [2:0]                  state_sync_o,
  input  logic [1:0][2:0]                  alt_state_sync_i,
  output logic      [$clog2(BankSize)-1:0] working_add_sync_o,
  input  logic [1:0][$clog2(BankSize)-1:0] alt_working_add_sync_i,

  output logic fault_o
);

  typedef enum logic [2:0] {Idle, Read, Write} scrub_state_e;
  scrub_state_e state_d, state_q, state_next;
  logic [2:0] state_q_logic;

  logic                        scrub_req;
  logic                        scrub_we;
  logic [$clog2(BankSize)-1:0] scrub_add;

  logic [$clog2(BankSize)-1:0] working_add_d, working_add_q, working_add_next;
  logic [$clog2(BankSize)-1:0] read_add_d, read_add_q;
  logic                        read_d, read_q;
  logic                        correcting_read;

  logic [1:0] faults;
  assign fault_o = |faults;

  assign scrub_add = working_add_q;

  assign bank_req_o   = intc_req_i | scrub_req | correcting_read;

  assign read_add_d = intc_add_i;
  assign read_d     = intc_req_i && !intc_we_i;

  assign intc_gnt_o = bank_gnt_i;

  always_comb begin : proc_bank_assign
    // By default, bank is connected to outside
    bank_we_o    = intc_we_i;
    bank_add_o   = intc_add_i;
    bank_wdata_use_scrub_o = '0;
    correcting_read = 1'b0;

    // If scrubber active and outside is not, do scrub
    if ( (state_q == Read || state_q == Write) && intc_req_i == 1'b0) begin
      bank_we_o    = scrub_we;
      bank_add_o   = scrub_add;
      bank_wdata_use_scrub_o = '1;
    end

    // We only try to write once, thereafter the scrubber will get there sometime
    if (CorrectRead && // Feature is enabled
        read_q && // last cycle was a read
        ecc_err_i[0] == 1'b1 && // read had a correctable error
        intc_req_i == 1'b0 // outside is not requesting
    ) begin
      bank_we_o  = 1'b1;
      bank_add_o = read_add_q;
      bank_wdata_use_scrub_o = '1;
      correcting_read = 1'b1;
    end
  end

  always_comb begin : proc_FSM_logic
    state_d       = state_q;
    scrub_req     = 1'b0;
    scrub_we      = 1'b0;
    working_add_d = working_add_q;
    bit_corrected_o = correcting_read;
    uncorrectable_o = 1'b0;

    if (state_q == Idle) begin
      // Switch to read state if triggered to scrub
      if (scrub_trigger_i) begin
        state_d = Read;
      end

    end else if (state_q == Read) begin
      // Request read to scrub
      scrub_req = 1'b1;
      // Request only active if outside is inactive
      if (intc_req_i == 1'b0 && correcting_read == 1'b0 && bank_gnt_i == 1'b1) begin
        state_d = Write;
      end

    end else if (state_q == Write) begin
      if (ecc_err_i[0] == 1'b0) begin   // No correctable Error
        // Return to idle state
        state_d       = Idle;
        working_add_d = (working_add_q + 1) % BankSize; // increment address
        uncorrectable_o = ecc_err_i[1];

      end else begin                  // Correctable Error
        // Write corrected version
        scrub_req = 1'b1;
        scrub_we  = 1'b1;

        // INTC interference - retry read and write
        if (intc_req_i == 1'b1 || correcting_read == 1'b1) begin
          state_d = Read;
        end else if (bank_gnt_i == 1'b0) begin // Wait for grant
          state_d = Write; // stay in write state
        end else begin                // Error corrected
          state_d       = Idle;
          working_add_d = (working_add_q + 1) % BankSize; // increment address
          bit_corrected_o = 1'b1;
        end
      end
    end
  end

  assign state_sync_o = state_next;
  bitwise_TMR_voter_fail #(
    .DataWidth($bits(scrub_state_e))
  ) i_state_voter (
    .a_i            ( state_next               ),
    .b_i            ( alt_state_sync_i[0]   ),
    .c_i            ( alt_state_sync_i[1]   ),
    .majority_o     ( state_q_logic          ),
    .fault_detected_o ( faults[0]               )
  );
  assign state_q = scrub_state_e'(state_q_logic);

  assign working_add_sync_o = working_add_next;
  bitwise_TMR_voter_fail #(
    .DataWidth($clog2(BankSize))
  ) i_working_add_voter (
    .a_i            ( working_add_next               ),
    .b_i            ( alt_working_add_sync_i[0]   ),
    .c_i            ( alt_working_add_sync_i[1]   ),
    .majority_o     ( working_add_q          ),
    .fault_detected_o ( faults[1]               )
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ff
    if(!rst_ni) begin
      state_next <= Idle;
      working_add_next <= '0;
    end else begin
      state_next <= state_d;
      working_add_next <= working_add_d;
    end
  end

  if (CorrectRead) begin : gen_correct_read_sync
    // Synchronize read address and read signal
    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_read_sync_ff
      if(!rst_ni) begin
        read_add_q <= '0;
        read_q <= 1'b0;
      end else begin
        read_add_q <= read_add_d;
        read_q <= read_d;
      end
    end
  end else begin
    assign read_q = '0;
    assign read_add_q = '0;
  end

endmodule
