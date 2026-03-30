// Copyright 2026 EPFL and Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: i2c_sdk.h
// Authors: Enrico Manfredi 
// Date: 06/03/2026
// Description: I2C SDK for basic interaction with the I2C peripheral

#include "i2c_sdk.h"

/******************************/
/* ---- GLOBAL VARIABLES ---- */
/******************************/

i2c_t i2c;
i2c_result_t i2c_result;
i2c_params_t i2c_params;
i2c_irq_snapshot_t irq_snapshot;
i2c_config_t i2c_config;
i2c_level_t rx_watermark_level = kDifI2cLevel16Byte;
i2c_level_t fmt_watermark_level = kDifI2cLevel16Byte;

i2c_timing_config_t i2c_timing_config = {
        .lowest_target_device_speed = kDifI2cSpeedStandard, // The lowest speed at which an I2C target connected to this host will operate.
        .clock_period_nanos = 0,                            // The period of the clock driving this device, in nanoseconds.
        .sda_rise_nanos = 200,                              // The expected time it takes for the I2C bus signal to rise, in nanoseconds.
        .sda_fall_nanos = 200,                              // The expected time for the bus signal to fall, similar to `sda_rise_nanos`.
        .scl_period_nanos = 0,                              // The desired period of the SCL line, in nanoseconds. 0 -> minimum period will be used.
        .data_signal_hold_cycles = 1,                       // The desired number of hold cycles between the start signal and the first bit transfer.
    };


/*************************************/
/* ---- FUNCTION IMPLEMENTATION ---- */
/*************************************/

i2c_result_t initialize_i2c(){
    // Get current Frequency to calculate the timer threshold
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
    uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);
    uint32_t clock_period_ns = 1000000000/freq_hz; // period in ns

    // I2C initialization 
    i2c_params.base_addr = mmio_region_from_addr((uintptr_t)I2C_START_ADDRESS);
    i2c_result = i2c_init(i2c_params, &i2c);
    if(i2c_result != kDifI2cOk) {
        return i2c_result;
    }

    // I2C timing computation
    i2c_result = i2c_compute_timing(i2c_timing_config, &i2c_config);
    if(i2c_result != kDifI2cOk) {
        return i2c_result;
    }

    // I2C configuration
    i2c_result = i2c_configure(&i2c, i2c_config);
    if(i2c_result != kDifI2cOk) {
        return i2c_result;
    }

    // I2C watermark settings
    i2c_result = i2c_set_watermarks(&i2c, rx_watermark_level, fmt_watermark_level);
    if(i2c_result != kDifI2cOk) {
        return i2c_result;
    }

    // I2C interrupt settings
    i2c_result = i2c_irq_disable_all(&i2c, &irq_snapshot);
    if(i2c_result != kDifI2cOk) {
        return i2c_result;
    }

    // I2C host functionality enable
    i2c_result = i2c_host_set_enabled(&i2c, kDifI2cToggleEnabled);
    if(i2c_result != kDifI2cOk) {
        return i2c_result;
    }

    return i2c_result;
}


void set_timing_config(i2c_speed_t lowest_target_device_speed,
                       uint32_t sda_rise_ns,
                       uint32_t sda_fall_ns,
                       uint32_t scl_period_ns,
                       uint16_t data_signal_hold_cycles){

    // Update the global timing configuration struct with the provided values
    i2c_timing_config.lowest_target_device_speed    = lowest_target_device_speed;
    i2c_timing_config.sda_rise_nanos                = sda_rise_ns;
    i2c_timing_config.sda_fall_nanos                = sda_fall_ns;
    i2c_timing_config.scl_period_nanos              = scl_period_ns;
    i2c_timing_config.data_signal_hold_cycles       = data_signal_hold_cycles;
}


void set_watermark_levels(i2c_level_t rx_level, i2c_level_t fmt_level){
    // Set the global watermark levels with the provided values
    rx_watermark_level = rx_level;
    fmt_watermark_level = fmt_level;
}


i2c_result_t i2c_write(uint8_t dev_addr, uint8_t reg, uint8_t *source, uint32_t num_bytes){
    /* I2C Write
     *     START | dev_addr (W) | reg | data | STOP
     */

    // Construct the address byte by left-shifting the 7-bit device address and adding the write bit (0)
    uint8_t address = WRITE_CMD | (dev_addr << 1);

    // I2C write operation
    i2c_write_byte(&i2c, address, kDifI2cFmtStart, true);       // start transaction and transmit address (7 bit) and r/w bit
    i2c_write_byte(&i2c, reg, kDifI2cFmtTx, true);              // transmit register address
    // Start transmitting data bytes
    for (int i = 0; i < num_bytes-1; i++) {
        i2c_write_byte(&i2c, source[i], kDifI2cFmtTx, true);
    }
    i2c_result = i2c_write_byte(&i2c, source[num_bytes-1], kDifI2cFmtTxStop, true);    // transmit last byte and stop signal
    return i2c_result;
}


i2c_result_t i2c_read(uint8_t dev_addr, uint8_t reg, uint8_t *destination, uint32_t num_bytes){
    /* I2C Read
     *     START | dev_addr (W) | reg | RESTART | dev_addr (R) | buf[0..len-1] | STOP
     */

    // Construct the address byte by left-shifting the 7-bit device address and adding the read/write bit (0/1)
    uint8_t   address;

    // Reset rx FIFO to make sure it's empty before reading
    i2c_reset_rx_fifo(&i2c);
    
    // I2C read requires two transactions:
    // First one sets the register to read with a write transaction
    address = WRITE_CMD | (dev_addr << 1);
    i2c_write_byte(&i2c, address, kDifI2cFmtStart, true);
    i2c_write_byte(&i2c, reg, kDifI2cFmtTx, true); 
    
    // The second one actually reads the data
    address = READ_CMD | (dev_addr << 1);
    i2c_write_byte(&i2c, address, kDifI2cFmtStart, false);
    for (int i=0; i<num_bytes-1; i++){
        i2c_write_byte(&i2c, 0x02, kDifI2cFmtRxContinue, false);
    }
    i2c_result = i2c_write_byte(&i2c, 0x02, kDifI2cFmtRxStop, false);
    if(i2c_result != kDifI2cOk) {
        return -1;
    }

    // Wait for received bytes (waiting is disabled in simulation)
    uint8_t fmt_lvl= 0;
    uint8_t rx_lvl = 0;
    #if !TARGET_SIM
        while(rx_lvl != num_bytes){
            i2c_get_fifo_levels(&i2c, &fmt_lvl, &rx_lvl);
        }
    #endif
    
    // Data sent by the sensor can be read from the buffer
    for(int i=0; i<num_bytes; i++){
        i2c_result = i2c_read_byte(&i2c, &destination[i]);
        if(i2c_result != kDifI2cOk) {
            return -1;
        }
    }
    return 0;
}