#include "common/xheep_common.h"
#include "core_v_mini_mcu.h"
#include "soc_ctrl_regs.h"
#include "esp_heep.h"

static esp_heep_profile_p2p_data_t local_data __attribute__((aligned(4)));

#if ESP_HEEP_PROFILE_P2P_USE_P2P
#define ESP_HEEP_PROFILE_P2P_WRITE_USER XHEEP_ESP_DMA_USER_P2P
#else
#define ESP_HEEP_PROFILE_P2P_WRITE_USER XHEEP_ESP_DMA_USER_MEM
#endif

static inline void xheep_signal_exit(uint32_t exit_code)
{
    volatile uint32_t *exit_value =
        (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALUE_REG_OFFSET);
    volatile uint32_t *exit_valid =
        (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALID_REG_OFFSET);

    *exit_value = exit_code;
    *exit_valid = 1u;
}

static void fill_pattern(uint8_t *buf, uint32_t len)
{
    for (uint32_t i = 0; i < len; ++i) {
        buf[i] = (uint8_t)((i * 29u + 7u) & 0xffu);
    }
}

int main(void)
{
    fill_pattern(local_data.bytes, ESP_HEEP_PROFILE_P2P_SIZE_BYTES);

    esp_dma_config_t cfg = {
        .addr = XHEEP_ESP_ADDR(ESP_HEEP_PROFILE_P2P_WRITE_USER, ESP_HEEP_PROFILE_P2P_DATA_OFFSET),
        .len_bytes = ESP_HEEP_PROFILE_P2P_SIZE_BYTES,
        .xheep_addr = (uintptr_t)local_data.bytes,
        .dir_write = 1u,
        .read_user = XHEEP_ESP_DMA_USER_MEM,
        .write_user = ESP_HEEP_PROFILE_P2P_WRITE_USER,
    };

    xheep_esp_dma_configure(&cfg);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_DIR_WRITE |
                        XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();

    xheep_signal_exit(0u);
    return 0;
}
