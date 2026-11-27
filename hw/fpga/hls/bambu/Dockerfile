# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Self-contained environment for running the Bambu HLS tool
# (https://github.com/ferrandi/PandA-bambu), so that the only host dependency
# of the Bambu flows under hw/fpga/hls/bambu is Docker. bambu.sh builds this
# image the first time it is needed:
#
#   docker build -t xheep-bambu:2026.11 hw/fpga/hls/bambu
#
# What is inside:
#   - Bambu, taken from the project's official AppImage release. The version is
#     pinned and the download is checked against a SHA-256, so a changed or
#     tampered file fails the build instead of being used.
#   - the 32-bit toolchain Bambu needs (it synthesizes for a 32-bit address
#     space and links a 32-bit co-simulation testbench) and Verilator, which
#     Bambu uses to co-simulate the generated RTL. Ubuntu 26.04 ships the
#     Verilator 5.x line that Bambu's generated simulation scripts expect.
FROM ubuntu:26.04

ARG BAMBU_VERSION=2026.11
ARG BAMBU_SHA256=6e8cd7049c09ef48ec7ea2ece88e91f2c70bf67547c77a71b6ff44c4e008fa06

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         build-essential ca-certificates file gcc-multilib g++-multilib \
         libtinfo6 make verilator wget gettext \
    && rm -rf /var/lib/apt/lists/*

# The AppImage is extracted instead of executed through FUSE, which is not
# available inside containers.
RUN wget -q -O /tmp/bambu.AppImage \
         "https://release.bambuhls.eu/appimage/bambu-${BAMBU_VERSION}.AppImage" \
    && echo "${BAMBU_SHA256}  /tmp/bambu.AppImage" | sha256sum -c - \
    && chmod +x /tmp/bambu.AppImage \
    && cd /tmp && ./bambu.AppImage --appimage-extract > /dev/null \
    && mv /tmp/squashfs-root /opt/bambu \
    && rm /tmp/bambu.AppImage

# The AppImage's entry script dispatches on these variables, which the
# AppImage runtime would normally set.
RUN printf '#!/bin/sh\nexport ARGV0=bambu APPDIR=/opt/bambu OWD="$PWD"\nexec /opt/bambu/AppRun "$@"\n' \
      > /usr/local/bin/bambu \
    && chmod 755 /usr/local/bin/bambu
