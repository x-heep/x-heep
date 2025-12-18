// Copyright (c) 2011-2024 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0
#ifndef __ESP_CFG_000_H__
#define __ESP_CFG_000_H__

#include "libesp.h"
#include "xheep_rtl.h"

typedef int32_t token_t;

/* <<--params-def-->> */
#define BOOT_EXIT_LOOP 0
#define BOOT_FETCH_CODE 0
#define BOOT_FETCH_CODE_ADDR 0x80000000
#define CODE_SIZE_WORDS 0

/* <<--params-->> */
const int32_t boot_exit_loop = BOOT_EXIT_LOOP;
const int32_t boot_fetch_code = BOOT_FETCH_CODE;
const int32_t boot_fetch_code_addr = BOOT_FETCH_CODE_ADDR;
const int32_t code_size_words = CODE_SIZE_WORDS;

#define NACC 1

struct xheep_rtl_access xheep_cfg_000[] = {{
    /* <<--descriptor-->> */
		.boot_exit_loop = BOOT_EXIT_LOOP,
		.boot_fetch_code = BOOT_FETCH_CODE,
		.boot_fetch_code_addr = BOOT_FETCH_CODE_ADDR,
		.code_size_words = CODE_SIZE_WORDS,
    .src_offset    = 0,
    .dst_offset    = 0,
    .esp.coherence = ACC_COH_NONE,
    .esp.p2p_store = 0,
    .esp.p2p_nsrcs = 0,
    .esp.p2p_srcs  = {"", "", "", ""},
}};

esp_thread_info_t cfg_000[] = {{
    .run       = true,
    .devname   = "xheep_rtl.0",
    .ioctl_req = XHEEP_RTL_IOC_ACCESS,
    .esp_desc  = &(xheep_cfg_000[0].esp),
}};

#endif /* __ESP_CFG_000_H__ */
