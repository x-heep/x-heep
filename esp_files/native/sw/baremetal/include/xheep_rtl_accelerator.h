#ifndef XHEEP_RTL_ACCELERATOR_H
#define XHEEP_RTL_ACCELERATOR_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "esp_accelerator.h"
#include "esp_probe.h"

#define XHEEP_CONF_IDX_CODE_SIZE     0
#define XHEEP_CONF_IDX_FETCH_ADDR    1
#define XHEEP_CONF_IDX_FETCH_TRIGGER 2
#define XHEEP_CONF_IDX_EXIT_TRIGGER  3
#define XHEEP_NUM_CONFIG_REGS        4
#define XHEEP_USR_BASE               0x40

typedef struct {
    uint32_t addr;
    uint32_t size;
    const uint8_t *data;
} xheep_fw_section_t;

static inline size_t xheep_align_up(size_t v, size_t a)
{
    return (v + a - 1) & ~(a - 1);
}

static inline size_t xheep_fw_size(const xheep_fw_section_t *sections, unsigned nsections)
{
    size_t sz = 0;
    for (unsigned s = 0; s < nsections; ++s) {
        size_t end = sections[s].addr + sections[s].size;
        if (end > sz) sz = end;
    }
    return xheep_align_up(sz, 8);
}

static inline void xheep_fw_flatten(uint8_t *buffer, size_t buffer_size,
                                    const xheep_fw_section_t *sections, unsigned nsections)
{
    for (unsigned s = 0; s < nsections; ++s) {
        if (sections[s].addr + sections[s].size > buffer_size) continue;
        memcpy(buffer + sections[s].addr, sections[s].data, sections[s].size);
    }
}

static inline void xheep_program_conf_regs(struct esp_device *dev,
                                           const uint32_t conf_regs[XHEEP_NUM_CONFIG_REGS],
                                           bool is_producer)
{
    const uintptr_t reg_code_size = is_producer ? (XHEEP_USR_BASE + 4) : XHEEP_USR_BASE;
    const uintptr_t reg_fetch_addr = is_producer ? XHEEP_USR_BASE : (XHEEP_USR_BASE + 4);

    iowrite32(dev, reg_code_size,  conf_regs[XHEEP_CONF_IDX_CODE_SIZE]);
    iowrite32(dev, reg_fetch_addr, conf_regs[XHEEP_CONF_IDX_FETCH_ADDR]);
    iowrite32(dev, XHEEP_USR_BASE + 8,  conf_regs[XHEEP_CONF_IDX_FETCH_TRIGGER]);
    iowrite32(dev, XHEEP_USR_BASE + 12, conf_regs[XHEEP_CONF_IDX_EXIT_TRIGGER]);
}

static inline void xheep_start(struct esp_device *dev)
{
    iowrite32(dev, CMD_REG, CMD_MASK_START);
}

static inline bool xheep_wait_done(struct esp_device *dev, unsigned max_polls, unsigned *out_polls)
{
    unsigned status = ioread32(dev, STATUS_REG);
    unsigned polls = 0;

    while (!(status & STATUS_MASK_DONE)) {
        if (max_polls && ++polls >= max_polls) {
            if (out_polls) *out_polls = polls;
            return false;
        }
        status = ioread32(dev, STATUS_REG);
    }

    if (out_polls) *out_polls = polls;
    iowrite32(dev, CMD_REG, 0x0);
    return true;
}

static inline bool xheep_fetch_firmware(struct esp_device *dev, uint32_t code_size_words,
                                        uint32_t fetch_addr, bool is_producer,
                                        unsigned max_polls)
{
    uint32_t conf_regs[XHEEP_NUM_CONFIG_REGS];
    conf_regs[XHEEP_CONF_IDX_CODE_SIZE]     = code_size_words;
    conf_regs[XHEEP_CONF_IDX_FETCH_ADDR]    = fetch_addr;
    conf_regs[XHEEP_CONF_IDX_FETCH_TRIGGER] = 1;
    conf_regs[XHEEP_CONF_IDX_EXIT_TRIGGER]  = 0;

    xheep_program_conf_regs(dev, conf_regs, is_producer);
    xheep_start(dev);
    return xheep_wait_done(dev, max_polls, NULL);
}

static inline void xheep_program_start(struct esp_device *dev, bool is_producer)
{
    uint32_t conf_regs[XHEEP_NUM_CONFIG_REGS];
    conf_regs[XHEEP_CONF_IDX_CODE_SIZE]     = 0;
    conf_regs[XHEEP_CONF_IDX_FETCH_ADDR]    = 0;
    conf_regs[XHEEP_CONF_IDX_FETCH_TRIGGER] = 0;
    conf_regs[XHEEP_CONF_IDX_EXIT_TRIGGER]  = 1;

    xheep_program_conf_regs(dev, conf_regs, is_producer);
}

#endif
