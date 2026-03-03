/* xheep_common.h � shared between ESP and X-HEEP */
#pragma once
#include <stdint.h>

#include "core_v_mini_mcu.h"
#include "power_manager_regs.h"
#include "soc_ctrl_regs.h"

/* Firmware entry point address - must match linker script __boot_address */
#define XHEEP_FW_ENTRY_POINT 0x180

/* One shared drop location inside X-HEEP RAM for the message */
#define XHEEP_SHARED_STR_OFFSET     0x0000FA00
#define XHEEP_SHARED_STR_MAX         128u

#define XHEEP_SOC_CTRL_WRITE_OFFSET    0x0000FF00

/* Derived in-X-HEEP addresses (offsets within the X-HEEP aperture) */
#define XHEEP_SHARED_STR_ADDR        (XHEEP_SHARED_STR_OFFSET)

/* Boot ROM control - tells boot ROM to exit loop and jump to BOOT_ADDRESS (default 0x180) */
#define XHEEP_BOOT_EXIT_LOOP_ADDR    (XHEEP_SOC_CTRL_WRITE_OFFSET + SOC_CTRL_BOOT_EXIT_LOOP_REG_OFFSET)
#define XHEEP_BOOT_ADDRESS_ADDR      (XHEEP_SOC_CTRL_WRITE_OFFSET + SOC_CTRL_BOOT_ADDRESS_REG_OFFSET)
#define XHEEP_BOOT_SELECT_ADDR       (XHEEP_SOC_CTRL_WRITE_OFFSET + SOC_CTRL_BOOT_SELECT_REG_OFFSET)
