#ifndef XHEEP_TB_UTIL_H
#define XHEEP_TB_UTIL_H

#include <iostream>

#define CLK_FREQUENCY_kHz (100*1000)
#define CLK_PERIOD_ps (1000*1000*1000 / CLK_FREQUENCY_kHz)

class XHEEP_CmdLineOptions // declare Calculator class
{

  public: // public members
    XHEEP_CmdLineOptions(int argc, char* argv[]); // default constructor

    std::string getCmdOption(int argc, char* argv[], const std::string& option); // get options from cmd lines
    bool get_use_openocd();
    std::string get_firmware();
    unsigned long long get_max_sim_time(bool& run_all);
    unsigned int get_boot_sel();
    bool get_execute_from_flash();
    int argc;
    char** argv;

};



#endif
