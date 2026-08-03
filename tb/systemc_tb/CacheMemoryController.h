#ifndef CACHEMEMORYCONTROLLER_H
#define CACHEMEMORYCONTROLLER_H

#include "systemc"
using namespace sc_core;
using namespace sc_dt;
using namespace std;

#include "tlm.h"
#include "tlm_utils/simple_initiator_socket.h"

#include "Cache.h"

#include <fstream>
#include <iostream>
#include <sstream>
#include <iomanip>

// OBI address-phase request, packed by the testbench into a single signal. This
// is the controller's only request input; it never sees the raw DUT pins.
struct ObiReq {
  bool     req   = false;
  bool     we    = false;
  uint32_t be    = 0;
  uint32_t addr  = 0;
  uint32_t wdata = 0;
  bool operator==(const ObiReq& o) const {
    return req==o.req && we==o.we && be==o.be && addr==o.addr && wdata==o.wdata;
  }
};
inline std::ostream& operator<<(std::ostream& os, const ObiReq& r) {
  os << (r.req ? (r.we ? "W" : "R") : "-") << " @0x" << std::hex << r.addr << std::dec;
  return os;
}
inline void sc_trace(sc_trace_file*, const ObiReq&, const std::string&) {}

// CacheMemoryController: the memory model as an RTL FSM -- two always_comb
// (mem_ready_comb, mem_resp_comb) + one always_ff (mem_seq) on clk. It owns the
// cache and all timing, counted in clock cycles (no sc_time), and knows nothing
// about OBI. It reads the request struct (obi_packet_req_i) and drives back:
//   * mem_ready_o              : combinational grant -- now for a HIT/config
//                                (REQ+0), after MISS_N cycles for a MISS (REQ+10);
//   * mem_rvalid_o/mem_rdata_o : combinational response decode, GNT+1+RESP_N (=GNT+2).
SC_MODULE(CacheMemoryController)
{
  // TLM-2 socket to main memory, defaults to 32-bits wide, base protocol
  tlm_utils::simple_initiator_socket<CacheMemoryController> socket;

  sc_in<bool>      clk_i;
  sc_in<ObiReq>    obi_packet_req_i;  // presented request (combinational)
  sc_out<bool>     mem_ready_o;       // grant permission (comb) -> gnt
  sc_out<bool>     mem_rvalid_o;      // response valid (comb decode of FSM state)
  sc_out<uint32_t> mem_rdata_o;       // response data  (comb, = resp_data)

  CacheMemory*   cache;
  std::ofstream  heep_mem_transactions;
  bool           bypass_state = false;
  uint32_t       resp_data    = 0;   // read data latched at grant, driven at RVALID

  // ---- RTL state (registers) ----
  enum { S_IDLE, S_GWAIT, S_RWAIT };
  sc_signal<int>      st;
  sc_signal<uint32_t> cnt;

  // ---- timing, in clock cycles (calibrated on the waveform) ----
  static const uint32_t MISS_N = 9;   // count in GWAIT  -> GNT at REQ+10
  static const uint32_t RESP_N = 1;   // count in RWAIT  -> RVALID at GNT+1+RESP_N (=GNT+2)

  // scratch for the functional work
  tlm::tlm_generic_payload* trans;
  uint8_t*  cache_data;
  int32_t*  main_mem_data;
  uint32_t  cache_block_size_byte;
  uint32_t  cache_block_size_word;

  typedef struct cache_statistics
  {
    uint32_t number_of_transactions;
    uint32_t number_of_hit;
    uint32_t number_of_miss;
  } cache_statistics_t;

  cache_statistics_t cache_stat;

  SC_CTOR(CacheMemoryController)
  : socket("socket"),  // Construct and name socket
    heep_mem_transactions("heep_mem_transactions.log")
  {
    cache = new CacheMemory;
    cache->create_cache();
    cache->initialize_cache();
    cache_stat.number_of_transactions = 0;
    cache_stat.number_of_hit = 0;
    cache_stat.number_of_miss = 0;
    cache->print_cache_status(cache_stat.number_of_transactions++, sc_time_stamp().to_string());

    trans = new tlm::tlm_generic_payload;
    cache_block_size_byte = cache->get_block_size();
    cache_block_size_word = cache->get_block_size()/4;
    cache_data    = new uint8_t[cache_block_size_byte];
    main_mem_data = new int32_t[cache_block_size_word];

    st.write(S_IDLE);
    cnt.write(0);

    SC_METHOD(mem_ready_comb);
    sensitive << obi_packet_req_i << st << cnt;

    SC_METHOD(mem_resp_comb);
    sensitive << st << cnt;

    SC_METHOD(mem_seq);
    sensitive << clk_i.pos();
  }

  // A write of 1/2 to the top word (0x7FFC of the 32 KB space) is a config
  // command (flush / set-bypass), not a normal cached access.
  static bool is_config_write(bool we, uint32_t addr) {
    return we && ((addr & 0x00007FFF) == 0x00007FFC);
  }

  // always_comb: ready now for a HIT/config; after the GWAIT counter reaches
  // MISS_N for a MISS/bypass; never in RWAIT (single-outstanding back-pressure).
  void mem_ready_comb() {
    ObiReq r = obi_packet_req_i.read();
    bool special = r.req && is_config_write(r.we, r.addr);
    bool hit     = r.req && !special && !bypass_state && cache->cache_hit(r.addr);
    bool ready = false;
    if      (st.read() == S_IDLE)  ready = r.req && (special || hit);
    else if (st.read() == S_GWAIT) ready = (cnt.read() >= MISS_N);
    mem_ready_o.write(ready);
  }

  // always_comb: RVALID/RDATA decoded from the FSM state (symmetric with gnt).
  // RVALID is high for the single RWAIT cycle where cnt reaches RESP_N, i.e. at
  // GNT+1+RESP_N. Being combinational (not registered) keeps the minimum response
  // latency at GNT+1, which a user can select with RESP_N=0.
  void mem_resp_comb() {
    mem_rvalid_o.write(st.read() == S_RWAIT && cnt.read() >= RESP_N);
    mem_rdata_o.write(resp_data);
  }

  // always_ff: grant + response-timing FSM.
  //   IDLE  : HIT/config -> grant now, do the work, go RWAIT;
  //           MISS/bypass -> go GWAIT and start the grant counter.
  //   GWAIT : count MISS_N cycles; when reached the grant happens (mem_ready is
  //           high this cycle) -> do the work, go RWAIT. Reading the counter here
  //           lands us on the SAME edge the DUT completes the handshake.
  //   RWAIT : count RESP_N cycles, then return to IDLE (RVALID is decoded in
  //           mem_resp_comb).
  void mem_seq() {
    ObiReq r = obi_packet_req_i.read();
    bool special = r.req && is_config_write(r.we, r.addr);
    bool hit     = r.req && !special && !bypass_state && cache->cache_hit(r.addr);
    bool immediate = special || hit;

    switch (st.read()) {

      case S_IDLE:
        if (r.req && immediate) { do_work(r); cnt.write(0); st.write(S_RWAIT); }
        else if (r.req)         { cnt.write(0); st.write(S_GWAIT); }
        break;

      case S_GWAIT:
        if (!r.req)                                                         // illegal!
          SC_REPORT_ERROR("OBI External Memory SystemC",
                          "REQ deasserted before GNT during a miss wait: the OBI master must hold REQ until granted");
        else if (cnt.read() >= MISS_N) { do_work(r); cnt.write(0); st.write(S_RWAIT); }
        else                           { cnt.write(cnt.read() + 1); }
        break;

      case S_RWAIT:
        if (cnt.read() >= RESP_N) { cnt.write(0); st.write(S_IDLE); }
        else                      { cnt.write(cnt.read() + 1); }
        break;
    }
  }


  uint32_t memory_copy(uint32_t addr, int32_t* buffer_data, int N, bool write_enable, tlm::tlm_generic_payload* trans, sc_time delay) {

    tlm::tlm_command cmd = write_enable ? tlm::TLM_WRITE_COMMAND : tlm::TLM_READ_COMMAND;

    //first read block_size bytes from memory to place them in cache regardless of the cmd
    for(int i=0; i < N; i++){
      trans->set_command( cmd );
      trans->set_address( (addr + i*4) & 0x00007FFF ); //15bits
      trans->set_data_ptr( reinterpret_cast<unsigned char*>(&buffer_data[i]) );
      trans->set_data_length( 4 );
      trans->set_streaming_width( 4 ); // = data_length to indicate no streaming
      trans->set_byte_enable_ptr( 0 ); // 0 indicates unused
      trans->set_dmi_allowed( false ); // Mandatory initial value
      trans->set_response_status( tlm::TLM_INCOMPLETE_RESPONSE ); // Mandatory initial value
      socket->b_transport( *trans, delay );  // Blocking transport call

      if(bypass_state){
        if(write_enable)
          heep_mem_transactions << "Writing to Mem[" << hex << ((addr + i*4) & 0x00007FFF) << "]: " << buffer_data[i] << " at time " << sc_time_stamp() <<std::endl;
        else
          heep_mem_transactions << "Reading from Mem[" << hex << ((addr + i*4) & 0x00007FFF) << "]: " << buffer_data[i] << " at time " << sc_time_stamp() <<std::endl;
      } else {
        if(write_enable)
          heep_mem_transactions << "Cache Writing to Mem[" << hex << ((addr + i*4) & 0x00007FFF) << "]: " << buffer_data[i] << " at time " << sc_time_stamp() <<std::endl;
        else
          heep_mem_transactions << "Cache Reading from Mem[" << hex << ((addr + i*4) & 0x00007FFF) << "]: " << buffer_data[i] << " at time " << sc_time_stamp() <<std::endl;
      }
      // Initiator obliged to check response status and delay
      if ( trans->is_response_error() )
        SC_REPORT_ERROR("TLM-2", "Response error from b_transport");
    }
    return N;
  }


  // Functional cache/TLM work for the granted request. Runs once, at the grant
  // edge (zero simulation time), and latches the read result into resp_data.
  void do_work(const ObiReq& rq)
  {
    bool     we_i      = rq.we;
    uint32_t be_i      = rq.be;
    uint32_t addr_i    = rq.addr;
    uint32_t rwdata_io = rq.wdata;

    sc_time delay = sc_time(1, SC_NS);
    uint32_t address_to_replace;
    uint32_t cache_flushed;

    heep_mem_transactions << "X-HEEP tlm_generic_payload REQ: { " << (we_i ? 'W' : 'R') << ", @0x" << hex << addr_i
              << " , DATA = 0x" << hex << rwdata_io << " BE = " << hex << be_i <<", at time " << sc_time_stamp() << " }" << std::endl;

    if(be_i!=0xF) {
      SC_REPORT_ERROR("OBI External Memory SystemC", "ByteEnable different than 0xF is not supported");
    }

    //if we are writing 1 or 2 to last address, flush cache or bypass
    if(is_config_write(we_i, addr_i)){

      if(rwdata_io == 1){
        //FLUSH Cache
        heep_mem_transactions << "X-HEEP Flush Cache, at time " << sc_time_stamp() << " }" << std::endl;
        uint32_t cache_number_of_blocks = cache->number_of_blocks;
        heep_mem_transactions<<"Cache Flushing at time "<<sc_time_stamp()<<std::endl;
        cache_flushed=0;
        for(int i=0;i<cache_number_of_blocks;i++){
            if (cache->is_entry_valid_at_index(i)) {
              cache_flushed++;
              //if we are going to replace a valid entry
              cache->get_data_at_index(i, cache_data);
              address_to_replace = cache->get_address_at_index(i);
              //write back
              memory_copy(address_to_replace, (int32_t *)cache_data, cache_block_size_word, true, trans, delay);
          }
        }
        heep_mem_transactions<<"Cache Flushed "<< dec << cache_flushed << " entries"<<std::endl;
      } else if (rwdata_io == 2){
        //ByPass Flash from next transaction
        bypass_state = true;
        heep_mem_transactions<<"Cache ByPass set at time "<<sc_time_stamp()<<std::endl;
        heep_mem_transactions << "X-HEEP Bypass Cache, at time " << sc_time_stamp() << " }" << std::endl;
      }
    }

    else{

      if (bypass_state) {
        heep_mem_transactions << "Cache in bypass state at time " << sc_time_stamp() <<std::endl;
        memory_copy(addr_i, (int32_t *) &rwdata_io, 1, we_i == true, trans, delay);
      } else {
        // we use the cache only to read
        if(cache->cache_hit(addr_i)){

          heep_mem_transactions << "Cache HIT on address " << hex << addr_i << " at time " << sc_time_stamp() <<std::endl;

          cache_stat.number_of_hit++;

          if(we_i)
            cache->set_word(addr_i, rwdata_io);
          else
            rwdata_io = cache->get_word(addr_i);
        }

        else { //miss case

          cache_stat.number_of_miss++;

          heep_mem_transactions << "Cache MISS on address " << hex << addr_i << " at time " << sc_time_stamp() <<std::endl;

          uint32_t addr_to_read = cache->get_base_address(addr_i);
          uint32_t addr_offset  = cache->get_block_offset(addr_i);

          //first read block_size bytes from memory to place them in cache regardless of the cmd
          memory_copy(addr_to_read, main_mem_data, cache_block_size_word, false, trans, delay);
          uint32_t index_to_add = cache->get_index(addr_i);
          uint32_t tag_to_add       = cache->get_tag(addr_i);

          heep_mem_transactions << "Adding to Cache TAG " << hex << tag_to_add << " and index " << hex << index_to_add <<std::endl;

          //always write back what will be replace if valid as we do not have dirty bits for simplicity
          if (cache->is_entry_valid(addr_i)) {
            //if we are going to replace a valid entry
            cache->get_data(addr_i, cache_data);
            address_to_replace = cache->get_address(addr_i);
            uint32_t index_to_replace = cache->get_index(addr_i);
            uint32_t tag_to_replace = cache->get_tag_from_index(index_to_replace);

            heep_mem_transactions << "Cache Replace address " << hex << addr_i << " with address " << hex << address_to_replace << " due to the MISS at time " << sc_time_stamp() <<std::endl;
            heep_mem_transactions << "Index to replace " << hex << index_to_replace << " Tag to replace " << tag_to_replace <<std::endl;

            //write back
            memory_copy(address_to_replace, (int32_t *)cache_data, cache_block_size_word, true, trans, delay);
          }

          //now replace the entry in cache
          cache->add_entry(addr_i, (uint8_t*)main_mem_data);

          //if Write, writes to cache
          if(we_i)
            cache->set_word(addr_i, rwdata_io);

          //now give back the rdata
          rwdata_io = main_mem_data[addr_offset>>2]; //>>2 as addr_offset is for byte address, not words
        }
      }
    }

    heep_mem_transactions << "X-HEEP tlm_generic_payload RESP: { DATA = 0x" << hex << rwdata_io <<", at time " << sc_time_stamp() << " }" << std::endl;
    cache->print_cache_status(cache_stat.number_of_transactions++, sc_time_stamp().to_string());

    resp_data = we_i ? 0u : rwdata_io;
  }
};

#endif
