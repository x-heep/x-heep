/*
 Copyright 2020 Silicon Labs, Inc.
  
 This file, and derivatives thereof are licensed under the
 Solderpad License, Version 2.0 (the "License");
 Use of this file means you agree to the terms and conditions
 of the license and are in full compliance with the License.
 You may obtain a copy of the License at
  
 https://solderpad.org/licenses/SHL-2.0/
  
 Unless required by applicable law or agreed to in writing, software
 and hardware implementations thereof
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


// OBI interface definition for instruction and data
// The two parameters set the types for payload 
// as these are different for instruction and data
// 
// The 'c' in the interface names means 'Compressed'
// since this interface is a subset of the full OBI spec.
interface if_c_obi import cv32e40x_pkg::*;
#(
    parameter type REQ_TYPE  = obi_inst_req_t,
    parameter type RESP_TYPE = obi_inst_resp_t
);
    // A channel signals
    obi_req_t                  s_req;
    obi_gnt_t                  s_gnt;
    REQ_TYPE                   req_payload;
    // R channel signals
    obi_rvalid_t               s_rvalid;
    RESP_TYPE                  resp_payload;
  
    modport master
       (
       output s_req, req_payload,
       input  s_gnt, s_rvalid, resp_payload
       );
  
    modport monitor
       (
       input  s_req, req_payload,
              s_gnt, s_rvalid, resp_payload
       );

endinterface : if_c_obi
