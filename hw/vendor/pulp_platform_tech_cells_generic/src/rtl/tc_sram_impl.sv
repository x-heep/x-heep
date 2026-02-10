// Copyright (c) 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>

// Description: A wrapper for `tc_sram` with generic ports for implementation-related IOs, which
//              may be used to connect dynamic control and status signals.  In this model, `impl_i`
//              is ignored and `impl_o` is statically driven. If you need such IOs in your
//              implementation, you may substitute this module directly instead of `tc_sram`.
//
// Additional parameters:
// - impl_in_t:   Implementation-related inputs, such as pseudo-static macro configuration inputs.
// - impl_out_t:  Implementation-related outputs. This model only supports driving static values.
// - ImplOutSim:  Static output assumed by `impl_out_t` in behavioral simulation.
//
// Additional ports:
// - `impl_i`:  Implementation-related inputs
// - `impl_o`:  Implementation-related outputs

module tc_sram_impl #(
  parameter int unsigned NumWords     = 32'd1024, // Number of Words in data array
  parameter int unsigned DataWidth    = 32'd128,  // Data signal width
  parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte
  parameter int unsigned NumPorts     = 32'd2,    // Number of read and write ports
  parameter int unsigned Latency      = 32'd1,    // Latency when the read data is available
  parameter              SimInit      = "none",   // Simulation initialization
  parameter bit          PrintSimCfg  = 1'b0,     // Print configuration
  parameter              ImplKey      = "none",   // Reference to specific implementation
  parameter type         impl_in_t    = logic,    // Type for implementation inputs
  parameter type         impl_out_t   = logic,    // Type for implementation outputs
  parameter impl_out_t   ImplOutSim   = 'X,       // Implementation output in simulation
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth, // ceil_div
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input  logic                 clk_i,      // Clock
  input  logic                 rst_ni,     // Asynchronous reset active low
  // implementation-related IO
  input  impl_in_t             impl_i,
  output impl_out_t            impl_o,
  // input ports
  input  logic  [NumPorts-1:0] req_i,      // request
  input  logic  [NumPorts-1:0] we_i,       // write enable
  input  addr_t [NumPorts-1:0] addr_i,     // request address
  input  data_t [NumPorts-1:0] wdata_i,    // write data
  input  be_t   [NumPorts-1:0] be_i,       // write byte enable
  // output ports
  output data_t [NumPorts-1:0] rdata_o     // read data
);

  // We drive a static value for `impl_o` in behavioral simulation.
  assign impl_o = ImplOutSim;

  tc_sram #(
  .NumWords     ( NumWords    ),
  .DataWidth    ( DataWidth   ),
  .ByteWidth    ( ByteWidth   ),
  .NumPorts     ( NumPorts    ),
  .Latency      ( Latency     ),
  .SimInit      ( SimInit     ),
  .PrintSimCfg  ( PrintSimCfg ),
  .ImplKey      ( ImplKey     )
  ) i_tc_sram (
    .clk_i,
    .rst_ni,
    .req_i,
    .we_i,
    .addr_i,
    .wdata_i,
    .be_i,
    .rdata_o
  );

endmodule
