// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors    :    Michael Schaffner (schaffner@iis.ee.ethz.ch)               //
//                 Andreas Traber    (atraber@iis.ee.ethz.ch)                 //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                 Oivind Ekelund -   oivind.ekelund@silabs.com               //
//                                                                            //
// Description:    RTL assertions for the div module                      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40x_div_sva
  import uvm_pkg::*;
  (
   input logic  clk,
   input logic  rst_n,
   
   input logic  valid_i,
   input logic  ready_o,

   input logic  ready_i,
   input logic  valid_o,

   input logic  data_ind_timing_i
);
  
  logic [5:0] cycle_count;

  // Division cycle counter
  always_ff @(posedge clk) begin
    if (valid_i && $past(ready_o)) begin
      // Division accpted, reset counter
      cycle_count <= '0;
    end
    else begin
      cycle_count <= cycle_count + 1'b1;
    end
  end

  // Assert that valid_o is set in the 34th cycle 
  // cycle_count==33 in the 34th cycle because the counter is reset in the cycle after division is accepted.
  //TODO: lowThis only applies to the 40S, data_ind_timing_i only exists there.
  //      Keep commented until 40S fork, and then delete from 40X
  /*
  a_data_ind_timing :
    assert property (@(posedge clk) disable iff (!rst_n)
                     ($rose(valid_o) && data_ind_timing_i |-> cycle_count == 33))
      else `uvm_error("div", "Data independent cycle count failed")
  */
  a_ready_o :  
    assert property (@(posedge clk) disable iff (!rst_n)
                     (valid_o && ready_i |-> ready_o))
      else `uvm_error("div", "ready_o not set in the same cycle as output is accepted")

  a_valid_o :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (valid_o |-> valid_i))
      else `uvm_error("div", "valid_o=1 when valid_i=0")
    
endmodule // cv32e40x_div_sva

