# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Self-contained environment for running the Dynamatic HLS compiler
# (https://github.com/EPFL-LAP/dynamatic), so that the only host dependency of
# the Dynamatic flows under hw/fpga/hls/dynamatic is Docker. dynamatic.sh
# builds this image the first time it is needed:
#
#   docker build -t xheep-dynamatic:2fac291 hw/fpga/hls/dynamatic
#
# Dynamatic publishes no binary releases or images, so it is built from
# source here, the way its own build script does it:
#   - Dynamatic is pinned to a git commit (DYNAMATIC_COMMIT). None of its git
#     submodules is needed for this flow (LLVM is prebuilt, see below; the
#     others are the visualizer and an optional buffer-placement library).
#   - LLVM/MLIR/clang/Polly come from the prebuilt release tarball that
#     Dynamatic's './build.sh --use-prebuilt-llvm' downloads (same URL, the
#     revision that commit expects). It is checked against the SHA-256 that
#     GitHub publishes for the release asset, so a changed or tampered file
#     fails the build instead of being used. Building LLVM from scratch would
#     need 50+ GB of disk and 16 GB of RAM instead of a ~1 GB download.
#
#   - Verilator, for Dynamatic's RTL co-simulation, is built from source at
#     the version X-HEEP uses (5.040, pinned to its tag's commit): Dynamatic's
#     Verilator testbench needs Verilator >= 5.024, and Ubuntu 24.04 ships
#     5.020.
#
# The image has three stages: two build Verilator and Dynamatic, the last one
# only keeps what running Dynamatic needs (its binaries, scripts and RTL
# library, LLVM's clang/opt and headers, and the tools its scripts call:
# graphviz for the DOT exports, a C++ toolchain and Verilator for its RTL
# co-simulation).

# Parallel compile jobs. Dynamatic's MLIR translation units need 1-2 GB of
# RAM each, so this is deliberately not "all cores".
ARG BUILD_JOBS=8

# ---------------------------------------------------------------------------
# Verilator build stage
# ---------------------------------------------------------------------------
FROM ubuntu:24.04 AS verilator

ARG BUILD_JOBS
ARG VERILATOR_VERSION=5.040
ARG VERILATOR_COMMIT=51cdf52d0f3a3e59b51fd87762646a851e9f4aff

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         autoconf bison ca-certificates flex g++ git help2man libfl-dev make \
         perl python3 zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone -q --depth 1 -b "v${VERILATOR_VERSION}" https://github.com/verilator/verilator.git /tmp/verilator \
    && cd /tmp/verilator \
    && test "$(git rev-parse HEAD)" = "${VERILATOR_COMMIT}" \
    && autoconf \
    && ./configure --prefix=/opt/verilator \
    && make -j"${BUILD_JOBS}" \
    && make install \
    && rm -rf /tmp/verilator

# ---------------------------------------------------------------------------
# Dynamatic build stage
# ---------------------------------------------------------------------------
FROM ubuntu:24.04 AS build

ARG BUILD_JOBS
ARG DYNAMATIC_COMMIT=2fac2911faf35b84156e08782a9fcfe8fc6174d8
ARG LLVM_URL=https://github.com/ETHZ-DYNAMO/llvm-project/releases/download/llvm-b06546b/llvm-b06546b-x86_64-linux.tar.gz
ARG LLVM_SHA256=3c2d56f349e07648cbcc45c1b2bd89dc775eff9a90a9c4ba70848e49feedc6df

# Dynamatic's own build dependencies (its Dockerfile), plus a C/C++ toolchain.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y \
         build-essential ca-certificates ccache clang cmake git graphviz \
         libboost-all-dev libreadline-dev lld ninja-build pkg-config python3 \
         python3-venv wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/dynamatic

RUN git init -q . \
    && git remote add origin https://github.com/EPFL-LAP/dynamatic.git \
    && git fetch -q --depth 1 origin "${DYNAMATIC_COMMIT}" \
    && git checkout -q FETCH_HEAD

# build.sh picks the tarball up from this path instead of downloading it.
RUN wget -q -O llvm-project-x86_64.tar.gz "${LLVM_URL}" \
    && echo "${LLVM_SHA256}  llvm-project-x86_64.tar.gz" | sha256sum -c -

RUN ./build.sh --release --use-prebuilt-llvm --threads "${BUILD_JOBS}" \
    && test -x bin/dynamatic

# Only needed to build: objects, static libraries, the tarball, git metadata.
RUN rm -rf llvm-project-x86_64.tar.gz .git /root/.cache \
    && find build -name '*.o' -delete \
    && find build -name '*.a' -delete

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM ubuntu:24.04

# python3: Dynamatic's RTL export runs in the venv its build created (which
#          points at this same /usr/bin/python3).
# graphviz: 'compile' renders the CFG/dataflow graphs with dot.
# build-essential (+ Verilator, from its stage): 'simulate --simulator
#          verilator' compiles the kernel's C testbench (with Dynamatic's
#          clang++, which uses the system's libstdc++/libc headers) and the
#          generated RTL.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         build-essential graphviz libreadline8t64 python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=verilator /opt/verilator /opt/verilator
COPY --from=build /opt/dynamatic /opt/dynamatic

ENV PATH=/opt/verilator/bin:$PATH
ENV DYNAMATIC_DIR=/opt/dynamatic
