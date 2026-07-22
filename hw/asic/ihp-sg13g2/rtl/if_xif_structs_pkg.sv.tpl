<%
  xif = xheep.xif()
  print(type(xif))
%>

package if_xif_structs_pkg;
% if xif:
  parameter int unsigned X_NUM_RS    = ${xif.x_num_rs};
  parameter int unsigned X_ID_WIDTH  = ${xif.x_id_width};
  parameter int unsigned X_MEM_WIDTH = ${xif.x_mem_width};
  parameter int unsigned X_RFR_WIDTH = ${xif.x_rfr_width};
  parameter int unsigned X_RFW_WIDTH = ${xif.x_rfw_width};
  parameter logic [31:0] X_MISA      = ${xif.x_misa};
  parameter logic [ 1:0] X_ECS_XS    = ${xif.x_ecs_xs};
% else:
  parameter int unsigned X_NUM_RS        =  2;
  parameter int unsigned X_ID_WIDTH      =  4;
  parameter int unsigned X_MEM_WIDTH     =  32;
  parameter int unsigned X_RFR_WIDTH     =  32;
  parameter int unsigned X_RFW_WIDTH     =  32;
  parameter logic [31:0] X_MISA          =  '0;
  parameter logic [ 1:0] X_ECS_XS        =  '0;
% endif

  localparam int XLEN = 32;

  typedef struct packed {
    logic [          15:0] instr;
    logic [           1:0] mode;
    logic [X_ID_WIDTH-1:0] id;
  } x_compressed_req_t;

  typedef struct packed {
    logic [31:0] instr;
    logic        accept;
  } x_compressed_resp_t;

  typedef struct packed {
    logic [          31:0]                  instr;
    logic [           1:0]                  mode;
    logic [X_ID_WIDTH-1:0]                  id;
    logic [X_NUM_RS  -1:0][X_RFR_WIDTH-1:0] rs;
    logic [X_NUM_RS  -1:0]                  rs_valid;
    logic [           5:0]                  ecs;
    logic                                   ecs_valid;
  } x_issue_req_t;

  typedef struct packed {
    logic       accept;
    logic       writeback;
    logic       dualwrite;
    logic [2:0] dualread;
    logic       loadstore;
    logic       ecswrite ;
    logic       exc;
  } x_issue_resp_t;

  typedef struct packed {
    logic [X_ID_WIDTH-1:0] id;
    logic                  commit_kill;
  } x_commit_t;

  typedef struct packed {
    logic [X_ID_WIDTH   -1:0] id;
    logic [             31:0] addr;
    logic [              1:0] mode;
    logic                     we;
    logic [              2:0] size;
    logic [X_MEM_WIDTH/8-1:0] be;
    logic [              1:0] attr;
    logic [X_MEM_WIDTH  -1:0] wdata;
    logic                     last;
    logic                     spec;
  } x_mem_req_t;

  typedef struct packed {
    logic       exc;
    logic [5:0] exccode;
    logic       dbg;
  } x_mem_resp_t;

  typedef struct packed {
    logic [X_ID_WIDTH -1:0] id;
    logic [X_MEM_WIDTH-1:0] rdata;
    logic                   err;
    logic                   dbg;
  } x_mem_result_t;

  typedef struct packed {
    logic [X_ID_WIDTH      -1:0] id;
    logic [X_RFW_WIDTH     -1:0] data;
    logic [                 4:0] rd;
    logic [X_RFW_WIDTH/XLEN-1:0] we;
    logic [                 5:0] ecsdata;
    logic [                 2:0] ecswe;
    logic                        exc;
    logic [                 5:0] exccode;
    logic                        err;
    logic                        dbg;
  } x_result_t;
endpackage
