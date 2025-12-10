#ifndef ESP_MEMORY_OPS_H
#define ESP_MEMORY_OPS_H

#include <stdint.h>
#include "core_v_mini_mcu.h"

void esp_write32(uint32_t addr, uint32_t value);
uint32_t esp_read32(uint32_t addr);
void esp_write16(uint32_t addr, uint16_t value);
uint16_t esp_read16(uint32_t addr);
void esp_write8(uint32_t addr, uint8_t value);
uint8_t esp_read8(uint32_t addr);


#endif // ESP_MEMORY_OPS_H
