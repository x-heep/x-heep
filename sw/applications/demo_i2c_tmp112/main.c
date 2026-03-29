// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Enrico Manfredi
// Date: 05/09/2025
// Description: Example application to use the I2C peripheral with the TMP112 sensor
// NOTE: this program needs at least 3 32-kB ram banks for code and data.

#include <stdint.h>
#include <stdio.h>
#include "i2c_sdk.h"
#include "timer_sdk.h"
#include "x-heep.h"

#ifndef I2C_IS_INCLUDED
  #error ( "This app does NOT work as the I2C peripheral is not included" )
#endif

/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

/* PYNQ-Z2 connections */
// P15 (arduino_direct_iic_scl_io) -> SCL
// P16 (arduino_direct_iic_sda_io) -> SDA


/* ============================================================
 * TMP112 - I2C Address
 * ============================================================ */
#define Board_TMP_ADDR             0x48

/* ============================================================
 * TMP112 Register Map
 * ============================================================ */
#define TMP117_OBJ_CONFIG          0x01
#define TMP117_OBJ_TEMP            0x00


/* ============================================================
 * TMP112 Driver Declarations
 * ============================================================ */

i2c_result_t TMP112_sensor_start_conversion(void);
uint16_t TMP112_sensor_read(void);


/* ============================================================
 * Timer interrupt handler
 * ============================================================ */
void __attribute__((aligned(4), interrupt)) handler_irq_timer(void) {
    timer_arm_stop();
    timer_irq_clear();
    return;   
}


/* ============================================================
 * Test Main
 * ============================================================ */
int main(int argc, char *argv[]){

    /* 0. Variable declaration */
    uint32_t conversion_delay_us = 20000;

    // Enable timer interrupt for delay between readings
    enable_timer_interrupt(); 

    PRINTF("=== TMP112 Test ===\n");
    

    /* 1. Init I2C bus */
    if (initialize_i2c() != kDifI2cOk) {
        PRINTF("[ERROR] I2C initialization failed\n");
        return -1;
    }

    /* 2. Start conversion */
    PRINTF("Starting temperature conversion...\n");
    if (TMP112_sensor_start_conversion() != kDifI2cOk) {
        PRINTF("[ERROR] I2C write failed\n");
        return -1;
    }

    /* 3. Wait for conversion */
    #if !TARGET_SIM
        timer_wait_us(conversion_delay_us);
    #endif

    /* 4. Read the last converted values */
    uint16_t sensor_value = TMP112_sensor_read();
    PRINTF("Value read from the sensor: %d (hex: %x)\n", sensor_value, sensor_value);

    /* 5. Convert the temperature */
    int temperature = ((int) sensor_value) * 0.0625;
    PRINTF("Temperature: %d degree celsius\n", temperature);

    PRINTF("=== Test finished ===\n");
    return 0;
}



/* ============================================================
 * TMP112 Driver Implementations
 * ============================================================ */

i2c_result_t TMP112_sensor_start_conversion(){
     
    uint8_t txBuffer[2]; 
    txBuffer[0] = 0x60;
    txBuffer[1] = 0xA0;

    return i2c_write(Board_TMP_ADDR, TMP117_OBJ_CONFIG, txBuffer, 2);
}

uint16_t TMP112_sensor_read(void){

    const int num_rx_bytes = 2;
    uint8_t   rxBuffer[num_rx_bytes];
    uint16_t  temperature = 0;

    if(i2c_read(Board_TMP_ADDR, TMP117_OBJ_TEMP, rxBuffer, num_rx_bytes) != kDifI2cOk) {
        PRINTF("Failed to read from I2C\n");
        return 0;
    } else {
        // Extract the real value from the received data
        temperature = (rxBuffer[0] << 8) | (rxBuffer[1]); 
        //shift 4 bits to the right because data is left aligned
        temperature = temperature >> 4;

        /*
         * If the MSB is set '1', then we have a 2's complement
         * negative value which needs to be sign extended
        */ 
        if (temperature & 0x800) {
            temperature ^= 0xFFF;
            temperature  = temperature + 1;
        }
    }
    return temperature;
}