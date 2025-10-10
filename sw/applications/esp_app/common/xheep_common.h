/* xheep_common.h — shared between ESP and X-HEEP */
#pragma once
#include <stdint.h>

#include "core_v_mini_mcu.h"
#include "power_manager_regs.h"

/* One shared drop location inside X-HEEP RAM for the message */
#define XHEEP_SHARED_STR_OFFSET      0x0000F000u
#define XHEEP_SHARED_STR_MAX         64u

/* Derived in-X-HEEP addresses (offsets within the X-HEEP aperture) */
#define XHEEP_SHARED_STR_ADDR        (XHEEP_SHARED_STR_OFFSET)

/* reset strobes */
#define XHEEP_RESET_ASSERT_ADDR      (POWER_MANAGER_START_ADDRESS + POWER_MANAGER_MASTER_CPU_FORCE_RESET_ASSERT_REG_OFFSET)
#define XHEEP_RESET_DEASSERT_ADDR    (POWER_MANAGER_START_ADDRESS + POWER_MANAGER_MASTER_CPU_FORCE_RESET_DEASSERT_REG_OFFSET)
