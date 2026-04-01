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
static int16_t transformer_layers_0_0_norm_weight[16] = {9166, 4100, 5980, 4202, 9582, 4020, 3408, 1920, 4971, -8702, 9735, -9152, 4409, 2100, -1508, -6427, };
static int16_t transformer_layers_0_0_norm_bias[16] = {7290, 9052, 10160, 5760, 6775, 8101, 8651, 7034, -6714, 6073, -2161, 11978, -368, -6191, 5897, 6622, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H0[64] = {9438, -8990, -5230, 9765, 5262, 1268, 6443, 6982, 9368, -7543, 29, 2802, -347, -9059, -3883, -4988, 108, -11192, 10369, 9639, 10296, -9530, -5598, 9187, -9007, -948, 8733, -9704, -810, 5957, 8109, 7021, -9924, -10109, 8144, 8155, 988, -656, -9997, 11325, 172, -6991, -1023, 1136, 6594, 9594, 7629, -5900, -2671, 10442, -10420, 9427, -7786, -3816, 6171, 5727, -11906, -11189, -4827, 597, -4641, -8139, -2128, 6876, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H1[64] = {-2524, -7498, 11453, 11946, 9996, 7933, 8329, 4561, -9706, 4816, -4551, 11251, 7703, 3840, 1768, -8643, -8059, -1982, -7436, -4544, 5145, -11838, 4328, -10401, -8652, 3599, 3610, -8195, 10913, 2749, -9048, 8725, 8096, 2301, -847, -5805, -453, -3565, -3000, -6521, -846, -5848, 10911, -3596, 244, 8845, -10546, 9855, 8098, 2907, 5587, 503, 7254, -2491, 9158, -4461, 6233, 11175, 6084, 7114, 8587, -9827, 8918, -11919, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H2[64] = {10259, -6030, -5951, -5543, 7691, 10120, 5286, -9561, -1381, 2279, -10488, -3228, 3902, -863, 708, -8317, 4287, 3173, -507, 183, -5203, -1033, -1800, 7955, -1346, -6791, 9309, -9396, -10328, -10466, -6378, -8203, 7922, 10283, 770, 4467, -5521, -7913, 9522, -11626, -2974, 1506, 11514, 7561, 9307, -10901, -2526, -2280, -2569, 588, -4646, 9574, -2246, 8797, -6301, 1174, 8637, 3817, 11265, -4873, 4671, 10039, 9252, -5430, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H3[64] = {9482, 3530, 4520, 8895, -11520, 3818, 2185, -11286, -4617, 1597, 1029, 259, 3991, -1447, -8696, -10237, 8047, -11249, -2074, 9309, -8546, 9592, 136, -3519, -10856, -1324, 9592, 319, -3176, -2038, 11883, -2910, -7378, 3001, 11564, 5456, 4650, -11271, -4305, 7421, 3779, 555, -1927, -8067, 6921, 177, -5206, 4790, 9114, -9372, 4936, 11620, 9722, 11356, -10679, -3929, 10944, 2223, 2958, -1761, -11477, 5220, 1490, 6151, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H0[64] = {9467, -11942, 8290, -10966, -7516, 7327, -1817, -6649, -8866, -1062, 11778, -9763, 11385, 6563, -10858, 4951, 11189, -3608, 11405, -6914, 9402, 7230, 4121, 10029, 10056, 7129, 10642, 2317, -9560, -9701, -4105, -7278, 8131, 9623, -10703, -169, -2771, 1102, -5375, -101, 4872, 10442, -8959, -1792, -3902, 7193, -2286, 6710, 8200, -1419, 9862, 11894, -3217, -10872, -3222, 3843, -741, -9029, -8121, 11936, -2873, 4010, -2324, 11320, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H1[64] = {-1671, 1232, 6333, -3386, 4403, -7021, 10016, 9603, 1965, 2625, -10065, -2750, -9402, -976, -5974, 1429, 1611, 1980, -6847, 10578, 559, 10660, 1436, 3187, -6111, -10711, 4540, -650, -6089, -11616, -1467, 4194, -10989, -5779, -7231, 3500, -810, 6841, -4980, 6128, -819, 878, -3488, 1734, 7373, -1626, -6196, -11101, -909, -8486, 6174, 4837, -4731, 11271, 621, 1819, -2732, 8740, 9469, 9951, -9506, 3229, -5170, 7300, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H2[64] = {10474, 8752, -2024, -6246, -5924, -4505, 8752, -3792, 7080, 805, 9923, 4007, -180, -10694, 694, -11278, -4782, 1668, -2040, 160, -10518, -1675, 5757, -4600, -7741, 10377, 7274, 4793, -9454, 5747, 10042, -2819, 2545, -9644, 5202, -4808, 1668, 9482, 4009, -1293, -3693, -4534, 5953, 3394, -4857, 3627, 1226, -2207, -2572, -324, 5511, -9350, 6677, -7952, 3078, -845, 11397, 11691, 10550, 3026, 3726, -11925, -941, -9181, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H3[64] = {8266, -9455, -6841, -6664, 11776, 2104, -10604, 1107, 9616, -599, 10439, 4397, 1691, 4791, -3076, 696, 7892, -5578, 2646, -1232, -1704, -2303, 2431, -8905, 8758, -8788, -523, 10755, -4728, 4073, 1921, 314, 5308, -6071, 6794, -10826, -6814, 3706, -11639, 1620, -2472, 256, 11714, 10262, -6551, 6067, -9771, -1858, 11851, -4219, 1812, 1160, -5855, -6966, -3610, -2640, -8194, -9020, 181, -9622, 5489, 1696, 5942, 2549, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H0[64] = {-6636, 11476, -7845, -9621, 9636, -11306, -4176, 8468, -5470, -9902, -6811, 4001, 10669, 315, -1314, 5789, 7933, -5834, 5157, -3990, -3955, -6133, -10665, 6835, -5327, -5717, 6165, -1748, -6283, -1000, -7280, -10934, -6305, -4961, -9104, 6339, -4926, -1010, 10207, 4561, 1477, 4991, 11561, 6951, 1926, 2144, 7625, -6195, -4967, -6195, -1146, 5169, 4757, -6735, 199, -2888, -6108, -6160, -2415, 8496, 9462, -8340, 3839, 1115, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H1[64] = {-2484, -11363, -6483, -8617, -6586, -3672, 4630, -9293, 931, -5971, -6375, 3603, 10596, 8534, -4640, -7236, 10779, -4888, -3521, 1435, 10338, 9276, -4445, 4850, 607, -2661, -8611, 5543, 642, -3615, -5299, -8278, 4454, -10373, -10020, 1407, 6747, 4316, 8557, 9886, -3790, 9467, 3516, 6487, 10651, -1693, -6287, -682, -11604, 5566, -8800, 2739, 8374, -8884, 6635, 446, -8283, 4367, 9966, 9150, 1932, 2515, 1353, -2447, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H2[64] = {-5949, 6578, -8453, 6962, -281, -1992, -3194, 8180, 6510, 2111, -1274, -11762, 7494, 6871, -1052, 9379, 812, 6946, 11832, -2606, -11911, -10243, 1712, -2152, -2199, -2020, 3138, 5229, 8485, -130, -10586, 3276, 4929, -10399, -9011, -11527, 10925, -8510, 1488, 9934, 1313, -4957, -9146, 4329, 9933, 8807, 1495, -1661, -7141, -5759, -9969, -1663, -4501, -6922, 8627, 7614, 7948, -7103, 234, 9711, 11384, -2024, -3407, 6818, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H3[64] = {-10521, 1035, 10454, -1010, 7989, -9476, 3579, -2973, -8809, -4968, 11499, -2651, 2554, 11893, -604, -6421, -7949, 3624, -2853, 6123, 7103, -3845, 2995, 11368, -7715, 4987, -7332, 2889, 4482, 10503, 10685, -9561, -10431, -981, 4045, -3177, -9992, 3596, 176, 4336, 1154, -6534, -11984, 2890, 716, -4526, 8888, -9617, -3587, -6287, 3062, -10801, -3399, 8855, -3668, -4246, -4331, 4013, 1456, -9054, 845, 6049, -9798, -3530, };

static int16_t transformer_layers_0_0_fn_projection_weight[256] = {-7601, 8210, -4184, -1, 10891, 5474, -729, 741, -11314, 11128, -1004, -232, 285, 9358, 1045, 10171, -18, 1277, -8319, -8596, -9550, -11114, 905, -7918, -7615, -6779, -6508, 2285, 6536, 7154, -10065, 3536, -539, -8875, -3984, 8651, 9969, -9081, -5297, 825, -5550, -10398, -8348, -6501, 8350, -10227, -4445, 8115, -3484, 1242, 5710, -5227, 9567, 1657, -8874, -11733, -4346, 4449, 9996, 552, 6663, -6113, -7957, -1673, -1315, 10323, 2222, -4173, 3291, -10251, 7542, -8084, -10248, 1278, 10835, 5409, -2175, -7080, 7871, 724, -7151, -990, 7621, 4785, 6017, 11141, -8803, 7782, -4283, 8378, 11640, -6146, 3198, -7503, -4971, -3623, -6708, -10286, -5783, -96, 3917, -3851, 881, -7694, 6848, -7115, -7885, -10784, 2792, -10102, 9415, -7772, 5607, 5198, -9075, -7930, 6707, -34, 7447, -275, 11357, 9422, -2730, 88, -6337, 5766, -7441, -5493, -6444, 7506, -3057, 6195, 8966, -9083, 10516, -2804, -4650, 6680, 6529, -8101, -2789, 3000, -5555, -9007, 10182, 6643, 9335, -5689, 10218, -604, -3450, 1586, 938, 4754, -374, -10528, -5351, -3166, 5428, 1437, -162, 2423, -10677, -6087, -4697, 1254, -5305, -8652, 680, -1044, -4588, 4384, 912, -10635, -2801, -432, 7425, -1191, -5275, 2294, -11829, -4062, 7342, -5582, 2927, 5476, 5191, 3960, -362, 8995, 10445, -6906, 7162, 8980, 5210, -1524, 2512, 5508, 5552, -9071, -5643, 5592, 9829, -11405, 2443, -10817, -7495, 6313, 960, 6817, 2632, 8582, -9087, -6116, 8543, 4134, -2268, 247, 6261, 3427, 4185, -8463, 2306, 11650, -8214, 1220, 8831, -927, -7990, 1223, 3806, -8310, -2251, -5745, 11018, -4538, 6202, -2834, 8404, 1329, 553, 7620, 8461, -8305, 7329, -2902, 11738, 4728, 8166, -7208, 8162, -6907, -11998, -7594, 832, -661, };
static int16_t transformer_layers_0_0_fn_projection_bias[16] = {2855, -798, 6013, 8561, -5267, -10522, 9686, -3439, 9889, 602, 1621, -4310, 10308, 7014, 11611, 1649, };

static int16_t transformer_layers_0_1_norm_weight[16] = {9848, 8174, 642, -4097, 1644, 2661, -10870, 10707, 8012, 4932, 1684, 11241, -7466, -8107, -6637, -975, };
static int16_t transformer_layers_0_1_norm_bias[16] = {1700, -2071, 3999, 1928, -351, 1752, 3402, 7013, 6062, 9092, -8168, -10210, 9133, 8506, 3201, -1781, };

static int16_t transformer_layers_0_1_fn_ff1_weight[64] = {-4240, 6919, 8101, -2342, 7495, -668, 607, 6532, -4793, 8840, 5954, -5343, 7564, 6526, 6080, 6512, -7070, -2558, -1, 10913, -7943, 9402, 3589, 4437, 10205, 8067, -9536, -11800, -2113, 1658, -2461, -4108, -3953, -5844, -4563, 1898, 5863, 9039, -2877, 8364, -2633, 6558, 4175, -9383, 7104, -11173, 7519, 7414, 11439, -6286, -4878, 2034, 10115, 753, 6344, -764, -878, 5854, 5267, -3737, -5775, -1862, -8111, 496, };
static int16_t transformer_layers_0_1_fn_ff1_bias[4] = {5422, -10838, 8400, 10968, };
static int16_t transformer_layers_0_1_fn_ff2_weight[64] = {-10360, -10495, -2998, 7531, 2699, 2742, -6870, 8034, -8426, -10630, 8164, -1864, -287, 9250, 2123, 10701, 11967, -482, -11423, -306, 8774, -5569, -7825, 7660, 7308, 1551, 4849, -2730, 9576, -11849, -6363, -5923, 1259, 4341, -4400, 11621, -3410, 10149, -8539, 4687, -6073, 3067, 332, 11900, -10051, 5677, 5048, 3828, -5050, 2647, -4789, -4849, -8137, -7350, -3178, -6756, 715, 3133, -7265, -11298, -329, -3538, -1381, -10723, };
static int16_t transformer_layers_0_1_fn_ff2_bias[16] = {257, 2496, 3641, 834, 8950, -10284, -437, 9118, -10246, -2462, 5236, -3827, 1674, -9161, -7137, -7055, };

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
