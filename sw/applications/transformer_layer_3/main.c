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
static int16_t transformer_layers_0_0_norm_weight[16] = {2900, 11758, 3542, -2564, -4548, 3770, 8844, 3876, -8763, -6752, 9440, -7307, -1987, -9859, 3049, -1294, };
static int16_t transformer_layers_0_0_norm_bias[16] = {6652, 6135, -4798, -8732, -4134, -10306, -3421, 8975, -2614, -3089, -3348, -429, 2972, -1035, 5087, 3245, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H0[64] = {-1064, 9965, -381, 6263, 4654, -7769, -7935, -3293, 5505, 5604, -5498, -1342, 1351, 2409, -3997, -7390, 1165, 47, -10250, -5722, -8111, -1391, 9703, 10436, -11079, 1254, -11342, 8410, 9151, -2306, 10710, 5926, 1478, -1153, -7401, -6678, -4387, -2006, 8605, -7287, -7477, 495, 1955, -3019, 2315, 2426, -6812, 5607, -9636, 6573, -3351, 10719, 3858, 5477, -1335, -6160, 8944, 4060, -5849, -11923, -1427, -11001, 2042, 5250, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H1[64] = {6035, 7410, 1532, 2295, 10304, 2815, -9856, -4817, 8844, 6039, -1400, -6285, -2417, -10479, 7890, -4163, 127, -1907, 2521, -3402, -2234, 7472, -9928, -9723, -2303, 7535, -10100, 3058, -702, -2471, 2456, 5651, -9051, 6214, 8397, 5457, 2058, -2360, 6492, 2105, -9030, 4516, 67, -1011, -11952, 11038, 8040, 1257, -11650, -3643, -8211, 7304, -9303, 6318, 10677, 1222, 2022, 4243, -3521, 11856, -955, -2266, 4076, -8079, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H2[64] = {-8523, -9628, -1475, -103, 3217, -10723, 7927, 5359, 58, 11939, -6076, 3765, 4911, -5023, -3160, -10452, -6988, -9111, -4101, 3669, 6278, -3848, 3382, -534, 3165, -8975, -6973, 961, -2474, 8291, -7657, -3334, 9431, -2871, 696, 856, 11053, -3199, 1439, 11395, 9899, 624, 2995, -2465, -4316, -5377, 2820, -3769, -9789, 6051, 8953, -3619, 2965, -6019, -2731, -4510, -11574, -7001, 2092, -9486, 5853, -1995, 3321, -1643, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H3[64] = {5402, -3201, 819, -5576, -1, -3897, -4411, 338, -5723, -1533, 3932, 11624, 7420, 9220, -7637, -7000, 11697, -1932, 1243, 8693, 668, -30, -7447, 7107, 4923, -6665, -8076, -8003, -5263, 5897, -8847, 7932, 1094, -2141, -10003, -7174, 10261, 5190, 5302, -7469, -8490, 10394, 8883, 4052, 8790, 9398, -6033, 5122, 4894, -11798, -11532, -11081, 7299, 11878, -11099, 4398, 10880, -1512, 5273, -8983, 11785, 10308, 9533, -9654, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H0[64] = {1826, -10230, -8519, -11424, -11841, -2573, -861, -210, -1422, -132, 10662, 3736, 9686, 5176, -3153, 1415, 4162, 3801, -1177, 8960, 11614, 2026, -9274, 91, -4221, -7124, 7007, -9653, 10781, 8344, -8400, -9540, -2309, -11774, 8063, -11470, 8045, 9367, -6237, 6646, 4416, -2, 10552, -6740, 10504, 6960, -9181, 11099, 1583, 7530, 117, 6455, -3403, 8044, -1355, -9875, 2023, 955, -2112, -2556, -11738, -5699, 11289, -3610, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H1[64] = {11087, 2754, -7859, 8380, -4644, -1763, -9260, -5111, 10993, -8722, -11691, -7654, 1976, -3269, -5903, -11565, 10669, 2263, 10507, 10118, -11938, -11642, -2903, -8321, 9639, -8343, -7628, 3016, -1459, 8674, -2724, 5044, 6437, 11128, 3399, -11040, -8814, -408, 1406, 4158, -499, 9116, 753, 2097, 6209, -7163, 5616, 6895, 11144, -4256, -33, 11457, -995, -8093, 8611, 507, -1818, 10799, -4732, 9971, 5263, 11277, 10539, 1991, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H2[64] = {-6507, 4759, 8235, -2896, -10342, 5902, -8081, -10631, -4307, -7169, 9874, 3262, -4197, -6001, -11899, -6263, 6750, -10302, 9112, -10927, -11361, 11593, -5617, 8205, -5735, -11078, -5874, 7799, 9792, -9129, -6865, 1, -6839, -2037, -1656, -1491, 10710, 7390, 6020, -11396, -10629, -3391, 994, 11657, 9969, -1039, -9512, -155, 6603, 9757, -11667, 3083, 8109, -8411, -1389, 10249, 1772, 42, 6317, -8206, -2815, -8929, 8392, -10391, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H3[64] = {-11462, 3664, 4643, 9475, 8731, -1896, 3901, -1774, -7691, 10775, 3630, -8236, -2563, 2937, -10013, 5969, 4408, 6188, 11657, 8157, 5712, -922, 2431, 2411, -8207, 11757, 6635, 11459, -4572, 8626, -1545, 9442, 5883, -11114, -8371, -5546, 4382, -1222, 10778, -8336, -4952, 8327, -3384, -4938, -10646, 2837, -7479, 4649, 6800, -1195, 5665, -6048, 3561, -6261, 11432, -10506, -11747, 5604, 1033, 6734, -2595, 4870, -5134, 260, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H0[64] = {-8884, -5924, 3338, -7925, -458, -3201, -2146, -6549, -6333, 5483, -5658, -7082, -4053, -1410, -1073, -2316, -4227, -7829, 3006, 1402, -1601, 11412, 1511, -4575, -6748, 8005, -6643, 6202, -9629, -3578, -1792, -9368, 2751, 10001, -8725, 1158, -8534, -6477, -1543, -144, 5619, 3069, -11569, 2082, 5068, -922, 9913, -552, -11613, 227, 1760, -8501, 1489, 4010, -447, -1015, -2281, 4329, 4092, -2989, 5570, -11589, 358, 8435, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H1[64] = {-3117, -3406, -5714, 3239, -6900, 3602, -5796, -4367, -5009, 3867, -3890, 7734, 2584, -3827, 9153, 1458, -3362, 2356, 4076, 7487, -700, -5873, -4674, 3634, 6536, -8460, 2906, -10830, 4094, -901, -2426, 4722, 5926, 489, 10256, -7905, -5890, 1825, 6153, -3637, -1210, -212, -6546, -8825, -3124, 10219, 9903, -4326, -1616, 6617, 10501, -1404, -3965, 10348, -8872, 7215, -8949, -2787, 441, 9408, -2734, -10870, -8967, 9686, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H2[64] = {8017, -2373, -7021, -3471, 5598, -7054, 2197, -7933, 4073, -9957, 9830, -2764, 6732, 2148, 5824, 7043, 3384, 4683, -4243, -2614, -11100, -10695, 6009, -3611, 427, -3386, 5908, -659, -7534, -2033, 2113, 3486, -1156, -7035, -7187, -9909, -3968, -200, 2832, -5333, -286, -2476, 3585, -9727, -2312, 8763, -3556, -2049, -6263, 3638, -1566, -52, 6071, -1080, 9711, 681, -4472, 7932, -7838, 2492, 6225, 7987, 5217, -8949, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H3[64] = {2263, -828, -426, 9123, 786, -4799, 2624, -10890, -2381, -11867, 3633, -7387, -5381, -10088, 7519, -11614, -5183, 9837, 9284, -7051, 1984, -9317, 6791, -487, -10679, -11732, -7075, 9036, 4744, -7482, -8263, -3396, -2386, -1894, -3727, -7297, -6092, -9672, 8610, -117, -10392, 5384, 5429, 7559, -9367, 7243, -7495, -10470, 6146, -8338, -1714, 10083, -8764, -6437, -7734, 7163, 1784, 6723, 8832, -9508, 11022, 2531, 10574, 8032, };

static int16_t transformer_layers_0_0_fn_projection_weight[256] = {-10521, 3010, 11079, -10692, -2228, 7774, 7651, -327, -2606, 7582, -8828, -2210, 2913, 11985, 2547, 10414, 670, -2306, 11741, -2151, 2857, -9808, -5874, -8429, -1277, -3255, 9792, -4982, 5119, -1741, 10630, -5057, 2522, 6436, 2439, -1014, 4781, -6417, -5527, -792, -300, 1464, -8832, 9690, 1553, 7724, 2283, 4619, 11930, 1400, -6267, 8190, 4917, 8172, 10264, -3472, -7816, -10079, -8576, -11948, -8284, 911, 8888, -2985, -9135, 8755, 4895, -7276, 5277, 6573, 2643, 8480, 1613, 7416, 11582, -1609, 11428, 7951, -2975, -886, -10543, 434, 9736, -11219, -7653, -8806, 8415, -7699, -9499, -607, 2846, -8875, 6674, -5693, -11335, -7144, 1079, 1001, 206, 7934, 5107, 2292, 2725, -1301, 5427, 8052, -5320, -6497, -1172, -3923, -114, 11165, -10228, -6532, 6022, -2364, -8018, -8297, 2942, 4760, -8258, -3797, -1930, -9941, -522, 3789, 8821, 6126, 10706, -4031, 7993, 9916, 3506, 3310, -3911, 1237, -11579, 8271, -4709, 11805, 1928, 147, -2335, -11708, 5060, 1803, -8112, 26, -1363, -5516, 10619, 6380, -9745, -5832, 6584, -4978, 3648, 5658, -5764, 11555, -6776, -10561, 8562, -7965, -8302, 5049, 4118, 6386, 273, -2690, 6048, -6153, 347, 7524, 3952, -8554, 8022, -4055, -595, -1204, 2226, 5034, -1678, 2016, -3281, -4613, -11996, 7834, 10250, -4790, -1065, -2192, -9457, 3659, 6174, 8964, -3269, 1834, -4095, -6783, 3832, -1704, -9142, -11751, -7610, -8986, 8937, -9828, -4085, -416, -6238, -10971, 10531, -6925, -8199, 9053, -3440, 4880, 10768, 1505, -10124, 10380, -6965, 1584, 1736, -6870, 9582, 4353, -1140, -6356, 171, -6224, 3328, 5591, -4622, 184, -7883, -11252, 4993, -3974, 8455, -7826, -3253, 5704, 6298, -10736, 732, -8932, -9954, -3982, -10878, -7860, -9897, 8564, 11587, -3095, };
static int16_t transformer_layers_0_0_fn_projection_bias[16] = {8234, -11378, -8884, 5184, -1457, 7896, 9219, 4181, 1709, 4170, 6927, 9758, -7823, 9520, 11539, 11559, };

static int16_t transformer_layers_0_1_norm_weight[16] = {-7036, -4929, -5602, 12000, 7915, 4401, 10928, 7070, 4401, 4543, 8440, 4032, 7513, 3240, 9665, 4764, };
static int16_t transformer_layers_0_1_norm_bias[16] = {-4966, -11056, 10140, -10631, 10763, -10422, -2550, 11826, -8827, -3479, 9280, -11224, -10767, -5968, 7511, -1542, };

static int16_t transformer_layers_0_1_fn_ff1_weight[64] = {9748, 974, -7771, 11148, 784, -5356, -10570, 10089, -83, 11412, -11212, 7730, 6312, 11113, 6549, 410, 519, -5932, -788, 9116, -6348, -7546, -4958, 7785, 8602, -6510, 3413, 6738, 7367, -2732, 3887, -1685, 11509, 6762, 391, 9290, -4701, -6567, -6269, 11041, 1261, 3343, -2675, 8469, 2338, 8707, -3823, -9992, -8680, -10549, 8896, 7160, 3868, 6479, 860, -4988, 9276, 4394, -9013, -8654, 2407, 11203, 6487, 2827, };
static int16_t transformer_layers_0_1_fn_ff1_bias[4] = {8061, 8141, 4859, 887, };
static int16_t transformer_layers_0_1_fn_ff2_weight[64] = {-1831, 1171, 2662, 6280, -8450, 1050, 3433, 8331, 7881, 5241, 6500, 6692, -8187, 11140, 3520, -8980, 3289, -11978, 4893, -5297, 10154, -9057, 1183, -4014, 2072, 2952, -1963, -7108, -1370, 6199, -9840, -1431, 9699, 2585, -3117, -9820, 11184, -10809, 137, 10254, 739, 8110, 10384, -7838, 8173, -6704, -3144, 2445, 9294, -1265, -5586, -5168, 8001, -11576, 7411, 4188, -1144, -11553, 8211, -4096, -6899, 2289, 10551, -6808, };
static int16_t transformer_layers_0_1_fn_ff2_bias[16] = {11501, -6290, 9151, -2350, -8479, 3705, -2504, -1411, 1305, 10632, -752, 7418, 3149, -10791, -5370, 5724, };

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
    static uint32_t done_word = 1u;

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

#if CONTINUE_RUN
    // 4) In continuous mode, copy done word to end of buffer and send in one transfer
    volatile uint32_t *done_word_ptr = (volatile uint32_t *)(layer_out + layer_bytes);
    *done_word_ptr = done_word++;
#endif

    // 3) Push output back to ESP-visible address
    cfg.addr = (uint32_t)XHEEP_LAYER_OUT_ADDR;
#if CONTINUE_RUN
    cfg.len_bytes = layer_bytes + XHEEP_LAYER_DONE_BYTES;
#else
    cfg.len_bytes = layer_bytes;
#endif
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
