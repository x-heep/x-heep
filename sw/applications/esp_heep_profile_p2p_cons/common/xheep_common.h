#ifndef __XHEEP_COMMON_H__
#define __XHEEP_COMMON_H__

#include <stdint.h>

#include "core_v_mini_mcu.h"

#ifndef ESP_HEEP_PROFILE_P2P_SIZE_BYTES
#define ESP_HEEP_PROFILE_P2P_SIZE_BYTES 2048u
#endif

#ifndef ESP_HEEP_PROFILE_P2P_USE_P2P
#define ESP_HEEP_PROFILE_P2P_USE_P2P 0u
#endif

#if ESP_HEEP_PROFILE_P2P_SIZE_BYTES == 0
#error "ESP_HEEP_PROFILE_P2P_SIZE_BYTES must be greater than zero"
#endif

#define ESP_HEEP_PROFILE_P2P_ALIGN_UP(_value, _align) \
    (((_value) + ((_align) - 1u)) & ~((_align) - 1u))

#define ESP_HEEP_PROFILE_P2P_DATA_OFFSET 0x00000000u
#define ESP_HEEP_PROFILE_P2P_SHARED_BYTES \
    ESP_HEEP_PROFILE_P2P_ALIGN_UP(ESP_HEEP_PROFILE_P2P_DATA_OFFSET + ESP_HEEP_PROFILE_P2P_SIZE_BYTES, 8u)

#if ESP_HEEP_PROFILE_P2P_USE_P2P
#define ESP_HEEP_PROFILE_P2P_MODE_NAME "p2p"
#else
#define ESP_HEEP_PROFILE_P2P_MODE_NAME "memory"
#endif

typedef struct {
    uint8_t bytes[ESP_HEEP_PROFILE_P2P_SIZE_BYTES];
} esp_heep_profile_p2p_data_t;

#endif /* __XHEEP_COMMON_H__ */
