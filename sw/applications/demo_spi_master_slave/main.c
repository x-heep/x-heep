/* Copyright 2025 EPFL
 Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

 File: demo_spi_master_slave.c
 Author: Juan Sapriza
 Date: 03/02/2025
 Description: This demo shows the exchange of data between two X-HEEP instances on two FPGAs. 
 Requirements: 
 * 2 pynq-z2 FPGAs
 * 2 EPFL programmers with two jumpers each
 * 5 female-female dupont cables (>10cm)
 * 4 female-male dupont cables (>10cm)
 * 3 USB-A to micro USB cables (or two power sources and one USB)

 Setup:
 1) Prepare the FPGAs. 
 1.a) Make the bitstreams of the FPGAs with make mcu-gen; make vivado-fpga FPGA_BOARD=pynq-z2
 1.b) One at a time, power up the FPGAs (with the power source, or by connecting the USB).
      Make sure the jumper next to the switches is in REG if you are using the source, or USB if you are using the USB. 
 1.c) Turn on the FPGA (a red LED will light up), and program it: make vivado-fpga-pgm FPGA_BOARD=pynq-z2. LED3 should light up green.
 1.d) Without powering off the first FPGA, repeat the process for the other one. 
 1.e) Put SW1 towards the outside of the board, and SW0 towards the inside of the board (to let X-HEEP know it should load the program from flash)
 2) Load the programs
 2.a) Connect both EPFL programmers through the PMOD connectors to the FPGAs. 
 2.b) Make sure they both have the jumpers on. The power option should be USB.
 2.c) Build the application: make app PROJECT=demo_spi_master_slave 
 2.d) Connect one USB cable to one programmer and load the flash: make flash-prog   
 2.e) Click on the reset button (BTN3) and a red and green LED should start to flash. 
 2.f) Disconnect the USB from the programmer, and switch it's jumper to the PMOD option.
 2.g) Repeat the process with the other FPGA. 
 3) Connect the FPGAs
 3.a) On the top three lines of pins of the diagram below there are the SPI slave pins. Connect the ones from one board 
      to the master ones of the other board. The pins stand for:
      Role (Ro), SPI clock (Ck), Chip select (Cs), Master-out-Slave-in (Mo), Master-in-Slave-out (Mi).
 3.b) For flexible roles (decided at run time), connect the master pins of one board to the slave pins of the other and vice versa (8 wires),
      and connect Ro of both boards together.
 3.c) For fixed roles, connect only the master pins of the master board to the slave pins of the slave board (4 wires),
      leave Ro unconnected on the master board, and connect Ro to ground (GD) on the slave board.
 3.d) For self-test (single board acting both as master and slave), connect the master pins on the board to the corresponding slave pins
      and leave Ro unconnected.
 4) Have fun
 4.a) Reset both boards. 
 4.b) The one that resets first (master) will light a yellow LED and start requesting a read from the slave (toggling between cyan and white).
 4.c) The one that resets the last (slave) will turn the blue LED and go to sleep. 
 4.d) If the transaction is successful, the master will leave the green LED on and the last LED (LD0) will light up.
      If the transaction fails (common after the first synchronization), the master will leave the red LED on and both LD0 and LD1 will light up. 
 4.e) You can restart the demo by resetting the master. 
 4.f) You can invert the roles by resetting both and releasing first the former slave.
_____________________________________________________
              17      13  11   9                     |
  ...[  ][  ][Vd][  ](Ro)(Ck)[GD][  ][  ][  ][Vd] 1  |    }
  ...[  ][  ][  ][  ][  ][  ][  ](Cs)[  ][  ][  ] 2  |    }
                                   8             ____|_   }-- Slave
             ... AR3 AR2 AR1 AR0                 |    |   }
 [  ][  ][  ][  ](Mo)(Mi)[  ][  ] J4             |HDMI|   }
                                                 |____|
                               SPI               ____|_
                         {   (Mi)[  ]            |    |
                Master --{   (Ck)(Mo)            |PMOD|
                         {   (Cs)[GD]            |  A |
                                                 |____|
                                                     |

Disclaimer: 
The FPGAs can have different bitstreams as long as the pinout remains the same. 
The two softwares instead NEED TO BE THE SAME. We are cheating in this demo by using the same software in both FPGAs.
This allows us to know the address of the buffer with the data on the slave X-HEEP (because it is linked to the same
location as in the master!). Even adding one tiny printf on one of the devices might make this addresses to not match, 
so the application will fail (you will read from the wrong address).
*/

#include <stdint.h>
#include <stdlib.h>

#include "x-heep.h"
#include "spi_host.h"
#include "spi_slave_sdk.h"
#include "gpio.h"
#include "hart.h"
#include "timer_sdk.h"

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA 1
#define PRINTF_IN_SIM 0

#if TARGET_SIM && PRINTF_IN_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...)
#endif

#if TARGET_SIM
#define ROLE_LOGIC(x) (~(x))
#else
#define ROLE_LOGIC(x) (x)
#endif

#define GPIO_LD5_R  11
#define GPIO_LD5_B  12
#define GPIO_LD5_G  13

#define DUMMY_CYCLES  32
#define GPIO_ROLE 10

#define DATA_LENGTH_B   100
#define DATA_CHUNK_W    1
#define DATA_CHUNK_B    1
#define CHUNKS_NW       (DATA_LENGTH_B/(DATA_CHUNK_W*4)) + ((DATA_LENGTH_B%(DATA_CHUNK_W*4))!=0)
#define CHUNKS_NB       (DATA_LENGTH_B/DATA_CHUNK_B)


// Buffer from where we will ask the SPI slave to read from. 
uint8_t buffer_read_from[DATA_LENGTH_B] = {
      1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  16,  17,  18,  19,  20,
     21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  32,  33,  34,  35,  36,  37,  38,  39,  40,
     41,  42,  43,  44,  45,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,
     61,  62,  63,  64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  80,
     81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,  92,  93,  94,  95,  96,  97,  98,  99, 100
};

// Buffer where we will copy the data read by the SPI host. 
uint8_t buffer_read_to  [DATA_LENGTH_B];

void __attribute__((aligned(4), interrupt)) handler_irq_timer(void) {
    timer_arm_stop();
    timer_irq_clear();
    return;   
}

int main(){
    uint16_t i;
    uint8_t role;

    // Configure a GPIO to use to set the role of both FPGAs.
    // GPIOs by default are set high. 
    // If one of the devices detects it is the master, it 
    // will lower the GPIO. The other, if it finds the 
    // GPIO lowered will know it should be a slave.
    gpio_cfg_t pin_cfg = {
    .pin = GPIO_ROLE,
    .mode = GpioModeIn,
    .en_input_sampling = true,
    .en_intr = false,
    };
    gpio_config(pin_cfg);

    // Configure the pynq's internal LEDs to show which is the slave
    // and which the master.  
    pin_cfg.mode    = GpioModeOutPushPull;
    pin_cfg.pin     = GPIO_LD5_R;
    gpio_config(pin_cfg);
    pin_cfg.pin     = GPIO_LD5_G;
    gpio_config(pin_cfg);
    pin_cfg.pin     = GPIO_LD5_B;
    gpio_config(pin_cfg);

    // Start color LED off
    gpio_write(GPIO_LD5_R, false);
    gpio_write(GPIO_LD5_G, false);
    gpio_write(GPIO_LD5_B, false);

    // Read the role GPIO to know if you are master
    gpio_read( GPIO_ROLE, &role );

    if( ROLE_LOGIC(role) ){ // If role == 1, you will be master. 

        // Write 0 on that GPIO to notify to the slave that the master
        // has been assigned. 
        gpio_set_mode( GPIO_ROLE, GpioModeOutPushPull );
        gpio_write(GPIO_ROLE, ROLE_LOGIC(false));

        // Declare dominance
        PRINTF("Look at me. I am the captain now.\n\r");

        // Turn LED yellow to identify the master
        gpio_write(GPIO_LD5_R, true);
        gpio_write(GPIO_LD5_G, true);
        gpio_write(GPIO_LD5_B, false);

        // Enable the timer interrupts to go to sleep between packets. 
        enable_timer_interrupt();
        // Wait a second for the slave to turn on
        #if !TARGET_SIM
        timer_wait_us(1000000);
        #endif

        // Turn LED cyan to signal start of transfer
        gpio_write(GPIO_LD5_R, false);
        gpio_write(GPIO_LD5_G, true);
        gpio_write(GPIO_LD5_B, true);

        // Initialize the SPI host IP
        if( spi_host_init(spi_host1, 0)!= SPI_FLAG_SUCCESS){
            // Something went wrong!  Turn on the pink beacon of doom and abort.
            gpio_write(GPIO_LD5_R, true);
            gpio_write(GPIO_LD5_G, false);
            gpio_write(GPIO_LD5_B, true);
            return EXIT_FAILURE;
        }

        // We will request chunks of chunk_w words. 
        // We will repeat the process N times until we have read the entirety of the buffer. 
        // Each time we will toggle the LED to give some feedback
        // and wait 250 ms sleeping waiting for the timer. 
        uint8_t chunk_w     = 5;
        uint8_t chunks_n    = (DATA_LENGTH_B/4)/chunk_w;
        for( i=0; i<chunks_n; i++){
            spi_slave_request_read(spi_host1,(uint8_t*)(&((uint32_t*)buffer_read_from)[i*chunk_w]),  chunk_w*4, DUMMY_CYCLES );
            spi_wait_for_rx_watermark(spi_host1);
            spi_copy_words( spi_host1, &((uint32_t*)buffer_read_to)[i*chunk_w],  chunk_w );
            #if !TARGET_SIM
            timer_wait_us(250000);
            #endif
            gpio_toggle(GPIO_LD5_R); // toggle between cyan and white
        }

        // Check if the read values are ok.
        for( i=0; i < chunks_n*chunk_w*4; i++){
            // If any value is not wahat you expected, the two rightmost LEDs of the board will be light up. 
            if(buffer_read_from[i] != buffer_read_to[i]){
                // Wrong result!  Turn on the red light of wrongness and abort.
                gpio_write(GPIO_LD5_R, true);
                gpio_write(GPIO_LD5_G, false);
                gpio_write(GPIO_LD5_B, false);
                return EXIT_FAILURE;
            }
        }

        // Celebrate by going green
        PRINTF("Well done!\n\r");
        gpio_write(GPIO_LD5_R, false);
        gpio_write(GPIO_LD5_G, true);
        gpio_write(GPIO_LD5_B, false);
    
    } else { // if instead your role is to be the slave
        // Lament it
        PRINTF("Oh snap, slave again it is...\n\r");
        // Turn the LED blue in disapproval
        gpio_write(GPIO_LD5_R, false);
        gpio_write(GPIO_LD5_G, false);
        gpio_write(GPIO_LD5_B, true);
        // Go to sleep, nothing else to be done by the CPU
        wait_for_interrupt();
    }

    // The rightmost LED of the board will be light up. 
    return EXIT_SUCCESS;
}





