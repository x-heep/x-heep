# Copyright 2023 Juan Sapriza

# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

# Author(s): Juan Sapriza (juan.sapriza@epfl.ch)
#            Michele Caon (michele.caon@epfl.ch)

# Example Makefile that uses this external.mk file to access X-HEEP targets and build software from directories outside X-HEEP can be found in eXtendingHEEP.md
# It is crucial that the 'include' directive is located after all your rules as it will catch any target that was not defined in your Makefile.


MAKE	= make

# Some internal tools (e.g., FuseSoC) may require the location of the top-level call to make, where this file is included. The following variable exposes this to
# X-HEEP's internal targets.
HEEP_EXTERNAL_ROOT	:= $(abspath .)

# Furthermore, a variable HEEP_DIR with the relative path between that directory and the X-HEEP base directory (where this file is lcoated) needs to be exported.
# This will compute the opposite relative path (from the X-HEEP base directory to where this file is included).
HEEP_REL_PATH = $(shell realpath --relative-to=$(HEEP_DIR) ".")

# This assumes that you are including this file from a directory where you have a "sw" directory.
# When this path is provided to sw/Makefile, it will be the relative path from there to the uppermost sw directory.
SW_TO_SW_REL_PATH = ../$(HEEP_REL_PATH)/sw/

# If a custom path wants to be provided (i.e. software sources will not be inside a sw directory), it should be specified by setting this variable when calling make.
SOURCE ?= $(SW_TO_SW_REL_PATH)

# Any target that was not present on the uppermost Makefile (the one in which this file is included) will be passed to the X-HEEP Makefile.
%:
	@echo "[X-HEEP] > Parent project is $(HEEP_EXTERNAL_ROOT)"
	@echo "[X-HEEP] > Your relative software sources path is $(SOURCE)"
	$(MAKE) -C $(HEEP_DIR) $(MAKECMDGOALS) SOURCE=$(SOURCE) HEEP_EXTERNAL_ROOT=$(HEEP_EXTERNAL_ROOT)
