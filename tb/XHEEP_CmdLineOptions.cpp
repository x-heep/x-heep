#include "XHEEP_CmdLineOptions.hh"
#include <iostream>
#include <string>

XHEEP_CmdLineOptions::XHEEP_CmdLineOptions(int argc, char* argv[]) // define default constructor
{
    this->argc = argc;
    this->argv = argv;
}

std::string XHEEP_CmdLineOptions::getCmdOption(int argc, char* argv[], const std::string& option)
{
    std::string cmd;
     for( int i = 0; i < argc; ++i)
     {
          std::string arg = argv[i];
          size_t arg_size = arg.length();
          size_t option_size = option.length();

          if(arg.find(option)==0){
            cmd = arg.substr(option_size,arg_size-option_size);
          }
     }
     return cmd;
}

bool XHEEP_CmdLineOptions::get_use_openocd()
{

  std::string arg_openocd = this->getCmdOption(this->argc, this->argv, "+openOCD=");;

  bool use_openocd = false;

  if(arg_openocd.empty()){
    std::cout<<"[TESTBENCH]: No OpenOCD is used"<<std::endl;
  } else {
    std::cout<<"[TESTBENCH]: OpenOCD is used"<<std::endl;
    use_openocd = true;
  }

  return use_openocd;
}


std::string XHEEP_CmdLineOptions::get_firmware()
{

  std::string firmware = this->getCmdOption(this->argc, this->argv, "+firmware=");

  if(firmware.empty()){
    std::cout<<"[TESTBENCH]: No firmware  specified"<<std::endl;
  } else {
    std::cout<<"[TESTBENCH]: loading firmware  "<<firmware<<std::endl;
  }

  return firmware;
}


unsigned long long XHEEP_CmdLineOptions::get_max_sim_time(bool& run_all)
{

  std::string arg_max_sim_time = this->getCmdOption(this->argc, this->argv, "+max_sim_time=");
  unsigned long long max_sim_time;

  max_sim_time     = 0;
  if(arg_max_sim_time.empty()){
    std::cout<<"[TESTBENCH]: No Max time specified"<<std::endl;
    run_all = true;
  } else {
    size_t u;
    max_sim_time = stoull(arg_max_sim_time, &u);
    if(u == arg_max_sim_time.length())  max_sim_time *= CLK_PERIOD_ps; // no suffix: clock cycles
    else if(arg_max_sim_time[u] == 'p') max_sim_time *= 1;             // "p" or "ps" suffix: picoseconds
    else if(arg_max_sim_time[u] == 'n') max_sim_time *= 1000;          // "n" or "ns" suffix: nanoseconds
    else if(arg_max_sim_time[u] == 'u') max_sim_time *= 1000000;       // "u" or "us" suffix: microseconds
    else if(arg_max_sim_time[u] == 'm') max_sim_time *= 1000000000;    // "m" or "ms" suffix: milliseconds
    else if(arg_max_sim_time[u] == 's') max_sim_time *= 1000000000000; // "s" suffix: seconds
    else {
      std::cout<<"[TESTBENCH]: ERROR: Unsupported suffix '"<<arg_max_sim_time.substr(u)<<"' for +max_sim_time"<<std::endl;
      exit(EXIT_FAILURE);
    }
    std::cout<<"[TESTBENCH]: Max sim time is "<<(max_sim_time/CLK_PERIOD_ps)<<" clock cycles"<<std::endl;
  }

  return max_sim_time;
}

unsigned int XHEEP_CmdLineOptions::get_boot_sel()
{
  std::string arg_boot_sel = this->getCmdOption(this->argc, this->argv, "+boot_sel=");
  unsigned int boot_sel     = 0;

  if(arg_boot_sel.empty()){
    std::cout<<"[TESTBENCH]: No Boot Option specified, using jtag (boot_sel=0)"<<std::endl;
    boot_sel = 0;
  } else {
    if(arg_boot_sel.compare("1") == 0) {
      boot_sel = 1;
      std::cout<<"[TESTBENCH]: Booting from flash"<<std::endl;
    } else if(arg_boot_sel.compare("0") == 0) {
      boot_sel = 0;
      std::cout<<"[TESTBENCH]: Booting from jtag"<<std::endl;
    } else {
      std::cout<<"[TESTBENCH]: Wrong Boot Option specified (jtag, flash) - using jtag (boot_sel=0)"<<std::endl;
      boot_sel = 0;
    }
  }

  return boot_sel;
}

bool XHEEP_CmdLineOptions::get_execute_from_flash()
{
  std::string arg = this->getCmdOption(this->argc, this->argv, "+execute_from_flash=");

  if(arg.empty() || arg.compare("0") == 0) {
    return false;
  } else if(arg.compare("1") == 0) {
    return true;
  } else {
    std::cout<<"[TESTBENCH]: Wrong execute_from_flash value (use 0 or 1) - defaulting to 0"<<std::endl;
    return false;
  }
}
