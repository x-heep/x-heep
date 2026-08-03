// Copyright 2024 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "verilated.h"
#include <verilated_vcd_sc.h>
#include "Vtestharness.h"
#include "Vtestharness__Syms.h"
#include "systemc.h"
#include <stdlib.h>
#include <iostream>
#include <sys/stat.h>
#include "XHEEP_CmdLineOptions.hh"

sc_event reset_done_event;


#include "systemc_tb/ObiMemorySlave.h"


SC_MODULE(testbench)
{

  sc_in<bool> clk_i;
  sc_out<bool> clk_o;
  sc_out<bool> rst_no;
  sc_out<bool> boot_select_o;
  sc_out<bool> execute_from_flash_o;
  sc_out<bool> jtag_tck_o;
  sc_out<bool> jtag_tms_o;
  sc_out<bool> jtag_trst_n_o;
  sc_out<bool> jtag_tdi_o;

  Vtestharness* dut;
  std::string* firmware;

  bool boot_select_option;
  unsigned int reset_cycles = 30;

  void make_clock () {
    while(1) {
      clk_o.write(false);
      wait();
      clk_o.write(true);
      wait();
    }
  }

  void do_reset_cycle () {
    //active low
    //-----
    rst_no.write(false);

    for(int i=0;i<reset_cycles;i++) wait();

    //-----|||||||
    rst_no.write(true);
    for(int i=0;i<reset_cycles;i++) wait();

    //-----|||||||------
    rst_no.write(false);
    for(int i=0;i<reset_cycles;i++) wait();

    //-----|||||||------||||||
    rst_no.write(true);
    for(int i=0;i<reset_cycles;i++) wait();
  }


  void load_firmware () {
    struct stat buffer;
    wait();
    // Check if the firmware file exists
    if (stat(firmware->c_str(), &buffer) != 0) {
      std::cerr << "[TESTBENCH]: ERROR: Firmware file " << firmware << " does not exist." << std::endl;
      exit(EXIT_FAILURE);
    }
    dut->tb_loadHEX(firmware->c_str());
  }

  void set_exit_loop () {
    wait();
    dut->tb_set_exit_loop();
  }

  void make_stimuli () {

    boot_select_o.write(boot_select_option);
    execute_from_flash_o.write(true);
    jtag_tck_o.write(false);
    jtag_tms_o.write(false);
    jtag_trst_n_o.write(false);
    jtag_tdi_o.write(false);

    std::cout<<"Start Reset Cycle: "<<sc_time_stamp()<< std::endl;
    do_reset_cycle();
    std::cout<<"Reset Released: "<<sc_time_stamp()<< std::endl;

    std::cout<<"Loading firmware "<<firmware->c_str()<<std::endl;
    load_firmware ();

    std::cout<<"Set Exit Loop"<< std::endl;
    set_exit_loop ();

    reset_done_event.notify();

    //sc_stop();
  }

  SC_CTOR(testbench)
  {

    SC_CTHREAD(make_clock, clk_i.pos());
    SC_CTHREAD(make_stimuli, clk_i.pos());

  }



};

int sc_main (int argc, char * argv[])
{

  std::string firmware;
  unsigned long long max_sim_time;
  unsigned int boot_sel, exit_val;
  bool use_openocd;
  bool run_all = false;
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  XHEEP_CmdLineOptions* cmd_lines_options = new XHEEP_CmdLineOptions(argc,argv);

  use_openocd = cmd_lines_options->get_use_openocd();
  firmware = cmd_lines_options->get_firmware();

  if(firmware.empty() && use_openocd==false) {
    std::cout<<"You must specify the firmware if you are not using OpenOCD"<<std::endl;
    exit(EXIT_FAILURE);
  }

  max_sim_time = cmd_lines_options->get_max_sim_time(run_all);

  boot_sel     = cmd_lines_options->get_boot_sel();

  if(use_openocd) {
    std::cout<<"[TESTBENCH]: ERROR: Executing from OpenOCD in SystemC is not supported (yet) in X-HEEP"<<std::endl;
    std::cout<<"exit simulation..."<<std::endl;
    exit(EXIT_FAILURE);
  }

  if(boot_sel == 1) {
    std::cout<<"[TESTBENCH]: ERROR: Executing from SPI is not supported (yet) in Verilator"<<std::endl;
    std::cout<<"exit simulation..."<<std::endl;
    exit(EXIT_FAILURE);
  }

  // generate clock, twice the speed as we generate it by dividing it by 2
  sc_clock clock_sig("clock", CLK_PERIOD_ps/2, SC_PS, 0.5);

  Vtestharness dut("TOP");
  testbench tb("testbench");
  ObiMemorySlave ext_mem_obislave("obi_memory_slave");

  svSetScope(svGetScopeFromName("TOP.testharness"));
  svScope scope = svGetScope();
  if (!scope) {
    std::cout<<"Warning: svGetScope failed"<< std::endl;
    exit(EXIT_FAILURE);
  }


  // static values
  tb.boot_select_option = boot_sel == 1;


  // Vtestharness interface
  sc_signal<bool, SC_MANY_WRITERS>     clk;
  sc_signal<bool, SC_MANY_WRITERS>     rst_n;
  sc_signal<bool, SC_MANY_WRITERS>     boot_select;
  sc_signal<bool, SC_MANY_WRITERS>     execute_from_flash;
  sc_signal<bool>     jtag_tck;
  sc_signal<bool>     jtag_tms;
  sc_signal<bool>     jtag_trst_n;
  sc_signal<bool>     jtag_tdi;
  sc_signal<bool>     jtag_tdo;
  sc_signal<uint32_t> exit_value;
  sc_signal<bool, SC_MANY_WRITERS>     exit_valid;
  sc_signal<bool>      ext_systemc_req_req;
  sc_signal<bool>      ext_systemc_req_we;
  sc_signal<uint32_t>  ext_systemc_req_be;
  sc_signal<uint32_t>  ext_systemc_req_addr;
  sc_signal<uint32_t>  ext_systemc_req_wdata;
  sc_signal<bool>      ext_systemc_resp_gnt;
  sc_signal<bool>      ext_systemc_resp_rvalid;
  sc_signal<uint32_t>  ext_systemc_resp_rdata;



  tb.clk_i(clock_sig);
  tb.clk_o(clk);
  tb.rst_no(rst_n);
  tb.boot_select_o(boot_select);
  tb.execute_from_flash_o(execute_from_flash);
  tb.jtag_tck_o(jtag_tck);
  tb.jtag_tms_o(jtag_tms);
  tb.jtag_trst_n_o(jtag_trst_n);
  tb.jtag_tdi_o(jtag_tdi);

  tb.dut = &dut;
  tb.firmware = &firmware;

  dut.clk_i(clk);
  dut.rst_ni(rst_n);
  dut.boot_select_i(boot_select);
  dut.execute_from_flash_i(execute_from_flash);
  dut.jtag_tck_i(jtag_tck);
  dut.jtag_tms_i(jtag_tms);
  dut.jtag_trst_ni(jtag_trst_n);
  dut.jtag_tdi_i(jtag_tdi);
  dut.jtag_tdo_o(jtag_tdo);
  dut.exit_value_o(exit_value);
  dut.exit_valid_o(exit_valid);
  dut.ext_systemc_req_req_o(ext_systemc_req_req);
  dut.ext_systemc_req_we_o(ext_systemc_req_we);
  dut.ext_systemc_req_be_o(ext_systemc_req_be);
  dut.ext_systemc_req_addr_o(ext_systemc_req_addr);
  dut.ext_systemc_req_wdata_o(ext_systemc_req_wdata);
  dut.ext_systemc_resp_gnt_i(ext_systemc_resp_gnt);
  dut.ext_systemc_resp_rvalid_i(ext_systemc_resp_rvalid);
  dut.ext_systemc_resp_rdata_i(ext_systemc_resp_rdata);

  ext_mem_obislave.clk_i(clk);
  ext_mem_obislave.ext_systemc_req_req_i(ext_systemc_req_req);
  ext_mem_obislave.ext_systemc_req_we_i(ext_systemc_req_we);
  ext_mem_obislave.ext_systemc_req_be_i(ext_systemc_req_be);
  ext_mem_obislave.ext_systemc_req_addr_i(ext_systemc_req_addr);
  ext_mem_obislave.ext_systemc_req_wdata_i(ext_systemc_req_wdata);
  ext_mem_obislave.ext_systemc_resp_gnt_o(ext_systemc_resp_gnt);
  ext_mem_obislave.ext_systemc_resp_rdata_o(ext_systemc_resp_rdata);
  ext_mem_obislave.ext_systemc_resp_rvalid_o(ext_systemc_resp_rvalid);



  // You must do one evaluation before enabling waves, in order to allow
  // SystemC to interconnect everything for testing.
  sc_start(1, SC_NS);


  VerilatedVcdSc* tfp = nullptr;
  tfp = new VerilatedVcdSc;
  dut.trace(tfp, 99);  // Trace 99 levels of hierarchy
  tfp->open("waveform.vcd");

  // Simulate until $finish, exit_valid, or max_sim_time
  sc_time max_sc_time((double)max_sim_time, SC_PS);
  while (!Verilated::gotFinish() && exit_valid != 1) {
      // Flush the wave files each cycle so we can immediately see the output
      // Don't do this in "real" programs, do it in an abort() handler instead
      if (tfp) tfp->flush();
      // Simulate 1ns
      sc_start(1, SC_NS);
      if (!run_all && sc_time_stamp() >= max_sc_time) break;
  }

  vluint64_t sim_cycles = (vluint64_t)(sc_time_stamp().to_seconds() * 1e12 / CLK_PERIOD_ps);
  std::cout << "Simulation finished after " << sim_cycles << " clock cycles" << std::endl;

  // This should be the last message printed so that the scripts like test-all can catch the exit value properly.
  // The return value should be the last character (in case it is 0)
  if(exit_valid == 1) {
    std::cout<<"Program Finished with value "<< exit_value <<std::endl;
    exit_val = EXIT_SUCCESS;
  } else {
    std::cout<<"Simulation was terminated before program finished"<<std::endl;
    exit_val = 2;
  }

  // Final model cleanup
  dut.final();

  // Close trace if opened
  if (tfp) {
      tfp->close();
      tfp = nullptr;
  }


  exit(exit_val);

}
