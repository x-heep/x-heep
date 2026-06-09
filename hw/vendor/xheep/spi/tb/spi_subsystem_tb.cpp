// ================================ INCLUDES ================================

// verilator libraries
#include <verilated.h>
#include <verilated_fst_c.h>

#include <cstdio>
#include <iostream>
#include <cassert>
#include <cstdint>
#include <getopt.h>
#include <time.h>
#include <random>
#include <deque>

// dut
#include "Vspi_subsystem_tb_wrapper.h"

// ================================ DEFINES ================================

// AXI datasize

/* _-|-__-|-__-|-__-|-__-|-_ MODIFIABLE VALUES  _-|-__-|-__-|-__-|-__-|-_ */

// change axi datasize according to parallelism : 0 = 32bit , 1 = 64bit
#define AXI_DATA_SIZE_IS_64_n32 1

#define CHEK_ENABLE 0
/*
    Enable the testbench execute a comparison between written data and read data.
    Works only if:
    - Data is alligned
    - w.strb is just ones
    - data is not random (because random data doesn't take into account byte lane rotation)
*/

/* _-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-__-|-_  */

// waves file
#define FST_FILENAME "logs/waves.fst"

// color macros
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define BOLD    "\033[1m" 

// time constants
// clock period is 2ps
#define MAX_SIM_CYCLES 2e7
#define MAX_SIM_TIME (MAX_SIM_CYCLES * 2)
#define END_OF_RESET_TIME 10
#define WATCHDOG_TIMEOUT 2e6
#define SWRST_CYCLES 10
#define END_OF_TEST_TIMEOUT 10
#define IDLE_CYCLES 2

// SPI_HOST base address
#define SPI_FLASH_START_ADDRESS 0x0

// SPI_SUBSYSTEM base address
#define SPI_SUBSYSTEM_START_ADDRESS 0x8000

// SPI_HOST register offsets
#define SPI_HOST_CONTROL_OFFSET 0x10
#define SPI_HOST_CSID_OFFSET 0x20
#define SPI_HOST_INTR_ENABLE_OFFSET 0x4
#define SPI_HOST_EVENT_ENABLE_OFFSET 0x38
#define SPI_HOST_ERROR_ENABLE_OFFSET 0x30
#define SPI_HOST_CONFIGOPTS_0_OFFSET 0x18

// SPI_SUBSYSTEM register offsets
#define SPI_SUBSYSTEM_CONTROL_OFFSET 0x0

// default values
#define DEFAULT_AXI_NUM 5
#define DEFAULT_AXI_SIZE 2
#define DEFAULT_AXI_ADDR 0x021fff

// Global variables

const uint64_t DEFAULT_AXI_WDATA_64[DEFAULT_AXI_NUM] = {
    0x3210000000000000,
    0x0000000000007654,
    0x00000000BA980000,
    0x0000FEDC00000000,
    0x1111000000000000
};

const uint64_t DEFAULT_AXI_WDATA_32[DEFAULT_AXI_NUM] = {
    0x0000000032100000,
    0x0000000000007654,
    0x00000000BA980000,
    0x000000000000FEDC,
    0x0000000011110000
};

// write strobe signal in the axi write channel
#define AXI_WSTRB_64 0xFF
#define AXI_WSTRB_32 0x0F

// Options usage example: make clean-sim TB_ARGS="--num_beats 3 --size_beat 4 --addr 0x021004 --random_data true"

// ================================ FUNCTION PROTOTYPES ================================

void clkGen(Vspi_subsystem_tb_wrapper *dut);
void rstDut(Vspi_subsystem_tb_wrapper *dut, vluint64_t sim_time);
void runCycles(unsigned int ncycles, Vspi_subsystem_tb_wrapper *dut, uint8_t gen_waves, VerilatedFstC *trace);
void clearHandshake(Vspi_subsystem_tb_wrapper* dut);
void genRegWriteReq(Vspi_subsystem_tb_wrapper* dut, uint64_t base, uint64_t offset, uint32_t reg_data);
void genAxiManagerAW(Vspi_subsystem_tb_wrapper* dut, uint64_t addr, uint64_t num, uint64_t size);
void genAxiManagerW(Vspi_subsystem_tb_wrapper* dut, uint64_t wdata);
void genAxiManagerB(Vspi_subsystem_tb_wrapper* dut);
void genAxiManagerAR(Vspi_subsystem_tb_wrapper* dut, uint64_t addr, uint64_t num, uint64_t size);
void genAxiManagerR(Vspi_subsystem_tb_wrapper* dut);

/*

--------------------------------------------------------------------------------
================================================================================
                                    MAIN
================================================================================
--------------------------------------------------------------------------------

*/

int main(int argc, char *argv[]){

    std::cout<< BLUE << BOLD << "Bus size currently set to "<< 32+32*AXI_DATA_SIZE_IS_64_n32<<
    ", if incorrect, change the define AXI_DATA_SIZE_IS_64_n32 in the testbench"<< RESET << std::endl;

    // Define command-line options
    const option longopts[] = {
        {"gen_waves", required_argument, NULL, 'w'},
        {"num_beats", required_argument, NULL, 'n'},
        {"size_beat", required_argument, NULL, 's'},
        {"addr", required_argument, NULL, 'a'},
        {"random_data", required_argument, NULL, 'r'},
        {NULL, 0, NULL, 0}
    };

    // Process command-line options

    int opt; // current option
    bool gen_waves = true;
    unsigned int axi_num = DEFAULT_AXI_NUM;
    unsigned int axi_size = DEFAULT_AXI_SIZE;
    uint32_t axi_addr = DEFAULT_AXI_ADDR;
    unsigned int random;

    std::cout << YELLOW << BOLD << "TCL arguments:" << RESET << std::endl;
    
    while ((opt = getopt_long(argc, argv, "w:n:s:a:r", longopts, NULL)) >= 0){
        unsigned long tmp = strtoul(optarg, NULL, 0);
        switch (opt){

            case 'w': // generate waves
                if (!strcmp(optarg, "true")) {
                    gen_waves = 1;
                    std::cout<<"Waves enabled"<<std::endl;
                }
                else {
                    gen_waves = 0;
                    std::cout<<"Waves disabled"<<std::endl;
                }
                break;
                
            case 'n': // number of beats
                if ( atoi(optarg) >= 1 && atoi(optarg) <= 17 ){
                    axi_num = atoi(optarg);
                }
                else {
                    std::cout<< RED << BOLD << "Incorrect value for num_beats"<< RESET << std::endl;
                    exit(EXIT_FAILURE);
                }
                std::cout<<"Beat number set to "<<axi_num<<std::endl;
                break;

            case 's': // size of beats (bytes)
                if ((atoi(optarg) == 1) || (atoi(optarg) == 2) || (atoi(optarg) == 4) || ((atoi(optarg) == 8) && (AXI_DATA_SIZE_IS_64_n32)) ) {
                    axi_size = atoi(optarg);
                }
                else {
                    std::cout<< RED << BOLD << "Incorrect value for size_beat"<< RESET << std::endl;
                    exit(EXIT_FAILURE);
                }
                std::cout<<"Beat size set to "<<axi_size<<std::endl;
                break;

            case 'a': // address of first beat (bytes)
                if ((uint32_t)strtoul(optarg, NULL, 0)<=0x00ffffff) {
                    axi_addr = strtoul(optarg, NULL, 0);
                }
                else {
                    std::cout<< RED << BOLD << "Incorrect value for addr_beat"<< RESET <<std::endl;
                    exit(EXIT_FAILURE);
                }
                std::cout<<"Axi address set to 0x"<< std::hex << axi_addr << std::dec << std::endl;
                break;

            case 'r': // force default vector (bytes)
                if (!strcmp(optarg, "true")) {
                    random = 1;
                    std::cout<<"Using random data vector"<<std::endl;
                }
                else{
                    random = 0;
                    std::cout<<"Using default data vector, "<< BOLD <<"ignoring other arguments"<< RESET << std::endl;
                }
                break;
            
            default:
                std::cout<< RED << BOLD << "Unrecognized option, terminating"<< RESET <<std::endl;
                exit(EXIT_FAILURE);
        }
    }

    // Create Verilator simulation context
    VerilatedContext *cntx = new VerilatedContext;

    if (gen_waves)
    {
        Verilated::mkdir("logs");
        cntx->traceEverOn(true);
    }

    // Instantiate DUT
    Vspi_subsystem_tb_wrapper *dut = new Vspi_subsystem_tb_wrapper(cntx);

    // Set the file to store the waveforms in
    VerilatedFstC *trace = NULL;
    if (gen_waves)
    {
        trace = new VerilatedFstC;
        dut->trace(trace, 10);
        trace->open(FST_FILENAME);
    }

    // --------------------------------------------------------------------
    //                      Random Data Generation 
    // --------------------------------------------------------------------

    std::random_device rd;  
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<uint64_t> dist(0, UINT64_MAX);
    std::deque<uint64_t> axi_wdata_vector;

    if(random){
        for (int i = 0; i < axi_num; ++i) {
            uint64_t rnd = dist(gen);
            axi_wdata_vector.push_back(rnd);
        }
    }else{
        axi_num = DEFAULT_AXI_NUM;
        axi_addr = DEFAULT_AXI_ADDR;
        axi_size = DEFAULT_AXI_SIZE;
        
        for(int i=0; i<DEFAULT_AXI_NUM; i++)
            axi_wdata_vector.push_back( AXI_DATA_SIZE_IS_64_n32 ? DEFAULT_AXI_WDATA_64[i] : DEFAULT_AXI_WDATA_32[i] );
    }
    std::cout<< BLUE << BOLD << "AXI attributes:" << RESET << std::endl;
    std::cout<< BLUE << "       LENGHT " << RESET << axi_num << std::endl;
    std::cout<< BLUE << "       SIZE " << RESET << axi_size << std::endl;
    std::cout<< BLUE << "       ADDR " << RESET << "0x" << std::hex << axi_addr << std::dec << std::endl;
    std::cout<< BLUE << BOLD << "AXI Write Data vector:" << RESET << std::endl;
    for (const auto& x : axi_wdata_vector) {
        printf("0x%016llX\n", x);
    }

    /*
      __    __    __    __    __    __    __    __    __    __    __    __    __    __  
    _|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |_

                                    Simulation Program
      __    __    __    __    __    __    __    __    __    __    __    __    __    __  
    _|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |_

    */

    // Definition of variables

    enum state_t{
        IDLE,
        CFG_SPISUBSYS_CONTROL,
        CFG_SPIHOST_SWRST_1,
        CFG_SPIHOST_SWRST_WAIT,
        CFG_SPIHOST_SWRST_0,
        CFG_SPIHOST_CSID,
        CFG_SPIHOST_INTR_ENABLE,
        CFG_SPIHOST_EVENT_ENABLE,
        CFG_SPIHOST_ERROR_ENABLE,
        CFG_SPIHOST_CONFIGOPTS_0,
        CFG_SPIHOST_CONTROL,
        AXI_AW_W,
        AXI_B,
        AXI_AR,
        AXI_R,
        FINISH
    };
    state_t state = CFG_SPISUBSYS_CONTROL;
    state_t prev_state;
    uint64_t base;
    uint64_t offset;
    uint32_t reg_data;
    uint64_t wdata;
    uint64_t rdata;
    std::deque<uint64_t> axi_rdata_vector;
    unsigned int deassert_AW = 0;
    unsigned int deassert_W = 0;
    unsigned int msg_printed = 0;
    unsigned int exit_timer = 0;
    unsigned int end_of_sim = 0;
    unsigned int watchdog = 0;
    unsigned int beat_count = 0;
    unsigned int sw_rst_cnt=0;
    unsigned int idle_cycles_cnt=0;
    unsigned long int t1,t2,t3;

    std::cout << GREEN << BOLD << "Starting simulation ..." << RESET << std::endl;

    while (!cntx->gotFinish() && cntx->time() < MAX_SIM_TIME){
        // Generate clock and reset
        rstDut(dut, cntx->time());
        clkGen(dut);

        // Evaluate simulation step
        dut->eval();

        if (dut->clk_i == 1 && cntx->time() > END_OF_RESET_TIME){

            clearHandshake(dut);
            reg_data = 0;

            switch (state){
                case IDLE:
                    if(idle_cycles_cnt++ > IDLE_CYCLES){
                        state = CFG_SPISUBSYS_CONTROL;
                        idle_cycles_cnt = 0;
                    }
                    break;

                case CFG_SPISUBSYS_CONTROL:
                    if(!msg_printed){
                        std::cout<<"Configuring spi_subsystem control ... "<<std::endl;
                        msg_printed=1;
                    }
                    base = SPI_SUBSYSTEM_START_ADDRESS;
                    offset = SPI_SUBSYSTEM_CONTROL_OFFSET;
                    reg_data = reg_data | (1 << 0);     // use_axi
                    reg_data = reg_data | (1 << 1);     // a2f_ctr_poweron_en
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->subsys_reg_ready_o && !dut->subsys_reg_error_o){
                        state = CFG_SPIHOST_SWRST_1;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_SWRST_1:
                    if(!msg_printed){
                        std::cout<<"Asserting spi_host sw_rst ... "<<std::endl;
                        msg_printed=1;
                    }
                    base = SPI_FLASH_START_ADDRESS;
                    offset = SPI_HOST_CONTROL_OFFSET;
                    reg_data = reg_data | (1 << 30);
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = CFG_SPIHOST_SWRST_WAIT;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_SWRST_WAIT:
                    // wait some clock cycles while sw_rst = 1
                    if(sw_rst_cnt++ >= SWRST_CYCLES){
                        state = CFG_SPIHOST_SWRST_0;
                    }
                    break;

                case CFG_SPIHOST_SWRST_0:
                    if(!msg_printed){
                        std::cout<<"Deasserting spi_host sw_rst ... "<<std::endl;
                        msg_printed=1;
                    }              
                    base = SPI_FLASH_START_ADDRESS;
                    offset = SPI_HOST_CONTROL_OFFSET;
                    reg_data = reg_data & ~(1 << 30);
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = CFG_SPIHOST_CSID;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_CSID:
                    if(!msg_printed){
                        std::cout<<"Configuring spi_host csid ... "<<std::endl;
                        msg_printed=1;
                    }                     
                    offset = SPI_HOST_CSID_OFFSET;
                    reg_data = reg_data & ~(1 << 0);
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = CFG_SPIHOST_INTR_ENABLE;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_INTR_ENABLE:
                    if(!msg_printed){
                        std::cout<<"Configuring spi_host intr_enable ... "<<std::endl;
                        msg_printed=1;
                    }          
                    offset = SPI_HOST_INTR_ENABLE_OFFSET;
                    reg_data = reg_data | 0b11;
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = CFG_SPIHOST_EVENT_ENABLE;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_EVENT_ENABLE:
                    if(!msg_printed){
                        std::cout<<"Configuring spi_host event_enable ... "<<std::endl; 
                        msg_printed=1;
                    }  
                    offset = SPI_HOST_EVENT_ENABLE_OFFSET;
                    reg_data = reg_data | 0b111111;
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = CFG_SPIHOST_ERROR_ENABLE;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_ERROR_ENABLE:
                    if(!msg_printed){
                        std::cout<<"Configuring spi_host error_enable ... "<<std::endl;                    
                        msg_printed=1;
                    } 
                    offset = SPI_HOST_ERROR_ENABLE_OFFSET;
                    reg_data = reg_data | 0b11111;
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = CFG_SPIHOST_CONFIGOPTS_0;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_CONFIGOPTS_0:
                    if(!msg_printed){
                        std::cout<<"Configuring spi_host configopts[0] ... "<<std::endl;                    
                        msg_printed=1;
                    } 
                    offset = SPI_HOST_CONFIGOPTS_0_OFFSET;
                    // reg_data[15:0] = 0x0000; // clkdiv
                    reg_data = reg_data | 0x0000;
                    // reg_data[19:16] = 0x0000; // csnidle
                    reg_data = reg_data | (0x0 << 16);
                    // reg_data[23:20] = 0x0001; // csntrail
                    reg_data = reg_data | (0x1 << 20);
                    // reg_data[27:24] = 0x0001; // csnlead
                    reg_data = reg_data | (0x1 << 24);
                    // reg_data[29] = 1; // fullcyc
                    reg_data = reg_data | (0b1 << 29);
                    // reg_data[30] = 0; // cpha
                    reg_data = reg_data | (0b0 << 30);
                    // reg_data[31] = 0; // cpol
                    reg_data = reg_data | (0b0 << 31);
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = CFG_SPIHOST_CONTROL;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case CFG_SPIHOST_CONTROL:
                    if(!msg_printed){
                        std::cout<<"Configuring spi_host control ... "<<std::endl;                    
                        msg_printed=1;
                    } 
                    offset = SPI_HOST_CONTROL_OFFSET;
                    // reg_data[29] = 1; // output_en
                    reg_data = reg_data | (0b1 << 29);
                    // reg_data[31] = 1; // spien
                    reg_data = reg_data | (0b1 << 31);
                    // reg_data[0:7] = RESVAL = 0x7f // rx_watermark
                    reg_data = reg_data | (0x7F << 0);
                    // reg_data[8:15] = RESVAL = 0x0 // tx_watermark
                    reg_data = reg_data | (0x00 << 16);
                    genRegWriteReq(dut,base,offset,reg_data);
                    if(dut->spihost_reg_ready_o && !dut->spihost_reg_error_o){
                        state = AXI_AW_W;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case AXI_AW_W:
                    // AXI write operation : AW and W
                    if(!msg_printed){
                        std::cout<<"Writing on AXI AW and W channels ... "<<std::endl;
                        t1=cntx->time();  
                        msg_printed=1;
                    }
                    // AW
                    if(!deassert_AW){
                        genAxiManagerAW(dut,axi_addr,axi_num,axi_size);
                    }else{
                        dut->aw_valid_i = 0;
                    }
                    if(dut->aw_ready_o){
                        deassert_AW = 1;
                    }
                    // W
                    if(!deassert_W){
                        wdata = axi_wdata_vector[beat_count];
                        genAxiManagerW(dut,wdata);
                        dut->w_last_i = (beat_count == axi_num-1) ? 1 : 0;
                    }else{
                        dut->w_valid_i = 0;
                        dut->w_last_i = 0;
                    }
                    if(dut->w_ready_o){
                        if(beat_count == axi_num-1){
                            deassert_W = 1;
                            beat_count = 0;
                        }else{
                            beat_count++;
                        }
                    }
                    if(deassert_AW && deassert_W){
                        state = AXI_B;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                        beat_count=0;
                    }
                    break;

                case AXI_B:
                    if(!msg_printed){
                        std::cout<<"Responding on AXI B channel ... "<<std::endl;                  
                        msg_printed=1;
                    }
                    genAxiManagerB(dut);
                    if(dut->b_valid_o){
                        state = AXI_AR;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case AXI_AR:
                    if(!msg_printed){
                        std::cout<<"Writing on AXI AR channel ... "<<std::endl;
                        t2=cntx->time();        
                        msg_printed=1;
                    }
                    genAxiManagerAR(dut,axi_addr,axi_num,axi_size);
                    if(dut->ar_ready_o){
                        state = AXI_R;
                        std::cout<<" ... done."<<std::endl;
                        msg_printed = 0;
                    }
                    break;

                case AXI_R:
                    if(!msg_printed){
                        std::cout<<"Responding on AXI R channel ... "<<std::endl;               
                        msg_printed=1;
                    }
                    genAxiManagerR(dut);
                    if(dut->r_valid_o){
                        rdata = AXI_DATA_SIZE_IS_64_n32 ?  dut->r_data_o : 0x00000000FFFFFFFF & dut->r_data_o;
                        axi_rdata_vector.push_back(rdata);
                        if(dut->r_last_o){
                            state = FINISH;
                            std::cout<<" ... done."<<std::endl;
                            msg_printed = 0;
                        }
                    }
                    break;

                case FINISH:
                    if(!msg_printed){
                        std::cout<< GREEN << BOLD << "Simulation terminated correctly"<< RESET << std::endl;
                        t3=cntx->time();
                        msg_printed=1;
                    }
                    end_of_sim = 1;
                    break;

                default : end_of_sim = 1;
            }

            // Update input signals
            dut->eval();

            // Check for exit conditions
            if (prev_state != state) watchdog = 0;
            else watchdog++;
            if (watchdog > WATCHDOG_TIMEOUT) {
                std::cout<< RED << BOLD << "Watchdog timeout reached: terminating simulation."<< RESET << std::endl;
                break;
            }
            prev_state = state;
            if (end_of_sim)
            {
                if (exit_timer++ == END_OF_TEST_TIMEOUT) {
                    break;
                }
            }
        }

        // Dump waveforms and advance simulation time
        if (gen_waves) trace->dump(cntx->time());
        cntx->timeInc(1);
    }

    std::cout << YELLOW << BOLD << "AXI Read data:" << RESET << std::endl;
    for (const auto& x : axi_rdata_vector) {
        if(AXI_DATA_SIZE_IS_64_n32){
            printf("    0x%016llX\n", x);
        }else{
            printf("    0x%08llX\n", x);
        }
    }

// --- Data Comparison Section ---
// Random data doesn't work with data check because active byte lane rotation is not implemented with random data
    if(CHEK_ENABLE){
        std::cout << std::endl << BLUE << BOLD << "========================================" << RESET << std::endl;
        std::cout << BOLD << "          DATA INTEGRITY CHECK" << RESET << std::endl;
        std::cout << BLUE << BOLD << "========================================" << RESET << std::endl;

        bool test_failed = false;
        
        // First, verify if the number of read beats matches the number of written beats
        if (axi_rdata_vector.size() != axi_wdata_vector.size()) {
            std::cout << RED << BOLD << "ERROR: Mismatch in number of beats!" << RESET << std::endl;
            std::cout << "Expected: " << axi_wdata_vector.size() << " | Received: " << axi_rdata_vector.size() << std::endl;
            test_failed = true;
        } else {
            // Iterate through the vectors and compare each beat
            for (size_t i = 0; i < axi_wdata_vector.size(); ++i) {
                uint64_t expected = axi_wdata_vector[i];
                uint64_t received = axi_rdata_vector[i];

                // If the bus is 32-bit, mask the upper 32 bits to ensure a fair comparison
                if (!AXI_DATA_SIZE_IS_64_n32) {
                    expected &= 0x00000000FFFFFFFFULL;
                }

                if (expected != received) {
                    // Print detailed error message on mismatch
                    printf(RED "Mismatch at beat [%zu]: Expected 0x%016llX, Got 0x%016llX" RESET "\n", i, expected, received);
                    test_failed = true;
                } else {
                    // Confirm successful match for the current beat
                    printf(GREEN "Beat [%zu]: Pass (0x%016llX)" RESET "\n", i, received);
                }
            }
        }

        // Final simulation status report
        if (test_failed) {
            std::cout << RED << BOLD << "\nTEST STATUS: FAILED" << RESET << std::endl;
        } else {
            std::cout << GREEN << BOLD << "\nTEST STATUS: SUCCESS" << RESET << std::endl;
        }
        std::cout << BLUE << BOLD << "========================================" << RESET << std::endl << std::endl;
    }
// --- End of Data Comparison Section ---

    std::cout << BOLD << "-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-."<< RESET << std::endl;
    std::cout << BOLD << "Number of cycles :"<< RESET << std::endl;
    std::cout <<"   WRITE: " << (t2-t1)/2 << std::endl;
    std::cout <<"   READ: " << (t3-t2)/2 << std::endl;

    // Simulation complete
    dut->final();

    // Clean up and exit
    if (gen_waves) trace->close();
    delete dut;
    delete cntx;
    
    return 0;
}

void clkGen(Vspi_subsystem_tb_wrapper *dut){

    dut->clk_i ^= 1;
}

void rstDut(Vspi_subsystem_tb_wrapper *dut, vluint64_t sim_time){

    dut->rst_ni = 1;
    if (sim_time > 1 && sim_time < END_OF_RESET_TIME)
    {
        dut->rst_ni = 0;
    }
}

void runCycles(unsigned int ncycles, Vspi_subsystem_tb_wrapper *dut, uint8_t gen_waves, VerilatedFstC *trace){

    VerilatedContext *cntx = dut->contextp();
    for (unsigned int i = 0; i < (2 * ncycles); i++)
    {
        // Generate clock
        clkGen(dut);

        // Evaluate the DUT
        dut->eval();

        // Save waveforms
        if (gen_waves)
            trace->dump(cntx->time());

        cntx->timeInc(1);
    }
}

void clearHandshake(Vspi_subsystem_tb_wrapper* dut){

    dut->subsys_reg_valid_i=0;
    dut->spihost_reg_valid_i=0;
    dut->aw_valid_i=0;
    dut->w_valid_i=0;
    dut->w_last_i=0;
    dut->b_ready_i=0;
    dut->ar_valid_i=0;
}

void genRegWriteReq(Vspi_subsystem_tb_wrapper* dut, uint64_t base, uint64_t offset, uint32_t reg_data){
    
    switch(base){
        case  SPI_SUBSYSTEM_START_ADDRESS:
            dut->subsys_reg_addr_i  = offset;
            dut->subsys_reg_wdata_i = reg_data;
            dut->subsys_reg_wstrb_i  = 0x0F;
            dut->subsys_reg_write_i = 1;
            dut->subsys_reg_valid_i = 1;
            break;
        case SPI_FLASH_START_ADDRESS:
            dut->spihost_reg_addr_i  = offset;
            dut->spihost_reg_wdata_i = reg_data;
            dut->spihost_reg_wstrb_i  = 0x0F;
            dut->spihost_reg_write_i = 1;
            dut->spihost_reg_valid_i = 1;
            break;
        default: exit(EXIT_FAILURE);
    }
}

void genAxiManagerAW(Vspi_subsystem_tb_wrapper* dut, uint64_t addr, uint64_t num, uint64_t size){
     
   uint64_t s;

    switch(size){
        case(1): s = 0; break;
        case(2): s = 1; break;
        case(4): s = 2; break;
        case(8): s = 3; break;
        default: exit(EXIT_FAILURE);
    }

    dut->aw_addr_i  = addr;
    dut->aw_len_i   = num - 1;
    dut->aw_size_i  = s; 
    dut->aw_valid_i = 1;

}

void genAxiManagerW(Vspi_subsystem_tb_wrapper* dut, uint64_t wdata){
    
    dut->w_data_i =  AXI_DATA_SIZE_IS_64_n32 ? wdata : (0x00000000FFFFFFFF & wdata);
    dut->w_strb_i  = AXI_DATA_SIZE_IS_64_n32 ? AXI_WSTRB_64 : AXI_WSTRB_32;
    dut->w_valid_i = 1;

}

void genAxiManagerB(Vspi_subsystem_tb_wrapper* dut){
    dut->b_ready_i=1;
}
                    
void genAxiManagerAR(Vspi_subsystem_tb_wrapper* dut, uint64_t addr, uint64_t num, uint64_t size){

   uint64_t s;

    switch(size){
        case(1): s = 0; break;
        case(2): s = 1; break;
        case(4): s = 2; break;
        case(8): s = 3; break;
        default: exit(EXIT_FAILURE);
    }

    dut->ar_addr_i  = addr;
    dut->ar_len_i   = num - 1;
    dut->ar_size_i  = s; 
    dut->ar_valid_i = 1;  
}

void genAxiManagerR(Vspi_subsystem_tb_wrapper* dut){
    dut->r_ready_i=1;
}