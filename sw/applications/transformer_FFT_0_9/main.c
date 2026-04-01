/*
 * X-HEEP pre-layer app (FFT + patch embedding frontend)
 * Input (DMA in):
 *   - raw signal windows and frontend parameters (see common/xheep_common.h)
 * Output (DMA out):
 *   - first-layer-ready tokens: (D_SEQ+1) x D_MODEL
 */

#include <stdbool.h>
#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "core_v_mini_mcu.h"
#include "soc_ctrl_regs.h"
#include "esp_heep.h"
#include "common/xheep_common.h"
#include "SYLT-FFT/fft.h"

#define NUM_FRACTION_BITS 0
#define MUL(x, y)       ((int32_t)((x) * (y)))
#define MUL_LONG(x, y)  ((int32_t)((x) * (y)))
#define MUL_HQ(x, y)    ((int32_t)((x) * (y)))

typedef int16_t quant_bit_width;

enum {
    XHEEP_FFT_DBG_BOOT = 32001,
    XHEEP_FFT_DBG_DMA_IN_CFG = 32002,
    XHEEP_FFT_DBG_DMA_IN_WAIT = 32003,
    XHEEP_FFT_DBG_DMA_IN_ERR = 32004,
    XHEEP_FFT_DBG_COMPUTE = 32100,
    XHEEP_FFT_DBG_TOKEN_START = 32110,
    XHEEP_FFT_DBG_COL_START = 32112,
    XHEEP_FFT_DBG_COL_FFT = 32113,
    XHEEP_FFT_DBG_COL_DONE = 32114,
    XHEEP_FFT_DBG_TOKEN_DONE = 32111,
    XHEEP_FFT_DBG_COMPUTE_DONE = 32120,
    XHEEP_FFT_DBG_DMA_OUT_CFG = 32200,
    XHEEP_FFT_DBG_DMA_OUT_WAIT = 32201,
    XHEEP_FFT_DBG_DMA_OUT_ERR = 32202,
    XHEEP_FFT_DBG_DONE = 32300
};

#define XHEEP_FFT_DEBUG CONTINUE_RUN_DEBUG

static inline void xheep_fft_debug_stage(uint16_t stage, uint16_t arg)
{
#if XHEEP_FFT_DEBUG
    volatile uint32_t *dbg = (volatile uint32_t *)(uintptr_t)XHEEP_LAYER_DONE_ADDR;
    *dbg = (((uint32_t)arg) << 16) | (uint32_t)stage;
#endif
}

static inline void xheep_signal_exit(uint32_t exit_code)
{
    volatile uint32_t *exit_value = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALUE_REG_OFFSET);
    volatile uint32_t *exit_valid = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALID_REG_OFFSET);
    *exit_value = exit_code;
    *exit_valid = 1u;
}

static inline void xheep_prepare_nextrun()
{
    volatile uint32_t *exit_value = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALUE_REG_OFFSET);
    volatile uint32_t *exit_valid = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALID_REG_OFFSET);
    volatile uint32_t *exit_loop = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_BOOT_EXIT_LOOP_REG_OFFSET);

    *exit_value = 0;
    *exit_valid = 0u;
    *exit_loop = 0u;
}

static inline int32_t fxp_div_int_round(int32_t num, int32_t den)
{
    if (den == 0) {
        return 0;
    }
    if (num >= 0) {
        return (num + (den / 2)) / den;
    }
    return (num - (den / 2)) / den;
}

static inline int64_t fxp_div_int64_round(int64_t num, int32_t den)
{
    if (den == 0) {
        return 0;
    }
    if (num >= 0) {
        return (num + (den / 2)) / den;
    }
    return (num - (den / 2)) / den;
}

static inline uint32_t fxp_isqrt_u64(uint64_t x)
{
    uint64_t op = x;
    uint64_t res = 0;
    uint64_t one = (uint64_t)1 << 62;

    while (one > op) {
        one >>= 2;
    }
    while (one != 0) {
        if (op >= res + one) {
            op -= res + one;
            res = (res >> 1) + one;
        } else {
            res >>= 1;
        }
        one >>= 2;
    }
    return (uint32_t)res;
}

static inline int32_t fxp_sqrt_qn(int32_t x_qn)
{
    if (x_qn <= 0) {
        return 0;
    }
    return (int32_t)fxp_isqrt_u64(((uint64_t)x_qn) << NUM_FRACTION_BITS);
}

static inline int32_t fxp_reciprocal_qn(int32_t x_qn)
{
    if (x_qn <= 0) {
        return INT32_MAX;
    }
    {
        int64_t one_qn = (int64_t)1 << NUM_FRACTION_BITS;
        int64_t res = (one_qn * one_qn) / x_qn;
        if (res > INT32_MAX) {
            return INT32_MAX;
        }
        return (int32_t)res;
    }
}

static inline int16_t clamp_i32_to_i16(int32_t v)
{
    if (v > 32767) {
        return 32767;
    }
    if (v < -32768) {
        return -32768;
    }
    return (int16_t)v;
}

static const int16_t hanning[XHEEP_FFT_INPUT_REAL_SAMPLES] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4,
    4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8, 9, 9,
    9, 10, 10, 10, 11, 11, 12, 12, 12, 13, 13, 14, 14, 14, 15, 15,
    16, 16, 16, 17, 17, 17, 18, 18, 19, 19, 19, 20, 20, 21, 21, 21,
    22, 22, 22, 23, 23, 23, 24, 24, 24, 25, 25, 25, 26, 26, 26, 27,
    27, 27, 27, 28, 28, 28, 28, 29, 29, 29, 29, 29, 30, 30, 30, 30,
    30, 30, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31,
    32, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 30,
    30, 30, 30, 30, 30, 29, 29, 29, 29, 29, 28, 28, 28, 28, 27, 27,
    27, 27, 26, 26, 26, 25, 25, 25, 24, 24, 24, 23, 23, 23, 22, 22,
    22, 21, 21, 21, 20, 20, 19, 19, 19, 18, 18, 17, 17, 17, 16, 16,
    16, 15, 15, 14, 14, 14, 13, 13, 12, 12, 12, 11, 11, 10, 10, 10,
    9, 9, 9, 8, 8, 8, 7, 7, 7, 6, 6, 6, 5, 5, 5, 4,
    4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 2, 1, 1, 1, 1,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

static inline uint32_t ilog2_u64_floor(uint64_t x)
{
    uint32_t n = 0;
    while (x >>= 1) {
        n++;
    }
    return n;
}

static inline quant_bit_width compute_log_amp(int32_t real, int32_t imag)
{
    int32_t rs = (MUL_HQ(real, 25) >> 9);
    int32_t is = (MUL_HQ(imag, 25) >> 9);
    int64_t e = ((int64_t)rs * (int64_t)rs) + ((int64_t)is * (int64_t)is);

    // ln(sqrt(eps)) ~= -23 for eps ~= 1e-10.
    if (e <= 0) {
        return (quant_bit_width)-23;
    }

    {
        uint64_t eu = (uint64_t)e;
        uint32_t msb = ilog2_u64_floor(eu);
        uint64_t base = (uint64_t)1u << msb;
        uint32_t frac_q10 = (uint32_t)(((eu - base) << 10) / base); // [0, 1023]
        int32_t f = (int32_t)frac_q10;

        // ln(1+f) with f in Q10: f - f^2/2
        int32_t ln1pf_q10 = f - (int32_t)(((int64_t)f * f) >> 11);
        int32_t ln_e_q10 = (int32_t)(msb * 709) + ln1pf_q10; // ln(2) ~= 0.6931, Q10 => 709
        int32_t ln_amp_q10 = ln_e_q10 >> 1;
        int32_t out = ln_amp_q10 >> 10;

        return clamp_i32_to_i16(out);
    }
}

static inline void initialize_stft(fft_complex_t *data, const quant_bit_width *raw_input_signal)
{
    uint32_t i;

    for (i = 0u; i < XHEEP_FFT_INPUT_REAL_SAMPLES; i++) {
        data[i].r = MUL_HQ(raw_input_signal[i], hanning[i]);
        data[i].i = 0;
    }
    for (i = XHEEP_FFT_INPUT_REAL_SAMPLES; i < XHEEP_FFT_SIZE; i++) {
        data[i].r = 0;
        data[i].i = 0;
    }
}

static void normalize_vector(const quant_bit_width *input,
                             quant_bit_width *output,
                             uint32_t len,
                             const quant_bit_width *weight,
                             const quant_bit_width *bias)
{
    uint32_t j;
    int32_t sum = 0;

    for (j = 0u; j < len; ++j) {
        sum += input[j];
    }

    {
        int32_t mean = fxp_div_int_round(sum, (int32_t)len);
        int64_t variance = 0;
        int32_t sd_qn;
        int32_t sd_inv_qn;

        for (j = 0u; j < len; ++j) {
            int32_t d = (int32_t)input[j] - mean;
            variance += MUL_HQ(d, d);
        }

        {
            int64_t variance_div = fxp_div_int64_round(variance, (int32_t)len);
            int32_t variance_qn = (int32_t)(variance_div >> NUM_FRACTION_BITS);
            sd_qn = fxp_sqrt_qn(variance_qn);
            sd_inv_qn = fxp_reciprocal_qn((sd_qn > 0) ? sd_qn : 1);
        }

        for (j = 0u; j < len; ++j) {
            int32_t v = MUL(((int32_t)input[j] - mean), sd_inv_qn);
            v = MUL(v, (int32_t)weight[j]) + (int32_t)bias[j];
            output[j] = (quant_bit_width)v;
        }
    }
}

static void dense_400x16(const quant_bit_width *input,
                         const quant_bit_width *weight,
                         const quant_bit_width *bias,
                         quant_bit_width *output)
{
    uint32_t out_idx;

    for (out_idx = 0u; out_idx < XHEEP_D_MODEL; ++out_idx) {
        uint32_t i;
        int32_t sum = 0;

        for (i = 0u; i < XHEEP_D_EMBEDDING; ++i) {
            sum += MUL_HQ(weight[i * XHEEP_D_MODEL + out_idx], input[i]);
        }
        sum = (sum >> NUM_FRACTION_BITS) + (int32_t)bias[out_idx];
        output[out_idx] = (quant_bit_width)sum;
    }
}

static void process_token(const quant_bit_width *token_400,
                          uint32_t token_idx,
                          quant_bit_width *out_seq,
                          const quant_bit_width *norm1_w,
                          const quant_bit_width *norm1_b,
                          const quant_bit_width *dense_w,
                          const quant_bit_width *dense_b,
                          const quant_bit_width *norm2_w,
                          const quant_bit_width *norm2_b,
                          const quant_bit_width *pos)
{
    quant_bit_width v1[XHEEP_D_EMBEDDING];
    quant_bit_width v2[XHEEP_D_MODEL];
    quant_bit_width v3[XHEEP_D_MODEL];
    uint32_t j;

    normalize_vector(token_400, v1, XHEEP_D_EMBEDDING, norm1_w, norm1_b);
    dense_400x16(v1, dense_w, dense_b, v2);
    normalize_vector(v2, v3, XHEEP_D_MODEL, norm2_w, norm2_b);

    for (j = 0u; j < XHEEP_D_MODEL; ++j) {
        out_seq[(token_idx + 1u) * XHEEP_D_MODEL + j] =
            (quant_bit_width)((int32_t)v3[j] + (int32_t)pos[(token_idx + 1u) * XHEEP_D_MODEL + j]);
    }
}

static inline uint8_t xheep_fft_read_user(void)
{
    return (uint8_t)(XHEEP_LAYER_USE_P2P_IN ? XHEEP_LAYER_P2P_USER_IN : XHEEP_LAYER_MEM_USER_IN);
}

static inline uint8_t xheep_fft_write_user(void)
{
    return (uint8_t)(XHEEP_LAYER_USE_P2P_OUT ? XHEEP_LAYER_P2P_USER_OUT : XHEEP_LAYER_MEM_USER_OUT);
}

int main(void)
{
    quant_bit_width *packed_in = (quant_bit_width *)(uintptr_t)XHEEP_LAYER_IN_OFFSET;
    quant_bit_width *pre_out = (quant_bit_width *)(uintptr_t)XHEEP_LAYER_OUT_OFFSET;

    const quant_bit_width *raw_input = packed_in + XHEEP_PRE_RAW_OFFSET_ELEMS;
    const quant_bit_width *norm1_w = packed_in + XHEEP_PRE_NORM1_WEIGHT_OFFSET_ELEMS;
    const quant_bit_width *norm1_b = packed_in + XHEEP_PRE_NORM1_BIAS_OFFSET_ELEMS;
    const quant_bit_width *dense_w = packed_in + XHEEP_PRE_DENSE_WEIGHT_OFFSET_ELEMS;
    const quant_bit_width *dense_b = packed_in + XHEEP_PRE_DENSE_BIAS_OFFSET_ELEMS;
    const quant_bit_width *norm2_w = packed_in + XHEEP_PRE_NORM2_WEIGHT_OFFSET_ELEMS;
    const quant_bit_width *norm2_b = packed_in + XHEEP_PRE_NORM2_BIAS_OFFSET_ELEMS;
    const quant_bit_width *cls_token = packed_in + XHEEP_PRE_CLS_OFFSET_ELEMS;
    const quant_bit_width *pos = packed_in + XHEEP_PRE_POS_OFFSET_ELEMS;

    fft_complex_t data[XHEEP_FFT_SIZE];
    quant_bit_width low_token[XHEEP_D_EMBEDDING];
    quant_bit_width high_token[XHEEP_D_EMBEDDING];

    uint32_t ch;

    esp_dma_config_t cfg = {
        .addr = (uint32_t)XHEEP_LAYER_IN_ADDR,
        .len_bytes = XHEEP_LAYER_IN_BYTES,
        .xheep_addr = (uint32_t)(uintptr_t)packed_in,
        .dir_write = 0u,
        .read_user = xheep_fft_read_user(),
        .write_user = XHEEP_ESP_DMA_USER_MEM
    };

    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_BOOT, 0u);
    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_DMA_IN_CFG, 0u);
    xheep_esp_dma_configure(&cfg);
    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_DMA_IN_WAIT, 0u);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();

    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_COMPUTE, 0u);

    // cls token + positional row 0 (only one split should emit this row)
#if XHEEP_SPLIT_EMIT_CLS
    for (ch = 0u; ch < XHEEP_D_MODEL; ++ch) {
        pre_out[ch] = (quant_bit_width)((int32_t)cls_token[ch] + (int32_t)pos[ch]);
    }
#endif

    for (ch = XHEEP_SPLIT_CHANNEL_START; ch < XHEEP_SPLIT_CHANNEL_END; ++ch) {
        uint32_t group;
        for (group = 0u; group < (XHEEP_STFT_TIME_STEPS / XHEEP_STFT_PATCH_WIDTH); ++group) {
            uint32_t col;
            uint32_t token_low_idx = ch * 6u + group;
            uint32_t token_high_idx = ch * 6u + group + 3u;

            memset(low_token, 0, sizeof(low_token));
            memset(high_token, 0, sizeof(high_token));
            xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_TOKEN_START, (uint16_t)token_low_idx);

            for (col = 0u; col < XHEEP_STFT_PATCH_WIDTH; ++col) {
                uint32_t time_step = group * XHEEP_STFT_PATCH_WIDTH + col;
                const quant_bit_width *raw_ptr = raw_input +
                    ch * XHEEP_RAW_SIGNAL_CH_SAMPLES +
                    XHEEP_STFT_WINDOW_STRIDE * time_step;
                uint32_t b;

                xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_COL_START, (uint16_t)time_step);
                initialize_stft(data, raw_ptr);
                xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_COL_FFT, (uint16_t)time_step);
                fft_fft(data, XHEEP_FFT_BITS);
                xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_COL_DONE, (uint16_t)time_step);

                for (b = 0u; b < XHEEP_STFT_PATCH_HEIGHT; ++b) {
                    low_token[b * XHEEP_STFT_PATCH_WIDTH + col] = compute_log_amp(data[b].r, data[b].i);
                    high_token[b * XHEEP_STFT_PATCH_WIDTH + col] = compute_log_amp(data[b + XHEEP_STFT_PATCH_HEIGHT].r,
                                                                                    data[b + XHEEP_STFT_PATCH_HEIGHT].i);
                }
            }

            process_token(low_token, token_low_idx, pre_out,
                          norm1_w, norm1_b,
                          dense_w, dense_b,
                          norm2_w, norm2_b,
                          pos);

            process_token(high_token, token_high_idx, pre_out,
                          norm1_w, norm1_b,
                          dense_w, dense_b,
                          norm2_w, norm2_b,
                          pos);

            xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_TOKEN_DONE, (uint16_t)token_high_idx);
        }
    }

    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_COMPUTE_DONE, 0u);

    cfg.addr = (uint32_t)(XHEEP_LAYER_OUT_ADDR + XHEEP_SPLIT_OUT_OFFSET_BYTES);
    cfg.len_bytes = XHEEP_SPLIT_OUT_BYTES;
    cfg.xheep_addr = (uint32_t)(uintptr_t)(pre_out + XHEEP_SPLIT_OUT_OFFSET_ELEMS);
    cfg.dir_write = 1u;
    cfg.read_user = XHEEP_ESP_DMA_USER_MEM;
    cfg.write_user = xheep_fft_write_user();

    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_DMA_OUT_CFG, 0u);
    xheep_esp_dma_configure(&cfg);
    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_DMA_OUT_WAIT, 0u);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_DIR_WRITE |
                        XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();

    xheep_fft_debug_stage((uint16_t)XHEEP_FFT_DBG_DONE, 0u);

#if CONTINUE_RUN
    xheep_signal_exit(0);
    uint32_t cacca=0;
    for(int i=0; i < 1000000; i++) {
        cacca++;
    }
    xheep_prepare_nextrun();
    while (1) {
    }
#else
    xheep_signal_exit(0);

    return 0;
#endif
}
