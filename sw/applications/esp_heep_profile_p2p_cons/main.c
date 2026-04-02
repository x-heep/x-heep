#include "common/xheep_common.h"
#include "core_v_mini_mcu.h"
#include "soc_ctrl_regs.h"
#include "esp_heep.h"

static esp_heep_profile_p2p_data_t local_data __attribute__((aligned(4)));
static volatile uint32_t consume_sink;

#if ESP_HEEP_PROFILE_P2P_USE_P2P
#define ESP_HEEP_PROFILE_P2P_READ_USER XHEEP_ESP_DMA_USER_P2P
#else
#define ESP_HEEP_PROFILE_P2P_READ_USER XHEEP_ESP_DMA_USER_MEM
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

static uint32_t consume_checksum(const uint8_t *buf, uint32_t len)
{
    uint32_t checksum = 0u;

    for (uint32_t i = 0; i < len; ++i) {
        checksum = (checksum << 5) - checksum + buf[i];
    }

    return checksum;
}

int main(void)
{
    esp_dma_config_t cfg = {
        .addr = XHEEP_ESP_ADDR(ESP_HEEP_PROFILE_P2P_READ_USER, ESP_HEEP_PROFILE_P2P_DATA_OFFSET),
        .len_bytes = ESP_HEEP_PROFILE_P2P_SIZE_BYTES,
        .xheep_addr = (uintptr_t)local_data.bytes,
        .dir_write = 0u,
        .read_user = ESP_HEEP_PROFILE_P2P_READ_USER,
        .write_user = XHEEP_ESP_DMA_USER_MEM,
    };

    xheep_esp_dma_configure(&cfg);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();

    consume_sink = consume_checksum(local_data.bytes, ESP_HEEP_PROFILE_P2P_SIZE_BYTES);
    xheep_signal_exit(0u);
    return 0;
}
