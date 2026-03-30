// Copyright 2026 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Author: Enrico Manfredi
// Date: 04/03/2026
// Description: Example application to use the I2C peripheral with the LSM6DSO sensor
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
 * LSM6DSO - I2C Address
 * ============================================================ */
#define LSM6DSO_I2C_ADDR    0x6B

/* ============================================================
 * LSM6DSO Register Map
 * ============================================================ */
#define LSM6DSO_WHO_AM_I    0x0F    /* Expected value: 0x6C  */
#define LSM6DSO_CTRL1_XL    0x10    /* Accelerometer control */
#define LSM6DSO_CTRL2_G     0x11    /* Gyroscope control     */
#define LSM6DSO_OUTX_L_G    0x22    /* Gyro X low byte       */
#define LSM6DSO_OUTX_L_A    0x28    /* Accel X low byte      */

#define LSM6DSO_WHO_AM_I_VAL  0x6C

/* ============================================================
 * Return codes
 * ============================================================ */
typedef enum {
    LSM6DSO_OK   =  0,
    LSM6DSO_ERR  = -1
} lsm6dso_status_t;

/* ============================================================
 * Raw sensor data
 * ============================================================ */
typedef struct {
    int16_t accel_x;
    int16_t accel_y;
    int16_t accel_z;
    int16_t gyro_x;
    int16_t gyro_y;
    int16_t gyro_z;
} lsm6dso_data_t;

/* ============================================================
 * LSM6DSO Driver Declarations
 * ============================================================ */

lsm6dso_status_t lsm6dso_check_id(void);
lsm6dso_status_t lsm6dso_init(void);
lsm6dso_status_t lsm6dso_read_data(lsm6dso_data_t *data);


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
int main(void){
    
    /* 0. Variable declaration */
    #if !TARGET_SIM
        int num_readings = 1000;
    #else
        int num_readings = 1;
    #endif
    uint32_t reading_delay_us = 200;
    lsm6dso_data_t sensor_data;

    // Enable timer interrupt for delay between readings
    enable_timer_interrupt(); 

    PRINTF("=== LSM6DSO Test ===\n");

    /* 1. Init I2C bus */
    if (initialize_i2c() != kDifI2cOk) {
        PRINTF("[ERROR] I2C initialization failed\n");
        return -1;
    }

    /* 2. Device verification */
    if (lsm6dso_check_id() != LSM6DSO_OK)
        return -1;

    /* 3. Configure sensor */
    if (lsm6dso_init() != LSM6DSO_OK)
        return -1;

    /* 4. Reading loop */
    PRINTF("\n[LSM6DSO] Data reading (Accel raw | Gyro raw):\n");
    for (int i = 0; i < num_readings; i++) {
        if (lsm6dso_read_data(&sensor_data) == LSM6DSO_OK) {
            PRINTF("  [%02d] Accel: X=%6d Y=%6d Z=%6d | "
                   "Gyro:  X=%6d Y=%6d Z=%6d\n",
                   i,
                   sensor_data.accel_x, sensor_data.accel_y, sensor_data.accel_z,
                   sensor_data.gyro_x,  sensor_data.gyro_y,  sensor_data.gyro_z);
        } else {
            PRINTF("  [%02d] Sensor read error\n", i);
        }
        #if !TARGET_SIM
            timer_wait_us(reading_delay_us); // delay between readings
        #endif
    }

    PRINTF("=== Test finished ===\n");
    return 0;
}


/* ============================================================
 * LSM6DSO Driver Implementations
 * ============================================================ */

/**
 * Verifies connection by reading WHO_AM_I.
 */
lsm6dso_status_t lsm6dso_check_id(void)
{
    uint8_t who_am_i = 0;
    
    if (i2c_read(LSM6DSO_I2C_ADDR, LSM6DSO_WHO_AM_I, &who_am_i, 1) != kDifI2cOk) {
        PRINTF("[LSM6DSO] Error reading WHO_AM_I\n");
        return LSM6DSO_ERR;
    }

    #if !TARGET_SIM
        if (who_am_i != LSM6DSO_WHO_AM_I_VAL) {
            PRINTF("[LSM6DSO] Incorrect WHO_AM_I: 0x%02X (expected 0x%02X)\n",
                who_am_i, LSM6DSO_WHO_AM_I_VAL);
            return LSM6DSO_ERR;
        }
    #endif

    PRINTF("[LSM6DSO] WHO_AM_I OK: 0x%02X\n", who_am_i);
    return LSM6DSO_OK;
}

/**
 * Initializes accel (104 Hz, ±2g) and gyro (104 Hz, 250 dps).
 */
lsm6dso_status_t lsm6dso_init(void)
{
    char config_value = 0xA0;

    /* CTRL1_XL: ODR=6.6kHz (0xA0), FS=±2g */
    if (i2c_write(LSM6DSO_I2C_ADDR, LSM6DSO_CTRL1_XL, &config_value, 1) != kDifI2cOk)
        return LSM6DSO_ERR;

    /* CTRL2_G: ODR=6.6kHz (0xA0), FS=250dps */
    if (i2c_write(LSM6DSO_I2C_ADDR, LSM6DSO_CTRL2_G, &config_value, 1) != kDifI2cOk)
        return LSM6DSO_ERR;

    PRINTF("[LSM6DSO] Initialization OK\n");
    return LSM6DSO_OK;
}

/**
 * Reads accel and gyro (6 bytes each, burst read).
 */
lsm6dso_status_t lsm6dso_read_data(lsm6dso_data_t *data)
{
    uint8_t raw[6];

    /* --- Gyroscope --- */
    if (i2c_read(LSM6DSO_I2C_ADDR, LSM6DSO_OUTX_L_G, raw, 6) != kDifI2cOk)
        return LSM6DSO_ERR;

    data->gyro_x = (int16_t)((raw[1] << 8) | raw[0]);
    data->gyro_y = (int16_t)((raw[3] << 8) | raw[2]);
    data->gyro_z = (int16_t)((raw[5] << 8) | raw[4]);

    /* --- Accelerometer --- */
    if (i2c_read(LSM6DSO_I2C_ADDR, LSM6DSO_OUTX_L_A, raw, 6) != kDifI2cOk)
        return LSM6DSO_ERR;

    data->accel_x = (int16_t)((raw[1] << 8) | raw[0]);
    data->accel_y = (int16_t)((raw[3] << 8) | raw[2]);
    data->accel_z = (int16_t)((raw[5] << 8) | raw[4]);

    return LSM6DSO_OK;
}