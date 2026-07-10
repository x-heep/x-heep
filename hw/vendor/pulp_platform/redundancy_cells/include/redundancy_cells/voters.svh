// Copyright 2024 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Macros to instantiate voters in a signel line


// Helper Macro to use enums bitwise
// This has no effect on array of bits, but does not work on plain logic!
`define BITWISE(a) \
  a[$bits(a)-1:0]


// Cell Instantiation Macros
// If you want to use different kinds of cells, you only have to change these
`define TMR_INSTANCE(input_signal, output_signal, instance_name) \
if ($bits(input_signal[0]) > 1) begin \
    bitwise_TMR_voter_fail #( \
        .DataWidth($bits(input_signal[0])), \
        .VoterType(2) \
    ) instance_name ( \
        .a_i(`BITWISE(input_signal[0])), \
        .b_i(`BITWISE(input_signal[1])), \
        .c_i(`BITWISE(input_signal[2])), \
        .majority_o(`BITWISE(output_signal)), \
        .fault_detected_o() \
    ); \
end else begin \
    TMR_voter_fail #( \
        .VoterType(2) \
    ) instance_name ( \
        .a_i(input_signal[0]), \
        .b_i(input_signal[1]), \
        .c_i(input_signal[2]), \
        .majority_o(output_signal), \
        .fault_detected_o() \
    ); \
end

`define TMR_INSTANCE_F(input_signal, output_signal, fault_any, instance_name) \
if ($bits(input_signal[0]) > 1) begin \
    bitwise_TMR_voter_fail #( \
        .DataWidth($bits(input_signal[0])), \
        .VoterType(1) \
    ) instance_name ( \
        .a_i(`BITWISE(input_signal[0])), \
        .b_i(`BITWISE(input_signal[1])), \
        .c_i(`BITWISE(input_signal[2])), \
        .majority_o(`BITWISE(output_signal)), \
        .fault_detected_o(fault_any) \
    ); \
end else begin \
    TMR_voter_fail #( \
        .VoterType(1) \
    ) instance_name ( \
        .a_i(input_signal[0]), \
        .b_i(input_signal[1]), \
        .c_i(input_signal[2]), \
        .majority_o(output_signal), \
        .fault_detected_o(fault_any) \
    ); \
end

`define TMR_INSTANCE_W(input_signal, output_signal, fault_210, fault_multiple, instance_name) \
if ($bits(input_signal[0]) > 1) begin \
    bitwise_TMR_voter #( \
        .DataWidth($bits(input_signal[0])), \
        .VoterType(2) \
    ) instance_name ( \
        .a_i(`BITWISE(input_signal[0])), \
        .b_i(`BITWISE(input_signal[1])), \
        .c_i(`BITWISE(input_signal[2])), \
        .majority_o(`BITWISE(output_signal)), \
        .error_o(fault_multiple), \
        .error_cba_o(fault_210) \
    ); \
end else begin \
    bitwise_TMR_voter #( \
        .DataWidth($bits(input_signal[0])), \
        .VoterType(2) \
    ) instance_name ( \
      .a_i(input_signal[0]), \
      .b_i(input_signal[1]), \
      .c_i(input_signal[2]), \
      .majority_o(output_signal), \
      .error_o(fault_multiple), \
      .error_cba_o(fault_210) \
    ); \
end


// 3 -> 1 Voters
`define VOTE31(input_signal, output_signal) \
`TMR_INSTANCE(input_signal, output_signal, i_bitwise_TMR_voter_fail);

`define VOTE31F(input_signal, output_signal, fault_any) \
`TMR_INSTANCE_F(input_signal, output_signal, fault_any, i_bitwise_TMR_voter_fail);

`define VOTE31W(input_signal, output_signal, fault_210, fault_multiple) \
`TMR_INSTANCE_W(input_signal, output_signal, fault_210, fault_multiple, i_bitwise_TMR_voter);


// 3 -> 3 Voters
`define VOTE33(input_signal, output_signal) \
`TMR_INSTANCE(input_signal, output_signal[0], i_bitwise_TMR_voter_fail_0); \
`TMR_INSTANCE(input_signal, output_signal[1], i_bitwise_TMR_voter_fail_1); \
`TMR_INSTANCE(input_signal, output_signal[2], i_bitwise_TMR_voter_fail_2);

`define VOTE33F(input_signal, output_signal, fault_any) \
`TMR_INSTANCE_F(input_signal, output_signal[0], fault_any, i_bitwise_TMR_voter_fail_0f); \
`TMR_INSTANCE(input_signal, output_signal[1], i_bitwise_TMR_voter_fail_1); \
`TMR_INSTANCE(input_signal, output_signal[2], i_bitwise_TMR_voter_fail_2);

`define VOTE33W(input_signal, output_signal, fault_210, fault_multiple) \
`TMR_INSTANCE_W(input_signal, output_signal[0], fault_210, fault_multiple, i_bitwise_TMR_voter_fail_0w); \
`TMR_INSTANCE(input_signal, output_signal[1], i_bitwise_TMR_voter_fail_1); \
`TMR_INSTANCE(input_signal, output_signal[2], i_bitwise_TMR_voter_fail_2);


// localparam replicas -> 1 Voters 
`define VOTEX1(replicas, input_signal, output_signal) \
if (replicas == 3) begin \
    `VOTE31(input_signal, output_signal); \
end else if (replicas == 2) begin \
    assign output_signal = input_signal[0]; \
end else if (replicas == 1) begin \
    assign output_signal = input_signal[0]; \
end else begin \
    $fatal(1, "Unsupported number of replicas in voter macro!\n"); \
end

`define VOTEX1F(replicas, input_signal, output_signal, fault_any) \
if (replicas == 3) begin \
    `VOTE31F(input_signal, output_signal, fault_any); \
end else if (replicas == 2) begin \
    assign output_signal = input_signal[0]; \
    assign fault_any = input_signal[0] != input_signal[1]; \
end else if (replicas == 1) begin \
    assign output_signal = input_signal[0]; \
    assign fault_any = 1'b0; \
end else begin \
    $fatal(1, "Unsupported number of replicas in voter macro!\n"); \
end


// localparam replicas -> replicas Voters 
`define VOTEXX(replicas, input_signal, output_signal) \
if (replicas == 3) begin \
    `VOTE33(input_signal, output_signal); \
end else if (replicas == 2) begin \
    assign output_signal[0] = input_signal[0]; \
    assign output_signal[1] = input_signal[1]; \
end else if (replicas == 1) begin \
    assign output_signal[0] = input_signal[0]; \
end else begin \
    $fatal(1, "Unsupported number of replicas in voter macro!\n"); \
end

`define VOTEXXF(replicas, input_signal, output_signal, fault_any) \
if (replicas == 3) begin \
    `VOTE33F(input_signal, output_signal, fault_any); \
end else if (replicas == 2) begin \
    assign output_signal[0] = input_signal[0]; \
    assign output_signal[1] = input_signal[1]; \
    assign fault_any = input_signal[0] != input_signal[1]; \
end else if (replicas == 1) begin \
    assign output_signal[0] = input_signal[0]; \
    assign fault_any = 1'b0; \
end else begin \
    $fatal(1, "Unsupported number of replicas in voter macro!\n"); \
end
