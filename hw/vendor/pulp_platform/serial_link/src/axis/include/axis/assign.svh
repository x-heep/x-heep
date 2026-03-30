// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Noah Huetter <huettern@iis.ee.ethz.ch>
//  - Nils Wistoff <nwistoff@iis.ee.ethz.ch>

// Macros to define AXI stream Channel and Request/Response Structs

`ifndef AXIS_ASSIGN_SVH_
`define AXIS_ASSIGN_SVH_

////////////////////////////////////////////////////////////////////////////////////////////////////
// Internal implementation for assigning one stream structs or interface to another struct or
// interface.  The path to the signals on each side is defined by the `__sep*` arguments.  The
// `__opt_as` argument allows to use this standalne (with `__opt_as = assign`) or in assignments
// inside processes (with `__opt_as` void).
`define __AXIS_TO_S(__opt_as, __lhs, __lhs_sep, __rhs, __rhs_sep)     \
  __opt_as __lhs``__lhs_sep``data   = __rhs``__rhs_sep``data;       \
  __opt_as __lhs``__lhs_sep``strb   = __rhs``__rhs_sep``strb;       \
  __opt_as __lhs``__lhs_sep``keep   = __rhs``__rhs_sep``keep;       \
  __opt_as __lhs``__lhs_sep``last   = __rhs``__rhs_sep``last;       \
  __opt_as __lhs``__lhs_sep``id     = __rhs``__rhs_sep``id;         \
  __opt_as __lhs``__lhs_sep``user   = __rhs``__rhs_sep``user;       \
  __opt_as __lhs``__lhs_sep``dest   = __rhs``__rhs_sep``dest;
`define __AXIS_TO_REQ(__opt_as, __lhs, __lhs_sep, __rhs, __rhs_sep)  \
  `__AXIS_TO_S(__opt_as, __lhs.t, __lhs_sep, __rhs.t, __rhs_sep)  \
  __opt_as __lhs.tvalid = __rhs.tvalid;
`define __AXIS_TO_RESP(__opt_as, __lhs, __lhs_sep, __rhs, __rhs_sep) \
  __opt_as __lhs.tready = __rhs.tready;
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Assigning one AXI4S interface to another, as if you would do `assign slv = mst;`
//
`define AXIS_ASSIGN_S(dst, src)             \
  `__AXIS_TO_S(assign, dst.t, , src.t, )      \
  assign dst.tvalid  = src.tvalid;          \
  assign src.tready  = dst.tready;
`define AXIS_ASSIGN(dst, src) \
  `AXIS_ASSIGN_S(dst, src)
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Assigning a stream interface from channel or request/response structs outside a process.
`define AXIS_ASSIGN_FROM_S(axi_if, s_struct) `__AXIS_TO_S(assign, axi_if.t, , s_struct, .)
`define AXIS_ASSIGN_FROM_REQ(axi_if, req_struct) `__AXIS_TO_REQ(assign, axi_if, , req_struct, .)
`define AXIS_ASSIGN_FROM_RESP(axi_if, resp_struct) `__AXIS_TO_RESP(assign, axi_if, , resp_struct, .)
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Assigning channel or request/response structs from an interface outside a process.
`define AXIS_ASSIGN_TO_R(s_struct, axi_if) `__AXIS_TO_S(assign, s_struct, ., axi_if.t, )
`define AXIS_ASSIGN_TO_REQ(req_struct, axi_if) `__AXIS_TO_REQ(assign, req_struct, ., axi_if, )
`define AXIS_ASSIGN_TO_RESP(resp_struct, axi_if) `__AXIS_TO_RESP(assign, resp_struct, ., axi_if, )
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros for assigning flattened AXI ports to req/resp AXI structs
// Flat AXI ports are required by the Vivado IP Integrator. Vivado naming convention is followed.
`define AXI_ASSIGN_TO_FLAT(__name, __req, __rsp)        \
  assign __name``_awvalid  = __req.aw_valid;  \
  assign __name``_awid     = __req.aw.id;     \
  assign __name``_awaddr   = __req.aw.addr;   \
  assign __name``_awlen    = __req.aw.len;    \
  assign __name``_awsize   = __req.aw.size;   \
  assign __name``_awburst  = __req.aw.burst;  \
  assign __name``_awlock   = __req.aw.lock;   \
  assign __name``_awcache  = __req.aw.cache;  \
  assign __name``_awprot   = __req.aw.prot;   \
  assign __name``_awqos    = __req.aw.qos;    \
  assign __name``_awregion = __req.aw.region; \
  // assign __name``_awatop   = __req.aw.atop;   \
  assign __name``_awuser   = __req.aw.user;   \
                                              \
  assign __name``_wvalid   = __req.w_valid;   \
  assign __name``_wdata    = __req.w.data;    \
  assign __name``_wstrb    = __req.w.strb;    \
  assign __name``_wlast    = __req.w.last;    \
  assign __name``_wuser    = __req.w.user;    \
                                              \
  assign __name``_bready   = __req.b_ready;   \
                                              \
  assign __name``_arvalid  = __req.ar_valid;  \
  assign __name``_arid     = __req.ar.id;     \
  assign __name``_araddr   = __req.ar.addr;   \
  assign __name``_arlen    = __req.ar.len;    \
  assign __name``_arsize   = __req.ar.size;   \
  assign __name``_arburst  = __req.ar.burst;  \
  assign __name``_arlock   = __req.ar.lock;   \
  assign __name``_arcache  = __req.ar.cache;  \
  assign __name``_arprot   = __req.ar.prot;   \
  assign __name``_arqos    = __req.ar.qos;    \
  assign __name``_arregion = __req.ar.region; \
  assign __name``_aruser   = __req.ar.user;   \
                                              \
  assign __name``_rready   = __req.r_ready;   \
                                              \
  assign __rsp.aw_ready = __name``_awready;   \
  assign __rsp.ar_ready = __name``_arready;   \
  assign __rsp.w_ready  = __name``_wready;    \
                                              \
  assign __rsp.b_valid  = __name``_bvalid;    \
  assign __rsp.b.id     = __name``_bid;       \
  assign __rsp.b.resp   = __name``_bresp;     \
  assign __rsp.b.user   = __name``_buser;     \
                                              \
  assign __rsp.r_valid  = __name``_rvalid;    \
  assign __rsp.r.id     = __name``_rid;       \
  assign __rsp.r.data   = __name``_rdata;     \
  assign __rsp.r.resp   = __name``_rresp;     \
  assign __rsp.r.last   = __name``_rlast;     \
  assign __rsp.r.user   = __name``_ruser;
`define AXI_ASSIGN_FROM_FLAT(__req, __rsp, __name)      \
  assign __req.aw_valid  = __name``_awvalid;  \
  assign __req.aw.id     = __name``_awid;     \
  assign __req.aw.addr   = __name``_awaddr;   \
  assign __req.aw.len    = __name``_awlen;    \
  assign __req.aw.size   = __name``_awsize;   \
  assign __req.aw.burst  = __name``_awburst;  \
  assign __req.aw.lock   = __name``_awlock;   \
  assign __req.aw.cache  = __name``_awcache;  \
  assign __req.aw.prot   = __name``_awprot;   \
  assign __req.aw.qos    = __name``_awqos;    \
  assign __req.aw.region = __name``_awregion; \
  assign __req.aw.atop   = '0;                \
  assign __req.aw.user   = __name``_awuser;   \
                                              \
  assign __req.w_valid   = __name``_wvalid;   \
  assign __req.w.data    = __name``_wdata;    \
  assign __req.w.strb    = __name``_wstrb;    \
  assign __req.w.last    = __name``_wlast;    \
  assign __req.w.user    = __name``_wuser;    \
                                              \
  assign __req.b_ready   = __name``_bready;   \
                                              \
  assign __req.ar_valid  = __name``_arvalid;  \
  assign __req.ar.id     = __name``_arid;     \
  assign __req.ar.addr   = __name``_araddr;   \
  assign __req.ar.len    = __name``_arlen;    \
  assign __req.ar.size   = __name``_arsize;   \
  assign __req.ar.burst  = __name``_arburst;  \
  assign __req.ar.lock   = __name``_arlock;   \
  assign __req.ar.cache  = __name``_arcache;  \
  assign __req.ar.prot   = __name``_arprot;   \
  assign __req.ar.qos    = __name``_arqos;    \
  assign __req.ar.region = __name``_arregion; \
  assign __req.ar.user   = __name``_aruser;   \
                                              \
  assign __req.r_ready   = __name``_rready;   \
                                              \
  assign __name``_awready = __rsp.aw_ready;   \
  assign __name``_arready = __rsp.ar_ready;   \
  assign __name``_wready  = __rsp.w_ready;    \
                                              \
  assign __name``_bvalid  = __rsp.b_valid;    \
  assign __name``_bid     = __rsp.b.id;       \
  assign __name``_bresp   = __rsp.b.resp;     \
  assign __name``_buser   = __rsp.b.user;     \
                                              \
  assign __name``_rvalid  = __rsp.r_valid;    \
  assign __name``_rid     = __rsp.r.id;       \
  assign __name``_rdata   = __rsp.r.data;     \
  assign __name``_rresp   = __rsp.r.resp;     \
  assign __name``_rlast   = __rsp.r.last;     \
  assign __name``_ruser   = __rsp.r.user;
`define AXI_ASSIGN_TO_FLAT_ATOP(__name, __req, __rsp)        \
  assign __name``_awvalid  = __req.aw_valid;  \
  assign __name``_awid     = __req.aw.id;     \
  assign __name``_awaddr   = __req.aw.addr;   \
  assign __name``_awlen    = __req.aw.len;    \
  assign __name``_awsize   = __req.aw.size;   \
  assign __name``_awburst  = __req.aw.burst;  \
  assign __name``_awlock   = __req.aw.lock;   \
  assign __name``_awcache  = __req.aw.cache;  \
  assign __name``_awprot   = __req.aw.prot;   \
  assign __name``_awqos    = __req.aw.qos;    \
  assign __name``_awregion = __req.aw.region; \
  assign __name``_awatop   = __req.aw.atop;   \
  assign __name``_awuser   = __req.aw.user;   \
                                              \
  assign __name``_wvalid   = __req.w_valid;   \
  assign __name``_wdata    = __req.w.data;    \
  assign __name``_wstrb    = __req.w.strb;    \
  assign __name``_wlast    = __req.w.last;    \
  assign __name``_wuser    = __req.w.user;    \
                                              \
  assign __name``_bready   = __req.b_ready;   \
                                              \
  assign __name``_arvalid  = __req.ar_valid;  \
  assign __name``_arid     = __req.ar.id;     \
  assign __name``_araddr   = __req.ar.addr;   \
  assign __name``_arlen    = __req.ar.len;    \
  assign __name``_arsize   = __req.ar.size;   \
  assign __name``_arburst  = __req.ar.burst;  \
  assign __name``_arlock   = __req.ar.lock;   \
  assign __name``_arcache  = __req.ar.cache;  \
  assign __name``_arprot   = __req.ar.prot;   \
  assign __name``_arqos    = __req.ar.qos;    \
  assign __name``_arregion = __req.ar.region; \
  assign __name``_aruser   = __req.ar.user;   \
                                              \
  assign __name``_rready   = __req.r_ready;   \
                                              \
  assign __rsp.aw_ready = __name``_awready;   \
  assign __rsp.ar_ready = __name``_arready;   \
  assign __rsp.w_ready  = __name``_wready;    \
                                              \
  assign __rsp.b_valid  = __name``_bvalid;    \
  assign __rsp.b.id     = __name``_bid;       \
  assign __rsp.b.resp   = __name``_bresp;     \
  assign __rsp.b.user   = __name``_buser;     \
                                              \
  assign __rsp.r_valid  = __name``_rvalid;    \
  assign __rsp.r.id     = __name``_rid;       \
  assign __rsp.r.data   = __name``_rdata;     \
  assign __rsp.r.resp   = __name``_rresp;     \
  assign __rsp.r.last   = __name``_rlast;     \
  assign __rsp.r.user   = __name``_ruser;
`define AXI_ASSIGN_FROM_FLAT_ATOP(__req, __rsp, __name)      \
  assign __req.aw_valid  = __name``_awvalid;  \
  assign __req.aw.id     = __name``_awid;     \
  assign __req.aw.addr   = __name``_awaddr;   \
  assign __req.aw.len    = __name``_awlen;    \
  assign __req.aw.size   = __name``_awsize;   \
  assign __req.aw.burst  = __name``_awburst;  \
  assign __req.aw.lock   = __name``_awlock;   \
  assign __req.aw.cache  = __name``_awcache;  \
  assign __req.aw.prot   = __name``_awprot;   \
  assign __req.aw.qos    = __name``_awqos;    \
  assign __req.aw.region = __name``_awregion; \
  assign __req.aw.atop   = __name``_awatop; \
  assign __req.aw.user   = __name``_awuser;   \
                                              \
  assign __req.w_valid   = __name``_wvalid;   \
  assign __req.w.data    = __name``_wdata;    \
  assign __req.w.strb    = __name``_wstrb;    \
  assign __req.w.last    = __name``_wlast;    \
  assign __req.w.user    = __name``_wuser;    \
                                              \
  assign __req.b_ready   = __name``_bready;   \
                                              \
  assign __req.ar_valid  = __name``_arvalid;  \
  assign __req.ar.id     = __name``_arid;     \
  assign __req.ar.addr   = __name``_araddr;   \
  assign __req.ar.len    = __name``_arlen;    \
  assign __req.ar.size   = __name``_arsize;   \
  assign __req.ar.burst  = __name``_arburst;  \
  assign __req.ar.lock   = __name``_arlock;   \
  assign __req.ar.cache  = __name``_arcache;  \
  assign __req.ar.prot   = __name``_arprot;   \
  assign __req.ar.qos    = __name``_arqos;    \
  assign __req.ar.region = __name``_arregion; \
  assign __req.ar.user   = __name``_aruser;   \
                                              \
  assign __req.r_ready   = __name``_rready;   \
                                              \
  assign __name``_awready = __rsp.aw_ready;   \
  assign __name``_arready = __rsp.ar_ready;   \
  assign __name``_wready  = __rsp.w_ready;    \
                                              \
  assign __name``_bvalid  = __rsp.b_valid;    \
  assign __name``_bid     = __rsp.b.id;       \
  assign __name``_bresp   = __rsp.b.resp;     \
  assign __name``_buser   = __rsp.b.user;     \
                                              \
  assign __name``_rvalid  = __rsp.r_valid;    \
  assign __name``_rid     = __rsp.r.id;       \
  assign __name``_rdata   = __rsp.r.data;     \
  assign __name``_rresp   = __rsp.r.resp;     \
  assign __name``_rlast   = __rsp.r.last;     \
  assign __name``_ruser   = __rsp.r.user;
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros for assigning flattened AXI stream ports to req/resp AXI structs
// Flat AXI ports are required by the Vivado IP Integrator. Vivado naming convention is followed.
`define AXIS_ASSIGN_TO_FLAT(__name, __req, __rsp)        \
  assign __name``_tvalid   = __req.tvalid;    \
  assign __name``_tdata    = __req.t.data;    \
  assign __name``_tstrb    = __req.t.strb;    \
  assign __name``_tkeep    = __req.t.keep;    \
  assign __name``_tid      = __req.t.id;      \
  assign __name``_tlast    = __req.t.last;    \
  assign __name``_tuser    = __req.t.user;    \
  assign __name``_tdest    = __req.t.dest;    \
  assign __rsp.tready     = __name``_tready;
`define AXIS_ASSIGN_FROM_FLAT(__req, __rsp, __name)      \
  assign __req.tvalid   = __name``_tvalid;    \
  assign __req.t.data    = __name``_tdata;    \
  assign __req.t.strb    = __name``_tstrb;    \
  assign __req.t.keep    = __name``_tkeep;    \
  assign __req.t.id      = __name``_tid;      \
  assign __req.t.last    = __name``_tlast;    \
  assign __req.t.user    = __name``_tuser;    \
  assign __req.t.dest    = __name``_tdest;    \
  assign __name``_tready = __rsp.tready;
////////////////////////////////////////////////////////////////////////////////////////////////////


`endif
