// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

`ifndef OBI_TYPEDEF_SVH
`define OBI_TYPEDEF_SVH

`define OBI_TYPEDEF_A_CHAN_T(a_chan_t, ADDR_WIDTH, DATA_WIDTH, ID_WIDTH, a_optional_t) \
  typedef struct packed {                                                              \
    logic [  ADDR_WIDTH-1:0] addr;                                                     \
    logic                    we;                                                       \
    logic [DATA_WIDTH/8-1:0] be;                                                       \
    logic [  DATA_WIDTH-1:0] wdata;                                                    \
    logic [    ID_WIDTH-1:0] aid;                                                      \
    a_optional_t             a_optional;                                               \
  } a_chan_t;

`define OBI_TYPEDEF_TYPE_A_CHAN_T(a_chan_t, addr_t, data_t, strb_t, id_t, a_optional_t) \
  typedef struct packed {                                                               \
    addr_t       addr;                                                                  \
    logic        we;                                                                    \
    strb_t       be;                                                                    \
    data_t       wdata;                                                                 \
    id_t         aid;                                                                   \
    a_optional_t a_optional;                                                            \
  } a_chan_t;

`define OBI_TYPEDEF_MINIMAL_A_OPTIONAL(a_optional_t) \
  typedef logic a_optional_t;

`define OBI_TYPEDEF_ATOP_A_OPTIONAL(a_optional_t, atop_t) \
  typedef struct packed {                                 \
    atop_t atop;                                          \
  } a_optional_t;

`define OBI_TYPEDEF_ALL_A_OPTIONAL(a_optional_t, AUSER_WIDTH, WUSER_WIDTH, MID_WIDTH, ACHK_WIDTH, ATOP_WIDTH, MEMTTYPE_WIDTH, PROT_WIDTH) \
  typedef struct packed {                                                                                                                 \
    logic [   AUSER_WIDTH-1:0] auser;                                                                                                     \
    logic [   WUSER_WIDTH-1:0] wuser;                                                                                                     \
    logic [    ATOP_WIDTH-1:0] atop;                                                                                                      \
    logic [MEMTTYPE_WIDTH-1:0] memtype;                                                                                                   \
    logic [     MID_WIDTH-1:0] mid;                                                                                                       \
    logic [    PROT_WIDTH-1:0] prot;                                                                                                      \
    logic                      dbg;                                                                                                       \
    logic [    ACHK_WIDTH-1:0] achk;                                                                                                      \
  } a_optional_t;

`define OBI_TYPEDEF_R_CHAN_T(r_chan_t, RDATA_WIDTH, ID_WIDTH, r_optional_t) \
  typedef struct packed {                                                   \
    logic [RDATA_WIDTH-1:0] rdata;                                          \
    logic [   ID_WIDTH-1:0] rid;                                            \
    logic                   err;                                            \
    r_optional_t            r_optional;                                     \
  } r_chan_t;

`define OBI_TYPEDEF_TYPE_R_CHAN_T(r_chan_t, data_t, id_t, r_optional_t) \
  typedef struct packed {                                               \
    data_t       rdata;                                                 \
    id_t         rid;                                                   \
    logic        err;                                                   \
    r_optional_t r_optional;                                            \
  } r_chan_t;

`define OBI_TYPEDEF_MINIMAL_R_OPTIONAL(r_optional_t) \
  typedef logic r_optional_t;

`define OBI_TYPEDEF_ALL_R_OPTIONAL(r_optional_t, RUSER_WIDTH, RCHK_WIDTH) \
  typedef struct packed {                                                 \
    logic [RUSER_WIDTH-1:0] ruser;                                        \
    logic                   exokay;                                       \
    logic [ RCHK_WIDTH-1:0] rchk;                                         \
  } r_optional_t;

`define OBI_TYPEDEF_DEFAULT_REQ_T(req_t, a_chan_t) \
  typedef struct packed {                          \
    a_chan_t a;                                    \
    logic    req;                                  \
  } req_t;

`define OBI_TYPEDEF_REQ_T(req_t, a_chan_t) \
  typedef struct packed {                  \
    a_chan_t a;                            \
    logic    req;                          \
    logic    rready;                       \
  } req_t;

`define OBI_TYPEDEF_RSP_T(rsp_t, r_chan_t) \
  typedef struct packed {                  \
    r_chan_t r;                            \
    logic    gnt;                          \
    logic    rvalid;                       \
  } rsp_t;

`define OBI_TYPEDEF_INTEGRITY_REQ_T(req_t, a_chan_t) \
  typedef struct packed {                            \
    a_chan_t a;                                      \
    logic    req;                                    \
    logic    rready;                                 \
    logic    reqpar;                                 \
    logic    rreadypar;                              \
  } req_t;

`define OBI_TYPEDEF_INTEGRITY_RSP_T(rsp_t, r_chan_t) \
  typedef struct packed {                            \
    r_chan_t r;                                      \
    logic    gnt;                                    \
    logic    gntpar;                                 \
    logic    rvalid;                                 \
    logic    rvalidpar;                              \
  } rsp_t;

`define OBI_TYPEDEF_ALL(obi_t, cfg)                                                                                                                              \
  `OBI_TYPEDEF_ALL_A_OPTIONAL(obi_t``_a_optional_t, cfg.OptionalCfg.AUserWidth, cfg.OptionalCfg.WUserWidth, cfg.OptionalCfg.MidWidth, cfg.OptionalCfg.AChkWidth, cfg.OptionalCfg.UseAtop*cfg.OptionalCfg.ATopWidth, cfg.OptionalCfg.UseMemtype * cfg.OptionalCfg.MemtypeWidth, cfg.OptionalCfg.UseProt * cfg.OptionalCfg.ProtWidth) \
  `OBI_TYPEDEF_A_CHAN_T(obi_t``_a_chan_t, cfg.AddrWidth, cfg.DataWidth, cfg.IdWidth, obi_t``_a_optional_t)                                                       \
  `OBI_TYPEDEF_INTEGRITY_REQ_T(obi_t``_req_t, obi_t``_a_chan_t)                                                                                                  \
  `OBI_TYPEDEF_ALL_R_OPTIONAL(obi_t``_r_optional_t, cfg.OptionalCfg.RUserWidth, cfg.OptionalCfg.RChkWidth)                                                       \
  `OBI_TYPEDEF_R_CHAN_T(obi_t``_r_chan_t, cfg.DataWidth, cfg.IdWidth, obi_t``_r_optional_t)                                                                      \
  `OBI_TYPEDEF_INTEGRITY_RSP_T(obi_t``_rsp_t, obi_t``_r_chan_t)

`define OBI_TYPEDEF_DEFAULT_ALL(obi_t, cfg)                                                                \
  `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(obi_t``_a_optional_t)                                                    \
  `OBI_TYPEDEF_A_CHAN_T(obi_t``_a_chan_t, cfg.AddrWidth, cfg.DataWidth, cfg.IdWidth, obi_t``_a_optional_t) \
  `OBI_TYPEDEF_DEFAULT_REQ_T(obi_t``_req_t, obi_t``_a_chan_t)                                              \
  `OBI_TYPEDEF_MINIMAL_R_OPTIONAL(obi_t``_r_optional_t)                                                    \
  `OBI_TYPEDEF_R_CHAN_T(obi_t``_r_chan_t, cfg.DataWidth, cfg.IdWidth, obi_t``_r_optional_t)                \
  `OBI_TYPEDEF_RSP_T(obi_t``_rsp_t, obi_t``_r_chan_t)

`define OBI_TYPEDEF_ALL_WITH_OPTIONAL(obi_t, cfg, a_optional_t, r_optional_t) \
  `OBI_TYPEDEF_A_CHAN_T(obi_t``_a_chan_t, cfg.AddrWidth, cfg.DataWidth, cfg.IdWidth, a_optional_t)                                                       \
  `OBI_TYPEDEF_INTEGRITY_REQ_T(obi_t``_req_t, obi_t``_a_chan_t)                                                                                                  \
  `OBI_TYPEDEF_R_CHAN_T(obi_t``_r_chan_t, cfg.DataWidth, cfg.IdWidth, r_optional_t)                                                                      \
  `OBI_TYPEDEF_INTEGRITY_RSP_T(obi_t``_rsp_t, obi_t``_r_chan_t)

`define OBI_TYPEDEF_ALL_DEFAULT_WITH_OPTIONAL(obi_t, cfg, a_optional_t, r_optional_t) \
  `OBI_TYPEDEF_A_CHAN_T(obi_t``_a_chan_t, cfg.AddrWidth, cfg.DataWidth, cfg.IdWidth, a_optional_t)                                                       \
  `OBI_TYPEDEF_DEFAULT_REQ_T(obi_t``_req_t, obi_t``_a_chan_t)                                                                                                  \
  `OBI_TYPEDEF_R_CHAN_T(obi_t``_r_chan_t, cfg.DataWidth, cfg.IdWidth, r_optional_t)                                                                      \
  `OBI_TYPEDEF_RSP_T(obi_t``_rsp_t, obi_t``_r_chan_t)

`define RELOBI_TYPEDEF_A_CHAN_T(a_chan_t, ADDR_WIDTH, DATA_WIDTH, ID_WIDTH, a_optional_t) \
  typedef struct packed {                                                                 \
    logic [2:0][                                           ADDR_WIDTH-1:0] addr;          \
    logic                                                                  we;            \
    logic [                                              DATA_WIDTH/8-1:0] be;            \
    logic [             DATA_WIDTH+hsiao_ecc_pkg::min_ecc(DATA_WIDTH)-1:0] wdata;         \
    logic [2:0][                                             ID_WIDTH-1:0] aid;           \
    a_optional_t                                                           a_optional;    \
    logic [hsiao_ecc_pkg::min_ecc(1+DATA_WIDTH/8+$bits(a_optional_t))-1:0] other_ecc;     \
  } a_chan_t;

`define RELOBI_TYPEDEF_DEFAULT_REQ_T(req_t, a_chan_t) \
  typedef struct packed {                     \
    a_chan_t    a;                            \
    logic [2:0] req;                          \
  } req_t;

`define RELOBI_TYPEDEF_REQ_T(req_t, a_chan_t) \
  typedef struct packed {                     \
    a_chan_t    a;                            \
    logic [2:0] req;                          \
    logic [2:0] rready;                       \
  } req_t;

`define RELOBI_TYPEDEF_R_CHAN_T(r_chan_t, RDATA_WIDTH, ID_WIDTH, r_optional_t) \
  typedef struct packed {                                                      \
    logic [RDATA_WIDTH+hsiao_ecc_pkg::min_ecc(RDATA_WIDTH)-1:0] rdata;         \
    logic [2:0][                                  ID_WIDTH-1:0] rid;           \
    logic                                                       err;           \
    r_optional_t                                                r_optional;    \
    logic [  hsiao_ecc_pkg::min_ecc(1+$bits(r_optional_t))-1:0] other_ecc;     \
  } r_chan_t;

`define RELOBI_TYPEDEF_RSP_T(rsp_t, r_chan_t) \
  typedef struct packed {                     \
    r_chan_t    r;                            \
    logic [2:0] gnt;                          \
    logic [2:0] rvalid;                       \
  } rsp_t;

`define RELOBI_TYPEDEF_ALL(obi_t, cfg)                                                                                                                              \
  `OBI_TYPEDEF_ALL_A_OPTIONAL(obi_t``_a_optional_t, cfg.OptionalCfg.AUserWidth, cfg.OptionalCfg.WUserWidth, cfg.OptionalCfg.MidWidth, cfg.OptionalCfg.AChkWidth) \
  `RELOBI_TYPEDEF_A_CHAN_T(obi_t``_a_chan_t, cfg.AddrWidth, cfg.DataWidth, cfg.IdWidth, obi_t``_a_optional_t)                                                       \
  `RELOBI_TYPEDEF_DEFAULT_REQ_T(obi_t``_req_t, obi_t``_a_chan_t)                                                                                                  \
  `OBI_TYPEDEF_ALL_R_OPTIONAL(obi_t``_r_optional_t, cfg.OptionalCfg.RUserWidth, cfg.OptionalCfg.RChkWidth)                                                       \
  `RELOBI_TYPEDEF_R_CHAN_T(obi_t``_r_chan_t, cfg.DataWidth, cfg.IdWidth, obi_t``_r_optional_t)                                                                      \
  `RELOBI_TYPEDEF_RSP_T(obi_t``_rsp_t, obi_t``_r_chan_t)

`define RELOBI_TYPEDEF_ALL_WITH_OPTIONAL(obi_t, cfg, a_optional_t, r_optional_t)                                                                                                                              \
  `RELOBI_TYPEDEF_A_CHAN_T(obi_t``_a_chan_t, cfg.AddrWidth, cfg.DataWidth, cfg.IdWidth, a_optional_t)                                                       \
  `RELOBI_TYPEDEF_DEFAULT_REQ_T(obi_t``_req_t, obi_t``_a_chan_t)                                                                                                  \
  `RELOBI_TYPEDEF_R_CHAN_T(obi_t``_r_chan_t, cfg.DataWidth, cfg.IdWidth, r_optional_t)                                                                      \
  `RELOBI_TYPEDEF_RSP_T(obi_t``_rsp_t, obi_t``_r_chan_t)


`endif // OBI_TYPEDEF_SVH
