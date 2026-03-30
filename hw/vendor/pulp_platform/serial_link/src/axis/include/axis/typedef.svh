// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Noah Huetter <huettern@iis.ee.ethz.ch>

// Macros to define AXI stream Channel and Request/Response Structs

`ifndef AXIS_TYPEDEF_SVH_
`define AXIS_TYPEDEF_SVH_

////////////////////////////////////////////////////////////////////////////////////////////////////
// AXI4-Stream Channel and Request/Response Structs
`define AXIS_TYPEDEF_S_T(s_chan_t, tdata_t, tstrb_t, tkeep_t, tlast_t, tid_t, tdest_t, tuser_t)  \
  typedef struct packed {  \
    tdata_t data;          \
    tstrb_t strb;          \
    tkeep_t keep;          \
    tlast_t last;          \
    tid_t id;              \
    tdest_t dest;          \
    tuser_t user;          \
  } s_chan_t;
`define AXIS_TYPEDEF_REQ_T(req_stream_t, s_chan_t)  \
  typedef struct packed {        \
    s_chan_t            t;       \
    logic               tvalid;  \
  } req_stream_t;
`define AXIS_TYPEDEF_RSP_T(resp_stream_t, tready_t)  \
  typedef struct packed {                             \
    tready_t             tready;                      \
  } resp_stream_t;
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// All AXI4-Stream Channels and Request/Response Structs in One Macro
//
// This can be used whenever the user is not interested in "precise" control of the naming of the
// individual channels.
//
// Usage Example:
// `AXIS_TYPEDEF_ALL(axi_stream, tdata_t, tstrb_t, tkeep_t, tlast_t, tid_t, tdest_t, tuser_t, tready_t)
//
// This defines `axi_stream_req_t` and `axi_stream_resp_t` request/response structs
`define AXIS_TYPEDEF_ALL(__name, __tdata_t, __tstrb_t, __tkeep_t, __tlast_t, __tid_t, __tdest_t, __tuser_t, __tready_t) \
  `AXIS_TYPEDEF_S_T(__name``_s_chan_t, __tdata_t, __tstrb_t, __tkeep_t, __tlast_t, __tid_t, __tdest_t, __tuser_t)  \
  `AXIS_TYPEDEF_REQ_T(__name``_req_t,__name``_s_chan_t)  \
  `AXIS_TYPEDEF_RSP_T(__name``_rsp_t, __tready_t)
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Flat AXI ports
`define AXI_FLAT_PORT_MASTER(__name, __aw, __dw, __iw, __uw)  \
  output logic [__iw-1:0]   __name``_awid,     \
  output logic [__aw-1:0]   __name``_awaddr,   \
  output axi_pkg::len_t     __name``_awlen,    \
  output axi_pkg::size_t    __name``_awsize,   \
  output axi_pkg::burst_t   __name``_awburst,  \
  output logic              __name``_awlock,   \
  output axi_pkg::cache_t   __name``_awcache,  \
  output axi_pkg::prot_t    __name``_awprot,   \
  output axi_pkg::qos_t     __name``_awqos,    \
  output axi_pkg::region_t  __name``_awregion, \
  // output axi_pkg::atop_t    __name``_awatop,   \
  output logic [__uw-1:0]   __name``_awuser,   \
  output logic [__dw-1:0]   __name``_wdata,    \
  output logic [__dw/8-1:0] __name``_wstrb,    \
  output logic              __name``_wlast,    \
  output logic [__uw-1:0]   __name``_wuser,    \
  input  logic [__iw-1:0]   __name``_bid,      \
  input  axi_pkg::resp_t    __name``_bresp,    \
  input  logic [__uw-1:0]   __name``_buser,    \
  output logic [__iw-1:0]   __name``_arid,     \
  output logic [__aw-1:0]   __name``_araddr,   \
  output axi_pkg::len_t     __name``_arlen,    \
  output axi_pkg::size_t    __name``_arsize,   \
  output axi_pkg::burst_t   __name``_arburst,  \
  output logic              __name``_arlock,   \
  output axi_pkg::cache_t   __name``_arcache,  \
  output axi_pkg::prot_t    __name``_arprot,   \
  output axi_pkg::qos_t     __name``_arqos,    \
  output axi_pkg::region_t  __name``_arregion, \
  output logic [__uw-1:0]   __name``_aruser,   \
  input  logic [__iw-1:0]   __name``_rid,      \
  input  logic [__dw-1:0]   __name``_rdata,    \
  input  axi_pkg::resp_t    __name``_rresp,    \
  input  logic              __name``_rlast,    \
  input  logic [__uw-1:0]   __name``_ruser,    \
  output logic              __name``_awvalid,  \
  output logic              __name``_wvalid,   \
  output logic              __name``_bready,   \
  output logic              __name``_arvalid,  \
  output logic              __name``_rready,   \
  input  logic              __name``_awready,  \
  input  logic              __name``_arready,  \
  input  logic              __name``_wready,   \
  input  logic              __name``_bvalid,   \
  input  logic              __name``_rvalid
`define AXI_FLAT_PORT_SLAVE(__name, __aw, __dw, __iw, __uw)  \
  input  logic [__iw-1:0]    __name``_awid,     \
  input  logic [__aw-1:0]    __name``_awaddr,   \
  input  axi_pkg::len_t      __name``_awlen,    \
  input  axi_pkg::size_t     __name``_awsize,   \
  input  axi_pkg::burst_t    __name``_awburst,  \
  input  logic               __name``_awlock,   \
  input  axi_pkg::cache_t    __name``_awcache,  \
  input  axi_pkg::prot_t     __name``_awprot,   \
  input  axi_pkg::qos_t      __name``_awqos,    \
  input  axi_pkg::region_t   __name``_awregion, \
  // input  axi_pkg::atop_t     __name``_awatop,   \
  input  logic [__uw-1:0]    __name``_awuser,   \
  input  logic [__dw-1:0]    __name``_wdata,    \
  input  logic [__dw/8-1:0]  __name``_wstrb,    \
  input  logic               __name``_wlast,    \
  input  logic [__uw-1:0]    __name``_wuser,    \
  output logic [__iw-1:0]  __name``_bid,      \
  output axi_pkg::resp_t   __name``_bresp,    \
  output logic [__uw-1:0]  __name``_buser,    \
  input  logic [__iw-1:0]    __name``_arid,     \
  input  logic [__aw-1:0]    __name``_araddr,   \
  input  axi_pkg::len_t      __name``_arlen,    \
  input  axi_pkg::size_t     __name``_arsize,   \
  input  axi_pkg::burst_t    __name``_arburst,  \
  input  logic               __name``_arlock,   \
  input  axi_pkg::cache_t    __name``_arcache,  \
  input  axi_pkg::prot_t     __name``_arprot,   \
  input  axi_pkg::qos_t      __name``_arqos,    \
  input  axi_pkg::region_t   __name``_arregion, \
  input  logic [__uw-1:0]    __name``_aruser,   \
  output logic [__iw-1:0]  __name``_rid,      \
  output logic [__dw-1:0]  __name``_rdata,    \
  output axi_pkg::resp_t   __name``_rresp,    \
  output logic             __name``_rlast,    \
  output logic [__uw-1:0]  __name``_ruser,    \
  input  logic               __name``_awvalid,  \
  input  logic               __name``_wvalid,   \
  input  logic               __name``_bready,   \
  input  logic               __name``_arvalid,  \
  input  logic               __name``_rready,   \
  output logic             __name``_awready,  \
  output logic             __name``_arready,  \
  output logic             __name``_wready,   \
  output logic             __name``_bvalid,   \
  output logic             __name``_rvalid
`define AXI_FLAT_PORT_MASTER_ATOP(__name, __aw, __dw, __iw, __uw)  \
  output logic [__iw-1:0]   __name``_awid,     \
  output logic [__aw-1:0]   __name``_awaddr,   \
  output axi_pkg::len_t     __name``_awlen,    \
  output axi_pkg::size_t    __name``_awsize,   \
  output axi_pkg::burst_t   __name``_awburst,  \
  output logic              __name``_awlock,   \
  output axi_pkg::cache_t   __name``_awcache,  \
  output axi_pkg::prot_t    __name``_awprot,   \
  output axi_pkg::qos_t     __name``_awqos,    \
  output axi_pkg::region_t  __name``_awregion, \
  output axi_pkg::atop_t    __name``_awatop,   \
  output logic [__uw-1:0]   __name``_awuser,   \
  output logic [__dw-1:0]   __name``_wdata,    \
  output logic [__dw/8-1:0] __name``_wstrb,    \
  output logic              __name``_wlast,    \
  output logic [__uw-1:0]   __name``_wuser,    \
  input  logic [__iw-1:0]   __name``_bid,      \
  input  axi_pkg::resp_t    __name``_bresp,    \
  input  logic [__uw-1:0]   __name``_buser,    \
  output logic [__iw-1:0]   __name``_arid,     \
  output logic [__aw-1:0]   __name``_araddr,   \
  output axi_pkg::len_t     __name``_arlen,    \
  output axi_pkg::size_t    __name``_arsize,   \
  output axi_pkg::burst_t   __name``_arburst,  \
  output logic              __name``_arlock,   \
  output axi_pkg::cache_t   __name``_arcache,  \
  output axi_pkg::prot_t    __name``_arprot,   \
  output axi_pkg::qos_t     __name``_arqos,    \
  output axi_pkg::region_t  __name``_arregion, \
  output logic [__uw-1:0]   __name``_aruser,   \
  input  logic [__iw-1:0]   __name``_rid,      \
  input  logic [__dw-1:0]   __name``_rdata,    \
  input  axi_pkg::resp_t    __name``_rresp,    \
  input  logic              __name``_rlast,    \
  input  logic [__uw-1:0]   __name``_ruser,    \
  output logic              __name``_awvalid,  \
  output logic              __name``_wvalid,   \
  output logic              __name``_bready,   \
  output logic              __name``_arvalid,  \
  output logic              __name``_rready,   \
  input  logic              __name``_awready,  \
  input  logic              __name``_arready,  \
  input  logic              __name``_wready,   \
  input  logic              __name``_bvalid,   \
  input  logic              __name``_rvalid
`define AXI_FLAT_PORT_SLAVE_ATOP(__name, __aw, __dw, __iw, __uw)  \
  input  logic [__iw-1:0]    __name``_awid,     \
  input  logic [__aw-1:0]    __name``_awaddr,   \
  input  axi_pkg::len_t      __name``_awlen,    \
  input  axi_pkg::size_t     __name``_awsize,   \
  input  axi_pkg::burst_t    __name``_awburst,  \
  input  logic               __name``_awlock,   \
  input  axi_pkg::cache_t    __name``_awcache,  \
  input  axi_pkg::prot_t     __name``_awprot,   \
  input  axi_pkg::qos_t      __name``_awqos,    \
  input  axi_pkg::region_t   __name``_awregion, \
  input  axi_pkg::atop_t     __name``_awatop,   \
  input  logic [__uw-1:0]    __name``_awuser,   \
  input  logic [__dw-1:0]    __name``_wdata,    \
  input  logic [__dw/8-1:0]  __name``_wstrb,    \
  input  logic               __name``_wlast,    \
  input  logic [__uw-1:0]    __name``_wuser,    \
  output logic [__iw-1:0]  __name``_bid,      \
  output axi_pkg::resp_t   __name``_bresp,    \
  output logic [__uw-1:0]  __name``_buser,    \
  input  logic [__iw-1:0]    __name``_arid,     \
  input  logic [__aw-1:0]    __name``_araddr,   \
  input  axi_pkg::len_t      __name``_arlen,    \
  input  axi_pkg::size_t     __name``_arsize,   \
  input  axi_pkg::burst_t    __name``_arburst,  \
  input  logic               __name``_arlock,   \
  input  axi_pkg::cache_t    __name``_arcache,  \
  input  axi_pkg::prot_t     __name``_arprot,   \
  input  axi_pkg::qos_t      __name``_arqos,    \
  input  axi_pkg::region_t   __name``_arregion, \
  input  logic [__uw-1:0]    __name``_aruser,   \
  output logic [__iw-1:0]  __name``_rid,      \
  output logic [__dw-1:0]  __name``_rdata,    \
  output axi_pkg::resp_t   __name``_rresp,    \
  output logic             __name``_rlast,    \
  output logic [__uw-1:0]  __name``_ruser,    \
  input  logic               __name``_awvalid,  \
  input  logic               __name``_wvalid,   \
  input  logic               __name``_bready,   \
  input  logic               __name``_arvalid,  \
  input  logic               __name``_rready,   \
  output logic             __name``_awready,  \
  output logic             __name``_arready,  \
  output logic             __name``_wready,   \
  output logic             __name``_bvalid,   \
  output logic             __name``_rvalid
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Flat AXI Stream ports
`define AXIS_FLAT_PORT_MASTER(__name, __DW, __IW, __DSTW, __UW, __RW, __LW) \
    output logic [__DW-1:0]     __name``_tdata,   \
    output logic [__DW/8-1-1:0] __name``_tstrb,   \
    output logic [__DW/8-1-1:0] __name``_tkeep,   \
    output logic [__LW-1:0]     __name``_tlast,   \
    output logic [__IW-1:0]     __name``_tid,     \
    output logic [__DSTW-1:0]   __name``_tdest,   \
    output logic [__UW-1:0]     __name``_tuser,   \
    output logic                __name``_tvalid,  \
    input  logic [__RW-1:0]     __name``_tready
`define AXIS_FLAT_PORT_SLAVE(__name, __DW, __IW, __DSTW, __UW, __RW, __LW) \
    input   logic [__DW-1:0]     __name``_tdata,   \
    input   logic [__DW/8-1-1:0] __name``_tstrb,   \
    input   logic [__DW/8-1-1:0] __name``_tkeep,   \
    input   logic [__LW-1:0]     __name``_tlast,   \
    input   logic [__IW-1:0]     __name``_tid,     \
    input   logic [__DSTW-1:0]   __name``_tdest,   \
    input   logic [__UW-1:0]     __name``_tuser,   \
    input   logic                __name``_tvalid,  \
    output  logic [__RW-1:0]     __name``_tready

////////////////////////////////////////////////////////////////////////////////////////////////////
`endif
