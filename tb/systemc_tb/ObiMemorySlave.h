// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#ifndef OBIMEMORYSLAVE_H
#define OBIMEMORYSLAVE_H

#include "systemc.h"
#include "CacheMemoryController.h"
#include "MainMemory.h"

// ObiMemorySlave: a stateless, clockless shim between the OBI pins and the
// memory model (CacheMemoryController). Two combinational methods:
//   * pack_req   : packs the OBI request pins into one ObiReq struct signal;
//   * drive_pins : gnt = req && mem_ready (same-cycle grant on a HIT); rvalid
//                  and rdata pass through the controller's registered outputs.
// All state (grant/response FSM, counters, cache) lives in the controller.
SC_MODULE(ObiMemorySlave)
{
  CacheMemoryController *cache_memory_controller;
  MainMemory    *memory;

  sc_in<bool>          clk_i;
  sc_in<bool>          ext_systemc_req_req_i;
  sc_in<bool>          ext_systemc_req_we_i;
  sc_in<uint32_t>      ext_systemc_req_be_i;
  sc_in<uint32_t>      ext_systemc_req_addr_i;
  sc_in<uint32_t>      ext_systemc_req_wdata_i;
  sc_out<bool>         ext_systemc_resp_gnt_o;
  sc_out<bool>         ext_systemc_resp_rvalid_o;
  sc_out<uint32_t>     ext_systemc_resp_rdata_o;

  sc_signal<ObiReq>    obi_packet_req;  // request packed from the pins
  sc_signal<bool>      mem_ready;       // <- controller: grant permission
  sc_signal<bool>      mem_rvalid;      // <- controller: registered rvalid
  sc_signal<uint32_t>  mem_rdata;       // <- controller: registered rdata

  // always_comb: pack the OBI address-phase pins into one struct signal.
  void pack_req () {
    ObiReq r;
    r.req   = ext_systemc_req_req_i.read();
    r.we    = ext_systemc_req_we_i.read();
    r.be    = ext_systemc_req_be_i.read();
    r.addr  = ext_systemc_req_addr_i.read();
    r.wdata = ext_systemc_req_wdata_i.read();
    obi_packet_req.write(r);
  }

  // always_comb: drive the OBI response pins. gnt is req && mem_ready (so a HIT
  // grants in REQ's own cycle); rvalid/rdata pass through the memory's registers.
  void drive_pins () {
    ext_systemc_resp_gnt_o.write(obi_packet_req.read().req && mem_ready.read());
    ext_systemc_resp_rvalid_o.write(mem_rvalid.read());
    ext_systemc_resp_rdata_o.write(mem_rdata.read());
  }

  SC_CTOR(ObiMemorySlave)
  {
    cache_memory_controller = new CacheMemoryController("cache_memory_controller");
    memory                  = new MainMemory   ("main_memory");

    cache_memory_controller->clk_i      (clk_i);
    cache_memory_controller->obi_packet_req_i(obi_packet_req);
    cache_memory_controller->mem_ready_o(mem_ready);
    cache_memory_controller->mem_rvalid_o(mem_rvalid);
    cache_memory_controller->mem_rdata_o (mem_rdata);

    SC_METHOD(pack_req);
    sensitive << ext_systemc_req_req_i << ext_systemc_req_we_i << ext_systemc_req_be_i
              << ext_systemc_req_addr_i << ext_systemc_req_wdata_i;

    SC_METHOD(drive_pins);
    sensitive << obi_packet_req << mem_ready << mem_rvalid << mem_rdata;

    // Bind cache_memory_controller socket to target socket
    cache_memory_controller->socket.bind( memory->socket );
  }
};

#endif
