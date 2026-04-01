/*
    * X-HEEP transformer layer app
    * - DMA in:  XHEEP_LAYER_IO_ADDR -> local SRAM
    * - Compute: one layer (placeholder for now)
    * - DMA out: local SRAM -> XHEEP_LAYER_IO_ADDR
    */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "common/xheep_common.h"
#include "core_v_mini_mcu.h"
#include "soc_ctrl_regs.h"
#include "esp_heep.h"
#include "addNormC.h"
#include "selfattentionC.h"
#include "transposeC.h"
#include "dense_layerC.h"
#include "csr.h"
#include "handler.h"

#define DEBUG_TRANSFORMER_LAYER 0

enum {
    XHEEP_DBG_BOOT = 31001,
    XHEEP_DBG_DMA_IN_CFG = 31002,
    XHEEP_DBG_DMA_IN_WAIT = 31003,
    XHEEP_DBG_COMPUTE_ENTER = 31100,
    XHEEP_DBG_SETUP_ATTN = 31110,
    XHEEP_DBG_NORM0 = 31120,
    XHEEP_DBG_SA_HEAD_START = 31130,
    XHEEP_DBG_SA_HEAD_DONE = 31131,
    XHEEP_DBG_TRANSPOSE = 31140,
    XHEEP_DBG_CONDENSE = 31150,
    XHEEP_DBG_RESID0 = 31160,
    XHEEP_DBG_NORM1 = 31170,
    XHEEP_DBG_FF1 = 31180,
    XHEEP_DBG_FF2 = 31190,
    XHEEP_DBG_RESID1 = 31200,
    XHEEP_DBG_MEMCPY_FINAL = 31210,
    XHEEP_DBG_COMPUTE_EXIT = 31220,
    XHEEP_DBG_DMA_OUT_CFG = 31300,
    XHEEP_DBG_DMA_OUT_WAIT = 31310,
    XHEEP_DBG_DONE = 31320
};

static inline void xheep_debug_stage(uint16_t stage, uint16_t arg)
{
#if DEBUG_TRANSFORMER_LAYER
    volatile uint32_t *dbg = (volatile uint32_t *)(uintptr_t)XHEEP_LAYER_DONE_ADDR;
    *dbg = (((uint32_t)arg) << 16) | (uint32_t)stage;
#endif
}


// ---------------------------------------------------------------------------
// Layer 0 weights/biases (copied from soft/common/apps/baremetal/transformer_ESP/data_cpp/data.h)
// ---------------------------------------------------------------------------
static int16_t transformer_layers_0_0_norm_weight[16] = {-10873, -10385, 11344, -6351, 1116, -7812, 10469, 5502, -4890, -6629, -5970, -6049, -393, -3881, 6473, 271, };
static int16_t transformer_layers_0_0_norm_bias[16] = {6321, 11923, 2990, -10355, 202, 2808, -777, 8129, -3273, 7292, 1980, 5912, 10527, 8797, 9594, 7132, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H0[64] = {8976, -502, 9391, 9375, 9223, -11726, 9385, -5549, 5256, -111, 1626, -11751, 8363, 10617, 10467, 10781, -11235, -9335, -10675, 5241, -3553, 6743, 7441, -11906, -11014, -10350, -10455, 5001, 6360, 7274, -10489, -4121, -6991, 11803, -1575, 5406, -11731, -2829, -2844, -8522, -5167, -8523, -10346, 6826, -8580, 48, 5551, 4179, 10932, 4815, -2676, 8743, -7487, -85, 3352, 3231, 1341, 8173, 5036, 5390, -10973, 10344, -10680, 7388, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H1[64] = {-1719, 11484, 4146, 6873, 7635, -10249, 436, -4968, -11100, -8552, -1229, -1529, 9339, -5402, -4196, -7057, -4100, -9341, -5554, 11216, 5706, -7682, 11079, -716, -7660, 6339, -10222, -3390, 2509, 4706, 3504, -9757, -11856, -4950, 2623, -2071, -1622, 8081, -6735, 8585, -6533, 3060, 566, -6776, -4518, 985, 8478, -2266, -10403, 1385, 10980, 4188, -3604, 3907, 9862, -1571, 4920, 7438, -2626, 7269, -6588, -6751, 846, 2326, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H2[64] = {-6694, 11660, 2499, 7823, -4881, -9151, 4324, -1595, -4819, -4320, 4533, -8599, -4741, 9829, 3825, -1253, -4769, -9547, 3659, 7028, 8983, -4078, 847, -6800, -802, -1719, -8831, 5283, 5464, 2866, -8214, -7047, 500, 3003, -7273, 11948, 2795, 5934, 11774, -1897, 2845, -584, 8823, 10473, 5630, -9865, -1883, 4495, 4700, 4742, -5406, -666, 8394, 3627, -10305, -7759, -11421, 7534, 1766, 7450, -10081, -1129, -1952, -2850, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H3[64] = {2846, 4948, -11831, -13, 1164, -4500, 5679, 1258, 8910, 8534, -5999, 9193, 5623, -6438, 8430, 6336, -3494, 10985, -1004, -7580, 4748, -3704, 2600, 5934, -1891, -3118, -3427, -4482, -10122, 4248, -2217, -6540, 11663, -5623, 11719, -9983, 11945, 10905, 9002, 10052, 6402, 10246, 10013, 1553, -4190, 6950, 6356, -2523, -3816, 4490, -178, 10730, 2482, -7399, -8667, 11686, 6680, 5332, 1375, -10816, 10384, 6174, -11899, 10187, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H0[64] = {10030, 5842, 10494, -213, -4652, 11271, -11330, 3089, 10958, 7914, -4658, -580, 8001, -6528, 2687, 10294, -1164, 11524, 8884, 5467, -5178, 7561, 11470, 5233, 4357, -6207, -10093, -6872, 8557, -6707, 2047, -5979, -1429, -2737, 8802, 2606, -4514, -10841, 5936, 3786, 253, -10014, 5986, -10402, -6081, -4002, -11644, 5530, 4219, -4448, 9083, 8665, -1386, -11196, 4004, 5370, 8950, -764, -5784, 7289, -9035, 3066, -798, -10817, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H1[64] = {6207, -201, 4634, -1474, -3653, 9013, -4764, -8973, -6743, 7496, 1843, -9993, -8061, 3002, 8251, -1665, -3092, 6798, -8929, 9754, -3980, -1671, -9363, -9390, -11767, -4918, 9884, 7230, 10735, -7201, 8296, -2479, 2124, 11113, -10395, -1079, 9401, -661, 5238, 362, -6048, -7536, -141, -11940, -321, -2472, 1566, -9881, 9247, 2454, 5572, -4018, -7724, 3375, -9966, -3218, -10461, 8267, 6462, 3738, 10209, -8997, 8096, 2802, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H2[64] = {-1633, -434, -9379, 4206, -4512, 3791, -11672, 4307, -5022, 7695, 10933, -316, -1986, -6516, 11741, 3679, -3356, -6066, 2085, -10867, 5916, -5636, -4025, 8073, 7222, 206, 6508, -3167, -1332, -9295, -4773, -5697, 8315, 9640, -9604, -4155, -6792, 356, -7355, 443, 3864, -3220, 4666, 10670, 1270, 3952, -7901, -11071, 3886, -6046, 2965, 11112, 427, 8370, 934, -651, -1153, 669, -7190, -2308, -11724, -2322, -11356, -3589, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H3[64] = {3352, -7036, -2345, -239, 3457, 2222, -2059, -11999, -5348, 1690, 9784, -2247, -102, -2512, 4559, 5462, 10287, 700, 10550, 6587, 7906, 7619, -8391, -3333, 9517, -4537, 11859, 5431, -3688, -11295, 6766, 987, 7157, -2792, -8075, -1925, -6935, -5616, -8116, 7237, -8002, 5946, 1022, 10592, 11736, 1220, -2985, 8123, 2364, -5065, -2993, 9948, -2081, 11553, 6781, -11970, -7602, 4211, 11051, -4905, 11935, 808, 1057, 6448, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H0[64] = {6221, 2843, -9676, 2411, -5207, -8199, 5970, -3655, 6295, -1100, 493, -5747, 4011, 5050, -710, -10171, 5899, -549, -1028, 3440, -4916, -11615, -7897, 6673, -2488, 10659, -1122, 2571, -8887, -7674, 5303, 2641, 307, -9882, 5208, -6678, -7963, -3006, 8397, -2650, -11418, 2943, 1528, -5050, -9087, -2192, -10764, 5361, 10807, 2044, -292, 8319, -923, 1679, -2301, 6075, -6486, -7656, -5485, -5029, -8459, -9621, 4655, 3343, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H1[64] = {-7349, 1717, -9702, 857, 10201, -9518, 10424, -3990, 9866, 6986, -525, -10196, -8550, -7226, 9358, 3930, 7650, 10023, -1282, 11113, -3443, 7941, 11813, 1042, -1163, -3127, -8965, 7225, -11164, 10594, -3082, 7495, -3206, 11605, -1716, -7900, -3654, -6976, 10949, 11429, -8796, -10145, -5848, -6247, -8350, -2467, -7180, -1888, -11284, -2829, 6703, -4209, 9114, 10112, 4836, 9308, 11368, 1324, 11875, -25, -186, -2200, 5372, -3715, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H2[64] = {10679, -950, 9269, 11690, 9357, -4816, -8601, -7284, 7541, 1130, 2823, 5808, 1641, -6473, 10856, -10385, 848, -951, 10075, 7718, -9214, -6908, -8326, 3209, 6335, -8261, -8507, 10708, -392, 5027, -4764, -10176, -4961, -10997, -426, -10592, -5622, 7382, -1705, -4302, -7815, 8923, -10589, -655, 5305, 6519, -2765, -10992, 10818, -3516, 5388, 9633, 3293, -8701, 6318, 8261, -1589, -694, 1001, -7912, 8781, -1335, 2277, -4926, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H3[64] = {-1376, -10092, -5112, -1801, 11756, -7738, -7576, 7749, -4950, 2004, -4107, -1535, 7367, -1328, -6239, 7533, -10215, 10966, 3421, 11385, -1290, 11176, 10673, -6638, -1191, 735, -4143, -9545, -7543, -9592, -8284, 7542, 586, 291, -3978, 7697, 1268, 8996, -9474, -3702, 11124, -1405, -1865, -7597, 11759, 4635, 4800, -7632, -1772, 8893, -4184, -8509, -9780, -10127, -10874, 10912, -9032, -5678, -9747, 1809, 10796, -3264, -10873, -718, };

static int16_t transformer_layers_0_0_fn_projection_weight[256] = {-3476, 4517, 430, -1944, 3791, -5170, -8306, 8804, 4689, -9626, -9849, -2379, -1119, 8927, -1913, -2770, 4202, 11956, -8310, -7833, 6676, -2968, 1039, 1395, -3873, 9002, -4346, 3779, 3859, 8015, 3733, -8079, 6562, 4919, 1138, 3198, 2705, 1864, 9594, -8730, -2060, -10619, 3118, 6761, -7603, -2701, -1754, -5312, 4656, 11712, 11386, -9947, -1277, -4641, 8812, -5319, 744, 6732, 10937, -11320, 2835, 674, 7660, -1855, 8142, -7240, -9289, 10254, 3230, -96, 5602, 9287, -10182, 352, -10988, 9049, -10601, 236, 3588, -9447, -4256, -10847, 6170, 1030, 8152, -11251, -10816, -67, -5255, 5398, -7288, -10012, -6709, 2315, 4680, -7662, -4228, -7500, -5027, -4453, -4820, 11827, -3781, 7542, -9773, 8248, -289, 9756, -1570, 4288, 5419, 5154, -9823, -7127, -5625, 305, 8923, -4018, -2360, -9989, -10852, -237, 7077, 11040, -860, 2306, -8255, -9397, 8781, -2199, 7812, -8726, -10089, -950, -10938, -11712, -10641, 5958, 945, -4434, 5697, 9891, 4093, -2108, -7855, -6619, -6091, 5259, -3609, -6714, -8090, -9399, -1924, 11991, 7219, -3317, -7504, 2940, 11034, -10172, -334, -9124, -5761, 3414, 1685, -8054, -857, 7930, 5492, 2839, -8222, 74, 9911, 6396, -11359, 10491, 1552, 3909, -3938, 1580, 8228, -2219, 3893, 6745, 10788, -7472, -9482, -870, -41, -11164, 11986, 5856, -10024, 2275, -4675, -10051, 9902, 1405, -6848, 1803, -1933, -1205, -11512, 435, -1870, -5516, -1418, 6595, 641, -1575, 608, -174, -10558, -10728, -11419, -9493, 7312, -6103, -2886, 10185, -11316, 9338, 9760, 259, 11630, -5449, 10873, -10242, 11593, 6289, 7962, 4467, 7617, -7578, -5856, 4239, 6037, 5594, -5054, -6914, 8455, 10259, 10989, 5297, -11024, 3170, -6492, 8683, 1651, -11623, 11816, 7890, -4054, 1089, -714, 6266, };
static int16_t transformer_layers_0_0_fn_projection_bias[16] = {-952, 11565, -7055, 3664, -511, 11011, 635, -6526, 1872, -4483, -130, 11983, 7995, -611, 5678, -11692, };

static int16_t transformer_layers_0_1_norm_weight[16] = {-1242, -9103, 8460, -3302, 8109, -4635, -4314, -5598, 3522, 2027, 11047, -6055, 2182, 10038, -3147, 680, };
static int16_t transformer_layers_0_1_norm_bias[16] = {10524, -5378, 7471, -10772, 2398, 9067, 9029, -9252, 7285, -1367, 7039, -88, -6905, 4918, 3949, -10519, };

static int16_t transformer_layers_0_1_fn_ff1_weight[64] = {8823, 9934, -1496, -3102, 7652, -1982, -2541, 2540, 12, -580, 11400, 2477, 10658, -7816, 11475, -8121, -8971, 2289, -5036, 1229, -8866, -3159, -4650, 9565, -3916, 9610, -11823, 2377, -6436, -10022, -7823, -4747, -172, 3412, -2266, -4708, -1091, 11057, 4860, -7151, 10689, 8228, -7911, 11435, 1181, -2188, 8357, -4081, -8827, 5933, -9713, -10060, 5241, 11205, 5017, 317, 4027, -10480, 5764, 1855, 9298, 5646, -279, -11161, };
static int16_t transformer_layers_0_1_fn_ff1_bias[4] = {-9254, -5302, 4898, -9584, };
static int16_t transformer_layers_0_1_fn_ff2_weight[64] = {-2600, -5443, -427, -10890, 10707, 3727, -5690, 5635, 799, 10278, 2885, -6784, 4117, -1877, -9480, -2179, 7039, 4308, 10159, 11627, 9011, -8022, -1586, 2360, -3663, -4692, -7803, -10419, -2838, 1699, 1687, 9575, -1038, -11270, 10374, -11646, 8164, 4571, 439, -7750, -7542, -2561, 5970, -11609, 1791, 5632, 5000, 304, 2921, -5569, 2525, 6290, -3971, 8892, 9173, 10354, -10828, -7055, -26, -7028, -2774, 5238, -5946, -2141, };
static int16_t transformer_layers_0_1_fn_ff2_bias[16] = {7953, 10775, -7065, -10322, 8757, -6462, 5668, -700, 5934, 11284, 1102, -11810, 5235, 4444, -10902, 8294, };

static void compute_layer0(int16_t *input,
                           int16_t *output,
                           int16_t *input_normalized,
                           int16_t *intermediate,
                           int16_t *qkv)
{
    xheep_debug_stage((uint16_t)XHEEP_DBG_COMPUTE_ENTER, 0u);
    const size_t seq_len = XHEEP_LAYER_SEQ_LEN;
    const size_t input_dim = XHEEP_LAYER_D_MODEL;
    const size_t head_hidden = XHEEP_LAYER_D_Q;
    const size_t num_heads = XHEEP_LAYER_NUM_HEADS;
    const size_t ff_size = XHEEP_LAYER_D_FF;

    AddNormalize addnorm0 = createAddNormalize((int)seq_len, (int)input_dim,
                                               transformer_layers_0_0_norm_weight,
                                               transformer_layers_0_0_norm_bias);
    AddNormalize addnorm1 = createAddNormalize((int)seq_len, (int)input_dim,
                                               transformer_layers_0_1_norm_weight,
                                               transformer_layers_0_1_norm_bias);

    Dense q_dense[XHEEP_LAYER_NUM_HEADS];
    Dense k_dense[XHEEP_LAYER_NUM_HEADS];
    Dense v_dense[XHEEP_LAYER_NUM_HEADS];
    SingleHeadSelfAttn self_attn[XHEEP_LAYER_NUM_HEADS];

    int16_t *q_weights[XHEEP_LAYER_NUM_HEADS] = {
        transformer_layers_0_0_fn_to_qkv_weight_Q_H0,
        transformer_layers_0_0_fn_to_qkv_weight_Q_H1,
        transformer_layers_0_0_fn_to_qkv_weight_Q_H2,
        transformer_layers_0_0_fn_to_qkv_weight_Q_H3
    };
    int16_t *k_weights[XHEEP_LAYER_NUM_HEADS] = {
        transformer_layers_0_0_fn_to_qkv_weight_K_H0,
        transformer_layers_0_0_fn_to_qkv_weight_K_H1,
        transformer_layers_0_0_fn_to_qkv_weight_K_H2,
        transformer_layers_0_0_fn_to_qkv_weight_K_H3
    };
    int16_t *v_weights[XHEEP_LAYER_NUM_HEADS] = {
        transformer_layers_0_0_fn_to_qkv_weight_V_H0,
        transformer_layers_0_0_fn_to_qkv_weight_V_H1,
        transformer_layers_0_0_fn_to_qkv_weight_V_H2,
        transformer_layers_0_0_fn_to_qkv_weight_V_H3
    };

    xheep_debug_stage((uint16_t)XHEEP_DBG_SETUP_ATTN, 0u);
    for (size_t n = 0; n < num_heads; n++) {
        self_attn[n].query_layer = &q_dense[n];
        self_attn[n].key_layer = &k_dense[n];
        self_attn[n].value_layer = &v_dense[n];
        int16_t *weights[3] = {q_weights[n], k_weights[n], v_weights[n]};
        create_SingleHeadSelfAttn(&self_attn[n], seq_len, input_dim, head_hidden, weights);
    }

    Dense condense;
    createDense(&condense, num_heads * head_hidden, input_dim,
                transformer_layers_0_0_fn_projection_weight,
                transformer_layers_0_0_fn_projection_bias);

    Dense ff1;
    createDense(&ff1, input_dim, ff_size,
                transformer_layers_0_1_fn_ff1_weight,
                transformer_layers_0_1_fn_ff1_bias);

    Dense ff2;
    createDense(&ff2, ff_size, input_dim,
                transformer_layers_0_1_fn_ff2_weight,
                transformer_layers_0_1_fn_ff2_bias);

    // // addNorm0
    xheep_debug_stage((uint16_t)XHEEP_DBG_NORM0, 0u);
    normalize(&addnorm0, input, input_normalized);

    // Multi-head self-attention
    for (size_t n = 0; n < num_heads; n++) {
        xheep_debug_stage((uint16_t)XHEEP_DBG_SA_HEAD_START, (uint16_t)n);
        compute_SingleHeadSelfAttn(&self_attn[n], input_normalized,
                                   output + n * (seq_len * head_hidden),
                                   qkv, intermediate);
        xheep_debug_stage((uint16_t)XHEEP_DBG_SA_HEAD_DONE, (uint16_t)n);
    }

    // Concatenate heads
    xheep_debug_stage((uint16_t)XHEEP_DBG_TRANSPOSE, 0u);
    multihead_transpose(output, intermediate, seq_len, head_hidden, num_heads);

    // Condense projection
    xheep_debug_stage((uint16_t)XHEEP_DBG_CONDENSE, 0u);
    computeDense(&condense, seq_len, intermediate, output);

    // Residual add
    xheep_debug_stage((uint16_t)XHEEP_DBG_RESID0, 0u);
    add(input, output, (int)seq_len, (int)input_dim);

    // // addNorm1
    xheep_debug_stage((uint16_t)XHEEP_DBG_NORM1, 0u);
    normalize(&addnorm1, input, input_normalized);

    // // Feed-forward
    xheep_debug_stage((uint16_t)XHEEP_DBG_FF1, 0u);
    computeDense(&ff1, seq_len, input_normalized, intermediate);
    activation(&ff1, seq_len * ff_size, intermediate, intermediate);
    xheep_debug_stage((uint16_t)XHEEP_DBG_FF2, 0u);
    computeDense(&ff2, seq_len, intermediate, output);

    // // Residual add
    xheep_debug_stage((uint16_t)XHEEP_DBG_RESID1, 0u);
    add(input, output, (int)seq_len, (int)input_dim);

    // Final output buffer
    xheep_debug_stage((uint16_t)XHEEP_DBG_MEMCPY_FINAL, 0u);
    memcpy(output, input, (size_t)(seq_len * input_dim * sizeof(int16_t)));
    xheep_debug_stage((uint16_t)XHEEP_DBG_COMPUTE_EXIT, 0u);
}

static inline void xheep_signal_exit(uint32_t exit_code)
{
    volatile uint32_t *exit_value = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALUE_REG_OFFSET);
    volatile uint32_t *exit_valid = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALID_REG_OFFSET);
    *exit_value = exit_code;
    *exit_valid = 1u;
}

static inline uint8_t xheep_layer_read_user(void)
{
    return (uint8_t)(XHEEP_LAYER_USE_P2P_IN ? XHEEP_ESP_DMA_USER_P2P : XHEEP_ESP_DMA_USER_MEM);
}

static inline uint8_t xheep_layer_write_user(void)
{
    return (uint8_t)(XHEEP_LAYER_USE_P2P_OUT ? XHEEP_ESP_DMA_USER_P2P : XHEEP_ESP_DMA_USER_MEM);
}

int main(void)
{
    const uint32_t layer_bytes = (uint32_t)(XHEEP_LAYER_ELEMS * XHEEP_LAYER_ELEM_BYTES);

    int16_t *layer_in  = (int16_t *)(uintptr_t)XHEEP_LAYER_IN_OFFSET;
    int16_t *layer_out = (int16_t *)(uintptr_t)XHEEP_LAYER_OUT_OFFSET;
    int16_t *layer_norm = (int16_t *)(uintptr_t)XHEEP_LAYER_NORM_OFFSET;
    int16_t *layer_intermediate = (int16_t *)(uintptr_t)XHEEP_LAYER_INTERMEDIATE_OFFSET;
    int16_t *layer_qkv = (int16_t *)(uintptr_t)XHEEP_LAYER_QKV_OFFSET;
    // Run this app fully polling-only: disable all machine interrupts.
    CSR_WRITE(CSR_REG_MIE, 0u);
    CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8u);

#if CONTINUE_RUN
    while (1) {
#endif

    xheep_debug_stage((uint16_t)XHEEP_DBG_BOOT, 0u);

    // 1) Pull input from ESP-visible address into local SRAM
    xheep_debug_stage((uint16_t)XHEEP_DBG_DMA_IN_CFG, 0u);
    esp_dma_config_t cfg = {
        .addr = (uint32_t)XHEEP_LAYER_IN_ADDR,
        .len_bytes = layer_bytes,
        .xheep_addr = (uint32_t)(uintptr_t)layer_in,
        .dir_write = 0u,
        .read_user = xheep_layer_read_user(),
        .write_user = XHEEP_ESP_DMA_USER_MEM
    };
    xheep_esp_dma_configure(&cfg);
    xheep_debug_stage((uint16_t)XHEEP_DBG_DMA_IN_WAIT, 0u);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();

    // 2) Compute layer
    compute_layer0(layer_in, layer_out, layer_norm, layer_intermediate, layer_qkv);

    // 3) Push output back to ESP-visible address
    cfg.addr = (uint32_t)XHEEP_LAYER_OUT_ADDR;
    cfg.len_bytes = layer_bytes;
    cfg.xheep_addr = (uint32_t)(uintptr_t)layer_out;
    cfg.dir_write = 1u;
    cfg.read_user = XHEEP_ESP_DMA_USER_MEM;
    cfg.write_user = xheep_layer_write_user();
    xheep_debug_stage((uint16_t)XHEEP_DBG_DMA_OUT_CFG, 0u);
    xheep_esp_dma_configure(&cfg);
    xheep_debug_stage((uint16_t)XHEEP_DBG_DMA_OUT_WAIT, 0u);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_DIR_WRITE |
                        XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();

    xheep_debug_stage((uint16_t)XHEEP_DBG_DONE, 0u);
#if CONTINUE_RUN
    }
    return 0;
#else
    xheep_signal_exit(0);
    return 0;
#endif
}
