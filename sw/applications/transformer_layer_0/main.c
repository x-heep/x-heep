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
static int16_t transformer_layers_0_0_norm_weight[16] = {-3532, 5080, 4885, -7866, 10479, 10346, -7047, 11277, -7575, 4366, 8761, -7641, -9541, 4786, -3695, 5619, };
static int16_t transformer_layers_0_0_norm_bias[16] = {-6330, -6219, -7092, 9640, -1916, -1349, -1231, 3636, -5215, 6074, 9057, -4670, -2390, 1677, 1608, -9483, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H0[64] = {-11075, 10893, 8634, 3746, 8828, 6197, -9621, 1320, -8737, 405, 7366, -9780, 97, -5771, 4618, 11372, 9027, -10899, -689, -7386, 11242, 478, 5848, 1798, -3542, -8388, 9561, -9071, -10458, -7278, -1633, -8855, 10663, 3971, -8250, 3073, 5591, 2036, 4764, 866, -5267, -3360, 7947, -668, -182, -3769, 11775, -6505, 6422, -2593, -1721, -4835, -7126, 1136, -10993, 7016, -3826, 7413, -11719, 1180, -814, -2190, -1315, -4750, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H1[64] = {-756, -7019, -7812, 3590, 1384, 9676, 6364, -7006, -8385, -6686, -7884, -5356, 8857, -6240, 10374, 8202, 11792, 7472, 4444, -5837, 8025, -3579, -8023, 6144, 11712, 8360, -6634, -8710, 5716, -11777, -3598, 11536, -8682, -6539, 1194, 7826, -8882, -1127, -6656, -5610, -5915, -722, 6212, -2596, 9907, -5717, -2919, -2579, 8308, -4379, -4103, -4317, 4255, 4911, 4971, -3522, 4668, 5602, -583, -2857, -2429, -8224, -9208, -7973, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H2[64] = {11095, 10427, 10442, -9462, 5854, -1719, 8045, -8646, -10608, 3762, -5286, 3979, 1511, 6070, 5881, 1272, -10123, -695, -3855, -11356, -2369, -1367, 8848, 11605, 8796, 433, -9506, 2611, 11834, -8845, 6478, -6562, 10552, 7845, 8803, 3731, -10789, 6576, 819, -1018, -8384, 403, -4782, -9884, -756, -2125, 8576, 2956, -908, 9936, 539, -3878, -8940, -11595, 9729, 10974, -3871, -9734, 1681, -10733, -10432, 9495, -724, 10199, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H3[64] = {8171, 10020, 2805, 3219, 6424, -3759, -3898, 4499, 2859, 11249, -11685, 2431, -5028, -292, 9612, -891, 342, -2465, 8684, -11444, 1364, -1406, 7547, -11274, -7202, 9929, -7474, 3647, 4761, 2006, -1941, 9523, 8572, -3037, -6838, 3562, 5202, -8017, -7290, 3706, 7037, -9898, 3892, 10083, -2298, 3473, -10910, -7898, -4509, -6985, -3907, 7206, 11814, 4907, -5188, 7642, -3092, 10103, -1949, 4589, -530, -2819, 2732, 11259, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H0[64] = {9644, 178, -1177, 7819, 1070, -322, 4770, 1096, -8018, -8602, 9420, -822, -8041, 6374, 9189, 8075, 7712, 5906, -2214, -2899, 8710, 822, -2634, 10565, 10735, 9275, -6988, -9779, 4465, 1268, -1917, 6021, -4409, -4083, -9767, 10303, 10200, -8317, 8929, -2194, 8715, -5202, 3829, -2665, 10451, 6729, -5361, -10054, -9518, -6253, -6659, 4027, 73, -186, 81, 4357, -6263, -9348, 9570, -6409, -2938, -4867, 1299, 642, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H1[64] = {3297, 6022, -3114, -1581, 9999, -8981, 4775, 10910, -5733, 1003, 3433, 6697, -1985, 3453, -11855, 8642, -6820, -2396, -4739, -1017, 5181, 2886, 11706, 9418, -6017, 1199, 5503, 11751, 5600, 4008, -7845, 5202, -3328, -2775, 10613, -11320, -1908, 11897, -1343, 1037, 11264, 193, -6337, -10246, -5848, -7601, -8414, -1886, -9638, -8678, -5959, -4591, 6274, -7241, -10974, 6312, 3236, -9300, 3232, 9305, 7713, 8339, 6217, -8003, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H2[64] = {-10358, 2638, -3071, -3937, -8847, -9305, -3074, -66, -2839, -4494, -4428, -11671, 5027, 475, -11656, -3269, -7777, 5145, -7511, 5715, 10970, -5481, -10190, 3625, 7399, -1499, 1993, -7704, -7196, -11778, -4187, -928, 7364, 4363, -8532, -1344, 11334, 2922, -9120, 1010, -5420, 5484, -7378, -1082, -1789, 3059, -6621, -6442, 2292, 1682, 2730, 2061, -9175, 9433, -2865, 11454, 7180, 5701, 4111, 4652, -1544, 10048, 10177, -457, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H3[64] = {-752, -6256, 8769, -149, -5119, 2498, -3370, -11304, -3400, -5089, 11039, 6081, 2093, 618, -3182, -7522, 5288, -6842, -1721, 2323, -1487, -11694, 6992, 6035, -1676, -4767, -9443, 2601, -10288, 276, 8071, -8759, -7694, -11028, -5534, -2520, 4241, -7362, 7507, 2184, 9641, -4405, 11384, -1515, 4921, -6585, 4451, -11156, -6426, 10240, 9107, 4535, -3254, 6073, -10723, -10652, 8050, -5599, -8102, 7489, -5529, -7159, -94, 901, };

static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H0[64] = {366, 4036, -1535, -10738, -8445, 1068, -4480, -7662, 11771, -10558, -9240, -2179, 7365, 1043, -6321, -11862, 3274, -6105, 474, -5035, 3051, -6421, 1614, -11284, -4854, 8773, 8008, 4733, 1883, 11992, -8093, -8249, -4502, 9437, -9503, -5237, 183, -2076, 5257, 1259, -11071, 10453, -5717, -7417, -236, -8646, -4760, -1289, 8787, 10879, -5759, 2312, 3039, -6017, -2294, 4831, 9937, 171, -10765, 2411, -2650, -10150, 10886, 7565, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H1[64] = {7122, 3186, 6029, -11380, 9127, -4505, 3844, 7907, -8984, -10459, 1215, 3807, -10798, -511, 7184, 7888, -3072, -11690, 4622, 3102, 5530, -3042, -8196, -5904, 3011, 11964, 3051, -6327, 7040, -4595, 6612, -6036, -6781, -10260, 11728, -11151, 3887, 9584, 11600, 6421, 9526, -11233, 10655, 5550, -9360, -3604, 5313, -9991, 7046, 317, 6495, -9862, -6575, 4587, -4390, -4781, -5496, -11386, 9794, 7925, -6752, 7883, 6346, 9430, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H2[64] = {7457, 7302, 2320, 298, 3731, -1245, 6966, -1540, 3713, 6226, 35, 3226, -7120, 6494, -11651, 2656, 11167, 5942, -5556, -925, 11970, 4184, -135, -1000, 4083, -9775, -8398, -5316, 2677, 8366, 10584, -10472, 10018, 25, -2201, -6108, 11498, 4359, -2514, -4210, 5271, -8538, -8920, 9626, 6290, 3571, 10791, -4429, -11075, -11595, -7672, 9183, 7903, -4896, 4017, 1983, 6799, 3006, 10430, -3853, 2534, -6262, 10301, -2794, };
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H3[64] = {1156, -11509, 688, 9043, 11786, -6547, 3418, -8156, -8202, 5180, 6142, -1221, -2700, 2322, -3581, -961, 1990, 10725, -5705, -2934, -6160, 5428, 1124, -5497, 10583, -8721, -10816, 7159, -3842, -4060, 5215, -1138, -11893, 1514, -1191, 5695, -2099, 1821, -6359, -2080, -8018, 4779, 3884, 7029, -6040, 3813, -9508, 11011, -9521, 11944, -11849, -10923, 1028, -11153, -7504, 8921, 1502, -11359, 2929, 1799, 9388, -6835, 11374, 6611, };

static int16_t transformer_layers_0_0_fn_projection_weight[256] = {-8108, 7234, -11795, 10637, 11803, 8229, -11774, -5657, -6328, 11537, -11340, 1111, -4610, -2919, 3521, 1216, 1086, -6842, -9163, -4729, -7502, -2431, 3684, -9439, -10916, -5559, 1980, 7386, 6270, -6495, 3535, -4116, 7521, -4173, 8109, -4241, 5407, -3382, 281, 3557, -10389, 843, 4948, 2940, -1541, -1086, 10036, -8441, -774, 9278, -10608, -9525, -9324, -3871, -1049, -6310, 40, 4606, 840, -1574, -10123, -10401, 6236, 7732, -3519, -11379, 1753, -11838, -1364, -5859, 3994, -7613, -3264, 864, -5061, 152, 888, -6370, -5624, -4068, 9794, -11796, 3730, -6309, 7631, -5826, -4457, -8285, 480, 4638, -5713, 9762, -1468, 8774, 5422, -1135, -8333, 10949, 3497, 3233, 11831, -11108, -6779, -6334, 11902, -1986, 11089, 10449, 5474, 8093, 3111, -5442, 10736, 3252, 6333, 5012, 1793, 3892, 8009, -1594, -6906, -413, -10614, -9147, 9614, 10587, -7282, 7735, 2173, 8967, -10270, -5794, -11773, 9872, 1506, -38, 2092, 8654, 7301, 7455, -4189, -6307, -9533, -8905, 6493, 10219, -8384, 10221, 2967, -8733, 10529, 10612, 3067, 439, 5386, -1570, -8329, 5975, -5764, -10386, 7784, 4120, -893, -7274, -10704, -5644, -6462, -3345, 5333, -10685, -10925, -1349, -10064, 9309, -10980, -4513, -7198, -2351, 10004, -2874, 7547, -10523, 2769, -3130, 5949, -4732, 334, 3577, -11552, 10050, 8185, 11844, -5253, -2949, -530, -2543, 11361, -1143, 9718, -10080, 8135, -2540, -6821, -11100, 443, -1864, -7059, 6534, -10440, -7146, 5128, -11539, -8670, -5864, 8555, -6910, -205, -3556, -10312, 7502, -4058, -2906, 9038, -5295, -11600, 3088, -6562, -8, -11919, -7985, -4691, 3975, 3204, 1784, -5728, 1512, -11298, -4792, 11237, -11613, 10822, -10736, -2236, 9462, -7145, 6839, 8873, -10030, -6751, 10110, 2987, -8194, -2292, 787, 525, 4312, };
static int16_t transformer_layers_0_0_fn_projection_bias[16] = {-7722, 3281, -181, -8824, -80, -5736, 9949, -5714, -4495, -1998, -3953, 9059, -600, -4520, -6222, 6621, };

static int16_t transformer_layers_0_1_norm_weight[16] = {-6027, -8695, -9987, -3497, 2143, 2816, -7610, 254, 3489, -10627, 455, 11482, -7147, -11360, 10281, 7952, };
static int16_t transformer_layers_0_1_norm_bias[16] = {6093, -3109, 4920, -8466, -6470, -3731, 6191, -7126, 8188, -3494, 2387, 10423, 9677, -368, 11936, -1846, };

static int16_t transformer_layers_0_1_fn_ff1_weight[64] = {-8863, 3378, 7950, 10009, -9227, 3727, -8752, 1379, -2086, 1637, 7999, 7266, -11280, 3648, 9870, 5282, 7664, 9371, -10612, -2307, 2424, -8436, 6740, -2834, 10963, -2769, -4646, -7589, 6117, 1557, -10623, -7984, -7331, -8329, 915, 7821, -4456, -6836, 7706, 9171, -3575, 7436, 4167, 3192, 6069, -467, 3269, 2881, -1907, -6448, -11481, 3372, 5666, 7407, 4448, -11959, -998, -5407, 6305, 93, -10782, 5524, 7715, -8731, };
static int16_t transformer_layers_0_1_fn_ff1_bias[4] = {-11169, -7771, 3607, 5712, };
static int16_t transformer_layers_0_1_fn_ff2_weight[64] = {9401, 4710, -10286, -98, 10094, -8876, 991, 3726, -2708, 7503, 3161, 2909, 11001, 3468, 2389, -3595, 300, 3233, -5941, 6069, 11268, 2096, -10329, -10435, -3325, 7058, -10982, -5807, 2802, 3245, -6798, -10150, 9380, -4433, 11622, -8287, 1447, -11512, 6624, 7808, -4815, -10834, 11274, 3389, -3597, -8981, -4274, -4812, 5452, -11237, -7914, 11759, -7271, -9955, 1044, 319, 1245, 9701, 1511, 9264, -5893, -10840, -4089, 3040, };
static int16_t transformer_layers_0_1_fn_ff2_bias[16] = {4909, -4324, -5679, 2464, 10681, 3223, -5889, 1075, 9845, -3304, -10047, 11535, 9936, 1667, -7266, -5160, };

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
    return (uint8_t)(XHEEP_LAYER_USE_P2P_IN ? XHEEP_LAYER_P2P_USER_IN : XHEEP_LAYER_MEM_USER_IN);
}

static inline uint8_t xheep_layer_write_user(void)
{
    return (uint8_t)(XHEEP_LAYER_USE_P2P_OUT ? XHEEP_LAYER_P2P_USER_OUT : XHEEP_LAYER_MEM_USER_OUT);
}

#define XHEEP_PRE_SPLIT0_ROWS         61u
#define XHEEP_PRE_SPLIT0_ELEMS        (XHEEP_PRE_SPLIT0_ROWS * XHEEP_LAYER_D_MODEL)
#define XHEEP_PRE_SPLIT0_BYTES        (XHEEP_PRE_SPLIT0_ELEMS * XHEEP_LAYER_ELEM_BYTES)
#define XHEEP_PRE_SPLIT1_OFFSET_ELEMS XHEEP_PRE_SPLIT0_ELEMS
#define XHEEP_PRE_SPLIT1_OFFSET_BYTES XHEEP_PRE_SPLIT0_BYTES
#define XHEEP_PRE_SPLIT1_BYTES        ((XHEEP_LAYER_ELEMS * XHEEP_LAYER_ELEM_BYTES) - XHEEP_PRE_SPLIT0_BYTES)

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
    esp_dma_config_t cfg = {0};
#if XHEEP_LAYER_USE_P2P_IN
    /* Keep the same shared I/O window base for both pulls. */
    cfg.addr = (uint32_t)(XHEEP_LAYER_IN_ADDR + (uintptr_t)XHEEP_SHARED_IO_OFFSET);
    cfg.len_bytes = XHEEP_PRE_SPLIT0_BYTES;
    cfg.xheep_addr = (uint32_t)(uintptr_t)layer_in;
    cfg.dir_write = 0u;
    /*
     * Deterministic join: use explicit source indices.
     * rd_source != 0 selects YX_REG entry by index in DMA RTL.
     */
    cfg.read_user = XHEEP_PRELAYER_P2P_SRC_SLOT0;
    cfg.write_user = XHEEP_ESP_DMA_USER_MEM;
    xheep_esp_dma_configure(&cfg);
    xheep_debug_stage((uint16_t)XHEEP_DBG_DMA_IN_WAIT, (uint16_t)XHEEP_PRELAYER_P2P_SRC_SLOT0);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();

    cfg.addr = (uint32_t)(XHEEP_LAYER_IN_ADDR +
                          (uintptr_t)(XHEEP_SHARED_IO_OFFSET + XHEEP_PRE_SPLIT1_OFFSET_BYTES));
    cfg.len_bytes = XHEEP_PRE_SPLIT1_BYTES;
    cfg.xheep_addr = (uint32_t)(uintptr_t)(layer_in + XHEEP_PRE_SPLIT1_OFFSET_ELEMS);
    cfg.dir_write = 0u;
    cfg.read_user = XHEEP_PRELAYER_P2P_SRC_SLOT1;
    cfg.write_user = XHEEP_ESP_DMA_USER_MEM;
    xheep_esp_dma_configure(&cfg);
    xheep_debug_stage((uint16_t)XHEEP_DBG_DMA_IN_WAIT, (uint16_t)XHEEP_PRELAYER_P2P_SRC_SLOT1);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();
#else
    cfg.addr = (uint32_t)XHEEP_LAYER_IN_ADDR;
    cfg.len_bytes = layer_bytes;
    cfg.xheep_addr = (uint32_t)(uintptr_t)layer_in;
    cfg.dir_write = 0u;
    cfg.read_user = xheep_layer_read_user();
    cfg.write_user = XHEEP_ESP_DMA_USER_MEM;
    xheep_esp_dma_configure(&cfg);
    xheep_debug_stage((uint16_t)XHEEP_DBG_DMA_IN_WAIT, 0u);
    xheep_esp_dma_start(XHEEP_ESP_DMA_CTRL_READ_USER(cfg.read_user) |
                        XHEEP_ESP_DMA_CTRL_WRITE_USER(cfg.write_user));
    xheep_esp_dma_wait_done();
#endif

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
