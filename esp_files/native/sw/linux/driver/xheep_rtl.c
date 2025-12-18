// Copyright (c) 2011-2024 Columbia University, System Level Design Group
// SPDX-License-Identifier: Apache-2.0
#include <linux/of_device.h>
#include <linux/mm.h>

#include <asm/io.h>

#include <esp_accelerator.h>
#include <esp.h>

#include "xheep_rtl.h"

#define DRV_NAME "xheep_rtl"

/* <<--regs-->> */
#define XHEEP_BOOT_EXIT_LOOP_REG 0x4c
#define XHEEP_BOOT_FETCH_CODE_REG 0x48
#define XHEEP_BOOT_FETCH_CODE_ADDR_REG 0x44
#define XHEEP_CODE_SIZE_WORDS_REG 0x40

struct xheep_rtl_device {
    struct esp_device esp;
};

static struct esp_driver xheep_driver;

static struct of_device_id xheep_device_ids[] = {
    {
        .name = "SLD_XHEEP_RTL",
    },
    {
        .name = "eb_066",
    },
    {
        .compatible = "sld,xheep_rtl",
    },
    {},
};

static int xheep_devs;

static inline struct xheep_rtl_device *to_xheep(struct esp_device *esp)
{
    return container_of(esp, struct xheep_rtl_device, esp);
}

static void xheep_prep_xfer(struct esp_device *esp, void *arg)
{
    struct xheep_rtl_access *a = arg;

    /* <<--regs-config-->> */
	iowrite32be(a->boot_exit_loop, esp->iomem + XHEEP_BOOT_EXIT_LOOP_REG);
	iowrite32be(a->boot_fetch_code, esp->iomem + XHEEP_BOOT_FETCH_CODE_REG);
	iowrite32be(a->boot_fetch_code_addr, esp->iomem + XHEEP_BOOT_FETCH_CODE_ADDR_REG);
	iowrite32be(a->code_size_words, esp->iomem + XHEEP_CODE_SIZE_WORDS_REG);
    iowrite32be(a->src_offset, esp->iomem + SRC_OFFSET_REG);
    iowrite32be(a->dst_offset, esp->iomem + DST_OFFSET_REG);
}

static bool xheep_xfer_input_ok(struct esp_device *esp, void *arg)
{
    /* struct xheep_rtl_device *xheep = to_xheep(esp); */
    /* struct xheep_rtl_access *a = arg; */

    return true;
}

static int xheep_probe(struct platform_device *pdev)
{
    struct xheep_rtl_device *xheep;
    struct esp_device *esp;
    int rc;

    xheep = kzalloc(sizeof(*xheep), GFP_KERNEL);
    if (xheep == NULL) return -ENOMEM;
    esp         = &xheep->esp;
    esp->module = THIS_MODULE;
    esp->number = xheep_devs;
    esp->driver = &xheep_driver;
    rc          = esp_device_register(esp, pdev);
    if (rc) goto err;

    xheep_devs++;
    return 0;
err:
    kfree(xheep);
    return rc;
}

static int __exit xheep_remove(struct platform_device *pdev)
{
    struct esp_device *esp                        = platform_get_drvdata(pdev);
    struct xheep_rtl_device *xheep = to_xheep(esp);

    esp_device_unregister(esp);
    kfree(xheep);
    return 0;
}

static struct esp_driver xheep_driver = {
    .plat =
        {
            .probe  = xheep_probe,
            .remove = xheep_remove,
            .driver =
                {
                    .name           = DRV_NAME,
                    .owner          = THIS_MODULE,
                    .of_match_table = xheep_device_ids,
                },
        },
    .xfer_input_ok = xheep_xfer_input_ok,
    .prep_xfer     = xheep_prep_xfer,
    .ioctl_cm      = XHEEP_RTL_IOC_ACCESS,
    .arg_size      = sizeof(struct xheep_rtl_access),
};

static int __init xheep_init(void)
{
    return esp_driver_register(&xheep_driver);
}

static void __exit xheep_exit(void) { esp_driver_unregister(&xheep_driver); }

module_init(xheep_init) module_exit(xheep_exit)

    MODULE_DEVICE_TABLE(of, xheep_device_ids);

MODULE_AUTHOR("Emilio G. Cota <cota@braap.org>");
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("xheep_rtl driver");
