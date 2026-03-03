#include "esp_memory_ops.h"

void esp_write32(uint32_t addr, uint32_t value) {
    volatile uint32_t *ptr = (volatile uint32_t *)(uintptr_t)(addr + EXT_SLAVE_START_ADDRESS);
    *ptr = value;
}

uint32_t esp_read32(uint32_t addr) {
    volatile uint32_t *ptr = (volatile uint32_t *)(uintptr_t)(addr + EXT_SLAVE_START_ADDRESS);
    return *ptr;
}

void esp_write16(uint32_t addr, uint16_t value) {
    // Read-modify-write: read full word, modify halfword, write back
    uint32_t word_addr = (addr + EXT_SLAVE_START_ADDRESS) & ~0x3;  // Align to word boundary
    uint32_t byte_offset = (addr & 0x3);  // Get byte offset within word (0, 2)
    
    volatile uint32_t *ptr = (volatile uint32_t *)(uintptr_t)word_addr;
    uint32_t word = *ptr;
    
    // Clear the target halfword and insert new value
    if (byte_offset == 0) {
        word = (word & 0xFFFF0000) | value;
    } else {  // byte_offset == 2
        word = (word & 0x0000FFFF) | ((uint32_t)value << 16);
    }
    
    *ptr = word;
}

uint16_t esp_read16(uint32_t addr) {
    // Read full word and extract halfword
    uint32_t word_addr = (addr + EXT_SLAVE_START_ADDRESS) & ~0x3;
    uint32_t byte_offset = (addr & 0x3);
    
    volatile uint32_t *ptr = (volatile uint32_t *)(uintptr_t)word_addr;
    uint32_t word = *ptr;
    
    if (byte_offset == 0) {
        return (uint16_t)(word & 0xFFFF);
    } else {  // byte_offset == 2
        return (uint16_t)((word >> 16) & 0xFFFF);
    }
}

void esp_write8(uint32_t addr, uint8_t value) {
    // retarget_for_dma=1 requires word-aligned operations
    // Read-modify-write: read full word, modify byte, write back
    uint32_t word_addr = (addr + EXT_SLAVE_START_ADDRESS) & ~0x3;  // Align to word boundary
    uint32_t byte_offset = (addr & 0x3);  // Get last 2 bits of address
    
    volatile uint32_t *ptr = (volatile uint32_t *)(uintptr_t)word_addr;
    uint32_t word = *ptr;
    
    // Clear the target byte and insert new value
    uint32_t shift = byte_offset * 8;
    uint32_t mask = ~(0xFF << shift);
    word = (word & mask) | ((uint32_t)value << shift);
    
    *ptr = word;
}

uint8_t esp_read8(uint32_t addr) {
    // Read full word and extract byte
    uint32_t word_addr = (addr + EXT_SLAVE_START_ADDRESS) & ~0x3;
    uint32_t byte_offset = (addr & 0x3);
    
    volatile uint32_t *ptr = (volatile uint32_t *)(uintptr_t)word_addr;
    uint32_t word = *ptr;
    
    uint32_t shift = byte_offset * 8;
    return (uint8_t)((word >> shift) & 0xFF);
}
