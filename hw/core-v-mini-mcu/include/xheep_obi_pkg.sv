// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
/*
 *
 * Description: OBI package, contains common system definitions.
 *
 */

`include "obi/typedef.svh"


package xheep_obi_pkg;

  /// The config type for OBI bus optional fields.
  typedef struct packed {
    bit          UseAtop;
    bit          UseMemtype;
    bit          UseProt;
    bit          UseDbg;
    int unsigned ATopWidth;
    int unsigned MemtypeWidth;
    int unsigned ProtWidth;
    int unsigned WUserWidth;
    int unsigned RUserWidth;
    int unsigned AUserWidth;
    int unsigned MidWidth;
    int unsigned AChkWidth;
    int unsigned RChkWidth;
  } obi_optional_cfg_t;

  /// The minimal optional configuration disables all optional features.
  localparam obi_optional_cfg_t ObiMinimalOptionalConfig = '{
      UseAtop: 1'b0,
      UseMemtype: 1'b0,
      UseProt: 1'b0,
      UseDbg: 1'b0,
      ATopWidth: 0,
      MemtypeWidth: 0,
      ProtWidth: 0,
      AUserWidth: 0,
      WUserWidth: 0,
      RUserWidth: 0,
      MidWidth: 0,
      AChkWidth: 0,
      RChkWidth: 0
  };

  /// The OBI bus config type.
  typedef struct packed {
    bit                UseRReady;
    bit                CombGnt;
    int unsigned       AddrWidth;
    int unsigned       DataWidth;
    int unsigned       IdWidth;
    bit                Integrity;
    bit                BeFull;
    obi_optional_cfg_t OptionalCfg;
  } obi_cfg_t;

  localparam obi_cfg_t xheep_obiCfg = '{
      UseRReady: 1'b0,
      CombGnt: 1'b0,
      AddrWidth: 32,
      DataWidth: 32,
      IdWidth: 1,
      Integrity: 1'b0,
      BeFull: 1'b1,
      OptionalCfg: ObiMinimalOptionalConfig
  };

  `OBI_TYPEDEF_ALL(xheep_obi, xheep_obiCfg)
  `RELOBI_TYPEDEF_ALL(xheep_rel_obi, xheep_obiCfg)

endpackage
