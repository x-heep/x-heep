// Copyright (c) 2020 OpenHW Group
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0

// Includes to print info about the RVFI output
// Contributors: Davide Schiavone <davide@openhwgroup.org>
//               Halfdan Bechmann <halfdan.bechmann@silabs.com>

package cv32e40x_rvfi_pkg;
  import cv32e40x_pkg::*;

  parameter STAGE_IF      = 0;
  parameter STAGE_ID      = 1;
  parameter STAGE_EX      = 2;
  parameter STAGE_WB      = 3;
  parameter STAGE_WB_PAST = 4;

  parameter NMEM = 128;   // Maximum number of memory transactions per instruction is currently 13 when ZC_EXT=1

  typedef enum logic [1:0] { // Memory error types
    MEM_ERR_IO_ALIGN          = 2'h0,
    MEM_ERR_ATOMIC            = 2'h1,
    MEM_ERR_PMP               = 2'h2
  } mem_err_t;

  typedef struct packed { // Autonomously updated CSRs
    logic [31:0] mcycle;
    logic [31:0] mcycleh;
    logic [31:0] cycle;
    logic [31:0] cycleh;
    logic [31:0] mip;
    logic        nmip;
  } rvfi_auto_csr_map_t;

  typedef struct packed {
    logic        [31:0] jvt;
    logic        [31:0] mstatus;
    logic        [31:0] misa;
    logic        [31:0] mie;
    logic        [31:0] mtvec;
    logic        [31:0] mstatush;
    logic        [31:0] mtvt;
    logic        [31:0] mcountinhibit;
    logic [31:0] [31:0] mhpmevent;
    logic        [31:0] mscratch;
    logic        [31:0] mepc;
    logic        [31:0] mcause;
    logic        [31:0] mtval;
    logic        [31:0] mip;
    logic        [31:0] mnxti;
    logic        [31:0] mintstatus;
    logic        [31:0] mintthresh;
    logic        [31:0] mscratchcsw;
    logic        [31:0] mscratchcswl;
    logic        [31:0] tselect;
    logic [ 3:0] [31:0] tdata;
    logic        [31:0] tinfo;
    logic        [31:0] tcontrol;
    logic        [31:0] dcsr;
    logic        [31:0] dpc;
    logic [ 1:0] [31:0] dscratch;
    logic        [31:0] mcycle;
    logic        [31:0] minstret;
    logic [31:0] [31:0] mhpmcounter;
    logic        [31:0] mcycleh;
    logic        [31:0] minstreth;
    logic [31:0] [31:0] mhpmcounterh;
    logic        [31:0] cycle;
    logic        [31:0] instret;
    logic [31:0] [31:0] hpmcounter;
    logic        [31:0] cycleh;
    logic        [31:0] instreth;
    logic [31:0] [31:0] hpmcounterh;
    logic        [31:0] mvendorid;
    logic        [31:0] marchid;
    logic        [31:0] mimpid;
    logic        [31:0] mhartid;
    logic        [31:0] mcounteren;
    logic [ 3:0] [31:0] pmpcfg;
    logic [15:0] [31:0] pmpaddr;
    logic        [31:0] mseccfg;
    logic        [31:0] mseccfgh;
    logic        [31:0] mconfigptr;
    logic        [31:0] menvcfg;
    logic        [31:0] menvcfgh;
    logic        [31:0] cpuctrl;
    logic        [31:0] secureseed0;
    logic        [31:0] secureseed1;
    logic        [31:0] secureseed2;
    logic        [31:0] mstateen0;
    logic        [31:0] mstateen1;
    logic        [31:0] mstateen2;
    logic        [31:0] mstateen3;
    logic        [31:0] mstateen0h;
    logic        [31:0] mstateen1h;
    logic        [31:0] mstateen2h;
    logic        [31:0] mstateen3h;

  } rvfi_csr_map_t;

  typedef struct packed {
    logic [10:0] cause;
    logic        interrupt;
    logic        exception;
    logic        intr;
  } rvfi_intr_t;

  typedef struct packed {
    logic        clicptr;
    logic [1:0]  cause_type;
    logic [2:0]  debug_cause;
    logic [5:0]  exception_cause;
    logic        debug;
    logic        exception;
    logic        trap;
  } rvfi_trap_t;

  typedef struct packed {
    obi_inst_req_t  req_payload;
    inst_resp_t     resp_payload;
  } rvfi_obi_instr_t;

endpackage // cv32e40x_rvfi_pkg

