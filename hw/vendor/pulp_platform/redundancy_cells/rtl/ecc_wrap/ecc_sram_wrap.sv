// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Adapts bus to sram adding ecc bits

// DEPRECATED!

module ecc_sram_wrap #(
  parameter  int unsigned BankSize         = 256,
  parameter  bit          InputECC         = 0, // 0: no ECC on input
                                                // 1: SECDED on input
  parameter  bit          EnableTestMask   = 1, // Enables test_write_mask in HW
                                                // Requries bitwise byte enable in SRAM
  parameter  int unsigned NumRMWCuts       = 0, // Number of cuts in the read-modify-write path
  // Set params
  parameter  int unsigned UnprotectedWidth = 32, // This currently only works for 32bit
  parameter  int unsigned ProtectedWidth   = 39, // This currently only works for 39bit
  localparam int unsigned DataInWidth      = InputECC ? ProtectedWidth : UnprotectedWidth,
  localparam int unsigned BEInWidth        = UnprotectedWidth/8,
  localparam int unsigned BankAddWidth     = $clog2(BankSize)
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  logic                      test_enable_i,

  input  logic                      scrub_trigger_i, // Set to 1'b0 to disable scrubber
  output logic                      scrubber_fix_o,
  output logic                      scrub_uncorrectable_o,

  input  logic [   DataInWidth-1:0] tcdm_wdata_i,
  input  logic [              31:0] tcdm_add_i,
  input  logic                      tcdm_req_i,
  input  logic                      tcdm_wen_i,
  input  logic [     BEInWidth-1:0] tcdm_be_i,
  output logic [   DataInWidth-1:0] tcdm_rdata_o,
  output logic                      tcdm_gnt_o,
  output logic                      single_error_o,
  output logic                      multi_error_o,

  input  logic [ProtectedWidth-1:0] test_write_mask_ni // Tie to '0 if unused!!!
);

  $warning("The `ecc_sram_wrap` module has been deprecated, please use the `ecc_sram` instead.");

  logic [1:0]                    ecc_error;
  logic                          valid_read_d, valid_read_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_valid_read
    if(~rst_ni) begin
      valid_read_q <= '0;
    end else begin
      valid_read_q <= valid_read_d;
    end
  end

  assign valid_read_d = tcdm_req_i && tcdm_gnt_o &&
                        (tcdm_wen_i || (tcdm_be_i != {BEInWidth{1'b1}}));
  assign single_error_o = ecc_error[0] && valid_read_q;
  assign multi_error_o  = ecc_error[1] && valid_read_q;

`ifndef TARGET_SYNTHESIS
  always @(posedge clk_i) begin
    if ((ecc_error[0] && valid_read_q) == 1)
      $display("[ECC] %t - single error detected", $realtime);
    if ((ecc_error[1] && valid_read_q) == 1)
      $display("[ECC] %t - multi error detected", $realtime);
  end
`endif

  logic                      bank_req;
  logic                      bank_we;
  logic [  BankAddWidth-1:0] bank_add;
  logic [ProtectedWidth-1:0] bank_wdata;
  logic [ProtectedWidth-1:0] bank_rdata;

  logic                      bank_scrub_req;
  logic                      bank_scrub_we;
  logic [  BankAddWidth-1:0] bank_scrub_add;
  logic [ProtectedWidth-1:0] bank_scrub_wdata;
  logic [ProtectedWidth-1:0] bank_scrub_rdata;

  logic                      test_req_d, test_req_q;
  logic [  BankAddWidth-1:0] test_add_d, test_add_q;

  logic                      bank_final_req;
  logic                      bank_final_we;
  logic [  BankAddWidth-1:0] bank_final_add;

  typedef enum logic { NORMAL, LOAD_AND_STORE } store_state_e;
  store_state_e store_state_d, store_state_q;
  logic [cf_math_pkg::idx_width(NumRMWCuts)-1:0] rmw_count_d, rmw_count_q;

  logic [ DataInWidth-1:0] input_buffer_d, input_buffer_q;
  logic [BankAddWidth-1:0] add_buffer_d, add_buffer_q;
  logic [   BEInWidth-1:0] be_buffer_d, be_buffer_q;

  logic [UnprotectedWidth-1:0] be_selector;
  assign be_selector    = {{8{be_buffer_q[3]}},{8{be_buffer_q[2]}},
                           {8{be_buffer_q[1]}},{8{be_buffer_q[0]}}};

  logic [ProtectedWidth-1:0] rmw_buffer_end;
  logic [ProtectedWidth-1:0] rmw_buffer_0;
  assign rmw_buffer_0 = bank_rdata;
  shift_reg #(
    .dtype(logic[ProtectedWidth-1:0]),
    .Depth(NumRMWCuts)
  ) i_rmw_buffer (
    .clk_i,
    .rst_ni,
    .d_i   (rmw_buffer_0),
    .d_o   (rmw_buffer_end)
  );

  if ( InputECC == 0 ) begin : gen_no_ecc_input
    // Loads  -> loads full data
    // Stores ->
    //   If BE_in == 1111: adds ECC and stores directly
    //   If BE_in != 1111: loads stored and buffers input (responds success to store command)
    //                     re-calculates ECC and stores correctly

    logic [DataInWidth-1:0] to_store;
    logic [cf_math_pkg::idx_width(NumRMWCuts)-1:0][DataInWidth-1:0] loaded;

    logic [ProtectedWidth-1:0] decoder_in;

    assign decoder_in = store_state_q == NORMAL ? bank_rdata : rmw_buffer_end;

    prim_secded_39_32_dec ecc_decode (
      .in         ( decoder_in ),
      .d_o        ( loaded ),
      .syndrome_o (),
      .err_o      (ecc_error)
    );

    hsiao_ecc_enc #(
      .DataWidth (UnprotectedWidth),
      .ProtWidth (ProtectedWidth - UnprotectedWidth)
    ) ecc_encode (
      .in  ( to_store   ),
      .out ( bank_wdata )
    );

    assign tcdm_rdata_o   = loaded;

    assign to_store = store_state_q == NORMAL ?
                      tcdm_wdata_i :
                      (be_selector & input_buffer_q) | (~be_selector & loaded);

  end else begin : gen_ecc_input

    logic [  ProtectedWidth-1:0] lns_wdata;
    logic [UnprotectedWidth-1:0] intermediate_data_ld, intermediate_data_st;

    assign bank_wdata = store_state_q == NORMAL ? tcdm_wdata_i : lns_wdata;
    assign tcdm_rdata_o   = bank_rdata;

    prim_secded_39_32_dec ld_decode (
      .in        (rmw_buffer_end),
      .d_o       (intermediate_data_ld),
      .syndrome_o(),
      .err_o     ()
    );

    hsiao_ecc_dec #(
      .DataWidth (UnprotectedWidth),
      .ProtWidth (ProtectedWidth - UnprotectedWidth)
    ) st_decode (
      .in        ( input_buffer_q ),
      .out       ( intermediate_data_st ),
      .syndrome_o(),
      .err_o     ()
    );

    hsiao_ecc_enc #(
      .DataWidth (UnprotectedWidth),
      .ProtWidth (ProtectedWidth - UnprotectedWidth)
    ) lns_encode (
      .in  ( (be_selector & intermediate_data_st) | (~be_selector & intermediate_data_ld)   ),
      .out ( lns_wdata )
    );
  end

  always_comb begin
    store_state_d  = NORMAL;
    tcdm_gnt_o     =  1'b1;
    bank_add       =  tcdm_add_i[BankAddWidth+2-1:2];
    bank_we        = ~tcdm_wen_i;
    input_buffer_d = tcdm_wdata_i;
    add_buffer_d   = tcdm_add_i[BankAddWidth+2-1:2];
    be_buffer_d    = tcdm_be_i;
    bank_req       =  tcdm_req_i;
    rmw_count_d    = rmw_count_q;
    if (store_state_q == NORMAL) begin
      if (tcdm_req_i & (tcdm_be_i != 4'b1111) & ~tcdm_wen_i) begin
        store_state_d = LOAD_AND_STORE;
        bank_we       = 1'b0;
        rmw_count_d   = NumRMWCuts;
      end
    end else begin
      tcdm_gnt_o  = 1'b0;
      bank_add        = add_buffer_q;
      bank_we         = 1'b1;
      input_buffer_d  = input_buffer_q;
      add_buffer_d    = add_buffer_q;
      be_buffer_d     = be_buffer_q;
      if (rmw_count_q == '0) begin
        bank_req      = 1'b1;
      end else begin
        bank_req      = 1'b0;
        rmw_count_d   = rmw_count_q - 1;
        store_state_d = LOAD_AND_STORE;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_load_and_store_ff
    if(!rst_ni) begin
      store_state_q  <= NORMAL;
      add_buffer_q   <= '0;
      input_buffer_q <= '0;
      be_buffer_q    <= '0;
      rmw_count_q    <= '0;
    end else begin
      add_buffer_q   <= add_buffer_d;
      store_state_q  <= store_state_d;
      input_buffer_q <= input_buffer_d;
      be_buffer_q    <= be_buffer_d;
      rmw_count_q    <= rmw_count_d;
    end
  end

  ecc_scrubber #(
    .BankSize       ( BankSize       ),
    .UseExternalECC ( 0              ),
    .DataWidth      ( ProtectedWidth )
  ) i_scrubber (
    .clk_i,
    .rst_ni,

    .scrub_trigger_i ( scrub_trigger_i  ),
    .bit_corrected_o ( scrubber_fix_o   ),
    .uncorrectable_o ( scrub_uncorrectable_o ),

    .intc_req_i      ( bank_req         ),
    .intc_we_i       ( bank_we          ),
    .intc_add_i      ( bank_add         ),
    .intc_wdata_i    ( bank_wdata       ),
    .intc_rdata_o    ( bank_rdata       ),

    .bank_req_o      ( bank_scrub_req   ),
    .bank_we_o       ( bank_scrub_we    ),
    .bank_add_o      ( bank_scrub_add   ),
    .bank_wdata_o    ( bank_scrub_wdata ),
    .bank_rdata_i    ( bank_scrub_rdata ),

    .ecc_out_o       (),
    .ecc_in_i        ( '0 ),
    .ecc_err_i       ( '0 )
  );

  always_comb begin : proc_test_req
    test_req_d     = bank_scrub_req;
    test_add_d     = bank_scrub_add;
    bank_final_req = bank_scrub_req;
    bank_final_we  = bank_scrub_we;
    bank_final_add = bank_scrub_add;
    if (test_enable_i) begin
      bank_final_req = test_req_q;
      bank_final_we  = 1'b0;
      bank_final_add = test_add_q;
      test_req_d     = test_req_q;
      test_add_d     = test_add_q;
    end
  end

  logic [(EnableTestMask ? ProtectedWidth : 1)-1:0] sram_be;
  if (EnableTestMask) begin : gen_be
    assign sram_be = ~test_write_mask_ni;
  end else begin : gen_be_const
    assign sram_be = 1'b1;
  end

  tc_sram #(
    .NumWords  ( BankSize                            ), // Number of Words in data array
    .DataWidth ( ProtectedWidth                      ), // Data signal width
    .ByteWidth ( EnableTestMask ? 1 : ProtectedWidth ), // Width of a data byte
    .NumPorts  ( 1                                   ), // Number of read and write ports
`ifndef TARGET_SYNTHESIS
    .SimInit   ( "zeros"                             ),
`endif
    .Latency   ( 1                                   ) // Latency when the read data is available
  ) i_bank (
    .clk_i,                                                   // Clock
    .rst_ni,                                                  // Asynchronous reset active low

    .req_i   ( bank_final_req    ), // request
    .we_i    ( bank_final_we     ), // write enable
    .addr_i  ( bank_final_add    ), // request address
    .wdata_i ( bank_scrub_wdata  ), // write data
    .be_i    ( sram_be           ), // write byte enable

    .rdata_o (  bank_scrub_rdata )  // read data
  );

  // These registers are to avoid writes during scan testing. Please ensure these registers are not scanned
  always_ff @(posedge clk_i) begin : proc_test_req_ff
    test_req_q <= test_req_d;
    test_add_q <= test_add_d;
  end

endmodule
