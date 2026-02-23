#ifndef ESP_HEEP_H
#define ESP_HEEP_H

#include <stdint.h>

#include "core_v_mini_mcu.h"

/* ESP aperture encoding: user field lives in addr[27:22]. */
#define XHEEP_ESP_USER_SHIFT 22u
#define XHEEP_ESP_USER_MASK  0x3Fu

#define XHEEP_ESP_BASE_ADDR(user) \
    (EXT_SLAVE_START_ADDRESS | ((uintptr_t)((user) & XHEEP_ESP_USER_MASK) << XHEEP_ESP_USER_SHIFT))

#define XHEEP_ESP_ADDR(user, offset) \
    (XHEEP_ESP_BASE_ADDR(user) + (uintptr_t)(offset))

/* ESP DMA CSR window (last 4KB of 0xF0000000-0xF0FFFFFF). */
#define XHEEP_ESP_DMA_CSR_BASE      ((uintptr_t)0xF0FFF000u)
#define XHEEP_ESP_DMA_CTRL_ADDR     (XHEEP_ESP_DMA_CSR_BASE + 0x00u)
#define XHEEP_ESP_DMA_STATUS_ADDR   (XHEEP_ESP_DMA_CSR_BASE + 0x04u)
#define XHEEP_ESP_DMA_ADDR_ADDR     (XHEEP_ESP_DMA_CSR_BASE + 0x08u)
#define XHEEP_ESP_DMA_LEN_ADDR      (XHEEP_ESP_DMA_CSR_BASE + 0x0Cu)
#define XHEEP_ESP_DMA_XHEEP_ADDR    (XHEEP_ESP_DMA_CSR_BASE + 0x10u)

/* DMA CTRL fields. */
#define XHEEP_ESP_DMA_CTRL_START         (1u << 0)
#define XHEEP_ESP_DMA_CTRL_DIR_WRITE     (1u << 1)
#define XHEEP_ESP_DMA_CTRL_READ_USER(x)  (((uint32_t)((x) & 0x3Fu)) << 2)
#define XHEEP_ESP_DMA_CTRL_WRITE_USER(x) (((uint32_t)((x) & 0x3Fu)) << 8)

/* DMA STATUS fields. */
#define XHEEP_ESP_DMA_STATUS_BUSY  (1u << 0)
#define XHEEP_ESP_DMA_STATUS_DONE  (1u << 1)
#define XHEEP_ESP_DMA_STATUS_ERR   (1u << 2)

/* DMA user field helpers. */
#define XHEEP_ESP_DMA_USER_MEM   0u
#define XHEEP_ESP_DMA_USER_P2P   1u
#define XHEEP_ESP_DMA_USER_MCAST(consumers) ((uint32_t)(consumers))

typedef struct {
    uint32_t addr;
    uint32_t len_bytes;
    uint32_t xheep_addr;
    uint8_t dir_write;
    uint8_t read_user;
    uint8_t write_user;
} esp_dma_config_t;

static inline void xheep_esp_dma_configure(const esp_dma_config_t *cfg)
{
    uint32_t ctrl = 0u;
    ctrl |= (cfg->dir_write ? XHEEP_ESP_DMA_CTRL_DIR_WRITE : 0u);
    ctrl |= XHEEP_ESP_DMA_CTRL_READ_USER(cfg->read_user);
    ctrl |= XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg->write_user);

    *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_CTRL_ADDR  = ctrl;
    *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_ADDR_ADDR  = cfg->addr;
    *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_LEN_ADDR   = cfg->len_bytes;
    *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_XHEEP_ADDR = cfg->xheep_addr;
}

static inline void xheep_esp_dma_start(uint32_t ctrl)
{
    *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_CTRL_ADDR = ctrl | XHEEP_ESP_DMA_CTRL_START;
}

static inline void xheep_esp_dma_get_config(esp_dma_config_t *cfg)
{
    uint32_t ctrl = *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_CTRL_ADDR;
    cfg->dir_write = (uint8_t)((ctrl & XHEEP_ESP_DMA_CTRL_DIR_WRITE) != 0u);
    cfg->read_user = (uint8_t)((ctrl >> 2) & 0x3Fu);
    cfg->write_user = (uint8_t)((ctrl >> 8) & 0x3Fu);
    cfg->addr = *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_ADDR_ADDR;
    cfg->len_bytes = *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_LEN_ADDR;
    cfg->xheep_addr = *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_XHEEP_ADDR;
}

static inline void xheep_esp_dma_wait_done(void)
{
    volatile uint32_t status;
    do {
        status = *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_STATUS_ADDR;
    } while ((status & XHEEP_ESP_DMA_STATUS_DONE) == 0u);

    /* W1C DONE bit. */
    *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_DMA_STATUS_ADDR = XHEEP_ESP_DMA_STATUS_DONE;
}

/* Generic 32-bit write helper. */
#define XHEEP_ESP_WRITE32(user, offset, value) \
    do { \
        *(volatile uint32_t *)(uintptr_t)XHEEP_ESP_ADDR((user), (offset)) = (uint32_t)(value); \
    } while (0)

/* Convenience macros for common modes. */
#define XHEEP_ESP_MEM_WRITE32(offset, value) \
    XHEEP_ESP_WRITE32(0u, (offset), (value))

/* P2P write: exactly 1 consumer. */
#define XHEEP_ESP_P2P_WRITE32(offset, value) \
    XHEEP_ESP_WRITE32(1u, (offset), (value))

/* Multicast write: user field is the number of consumers (>1). */
#define XHEEP_ESP_MCAST_WRITE32(consumers, offset, value) \
    XHEEP_ESP_WRITE32((consumers), (offset), (value))

#endif /* ESP_HEEP_H */
