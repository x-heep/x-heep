// Copyright 2025 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: dlc.sv
// Author: Alessio Naclerio
// Date: 17/02/2025
// Description: Digital Level Crossing Block

module dlc #(
    parameter int  RW_FIFO_DEPTH_W = 4,
    parameter type reg_req_t,
    parameter type reg_rsp_t,
    parameter type fifo_req_t,
    parameter type fifo_rsp_t
) (
    input logic clk_i,
    input logic rst_ni,
    // Register interface (connected to the external peripheral bus)
    input reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,
    // hw fifo interface (connected to the DMA)
    input fifo_req_t hw_fifo_req_i,
    output fifo_rsp_t hw_fifo_resp_o,
    // done signal
    output logic dlc_done_o,
    // LC signals
    output logic dlc_xing_o,
    output logic dlc_dir_o

);

  // Signals Declaration

  // ------------------------- FSM

  typedef enum logic [1:0] {
    DLC_RUN,
    DLC_DLVL_OVF,
    DLC_DT_OVF
  } dlc_state_t;

  dlc_state_t dlc_state_n;
  dlc_state_t dlc_state;

  // ------------------------- Write and Read Fifos

  logic hw_r_fifo_empty;
  logic hw_r_fifo_full;
  logic [1:0] hw_r_fifo_usage;
  logic hw_r_fifo_pop;
  logic signed [31:0] hw_r_fifo_data_out;
  logic [15:0] hw_w_fifo_data_in;
  logic hw_w_fifo_full;
  logic hw_w_fifo_push;

  // ------------------------- Registers

  dlc_reg_pkg::dlc_reg2hw_t reg2hw;
  dlc_reg_pkg::dlc_hw2reg_t hw2reg;
  logic [3:0] reg_log_wl;  // log2 of the level width
  logic [3:0] reg_discard;  // log2 of the level width
  logic [3:0] reg_dlvl_bits;  // number of bits for the delta levels in the output data
  logic [15:0] reg_dlvl_mask;  // mask for delta levels, it has as many 1s as the number of bits for the delta levels
  logic [15:0] reg_dt_mask;  // mask for delta time, it has as many 1s as the number of bits for the delta time
  logic reg_dlvl_twoscomp_n_sgnmod;  // if '1' delta levels are in 2s complement, else sign|abs_value
  logic reg_bypass;  // bypass mode

  // ------------------------- Level Crossing Logic

  logic signed [15:0] din_lvl;  // input data level
  logic [15:0] trans_counter;  // transaction counter

  // ------------------------- Adder I/O Operands

  logic [15:0] add_op1;
  logic [15:0] add_op2;
  logic [15:0] add_res;
  logic [15:0] add_one_op1;
  logic [15:0] add_one_op2;
  logic [15:0] add_one_res;

  // ------------------------- Sample Difference Counter

  logic [15:0] sdiff_cnt;  // Sample difference counter for the number of samples that have passed
  logic sdiff_cnt_en;  // Sample difference counter enable signal
  logic sdiff_cnt_rst;  // Sample differene counter reset signal
  logic [15:0] dt_out;  // delta time actual output

  // ------------------------- Delta Levels Management

  logic [15:0] dlvl;  // difference between din level and the current level (signed)
  logic signed [15:0] dlvl_abs;  // abolute value delta levels
  logic dlvl_ovf;  // delta levels overflow bit
  logic [15:0] dlvl_out;  // delta levels actual output
  logic [15:0] ovf_dwn_cnt;  // overflow down counter
  logic check_end_ovf;  // '1' if overflow data must not be sent anymore
  logic dir;  // direction of the delta levels
  logic dir_d1;  // The last direction of delta levels (from the last crossing)
  logic dir_reg;  // direction register
  logic [16:0] dt_dir_out;  // delta-time and direction packet extended on 17 bits
  logic dir_out;  // dir actual output
  logic [16:0] dlc_output;  // dLC output packet

  logic xing;  // a crossing event

  // ------------------------- FSM

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      trans_counter <= '0;
    end else begin
      if (hw_fifo_req_i.flush) begin
        trans_counter <= reg2hw.trans_size.q;
      end else if (hw_fifo_req_i.push) begin
        trans_counter <= trans_counter - 1;
      end
    end
  end

  assign dlc_done_o = (trans_counter == 0);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      dlc_state <= DLC_RUN;
    end else begin
      dlc_state <= dlc_state_n;
    end
  end

  always_comb begin
    if (dlc_state == DLC_RUN) begin
      /*
        dlvl has overflowed and write fifo is not full
        (if the hw write fifo is full, no need to stall because din_lvl will be preserved
        as no pop operation will be issued from the hw read fifo)
      */
      if (dlvl_ovf) begin  // && !hw_w_fifo_full) begin
        dlc_state_n = DLC_DLVL_OVF;
        /*
        delta time has overflowed
      */
      end else if (sdiff_cnt_en && (sdiff_cnt == reg_dt_mask)) begin
        dlc_state_n = DLC_DT_OVF;
      end else begin
        dlc_state_n = DLC_RUN;
      end
    end else if (dlc_state == DLC_DLVL_OVF) begin
      /*
        the end of delta level overflow has been reached so we can go back to the run state
      */
      if (check_end_ovf == 1'b1) begin
        dlc_state_n = DLC_RUN;
      end else begin
        dlc_state_n = DLC_DLVL_OVF;
      end
    end else if (dlc_state == DLC_DT_OVF) begin
      /*
        if the write fifo is not full anymore we can go back to the run state
        otherwise we stay in the stall state due to delta time overflow
      */
      if (!hw_w_fifo_full) begin
        dlc_state_n = DLC_RUN;
      end else begin
        dlc_state_n = DLC_DT_OVF;
      end
    end else begin
      dlc_state_n = DLC_RUN;
    end
  end

  // ------------------------- Write and Read Fifos

  // The dLC response packet is at most 16-bit wide
  assign hw_fifo_resp_o.data[31:16] = '0;

  /* Hardware Read Fifo */
  fifo_v3 #(
      .DEPTH(RW_FIFO_DEPTH_W),
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH(32)
  ) hw_r_fifo_i (
      .clk_i(clk_i),
      .rst_ni,
      .flush_i(),
      .testmode_i(1'b0),
      .full_o(hw_r_fifo_full),
      .empty_o(hw_r_fifo_empty),
      .usage_o(hw_r_fifo_usage),
      .data_i(hw_fifo_req_i.data),
      .push_i(hw_fifo_req_i.push),
      .data_o(hw_r_fifo_data_out),
      .pop_i(hw_r_fifo_pop)
  );

  assign hw_fifo_resp_o.full = hw_r_fifo_full;
  assign hw_fifo_resp_o.alm_full = hw_r_fifo_usage == 2'd3;

  /* Hardware Write Fifo */
  fifo_v3 #(
      .DEPTH(RW_FIFO_DEPTH_W),
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH(16)
  ) hw_w_fifo_i (
      .clk_i(clk_i),
      .rst_ni,
      .flush_i(),
      .testmode_i(1'b0),
      .full_o(hw_w_fifo_full),
      .empty_o(hw_fifo_resp_o.empty),
      .usage_o(),
      .data_i(hw_w_fifo_data_in),
      .push_i(hw_w_fifo_push),
      .data_o(hw_fifo_resp_o.data[15:0]),
      .pop_i(hw_fifo_req_i.pop)
  );

  // ------------------------- Registers
  dlc_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) dlc_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg2hw,
      .hw2reg,
      .reg_req_i,
      .reg_rsp_o,
      .devmode_i(1'b0)
  );

  /*
    Delta-Levels Configuration
  */
  assign reg_log_wl = reg2hw.dlvl_log_level_width.q;
  assign reg_discard = reg2hw.discard_bits.q;
  assign reg_dlvl_bits = reg2hw.dlvl_n_bits.q;
  assign reg_dlvl_mask = reg2hw.dlvl_mask.q;
  assign reg_dlvl_twoscomp_n_sgnmod = reg2hw.dlvl_format.q;
  /*
    Delta-Time Configuration
  */
  assign reg_dt_mask = reg2hw.dt_mask.q;
  /*
    Response 'Push' Configuration
  */
  assign reg_bypass = reg2hw.bypass.q;

  // ------------------------- Fifo Control Logic

  // Management of popping from HW Read FIFO
  always_comb begin
    /*
      Popping from the hw read fifo is allowed only when (at the same time):
        -> the hw read fifo is not empty
        -> the hw write fifo is not full
        -> the dlc state is in the run state
    */
    hw_r_fifo_pop = 1'b0;
    if (hw_r_fifo_empty == 1'b0 &&
        hw_w_fifo_full == 1'b0 &&
        (dlc_state != DLC_DLVL_OVF && dlc_state != DLC_DT_OVF)) begin
      hw_r_fifo_pop = 1'b1;
    end
  end

  // Management of pushing to HW Write FIFO
  always_comb begin

    /*
      Pushing to the hw write fifo is allowed only when:
        -> the hw write fifo is not full AND
          -> the dlc state is DLC_RUN and a crossing is detected (standard crossing case)
          -> delta levels have just overflowed (dlvl_ovf) or the state is DLC_DLVL_OVF
             (this means that the overflow data is being pushed to hw write fifo)
          -> delta time has overflowed (sdiff_cnt_ovf) and the state is DLC_DT_OVF
             (this means that the overflow data is waiting to being pushed to hw write fifo
              as soon as the hw write fifo is not full anymore)

      The hw write fifo is pushed only when one of the above conditions is met.
    */

    hw_w_fifo_push = 1'b0;
    if (hw_w_fifo_full == 1'b0 && ((xing && dlc_state == DLC_RUN && !dlvl_ovf) ||  // crossing detected
        (dlc_state == DLC_DLVL_OVF) ||  // delta levels overflows
        (dlc_state == DLC_DT_OVF))) begin  // delta time overflows
      hw_w_fifo_push = 1'b1;
    end
  end

  // ------------------------- Shared 17-bit Subtractor
  /*
    The adder is used both for calculating the delta levels and for the delta-level overflow case.
  */

  always_comb begin
    if (hw_r_fifo_pop && dlc_state == DLC_RUN) begin
      add_op1 = din_lvl;
      add_op2 = reg2hw.curr_lvl;
    end else if (dlc_state == DLC_DLVL_OVF) begin
      add_op1 = ovf_dwn_cnt;
      add_op2 = reg_dlvl_mask;
    end else begin
      add_op1 = '0;
      add_op2 = '0;
    end
  end

  assign add_res = $signed(add_op1) - $signed(add_op2);

  // ------------------------- Shared 16-bit +1 Adder
  /*
    The adder is used both for incrementing delta-time and for generating the absolute value of delta-levels.
  */

  always_comb begin
    if (sdiff_cnt_en) begin
      add_one_op1 = sdiff_cnt;
      add_one_op2 = 16'd1;
    end else begin
      add_one_op1 = dlvl[15] ? (~dlvl) : dlvl;
      add_one_op2 = dlvl[15] ? 16'd1 : 16'd0;
    end
  end

  assign add_one_res = $signed(add_one_op1) + $signed(add_one_op2);

  // ------------------------- Level Crossing Logic

  /*
    Input data level detection:
      input data shifted right by (log2 of the level width) positions.
      the resulting signal indicates the level the input data belongs to.
      4-bit arithmetic right shifter.

    Delta-Level calculation:
      the difference between the input data level and the current level is calculated using the shared 17-bit adder.

    Level crossing detection:
      the crossing signal is set to 1 when difference of levels between the input data level and the current level
      is not equal to 0 and the dLC is in DLC_RUN state and a data has been popped from hw read fifo.
      This either means that the input data belongs to a level above or below the current level.
  */

  logic signed [31:0] tmp1;
  logic signed [15:0] tmp2;



  always_ff @(negedge rst_ni or posedge clk_i) begin
    if (~rst_ni) begin
      dlc_dir_o <= '0;
      dir_d1 <= '0;
      dlc_xing_o <= '0;
    end else begin
      if (dlc_state == DLC_RUN && dlvl != 0) begin
        /*On every level crossed the direction is updated. Even if we do not issue a xing, the last dir is updated.*/
        dir_d1 <= dir;
      end
      if (xing) begin
        /*
        Update the direction output when there are crossings
        */
        dlc_dir_o <= dir;
      end
      dlc_xing_o <= xing;
    end
  end


  always_comb begin
    dir = 0;
    xing = 0;
    hw2reg.curr_lvl.de = '0;
    hw2reg.curr_lvl.d = '0;

    if (dlc_state == DLC_RUN && dlvl != 0) begin
      /*
      Compute the direction of the crossing
      */
      dir = dlvl[15];

      /*
        A crossing is detected once the hw read fifo is poped, if the dLC is in run state and:
        a) "the level difference is non zero", and
        b) only if hysteresis is enabled: "the direction of the xing is the same as the previous direction"
      */
      xing = (reg2hw.hysteresis_en ? (dir_d1 == dir) : 1'b1);

      /*
      Threshold updating:
        the current level is updated only when a crossing is detected and the dLC is in DLC_RUN state.
        the current level is updated with the input data level.
      */
      hw2reg.curr_lvl.de = 1;
      hw2reg.curr_lvl.d = din_lvl;

    end
  end

  always_comb begin
    if (hw_r_fifo_pop == 1'b1) begin
      tmp1 = hw_r_fifo_data_out >> reg_discard; // First we discard the least significant bits that are not relevant
      tmp2 = tmp1[15:0];  // We keep only the relevant 16 bits
      din_lvl = tmp2 >>> reg_log_wl;  // Then we right shift keeping the sign.
      dlvl = add_res;
    end else begin
      tmp1 = '0;
      tmp2 = '0;
      din_lvl = '0;
      dlvl = '0;
    end
  end

  // ------------------------- Sample difference Counter

  always_comb begin
    /*
      sample difference counter enable:
        the sample difference counter is enabled when no crossing happened and the hw read fifo is being popped.
        This means that the sample difference counter is incremented only when a crossing is not detected on a valid input data.
    */
    sdiff_cnt_en = !xing && hw_r_fifo_pop;

    /*
      sample difference counter reset:
        the sample difference counter is reset when a crossing is detected or the sample difference counter has overflowed.
    */
    sdiff_cnt_rst = (xing && !dlvl_ovf) || (dlc_state == DLC_DT_OVF && !hw_w_fifo_full) || (dlc_state == DLC_DLVL_OVF);
  end

  // Sample difference 16-bit Counter
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      sdiff_cnt <= 16'd0;
    end else begin
      if (reg_bypass == 1'b0) begin
        if (dlc_state == DLC_DLVL_OVF) begin
          if (check_end_ovf == 1'b1) begin
            sdiff_cnt <= 16'd1;
          end else begin
            sdiff_cnt <= 16'd0;
          end
        end else if (sdiff_cnt_rst == 1'b1) begin
          sdiff_cnt <= 16'd1;
        end else if (sdiff_cnt_en == 1'b1) begin
          sdiff_cnt <= add_one_res;
        end else begin
          sdiff_cnt <= sdiff_cnt;
        end
      end
    end
  end

  /* Delta Time Output:
      -> if the sample difference counter has overflowed
         delta time output is set to the sample difference counter mask (all 1s).
      -> if delta levels have just overflowed, delta time is the sample difference counter value.
      -> if delta levels have overflowed and a stall due to them is happening, delta time is 0
         because more than one packets must be sent to represent one data, but they should appear
         one right after the other, with zero time interval.
      -> if the delta levels are valid, delta time is the sample difference counter value.
  */
  always_comb begin
    if (dlc_state == DLC_DT_OVF) begin  // sample difference cnt overflow or stall due to it
      dt_out = reg_dt_mask;
    end else begin
      dt_out = sdiff_cnt;  // standard run case
    end
  end

  // ------------------------- Delta Levels Management
  always_comb begin
    // absolute value of the delta levels
    dlvl_abs = add_one_res;

    /* delta levels overflow detection:
        the overflow bit is set to 1 when a crossing is detected and delta-level is greater than the delta levels mask.
        This is detected by ANDing dlvl with the inverted delta levels mask and then checking if any of the bits is set to 1.
        If this is the case, it means that dlvl cannot be represented with the current number of bits dedicated to it.
    */
    dlvl_ovf = (reg_bypass == 1'b0) ? (xing && (|(dlvl_abs & ~reg_dlvl_mask))) : 1'b0;

    /*
      delta-level overflow stops when add_res is equal to 0 or or negative
    */
    check_end_ovf = hw_w_fifo_full ? '0 : (add_res[15] == 1'b1 || add_res == 16'h0);
  end

  /*
    Overflow down counter and direction register:
      -> the overflow down counter is updated to its next value if delta level just overflowed
         or if the dLC is stalling due to an delta-level overflow. Otherwise, it is set to 0.
         The downcounter starts from dlvl_abs and counts down by reg_dlvl_mask.
      -> the direction register is updated to the direction of the delta levels if the dlvl just overflowed.
         If a stall is in act, dir keeps its valid. Otherwise, it is set to 0.
  */
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      ovf_dwn_cnt <= '0;
      dir_reg <= 1'b0;
    end else begin
      if (!hw_w_fifo_full) begin
        if (dlvl_ovf) begin
          ovf_dwn_cnt <= dlvl_abs;
          dir_reg <= dir;
        end else if (dlc_state == DLC_DLVL_OVF) begin
          if (check_end_ovf) begin
            ovf_dwn_cnt <= '0;
          end else begin
            ovf_dwn_cnt <= add_res;
          end
          dir_reg <= dir_reg;
        end else begin
          ovf_dwn_cnt <= '0;
          dir_reg <= 1'b0;
        end
      end
    end
  end

  /* dlvl and dir output construction:
      -> if a stall is happening due to delta levels and it is ongoing, the delta levels output is set to the delta levels mask
         and the direction is set to the direction register.
      -> if a stall is happening due to delta levels and it has finished, the delta levels output is set to ovf_dwn_cnt
         because it is the remainder of the delta levels and the direction is set to the direction register.
      -> if a stall is happening due to delta time, the delta levels output is set to 0 and the direction is set to 0.
      -> if dLC is in DLC_RUN state, the delta levels output is set to the correct value depending on the format of the delta-level field (twos-complement or sign and abs value)
         and the direction is set to dir.
  */
  always_comb begin
    if (dlc_state == DLC_DLVL_OVF && check_end_ovf == 1'b0) begin
      dlvl_out = reg_dlvl_mask;
      dir_out  = dir_reg;
    end else if (dlc_state == DLC_DLVL_OVF && check_end_ovf == 1'b1) begin
      dlvl_out = ovf_dwn_cnt & reg_dlvl_mask;
      dir_out  = dir_reg;
    end else if (dlc_state == DLC_DT_OVF) begin
      dlvl_out = '0;
      dir_out  = '0;
    end else begin
      dlvl_out = (reg_dlvl_twoscomp_n_sgnmod) ? (dlvl & reg_dlvl_mask) : (dlvl_abs & reg_dlvl_mask);
      dir_out = dir;
    end
  end

  // ------------------------- Write Fifo Input Data Construction

  /* Output packet construction:
      -> dt_dir_out contains:
        - if the delta levels are in 2s complement
          - the direction of the delta levels in the LSB
          - delta time in the 15 MSBs
        - if the delta levels are in sign|abs_value
          - just delta time in the 16 MSBs
      -> dlc_output contains:
        - dt_dir_out shifted left by the number of bits for the delta levels
        - delta levels in the LSBs
  */
  always_comb begin
    dt_dir_out[16:0] = (reg_dlvl_twoscomp_n_sgnmod) ? {1'b0, dt_out[15:0]} : {dt_out[15:0], dir_out};
    // 4-bit left shifter
    dlc_output = (dt_dir_out << reg_dlvl_bits) | {1'b0, dlvl_out};
  end

  assign hw_w_fifo_data_in = reg_bypass ? hw_r_fifo_data_out[15:0] : dlc_output[15:0];


endmodule
