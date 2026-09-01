#include <stdint.h>
#include <stdio.h>

#include "camera_regs.h"
#include "camera_structs.h"
#include "dma.h"
#include "i2c_sdk.h"
#include "pad_control.h"
#include "pad_control_regs.h"
#include "timer_sdk.h"
#include "x-heep.h"

#ifndef I2C_IS_INCLUDED
#error ( "This app does NOT work as the I2C peripheral is not included" )
#endif

#ifndef CAMERA_IS_INCLUDED
#error ( "This app does NOT work as the CAMERA peripheral is not included" )
#endif
/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA 1
#define PRINTF_IN_SIM 1

#if TARGET_SIM && PRINTF_IN_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...)
#endif

/* PYNQ-Z2 connections */
// P15 (arduino_direct_iic_scl_io) -> SCL
// P16 (arduino_direct_iic_sda_io) -> SDA

// i2c adress of the camera
// Datasheet say it's 0x42 and 0x43 for write and read, but the LSB is the R/W
// bit, so the address is 0x21
#define OV7670_ADDR 0x21

uint16_t rgb565[2000];
// volatile uint16_t rgb565[1000];

void set_pad(void) {
  pad_control_t pad_control;
  pad_control.base_addr =
      mmio_region_from_addr((uintptr_t)PAD_CONTROL_START_ADDRESS);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_0_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_1_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_2_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_3_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_4_REG_OFFSET), 1);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_5_REG_OFFSET), 1);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_6_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_7_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_8_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_9_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_10_REG_OFFSET), 2);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_11_REG_OFFSET), 1);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_12_REG_OFFSET), 1);
  pad_control_set_mux(&pad_control,
                      (ptrdiff_t)(PAD_CONTROL_PAD_MUX_GPIO_13_REG_OFFSET), 1);
}

// Initialize the camera via I2C
// value takken from
// https://github.com/EPFL-LAP/cs476/blob/main/virtualprototype/programs/support/src/ov7670.c
uint8_t camera_i2c_init() {
  uint8_t config_value = 0x80;  // reset all registers to default values
  if (i2c_write(OV7670_ADDR, 0x12, &config_value, 1) != kDifI2cOk) return 1;

  config_value = 0xF6;  // href
  if (i2c_write(OV7670_ADDR, 0x32, &config_value, 1) != kDifI2cOk) return 1;

  config_value = 0x13;  // hstart
  if (i2c_write(OV7670_ADDR, 0x17, &config_value, 1) != kDifI2cOk) return 1;

  config_value = 0x01;  // hstop
  if (i2c_write(OV7670_ADDR, 0x18, &config_value, 1) != kDifI2cOk) return 1;

  config_value = 0x02;  // vstrt
  if (i2c_write(OV7670_ADDR, 0x19, &config_value, 1) != kDifI2cOk) return 1;

  config_value = 0x7A;  // vstop
  if (i2c_write(OV7670_ADDR, 0x1A, &config_value, 1) != kDifI2cOk) return 1;

  config_value = 0x0A;  // vref
  if (i2c_write(OV7670_ADDR, 0x03, &config_value, 1) != kDifI2cOk) return 1;

  return 0;
}

/* ============================================================
 * Test Main
 * ============================================================ */
int main(void) {
  // Configure the pad control to set the correct mux for the camera interface
  set_pad();

  PRINTF("=== Camera Test ===\n");

  // i2c not used yet
  if (initialize_i2c() != kDifI2cOk) {
    PRINTF("[ERROR] I2C initialization failed\n");
    return -1;
  }

  uint8_t producdt_id = 0;
  i2c_read(OV7670_ADDR, 0x0A, &producdt_id, 1);

  PRINTF("Camera product id: %x, should be 0x76\n", producdt_id);

  if (camera_i2c_init() != 0) {
    PRINTF("[ERROR] Camera I2C initialization failed\n");
    return -1;
  }

  for (int i = 0; i < 1000; i++) rgb565[i] = 0x1234;
  // memset(rgb565, 0x55, sizeof(rgb565));

  dma_init(NULL);

  static dma_target_t tgt_src = {
      .inc_d1_du = 0,              // Target is peripheral, no increment
      .type = DMA_DATA_TYPE_WORD,  // Data type is word
  };
  uint32_t* fifo_ptr_rx =
      (uint32_t*)((uintptr_t)camera_peri + CAMERA_DATA_REG_OFFSET);
  // Target is SPI RX FIFO
  tgt_src.ptr = (uint8_t*)fifo_ptr_rx;
  // Trigger to control the data flow
  tgt_src.trig = 0;

  // Set up DMA destination target
  static dma_target_t tgt_dst = {
      .inc_d1_du = 1,              // Increment by 1 data unit (word)
      .type = DMA_DATA_TYPE_WORD,  // Data type is byte
      .trig = DMA_TRIG_MEMORY,     // Read-write operation to memory
  };
  tgt_dst.ptr = (uint8_t*)rgb565;  // Target is the data buffer

  // Set up DMA transaction
  static dma_trans_t trans = {
      .src = &tgt_src,
      .dst = &tgt_dst,
      .end = DMA_TRANS_END_POLLING,
  };
  // Size is in data units (words in this case)
  trans.size_d1_du = 1000;

  // Validate, load and launch DMA transaction

  dma_config_flags_t res;
  res = dma_validate_transaction(&trans, DMA_ENABLE_REALIGN,
                                 DMA_PERFORM_CHECKS_INTEGRITY);
  res = dma_load_transaction(&trans);

  camera_peri->CONTROL |= ((0x1) << CAMERA_CONTROL_START_BIT);  // Enable camera
  res = dma_launch(&trans);

  while (!dma_is_ready(0));

  // if it's a7a7, UseTestPattern is probably set to 1
  PRINTF("%x\n", rgb565[2]);

  PRINTF("=== Test finished ===\n");
  return 0;
}
