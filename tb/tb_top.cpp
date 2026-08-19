// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtestharness.h"
#include "Vtestharness__Syms.h"

#include <stdlib.h>
#include <iostream>

#include "XHEEP_CmdLineOptions.hh"

vluint64_t sim_time = 0;

void runCycles(unsigned int ncycles, Vtestharness *dut, VerilatedFstC *m_trace){
  for(unsigned int i = 0; i < 2*ncycles; i++) {
    sim_time += CLK_PERIOD_ps/2;
    dut->clk_i ^= 1;
    dut->eval();
    m_trace->dump(sim_time);
  }
}

int main (int argc, char * argv[])
{

  std::string firmware;
  vluint64_t max_sim_time;
  unsigned int boot_sel, exit_val;
  bool use_openocd;
  bool run_all = false;

  Verilated::commandArgs(argc, argv);

  // Instantiate the model
  Vtestharness *dut = new Vtestharness;

  // Open VCD
  Verilated::traceEverOn (true);
  VerilatedFstC *m_trace = new VerilatedFstC;
  dut->trace (m_trace, 99);
  m_trace->open ("waveform.fst");

  XHEEP_CmdLineOptions* cmd_lines_options = new XHEEP_CmdLineOptions(argc,argv);

  use_openocd = cmd_lines_options->get_use_openocd();
  firmware = cmd_lines_options->get_firmware();

  if(firmware.empty() && use_openocd==false){
      std::cout<<"You must specify the firmware if you are not using OpenOCD"<<std::endl;
      exit(EXIT_FAILURE);
  }

  max_sim_time = cmd_lines_options->get_max_sim_time(run_all);

  boot_sel     = cmd_lines_options->get_boot_sel();

  svSetScope(svGetScopeFromName("TOP.testharness"));
  svScope scope = svGetScope();
  if (!scope) {
    std::cout<<"Warning: svGetScope failed"<< std::endl;
    exit(EXIT_FAILURE);
  }

  dut->clk_i                = 0;
  dut->rst_ni               = 1;
  dut->jtag_tck_i           = 0;
  dut->jtag_tms_i           = 0;
  dut->jtag_trst_ni         = 0;
  dut->jtag_tdi_i           = 0;

  dut->eval();
  m_trace->dump(sim_time);

  dut->rst_ni               = 1;
  dut->boot_select_i        = boot_sel;

  //this creates the negedge
  runCycles(20, dut, m_trace);
  dut->rst_ni               = 0;
  runCycles(40, dut, m_trace);

  dut->rst_ni = 1;
  runCycles(40, dut, m_trace);
  std::cout<<"Reset Released"<< std::endl;

  dut->load_flash_hex(firmware.c_str());

  if(boot_sel != 1) {
    //Booting from JTAG or loading the memory from the testbench
    if(use_openocd==false) {
      dut->tb_loadHEX(firmware.c_str());
      runCycles(1, dut, m_trace);
      //you need to exit from the bootrom loop if not using OpenOCD
      dut->tb_set_exit_loop();
      std::cout<<"Set Exit Loop"<< std::endl;
      runCycles(1, dut, m_trace);
      std::cout<<"Memory Loaded"<< std::endl;
    } else {
      std::cout<<"Waiting for GDB"<< std::endl;
    }
  } else {
      std::cout<<"X-HEEP is loading from FLASH..."<< std::endl;
  }


  if(run_all==false) {
    while(dut->exit_valid_o!=1 && sim_time<max_sim_time) {
      runCycles(100, dut, m_trace);
    }
  } else {
    while(dut->exit_valid_o!=1) {
      runCycles(100, dut, m_trace);
    }
  }

  std::cout<<"Simulation finished after "<<(sim_time/CLK_PERIOD_ps)<<" clock cycles"<<std::endl;

  // This should be the last message printed  so that the scripts like test-all can catch the exit value properly. 
  // The return value should be the last character (in case it is 0)
  if(dut->exit_valid_o==1) { 
    std::cout<<"Program Finished with value "<<dut->exit_value_o<<std::endl;
    exit_val = EXIT_SUCCESS;
  } else {
    std::cout<<"Simulation was terminated before program finished"<<std::endl;
    exit_val = 2; // exit 2 to indicate successful run but premature termination
  }

  m_trace->close();
  delete dut;
  delete cmd_lines_options;

  exit(exit_val);

}
