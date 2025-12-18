# Copyright (c) 2011-2024 Columbia University, System Level Design Group
# SPDX-License-Identifier: Apache-2.0
EXTRA_CFLAGS ?= -I$(DRIVERS)/../common/apps/baremetal/xheep -I.

BUILD_DRIVERS ?= $(BUILD_PATH)/../../..

SUBDIRS := $(wildcard */.)
SUBDIR_SRCS := $(wildcard */*.c)

.PHONY: all clean subdirs build-subdir-app

all: subdirs
	@if [ -n "$(wildcard *.c)" ]; then \
		$(MAKE) default-apps; \
	fi

# Build top-level apps
default-apps:
	@$(MAKE) -f $(DRIVERS)/common.mk

# Build apps in subdirectories
subdirs:
	@for src in $(SUBDIR_SRCS); do \
		dirname=$$(dirname $$src); \
		target=$(BUILD_PATH)/$${dirname}.exe; \
		$(MAKE) --no-print-directory build-subdir-app SRC=$$src TARGET=$$target || true; \
	done

build-subdir-app:
	@echo "   MAKE $(notdir $(TARGET)) from $(dir $(SRC))"
	@mkdir -p $(BUILD_PATH)
	@CROSS_COMPILE=$(CROSS_COMPILE) DRIVERS=$(DRIVERS) $(MAKE) -C $(BUILD_DRIVERS)/contig_alloc/ libcontig.a > /dev/null 2>&1 || true
	@CROSS_COMPILE=$(CROSS_COMPILE) BUILD_PATH=$(BUILD_DRIVERS)/test $(MAKE) -C $(DRIVERS)/test > /dev/null 2>&1 || true
	@CROSS_COMPILE=$(CROSS_COMPILE) BUILD_PATH=$(BUILD_DRIVERS)/libesp $(MAKE) -C $(DRIVERS)/libesp > /dev/null 2>&1 || true
	@CROSS_COMPILE=$(CROSS_COMPILE) BUILD_PATH=$(BUILD_DRIVERS)/monitors DESIGN_PATH=$(DESIGN_PATH) MODE=LINUX \
		$(MAKE) -B -C $(DRIVERS)/../common/monitors > /dev/null 2>&1 || true
	@CROSS_COMPILE=$(CROSS_COMPILE) BUILD_PATH=$(BUILD_DRIVERS)/utils/linux $(MAKE) -C $(DRIVERS)/utils > /dev/null 2>&1 || true
	-$(CROSS_COMPILE)gcc $(EXTRA_CFLAGS) -O3 -Wall -DLINUX \
		-I$(DRIVERS)/include -I$(DRIVERS)/../common/include -I../include -I$(DESIGN_PATH)/socgen/esp \
		-L$(BUILD_DRIVERS)/contig_alloc -L$(BUILD_DRIVERS)/test \
		-L$(BUILD_DRIVERS)/libesp -L$(BUILD_DRIVERS)/utils/linux -L$(BUILD_DRIVERS)/monitors \
		-o $(TARGET) $(SRC) -lm -lrt -lpthread -lesp -ltest -lcontig -lutils -lmonitors 2>&1 || \
		echo "   WARNING $(notdir $(TARGET)) compilation failed!"

clean:
	rm -rf $(BUILD_PATH)
