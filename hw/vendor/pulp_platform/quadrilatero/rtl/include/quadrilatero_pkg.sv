// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Saverio Nasturzio
package quadrilatero_pkg;

  parameter int unsigned N_REGS                 =   8;
  parameter int unsigned DATA_WIDTH             =  32;
  parameter int unsigned BUS_WIDTH              = 128;
  parameter int unsigned MESH_WIDTH             =   4;
  parameter int unsigned NUM_EXEC_UNITS         =   3;  // change me to add units
  parameter int unsigned MAX_NUM_READ_OPERANDS  =   3;
  parameter int unsigned MAX_NUM_WRITE_OPERANDS =   1;
  parameter int unsigned READ_PORTS             =   4;  // we'll have fewer write ports so we take the maximum one which is the number of READ PORTS for the rw_queue_t
  parameter int unsigned WRITE_PORTS            =   3;  //
  parameter int unsigned RF_READ_PORTS          =   4;
  parameter int unsigned RF_WRITE_PORTS         =   3;

  localparam int unsigned N_ROWS = MESH_WIDTH             ;
  localparam int unsigned RLEN   = DATA_WIDTH * MESH_WIDTH;


  typedef enum logic [2:0] {
    SIZE_32 = 1,  // 32-bit operation
    SIZE_16 = 2,  // 16-bit operation
    SIZE_8  = 4   // 8-bit operation
  } datatype_t;

  typedef struct packed {
    logic      is_float;
    datatype_t datatype;
  } sa_ctrl_t;

  typedef struct packed {
    logic [$clog2(N_REGS)-1:0]      data_reg  ;
    logic [$clog2(N_REGS)-1:0]      acc_reg   ;
    logic [$clog2(N_REGS)-1:0]      weight_reg;
    logic [xif_pkg::X_ID_WIDTH-1:0] id        ;
    sa_ctrl_t                       sa_ctrl   ;
  } sa_instr_t;

  typedef struct packed {
    logic [32-1:0]                  stride;
    logic [32-1:0]                  addr;
    logic [$clog2(N_REGS)-1:0]      operand_reg;
    logic [xif_pkg::X_ID_WIDTH-1:0] id;
    logic                           is_store;
  } lsu_instr_t;

  typedef struct packed {
    logic [31:0] n_col_bytes;
    logic [31:0] n_rows;
  } lsu_conf_t;

  typedef struct packed {
    logic [xif_pkg::X_ID_WIDTH-1:0] id;  
    logic                           rvalid;  
    logic                           wready;     
  } rw_queue_t;

  localparam int unsigned WR_PORT = (WRITE_PORTS > 1) ? $clog2(WRITE_PORTS) : 1;
  localparam int unsigned RD_PORT = (READ_PORTS  > 1) ? $clog2(READ_PORTS ) : 1;
  typedef enum logic [RD_PORT-1:0] {
    SYSTOLIC_ARRAY_W,
    SYSTOLIC_ARRAY_D,
    SYSTOLIC_ARRAY_A,
    LSU_R
  } read_ports_t;

  typedef enum logic [WR_PORT-1:0] {
    SYSTOLIC_ARRAY,
    LSU_W,
    RF_W
  } write_ports_t;

  // Int formats
  typedef enum logic [$clog2(NUM_EXEC_UNITS)-1:0] {
    FU_SYSTOLIC_ARRAY = 0,
    FU_LSU,
    FU_RF
    // add new units here
  } execution_units_t;


  localparam int unsigned WR_OPS = (MAX_NUM_WRITE_OPERANDS > 1) ? $clog2(MAX_NUM_WRITE_OPERANDS) : 1;
  localparam int unsigned RD_OPS = (MAX_NUM_READ_OPERANDS  > 1) ? $clog2(MAX_NUM_READ_OPERANDS ) : 1;
  typedef struct packed {
    logic [RD_OPS-1:0] n_read_ports;
    logic [WR_OPS-1:0] n_write_ports;
    // Where within read_ports the functional unit starts
    logic [$clog2(READ_PORTS):0] base_offset_read;
    logic [$clog2(READ_PORTS):0] base_offset_write;
  } fu_ports_info;

  // Follow execution_units_t order
  parameter fu_ports_info FU_INFO[NUM_EXEC_UNITS] = '{
      '{  // SYSTOLIC_ARRAY
          n_read_ports: 3,
          n_write_ports: 1,
          base_offset_read: 0,
          base_offset_write: 0
      },
      '{  // LSU_W
          n_read_ports: 1,
          n_write_ports: 1,
          base_offset_read: 3,  // forth element in read_ports_t
          base_offset_write: 1
      },
      '{  // RF_W
          n_read_ports: 0,
          n_write_ports: 1,
          base_offset_read: 4,
          base_offset_write: 2
      }
  };



endpackage
