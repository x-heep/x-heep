// Copyright (c) 2011-2024 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0
#ifndef _XHEEP_RTL_H_
#define _XHEEP_RTL_H_

#ifdef __KERNEL__
    #include <linux/ioctl.h>
    #include <linux/types.h>
#else
    #include <sys/ioctl.h>
    #include <stdint.h>
    #ifndef __user
        #define __user
    #endif
#endif /* __KERNEL__ */

#include <esp.h>
#include <esp_accelerator.h>

struct xheep_rtl_access {
    struct esp_access esp;
    /* <<--regs-->> */
	unsigned boot_exit_loop;
	unsigned boot_fetch_code;
	unsigned boot_fetch_code_addr;
	unsigned code_size_words;
    unsigned src_offset;
    unsigned dst_offset;
};

#define XHEEP_RTL_IOC_ACCESS _IOW('S', 0, struct xheep_rtl_access)

#endif /* _XHEEP_RTL_H_ */
