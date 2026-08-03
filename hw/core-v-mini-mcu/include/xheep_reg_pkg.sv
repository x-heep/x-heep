/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the “License”); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 *
 * Description: REG package, contains common system definitions.
 *
 */

package xheep_reg_pkg;

  typedef struct packed {
    logic        valid;
    logic        write;
    logic [3:0]  wstrb;
    logic [31:0] addr;
    logic [31:0] wdata;
  } xheep_reg_req_t;

  typedef struct packed {
    logic        error;
    logic        ready;
    logic [31:0] rdata;
  } xheep_reg_rsp_t;

endpackage
