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
static int16_t transformer_layers_0_0_norm_weight[16] = {4052, 4657, 4613, 4245, 4042, 4415, 4086, 4275, 4240, 4498, 4285, 4081, 4387, 4184, 4302, 4580};
static int16_t transformer_layers_0_0_norm_bias[16] = {80, -54, 40, 214, -203, -129, -101, 57, -177, 57, -56, -281, -36, 219, -182, 92};

static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H0[64] = {-568, -962, 189, -868, -562, 692, 858, 407, -818, -814, 262, -471, 1273, 623, -384, 338, -321, -114, -723, 913, -697, 294, -35, -123, -264, -331, 509, 129, 184, 595, 16, -677, -348, 313, -401, 679, -798, 378, -145, 190, 618, -246, 776, 801, 974, 570, 842, -29, -685, 721, 640, 87, -612, -939, 890, -225, 522, 70, -514, 927, 990, 825, 114, -893};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H1[64] = {640, 166, -336, 542, 491, -1105, -458, -497, 20, -292, 989, -578, -438, 699, -855, 724, 901, 119, -824, 607, 1135, 1478, -883, -673, -923, -897, 445, 395, -782, 260, 591, 327, 970, -1386, 631, 281, -121, -721, 109, 203, 74, 106, 593, 1065, 857, -728, 761, -620, -558, 765, -514, 587, -489, -144, 839, -142, -270, 415, -757, 288, 305, 1302, -249, 247};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H2[64] = {-1419, 962, -640, 252, -124, -585, -573, 363, 218, 537, 461, 201, -502, 636, 804, -1101, 434, 91, -595, -67, -209, -257, 132, 782, -55, -268, -36, -205, -1225, 1346, 648, -933, 360, 693, -726, -675, 1319, 324, -601, -707, 234, 687, 630, 769, 323, -334, -855, 135, -410, 330, -330, 739, -812, -33, -356, -471, 689, -841, 242, -763, -1304, 937, 743, -440};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_Q_H3[64] = {-1060, 1048, 444, 53, 299, -1202, -112, -899, 1136, 226, 103, -466, 653, 104, 151, -131, -910, 333, 104, -1167, -337, -744, -291, 445, -339, -916, 64, -170, -569, 334, -1016, 803, -782, -18, 583, -961, 304, -358, 725, 244, -567, -128, -370, 950, 536, -757, 290, -506, -365, -1083, 685, -1292, 555, -640, -304, 840, 919, -707, 665, -777, 781, 909, 869, 882};

static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H0[64] = {339, 84, 743, 513, 937, -490, 499, -304, 1092, 299, 522, -95, -850, -672, -565, 107, -47, -401, 196, 1062, -158, -507, 736, -381, -249, 768, -185, -849, -107, 483, 520, -997, -234, -945, 1008, -44, 674, -34, -388, -817, 289, 988, -652, -446, -603, 226, 427, 582, -422, 37, 474, -103, 561, 198, 113, 520, 150, 37, -857, 1162, -361, -122, -909, 596};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H1[64] = {587, -190, 215, -264, -1101, -633, 784, 643, 562, 794, -31, 134, -75, 572, -551, 233, -162, -1081, 780, -472, -588, 170, 1040, -1217, 805, 505, -961, -23, 457, 730, -77, 117, 771, -422, -811, -611, 622, 678, 554, -690, 435, 403, -904, 91, -350, -398, -563, -750, 352, -406, -22, 667, 468, -1362, 395, -764, 132, -553, -612, 61, -284, -933, -340, -561};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H2[64] = {399, -840, -111, -768, -787, 925, 1041, 579, -842, 1107, -195, -454, -1018, -673, 330, -1015, 554, 339, 389, 461, 579, -387, -826, 465, -1171, 274, -94, 518, 899, -878, -986, 258, -406, 199, -487, -577, -1264, 1126, -283, -1205, -1311, -101, 970, 79, 183, -108, -499, 980, 122, 110, -163, -25, 767, -718, -836, -838, 839, 120, -734, 789, -324, 119, -159, -411};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_K_H3[64] = {585, 567, -262, -561, -166, 469, 155, -56, -512, 839, -519, 859, -225, 693, -983, -707, 395, -196, -574, 63, 3, -162, -1000, -962, 248, 335, 1235, -284, 994, 727, -475, -891, -428, -817, -598, -1159, 526, 715, -232, -742, -191, -21, 65, 1479, 84, 389, 658, 385, 674, 729, 169, 221, 7, -27, 811, 841, -1080, 645, 14, -1033, -1146, -472, -74, 265};

static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H0[64] = {356, -364, 862, -1113, -938, 408, 1437, 968, 987, 664, -411, -881, 756, 768, -795, 77, 326, 481, -714, 196, -110, -215, 106, 621, -812, 542, 213, 1043, -188, -725, -266, -114, 785, -690, 427, 627, 1001, 796, -752, -410, -760, -304, 129, 1112, 62, 805, -1030, 382, -1195, -1002, 855, 1261, 1026, -281, 57, -850, 763, 77, 738, -135, 1189, 65, -1168, 617};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H1[64] = {536, 374, 293, 992, -103, -576, -463, -1069, -605, 1261, 597, -599, 643, -622, 268, 603, 712, 373, -455, 8, 760, -1245, -460, 201, 1035, 731, 955, 626, -131, -759, 43, -722, -817, -398, 168, 999, 474, 150, 639, -148, -359, -493, -551, 339, -737, 825, -827, -86, -681, 474, 757, -1097, -858, -351, 372, -792, -44, -609, -879, 540, 286, 701, 875, 406};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H2[64] = {764, 345, -422, -624, 1231, 99, -640, -1501, -301, -900, 283, 1233, -1172, 202, 1417, -498, 544, 858, 106, 761, 381, -695, -1310, 63, 651, -635, 946, 848, 999, 198, 84, -923, 1050, 851, -766, -870, -854, -29, 999, 47, -538, -926, -208, 448, 898, 61, -418, 1075, 429, -731, -414, -264, -538, 892, 876, 667, 311, -928, -294, 449, -854, 53, 670, -212};
static int16_t transformer_layers_0_0_fn_to_qkv_weight_V_H3[64] = {-944, 62, 621, 124, -535, -149, 709, 95, 1129, 832, -644, 656, 547, 233, -187, 737, -793, 821, 16, -558, 129, -235, -896, 491, 753, 42, 343, 894, -531, -820, 518, -426, -787, 3, -398, -1120, 1170, 1063, -813, -105, -78, -135, 248, -263, -351, -172, 224, -430, -1072, -956, 331, -6, -221, -602, -34, 0, 913, -859, -110, -512, 1154, 657, -630, 8};

static int16_t transformer_layers_0_0_fn_projection_weight[256] = {-402, -1077, -244, -103, 318, -176, 766, -1187, -866, 337, 1127, 451, -280, -1007, -185, -704, 654, 854, 369, -532, 565, -666, 1063, 433, 312, 232, 211, 846, 273, 115, -969, 847, -514, 236, -588, 549, -298, 759, -253, 1035, 6, -854, -445, -1030, -204, -85, -398, -307, 785, 142, -1233, -991, 496, 512, -675, -12, 172, 11, -1111, -633, 573, 502, -201, 322, -391, 248, -499, -56, -559, -305, -527, 629, 315, 130, -98, -248, 172, 148, 36, -337, 494, 353, 696, 517, 187, -1141, 985, -1041, -1095, 86, -29, 626, -1129, 678, -357, 67, 557, 291, -223, 493, -797, -561, 1218, -793, -542, 266, 275, 229, -637, -993, 965, 673, -884, 707, -19, -635, -663, -730, 87, 528, -179, 1047, -677, 1117, -854, -716, -700, 234, -970, 807, -180, -116, 1006, -13, -1029, -40, 182, 390, -1164, -858, 584, -453, 202, -765, 821, 362, -337, -572, 40, 20, -963, 525, -390, -743, 990, -432, 156, -54, 629, 666, -252, 461, 486, -5, 762, -728, 3, -742, -741, 1112, 1431, 1199, -676, -393, 403, -522, -474, -760, 508, -904, -265, 203, 78, -1096, -852, 587, 113, -680, 171, -308, -231, -484, -210, -463, 635, -561, -1093, 140, 509, -767, -329, 120, 518, 396, 280, -194, -414, 772, -697, -104, 218, 260, -105, 210, 1339, -369, -991, 856, 977, -735, 664, 306, 405, -156, -290, -772, -732, 594, -101, 930, -1060, 1133, 977, -515, -736, -390, 1010, 118, -351, -652, 74, -553, 216, -609, 289, -209, 1004, 930, 462, 171, 755, -914, -686, -185, -616, -648};
static int16_t transformer_layers_0_0_fn_projection_bias[16] = {-840, -92, -107, 118, 323, -361, 278, -5, 135, 300, -784, 540, -15, 380, 771, 648};

static int16_t transformer_layers_0_1_norm_weight[16] = {3913, 4457, 4086, 4198, 3935, 4065, 4044, 3934, 3956, 3983, 4205, 3852, 4319, 4076, 4119, 3967};
static int16_t transformer_layers_0_1_norm_bias[16] = {-176, -178, -255, 86, 151, -163, -161, -8, 155, -133, -118, 180, -206, 30, -113, -222};

static int16_t transformer_layers_0_1_fn_ff1_weight[64] = {-269, 879, 417, 125, -1042, 562, 825, 151, -22, 941, 340, 837, -99, -941, -81, -34, 779, -802, -170, 98, -331, -642, 898, 694, -266, 574, -677, 748, -770, -37, 501, -738, 539, -756, 846, -539, 380, 724, -628, 795, 1144, 372, 525, 499, -257, -2, -298, -356, -821, -8, 829, 852, 205, 290, -229, 201, -910, -991, -340, 841, -610, 961, 227, 151};
static int16_t transformer_layers_0_1_fn_ff1_bias[4] = {-143, -827, -308, 129};
static int16_t transformer_layers_0_1_fn_ff2_weight[64] = {305, -252, 1555, 1351, -1680, 1389, 1229, -741, -1475, 285, -203, -1095, -1407, -1403, -1965, 1256, -273, -533, -1, -1734, -417, 176, -253, 1055, -326, -525, -1, 343, -413, 309, -1034, -1608, -1219, -547, -472, -663, -1628, -1026, -56, -1330, 673, 451, -900, -1720, 2030, 607, 1103, -1915, 1853, 911, -939, 398, 21, 15, 1670, -409, 378, -1568, 1405, 1371, 933, -759, 545, -2014};
static int16_t transformer_layers_0_1_fn_ff2_bias[16] = {837, -1010, 736, 2060, 1857, -1132, 728, -1052, 947, 1603, 1612, 1908, 1519, 508, -1745, -1202};

static void compute_layer0(int16_t *input,
                           int16_t *output,
                           int16_t *input_normalized,
                           int16_t *intermediate,
                           int16_t *qkv)
{
    // xheep_debug_stage((uint16_t)XHEEP_DBG_COMPUTE_ENTER, 0u);
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

static inline void xheep_prepare_nextrun()
{
    volatile uint32_t *exit_value = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALUE_REG_OFFSET);
    volatile uint32_t *exit_valid = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_EXIT_VALID_REG_OFFSET);
    volatile uint32_t *exit_loop = (volatile uint32_t *)(uintptr_t)(SOC_CTRL_START_ADDRESS + SOC_CTRL_BOOT_EXIT_LOOP_REG_OFFSET);

    *exit_value = 0;
    *exit_valid = 0u;
    *exit_loop = 0u;
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
    static volatile uint32_t done_flag = 0x1u;

    // Run this app fully polling-only: disable all machine interrupts.
    CSR_WRITE(CSR_REG_MIE, 0u);
    CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8u);
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
    xheep_signal_exit(0);   

    int poll =0;
    while (poll < 1000000) {
        poll++;
    }

    xheep_prepare_nextrun();

    while (1);
    
    
    return 0;
}
