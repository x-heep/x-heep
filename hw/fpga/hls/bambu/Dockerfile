# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Self-contained environment for running the Bambu HLS tool
# (https://github.com/ferrandi/PandA-bambu), so that the only host dependency
# of the Bambu flows under hw/fpga/hls/bambu is Docker. bambu.sh builds this
# image the first time it is needed:
#
#   docker build -t xheep-bambu:2024.10 hw/fpga/hls/bambu
#
# What is inside:
#   - Bambu, taken from the project's official AppImage release. The version is
#     pinned and the download is checked against a SHA-256, so a changed or
#     tampered file fails the build instead of being used.
#   - the 32-bit toolchain Bambu needs (it synthesizes for a 32-bit address
#     space and links a 32-bit co-simulation testbench) and Verilator, which
#     Bambu uses to co-simulate the generated RTL. Ubuntu 22.04 ships the
#     Verilator 4.x line that Bambu's generated simulation scripts expect.
FROM ubuntu:22.04

ARG BAMBU_VERSION=2024.10
ARG BAMBU_SHA256=e4f0214496a5d35de1932975b0f41cd95bc33a53a904fc565d6c2cb01df40773

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         build-essential ca-certificates file gcc-multilib g++-multilib \
         libtinfo5 make verilator wget \
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
