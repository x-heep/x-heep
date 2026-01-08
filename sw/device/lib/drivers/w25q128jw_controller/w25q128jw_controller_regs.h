// Generated register defines for w25q128jw_controller

#ifndef _W25Q128JW_CONTROLLER_REG_DEFS_
#define _W25Q128JW_CONTROLLER_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define W25Q128JW_CONTROLLER_PARAM_REG_WIDTH 32

// Control register for flash controller
#define W25Q128JW_CONTROLLER_CONTROL_REG_OFFSET 0x0
#define W25Q128JW_CONTROLLER_CONTROL_START_BIT 0
#define W25Q128JW_CONTROLLER_CONTROL_RNW_BIT 1

// Status register for flash controller
#define W25Q128JW_CONTROLLER_STATUS_REG_OFFSET 0x4
#define W25Q128JW_CONTROLLER_STATUS_READY_BIT 0

// Address in flash to read from/write to
#define W25Q128JW_CONTROLLER_F_ADDRESS_REG_OFFSET 0x8

// Address to store read data from SPI_FLASH
#define W25Q128JW_CONTROLLER_S_ADDRESS_REG_OFFSET 0xc

// Address where data with which we have to modify the flash is
#define W25Q128JW_CONTROLLER_MD_ADDRESS_REG_OFFSET 0x10

// Length of data to W/R
#define W25Q128JW_CONTROLLER_LENGTH_REG_OFFSET 0x14

// Interrupt status register
#define W25Q128JW_CONTROLLER_INTR_STATUS_REG_OFFSET 0x18
#define W25Q128JW_CONTROLLER_INTR_STATUS_INTR_STATUS_BIT 0

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _W25Q128JW_CONTROLLER_REG_DEFS_
// End generated register defines for w25q128jw_controller