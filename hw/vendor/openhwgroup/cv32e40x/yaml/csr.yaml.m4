# Copyright 2022 Silicon Labs, Inc.
# Copyright 2020 OpenHW Group
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
#
################################################################################
#
# CSR definitions for the CV32E40X/S CORE-V processors.
#
# This file can be used as input to "gen_csr_test.py" delivered as part of
# Google's riscv-dv project.  Assuming you are running this from
# core-v-verif/vendor_lib/google/corev-dv and you've cloned riscv-dv, then the
# following command-line should work for you:
#
#    python3 ../riscv-dv/scripts/gen_csr_test.py  \
#            --csr_file  csr.yaml  \
#            --xlen 32
#
# Source document is the core's User Manual:
# https://docs.openhwgroup.org/projects/cv32e40x-user-manual/en/latest/control_status_registers.html
# https://docs.openhwgroup.org/projects/cv32e40s-user-manual/en/latest/control_status_registers.html
#
# Assumptions:
#       1. Configuration core input mtvec_addr_i == 32'h0000_0000
#       2. Configuration core input mhartid_i == 32'h0000_0000
#       3. Configuration core input mimpid_patch_i == 4'h0
#       4. Core RTL parameters set as per User Manual defaults.
#
################################################################################
#- csr: CSR_NAME
#  description: >
#    BRIEF_DESCRIPTION
#  address: 0x###
#  privilege_mode: MODE (D/M/S/H/U)
#  rv32:
#    - MSB_FIELD_NAME:
#      - description: >
#          BRIEF_DESCRIPTION
#      - type: TYPE (WPRI/WLRL/WARL/R)
#      - reset_val: RESET_VAL
#      - msb: MSB_POS
#      - lsb: LSB_POS
#    - ...
#    - ...
#    - LSB_FIELD_NAME:
#      - description: ...
#      - type: ...
#      - ...


changequote(`[[[', `]]]')


# Machine CSRs

# mcycle(h) and minstret(h) are done here because out of reset mcountinhibit
# will disable cycle and instruction retirement counts.  These access tests
# will not work if this counting is enabled.
- csr: mcycle
  description: >
    Lower 32 Machine Cycle Counter
  address: 0xB00
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine cycle counter
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
- csr: mcycleh
  description: >
    Upper 32 Machine Cycle Counter
  address: 0xB80
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine cycle counter
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
- csr: minstret
  description: >
    Lower 32 Machine Instructions-Retired Counter
  address: 0xB02
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine instructions retired counter
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
- csr: minstreth
  description: >
    Upper 32 Machine Instructions-Retired Counter
  address: 0xB82
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine instructions retired counter
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: cycle
  description: >
    Unprivileged alias of lower 32 Machine Cycle Counter
  address: 0xC00
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine cycle counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: cycleh
  description: >
    Unprivileged alias of upper 32 Machine Cycle Counter
  address: 0xC80
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine cycle counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: instret
  description: >
    Unprivileged alias of lower 32 Machine Instructions-Retired Counter
  address: 0xC02
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine instructions retired counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: instreth
  description: >
    Unprivileged alias of upper 32 Machine Instructions-Retired Counter
  address: 0xC82
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine instructions retired counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: time
  description: >
    Unprivileged alias of lower 32 bits of Time Counter
  address: 0xC01
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit time counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: timeh
  description: >
    Unprivileged alias of upper 32 bits of Time Counter
  address: 0xC81
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit time counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

- csr: mhpmcounter3
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB03
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 1), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter3h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB83
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 1), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter4
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB04
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 2), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter4h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB84
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 2), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter5
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB05
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 3), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter5h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB85
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 3), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter6
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB06
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 4), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter6h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB86
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 4), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter7
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB07
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 5), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter7h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB87
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 5), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter8
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB08
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 6), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter8h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB88
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 6), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter9
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB09
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 7), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter9h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB89
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 7), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter10
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB0A
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 8), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter10h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB8A
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 8), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter11
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB0B
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 9), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter11h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB8B
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 9), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter12
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB0C
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 10), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter12h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB8C
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 10), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter13
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB0D
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 11), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter13h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB8D
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 11), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter14
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB0E
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 12), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter14h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB8E
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 12), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter15
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB0F
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 13), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter15h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB8F
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 13), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter16
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB10
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 14), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter16h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB90
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 14), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter17
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB11
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 15), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter17h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB91
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 15), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter18
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB12
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 16), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter18h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB92
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 16), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter19
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB13
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 17), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter19h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB93
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 17), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter20
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB14
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 18), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter20h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB94
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 18), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter21
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB15
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 19), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter21h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB95
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 19), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter22
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB16
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 20), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter22h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB96
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 20), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter23
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB17
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 21), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter23h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB97
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 21), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter24
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB18
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 22), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter24h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB98
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 22), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter25
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB19
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 23), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter25h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB99
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 23), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter26
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB1A
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 24), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter26h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB9A
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 24), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter27
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB1B
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 25), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter27h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB9B
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 25), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter28
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB1C
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 26), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter28h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB9C
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 26), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter29
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB1D
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 27), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter29h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB9D
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 27), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter30
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB1E
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 28), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter30h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB9E
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 28), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmcounter31
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xB1F
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 29), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])
- csr: mhpmcounter31h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xB9F
  privilege_mode: M
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      reset_val: 0
      msb: 31
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 29), 1, [[[
      type: RW
]]], [[[dnl
      type: WARL
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter3
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC03
  privilege_mode: U
  # TODO:silabs-robin  Wrong privmode
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter3h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC83
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter4
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC04
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter4h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC84
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter5
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC05
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter5h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC85
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter6
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC06
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter6h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC86
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter7
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC07
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter7h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC87
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter8
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC08
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter8h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC88
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter9
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC09
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter9h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC89
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter10
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC0A
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter10h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC8A
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter11
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC0B
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter11h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC8B
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter12
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC0C
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter12h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC8C
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter13
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC0D
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter13h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC8D
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter14
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC0E
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter14h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC8E
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter15
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC0F
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter15h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC8F
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter16
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC10
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter16h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC90
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter17
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC11
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter17h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC91
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter18
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC12
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter18h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC92
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter19
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC13
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter19h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC93
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter20
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC14
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter20h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC94
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter21
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC15
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter21h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC95
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter22
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC16
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter22h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC96
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter23
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC17
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter23h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC97
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter24
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC18
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter24h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC98
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter25
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC19
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter25h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC99
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter26
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC1A
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter26h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC9A
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter27
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC1B
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter27h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC9B
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter28
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC1C
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter28h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC9C
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter29
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC1D
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter29h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC9D
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter30
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC1E
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter30h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC9E
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(ZICNTR != 0), 1, [[[
- csr: hpmcounter31
  description: >
    Lower 32-bit Machine Performance Monitoring Counter
  address: 0xC1F
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Lower 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: hpmcounter31h
  description: >
    Upper 32-bit Machine Performance Monitoring Counter
  address: 0xC9F
  privilege_mode: U
  rv32:
    - field_name: Count
      description: >
        Upper 32-bits of 64-bit machine performance-monitoring counter
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(DEBUG != 0), 1, [[[
- csr: dcsr
  description: >
    Debug Control and Status
  address: 0x7B0
  privilege_mode: D
  rv32:
    - field_name: XDEBUGVER
      description: >
        External debug support exists
      type: R
      reset_val: 4
      msb: 31
      lsb: 28
    - field_name: RESERVED_27_18
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 27
      lsb: 18
      warl_legalize: |
        val_out = 0
    - field_name: EBREAKVS
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 17
      lsb: 17
      warl_legalize: |
        val_out = 0
    - field_name: EBREAKVU
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 16
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: EBREAKM
      description: >
        Set to enter debug mode on ebreak instruction during machine mode
      type: RW
      reset_val: 0
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_14
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 14
      warl_legalize: |
        val_out = 0
    - field_name: EBREAKS
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 13
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: EBREAKU
      description: >
        Set to enter debug mode on ebreak instruction during user mode
      type: R
ifelse(eval(UMODE != 0), 1, [[[
      type: WARL
]]])
      reset_val: 0
      msb: 12
      lsb: 12
    - field_name: STEPIE
      description: >
        Single step interrupt enable
      type: WARL
      reset_val: 0
      msb: 11
      lsb: 11
    - field_name: STOPCOUNT
      description: >
        Stop counters during debug
      type: WARL
      reset_val: 1
      msb: 10
      lsb: 10
    - field_name: STOPTIME
      description: >
        Hardwired to zero
      type: WARL
      reset_val: 0
      msb: 9
      lsb: 9
      warl_legalize: |
        val_out = 0
    - field_name: CAUSE
      description: >
        Cause for debug entry
      type: R
      reset_val: 0
      msb: 8
      lsb: 6
    - field_name: V
      description: >
        Hardwired to 0
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: MPRVEN
      description: >
        Hardwired to 1
      type: WARL
      reset_val: 1
      msb: 4
      lsb: 4
      warl_legalize: |
        val_out = 1
    - field_name: NMIP
      description: >
        If set, an NMI is pending
      type: R
      reset_val: 0
      msb: 3
      lsb: 3
    - field_name: STEP
      description: >
        Single step enable
      type: RW
      reset_val: 0
      msb: 2
      lsb: 2
    - field_name: PRV
      description: >
        Privilege mode before debug entry
      type: WARL
      reset_val: 0x3
      msb: 1
      lsb: 0
      warl_legalize: |
        val_out = 0x3
ifelse(eval(UMODE != 0), 1, [[[
      warl_legalize: |
        val_out = val_in if ((val_in == 0x3) or (val_in == 0x0)) else val_orig
]]])
]]])

ifelse(eval(DEBUG != 0), 1, [[[
- csr: dpc
  description: >
    Debug PC
  address: 0x7B1
  privilege_mode: D
  rv32:
    - field_name: DPC
      description: >
        Debug PC[31:1].
      type: RW
      reset_val: 0
      msb: 31
      lsb: 1
    - field_name: Zero
      description: >
          Debug PC[0] (always zero)
      type: WARL
      reset_val: 0
      msb: 0
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(DEBUG != 0), 1, [[[
- csr: dscratch0
  description: >
    Debug scratch register
  address: 0x7B2
  privilege_mode: D
  rv32:
    - field_name: SCRATCH
      description: >
        Debug scratch register 0.
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(DEBUG != 0), 1, [[[
- csr: dscratch1
  description: >
    Debug scratch register
  address: 0x7B3
  privilege_mode: D
  rv32:
    - field_name: SCRATCH
      description: >
        Debug scratch register 1.
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
]]])

- csr: mstatus
  description: >
    Machine Status Register
  address: 0x300
  privilege_mode: M
  rv32:
    - field_name: SD
      description: >
        State Dirty
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 31
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_30_23
      description: >
        Always return zero
      type: WPRI
      reset_val: 0
      msb: 30
      lsb: 23
      # WPRI not further specified
    - field_name: TSR
      description: >
        TSR. Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 22
      warl_legalize: |
        val_out = 0
    - field_name: TW
      description: >
        Timeout wait
      type: WARL
      reset_val: 0
      msb: 21
      lsb: 21
      warl_legalize: |
        val_out = 0
ifelse(eval(UMODE != 0), 1, [[[
    - field_name: TW
      description: >
        Timeout wait. When set, WFI from user mode causes illegal instruction.
      type: WARL
      reset_val: 0
      msb: 21
      lsb: 21
]]])
    - field_name: TVM
      description: >
        TVM. Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 20
      lsb: 20
      warl_legalize: |
        val_out = 0
    - field_name: MXR
      description: >
        MXR. Hardwired to 0.
      type: R
      reset_val: 0
      msb: 19
      lsb: 19
    - field_name: SUM
      description: >
        SUM. Hardwired to 0.
      type: R
      reset_val: 0
      msb: 18
      lsb: 18
    - field_name: MPRV
      description: >
        Modify Privilege
      type: R
      reset_val: 0
      msb: 17
      lsb: 17
ifelse(eval(UMODE != 0), 1, [[[
    - field_name: MPRV
      description: >
        Modify Privilege
      type: RW
      reset_val: 0
      msb: 17
      lsb: 17
]]])
    - field_name: XS
      description: >
        Other Extension Context Status.
      type: R
      reset_val: 0
      msb: 16
      lsb: 15
    - field_name: FS
      description: >
        FPU Extension Context Status.
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
ifelse(eval(X_EXT != 0), 1, [[[
    - field_name: FS
      # TODO:silabs-robin "X_EXT" means 2 different things
      description: >
        FPU Extension Context Status.
      type: RW
      reset_val: 0  # Note: Based on default value of "X_ECS_XS"
      msb: 14
      lsb: 13
]]])
    - field_name: MPP
      description: >
        Machine Previous Privilege mode
      type: WARL
      reset_val: 3
      msb: 12
      lsb: 11
      warl_legalize: |
        val_out = 0x3
ifelse(eval(UMODE != 0), 1, [[[
      warl_legalize: |
        val_out = val_in if ((val_in == 0x3) or (val_in == 0x0)) else val_orig
]]])
    - field_name: VS
      description: >
        Vector Extension Context Status
      type: WPRI
ifelse(eval(X_EXT != 0), 1, [[[
      type: RW
]]])
      reset_val: 0
      msb: 10
      lsb: 9
    - field_name: SPP
      description: >
        SPP. Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 8
      lsb: 8
      warl_legalize: |
        val_out = 0
    - field_name: MPIE
      description: >
          Machine Previous Interrupt Enable
      type: RW
      reset_val: 0
      msb: 7
      lsb: 7
    - field_name: UBE
      description: >
        UBE. Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 6
      warl_legalize: |
        val_out = 0
    - field_name: SPIE
      description: >
        SPIE. Hardwired to 0.
      type: R
      reset_val: 0
      msb: 5
      lsb: 5
    - field_name: RESERVED_4_4
      description: >
        Always return zero
      type: WPRI
      reset_val: 0
      msb: 4
      lsb: 4
      # WPRI not further specified
    - field_name: MIE
      description: >
          Machine Interrupt Enable
      type: RW
      reset_val: 0
      msb: 3
      lsb: 3
    - field_name: RESERVED_2_2
      description: >
        Always return zero
      type: WPRI
      reset_val: 0
      msb: 2
      lsb: 2
      # WPRI not further specified
    - field_name: SIE
      description: >
        SIE. Hardwired to 0.
      type: R
      reset_val: 0
      msb: 1
      lsb: 1
    - field_name: RESERVED_0_0
      description: >
        Always return zero
      type: WPRI
      reset_val: 0
      msb: 0
      lsb: 0
      # WPRI not further specified

- csr: misa
  description: >
    Machine ISA Register
  address: 0x301
  privilege_mode: M
  rv32:
    - field_name: MXL
      description: >
        Encodes native base ISA width
      type: WARL
      reset_val: 1
      msb: 31
      lsb: 30
      warl_legalize: |
        val_out = 1
    - field_name: Z
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 25
      lsb: 25
      warl_legalize: |
        val_out = 0
    - field_name: Y
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 24
      lsb: 24
      warl_legalize: |
        val_out = 0
    - field_name: X
      description: >
        Non-standard extensions present
      type: WARL
      reset_val: 1
      msb: 23
      lsb: 23
      warl_legalize: |
        val_out = 1
    - field_name: W
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 22
      warl_legalize: |
        val_out = 0
    - field_name: V
      description: >
        Tentatively reserved for Vector extension
      type: WARL
      reset_val: 0
      msb: 21
      lsb: 21
      warl_legalize: |
        val_out = 0
ifelse(eval(V_EXT != 0), 1, [[[
    - field_name: V
      description: >
        Tentatively reserved for Vector extension
      type: WARL
      reset_val: 0
      msb: 21
      lsb: 21
]]])
    - field_name: U
      description: >
        User mode
      type: WARL
      msb: 20
      lsb: 20
ifelse(eval(UMODE != 0), 1, [[[
      reset_val: 1
      warl_legalize: |
        val_out = 1
]]], [[[dnl
      reset_val: 0
      warl_legalize: |
        val_out = 0
]]])
    - field_name: T
      description: >
        Tentatively reserved for Transactional Memory extension
      type: WARL
      reset_val: 0
      msb: 19
      lsb: 19
      warl_legalize: |
        val_out = 0
    - field_name: S
      description: >
        Supervisor mode
      type: WARL
      reset_val: 0
      msb: 18
      lsb: 18
      warl_legalize: |
        val_out = 0
    - field_name: R
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 17
      lsb: 17
      warl_legalize: |
        val_out = 0
    - field_name: Q
      description: >
        Quad precision floating point
      type: WARL
      reset_val: 0
      msb: 16
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: P
      description: >
        Packed SIMD
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 15
      warl_legalize: |
        val_out = 0
ifelse(eval(P_EXT != 0), 1, [[[
    - field_name: P
      description: >
        Packed SIMD
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 15
]]])
    - field_name: O
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 14
      warl_legalize: |
        val_out = 0
    - field_name: N
      description: >
        User mode interrupts
      type: WARL
      reset_val: 0
      msb: 13
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: M
      description: >
        Integer multiply and divide
      type: WARL
      msb: 12
      lsb: 12
ifelse(eval(M_EXT != 0), 1, [[[
      reset_val: 1
      warl_legalize: |
        val_out = 1
]]])
ifelse(eval(M_NONE != 0), 1, [[[
      reset_val: 0
      warl_legalize: |
        val_out = 0
]]])
    - field_name: L
      description: >
        Tentatively reserved for decimal floating point extension
      type: WARL
      reset_val: 0
      msb: 11
      lsb: 11
      warl_legalize: |
        val_out = 0
    - field_name: K
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 10
      lsb: 10
      warl_legalize: |
        val_out = 0
    - field_name: J
      description: >
        Tentatively reserved for dynamically translated languages extension
      type: WARL
      reset_val: 0
      msb: 9
      lsb: 9
      warl_legalize: |
        val_out = 0
    - field_name: I
      description: >
        RV32I/RV64I/RV128I ISA
      type: WARL
      msb: 8
      lsb: 8
ifelse(eval(I_BASE != 0), 1, [[[
      reset_val: 1
      warl_legalize: |
        val_out = 1
]]])
ifelse(eval(E_BASE != 0), 1, [[[
      reset_val: 0
      warl_legalize: |
        val_out = 0
]]])
    - field_name: H
      description: >
        Hypervisor extension
      type: WARL
      reset_val: 0
      msb: 7
      lsb: 7
      warl_legalize: |
        val_out = 0
    - field_name: G
      description: >
        Additional standard extensions present
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 6
      warl_legalize: |
        val_out = 0
    - field_name: F
      description: >
        Single presition floating point
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 5
      warl_legalize: |
        val_out = 0
ifelse(eval(F_EXT != 0), 1, [[[
    - field_name: F
      description: >
        Single presition floating point
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 5
]]])
    - field_name: E
      description: >
        RV32E base ISA
      type: WARL
      msb: 4
      lsb: 4
ifelse(eval(E_BASE != 0), 1, [[[
      reset_val: 1
      warl_legalize: |
        val_out = 1
]]])
ifelse(eval(I_BASE != 0), 1, [[[
      reset_val: 0
      warl_legalize: |
        val_out = 0
]]])
    - field_name: D
      description: >
        Double presition floating point extension
      type: WARL
      reset_val: 0
      msb: 3
      lsb: 3
      warl_legalize: |
        val_out = 0
    - field_name: C
      description: >
        Compressed extension
      type: WARL
      reset_val: 1
      msb: 2
      lsb: 2
      warl_legalize: |
        val_out = 1
    - field_name: B
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 1
      lsb: 1
      warl_legalize: |
        val_out = 0
    - field_name: A
      description: >
        Atomic extension
      type: WARL
      msb: 0
      lsb: 0
      reset_val: 0
      warl_legalize: |
        val_out = 0
ifelse(eval(A_EXT != 0), 1, [[[
      reset_val: 1
      warl_legalize: |
        val_out = 1
]]])

ifelse(eval(CLINT != 0), 1, [[[
- csr: mie
  description: >
    Machine Interrupt Enable
  address: 0x304
  privilege_mode: M
  rv32:
    - field_name: MFIE
      description: >
        Machine Fast Interrupt Enables
      type: RW
      reset_val: 0
      msb: 31
      lsb: 16
    - field_name: RESERVED_15_12
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 12
      warl_legalize: |
        val_out = 0
    - field_name: MEIE
      description: >
        Machine External Interrupt Enable
      type: RW
      reset_val: 0
      msb: 11
      lsb: 11
    - field_name: RESERVED_10_10
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 10
      lsb: 10
      warl_legalize: |
        val_out = 0
    - field_name: SEIE
      description: >
        Supervisor External Interrupt Enable
      type: WARL
      reset_val: 0
      msb: 9
      lsb: 9
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_8_8
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 8
      lsb: 8
      warl_legalize: |
        val_out = 0
    - field_name: MTIE
      description: >
        Machine Timer Interrupt Enable
      type: RW
      reset_val: 0
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_6
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 6
      warl_legalize: |
        val_out = 0
    - field_name: STIE
      description: >
        Supervisor Timer Interrupt Enable
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_4_4
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 4
      lsb: 4
      warl_legalize: |
        val_out = 0
    - field_name: MSIE
      description: >
        Machine Software Interrupt Enable
      type: RW
      reset_val: 0
      msb: 3
      lsb: 3
    - field_name: RESERVED_2_2
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 2
      lsb: 2
      warl_legalize: |
        val_out = 0
    - field_name: SSIE
      description: >
        Supervisor Software Interrupt Enable
      type: WARL
      reset_val: 0
      msb: 1
      lsb: 1
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_0_0
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 0
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mie
  description: >
    Machine Interrupt Enable
  address: 0x304
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_0
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(CLINT != 0), 1, [[[
- csr: mtvec
  description: >
    Machine Trap-Vector Base Address
  address: 0x305
  privilege_mode: M
  rv32:
    - field_name: BASE_31_7
      description: >
        Trap-handler base address, always aligned to 128 bytes
      type: WARL
      reset_val: 0  # Note: assumes mtvec_i == 0
      msb: 31
      lsb: 7
    - field_name: BASE_6_2
      description: >
        Trap-handler base address, always aligned to 128 bytes
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 2
      warl_legalize: |
        val_out = 0
    - field_name: MODE
      description: >
        0 = Direct mode, 1 = vectored mode
      type: WARL
      reset_val: 1
      msb: 1
      lsb: 0
      warl_legalize: |
        val_out = val_in if (val_in == 0 or val_in == 1) else val_orig
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mtvec
  description: >
    Machine Trap-Vector Base Address
  address: 0x305
  privilege_mode: M
  rv32:
    - field_name: BASE_31_7
      description: >
        Trap-handler base address, always aligned to 128 bytes
      type: WARL
      reset_val: 0  # Note: assumes mtvec_i == 0
      msb: 31
      lsb: 7
    - field_name: BASE_6
      description: >
        Trap-handler base address, always aligned to 128 bytes
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 6
      warl_legalize: |
        val_out = 0
    - field_name: SUBMODE
      description: >
        Sub mode, reserved for future use
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 2
      warl_legalize: |
        val_out = 0
    - field_name: MODE
      description: >
        CLIC mode enabled
      type: WARL
      reset_val: 3
      msb: 1
      lsb: 0
      warl_legalize: |
        val_out = 3
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mtvt
  description: >
    Machine Trap Vector Table Base Address
  address: 0x307
  privilege_mode: M
  rv32:
    - field_name: BASE_31_N
      description: >
        Trap-handler vector base address. Alignment depends on CLIC_ID_WIDTH parameter.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 7
    - field_name: BASE_N_1_6
      description: >
        Base address alignment field, hardcoded zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 6
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_5_0
      description: >
        Reserved
      type: R
      reset_val: 0
      msb: 5
      lsb: 0
]]])

- csr: mstatush
  description: >
    Machine Status Registers
  address: 0x310
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_6
      description: >
        Reserved
      type: WPRI
      reset_val: 0
      msb: 31
      lsb: 6
    - field_name: MBE
      description: >
        Machine Mode Big Endian Memory Access (Always zero)
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: SBE
      description: >
        Supervisor Big Endian Memory Access (Always zero)
      type: WARL
      reset_val: 0
      msb: 4
      lsb: 4
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_3_0
      description: >
        Reserved
      type: WPRI
      reset_val: 0
      msb: 3
      lsb: 0

- csr: mcountinhibit
  description: >
    Machine Counter-Inhibit
  address: 0x320
  privilege_mode: M
  rv32:
    - field_name: Selectors_31_4
      description: >
        Selectors for mhpmcounter31..4 inhibit (assuming NUM_MHPMCOUNTER set to 1)
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 3
      warl_legalize: |
        val_out = 0
    - field_name: IR
      description: >
        Inhibit minstret counting
      type: WARL
      reset_val: 1
      msb: 2
      lsb: 2
    - field_name: RESERVED_1_1
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 1
      lsb: 1
      warl_legalize: |
        val_out = 0
    - field_name: CY
      description: >
        Inhibit mcycle counting
      type: WARL
      reset_val: 1
      msb: 0
      lsb: 0

- csr: mhpmevent3
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 3
  address: 0x323
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 1), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent4
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 4
  address: 0x324
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 2), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent5
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 5
  address: 0x325
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 3), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent6
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 6
  address: 0x326
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 4), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent7
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 7
  address: 0x327
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 5), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent8
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 8
  address: 0x328
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 6), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent9
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 9
  address: 0x329
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 7), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent10
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 10
  address: 0x32a
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 8), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent11
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 11
  address: 0x32b
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 9), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent12
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 12
  address: 0x32c
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 10), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent13
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 13
  address: 0x32d
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 11), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent14
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 14
  address: 0x32e
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 12), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent15
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 15
  address: 0x32f
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 13), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent16
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 16
  address: 0x330
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 14), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent17
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 17
  address: 0x331
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 15), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent18
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 18
  address: 0x332
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 16), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent19
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 19
  address: 0x333
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 17), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent20
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 20
  address: 0x334
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 18), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent21
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 21
  address: 0x335
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 19), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent22
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 22
  address: 0x336
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 20), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent23
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 23
  address: 0x337
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 21), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent24
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 24
  address: 0x338
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 22), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent25
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 25
  address: 0x339
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 23), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent26
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 26
  address: 0x33a
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 24), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent27
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 27
  address: 0x33b
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 25), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent28
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 28
  address: 0x33c
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 26), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent29
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 29
  address: 0x33d
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 27), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent30
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 30
  address: 0x33e
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 28), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mhpmevent31
  description: >
    (HPM) Machine Performance-Monitoring Event Selector 31
  address: 0x33f
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved, hard coded 0
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: SELECTORS
      description: >
        Selects counter events
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 0
ifelse(eval(NUM_MHPMCOUNTERS >= 29), 1, [[[
]]], [[[dnl
      warl_legalize: |
        val_out = 0
]]])

- csr: mscratch
  description: >
    Machine Scratch-pad Register
  address: 0x340
  privilege_mode: M
  rv32:
    - field_name: SCRATCH
      description: >
        Scratch-pad
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0

- csr: mepc
  description: >
    Machine Exception Program Counter
  address: 0x341
  privilege_mode: M
  rv32:
    - field_name: EPC
      description: >
          Exception PC[31:1]
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 1
    - field_name: Zero
      description: >
          Exception PC[0] (always zero)
      type: WARL
      reset_val: 0
      msb: 0
      lsb: 0
      warl_legalize: |
        val_out = 0

ifelse(eval(CLIC != 0), 1, [[[
- csr: mcause
  description: >
    Machine Exception Cause
  address: 0x342
  privilege_mode: M
  rv32:
    - field_name: Interrupt
      description: >
          Set when exception triggered by interrupt
      type: RW
      reset_val: 0
      msb: 31
      lsb: 31
    - field_name: Minhv
      description: >
          Set at start of CLIC hardware vectoring, cleared after successful vectoring.
      type: RW
      reset_val: 0
      msb: 30
      lsb: 30
    - field_name: MPP
      description: >
          Alias for mstatus.MPP
      type: WARL
      reset_val: 0
      msb: 29
      lsb: 28
      warl_legalize: |
        val_out = 0x3
ifelse(eval(UMODE != 0), 1, [[[
      warl_legalize: |
        val_out = val_in if ((val_in == 0x3) or (val_in == 0x0)) else val_orig
]]])
    - field_name: MPIE
      description: >
          Alias for mstatus.MPIE
      type: RW
      reset_val: 0
      msb: 27
      lsb: 27
    - field_name: RESERVED_26_24
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 26
      lsb: 24
      warl_legalize: |
        val_out = 0
    - field_name: MPIL
      description: >
          Machine Previous Interrupt Level
      type: RW
      reset_val: 0
      msb: 23
      lsb: 16
    - field_name: RESERVED_15_12
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 12
      warl_legalize: |
        val_out = 0
    - field_name: Exccode_11
      description: >
          Exception Code
      type: WARL
      reset_val: 0
      msb: 11
      lsb: 11
      warl_legalize: |
        val_out = 0
    - field_name: Exccode_10_0
      description: >
          Exception Code
      type: WLRL
      reset_val: 0
      msb: 10
      lsb: 0
]]])

ifelse(eval(CLINT != 0), 1, [[[
- csr: mcause
  description: >
    Machine Exception Cause
  address: 0x342
  privilege_mode: M
  rv32:
    - field_name: Interrupt
      description: >
          Set when exception triggered by interrupt
      type: RW
      reset_val: 0
      msb: 31
      lsb: 31
    - field_name: Exccode_30_11
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 11
      warl_legalize: |
        val_out = 0
    - field_name: Exccode_10_0
      description: >
          Exception Code
      type: WLRL
      reset_val: 0
      msb: 10
      lsb: 0
]]])

- csr: mtval
  description: >
    Machine Trap Value
  address: 0x343
  privilege_mode: M
  rv32:
    - field_name: mtval
      description: >
         Machine Trap Value
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0

ifelse(eval(CLINT != 0), 1, [[[
- csr: mip
  description: >
    Machine Interrupt Pending
  address: 0x344
  privilege_mode: M
  rv32:
    - field_name: MFIP
      description: >
         Fast Interrupts Pending
      type: R
      reset_val: 0
      msb: 31
      lsb: 16
    - field_name: RESERVED_15_12
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 15
      lsb: 12
      warl_legalize: |
        val_out = 0
    - field_name: MEIP
      description: >
         Machine External Interrupt Pending
      type: R
      reset_val: 0
      msb: 11
      lsb: 11
    - field_name: RESERVED_10_10
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 10
      lsb: 10
      warl_legalize: |
        val_out = 0
    - field_name: SEIP
      description: >
        Always zero
      type: WARL
      reset_val: 0
      msb: 9
      lsb: 9
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_8_8
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 8
      lsb: 8
      warl_legalize: |
        val_out = 0
    - field_name: MTIP
      description: >
         Machine Timer Interrupt Pending
      type: R
      reset_val: 0
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_6
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 6
      warl_legalize: |
        val_out = 0
    - field_name: STIP
      description: >
        Always zero
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_4_4
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 4
      lsb: 4
      warl_legalize: |
        val_out = 0
    - field_name: MSIP
      description: >
         Machine Software Interrupt Pending
      type: R
      reset_val: 0
      msb: 3
      lsb: 3
    - field_name: RESERVED_2_2
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 2
      lsb: 2
      warl_legalize: |
        val_out = 0
    - field_name: SSIP
      description: >
         Always zero
      type: WARL
      reset_val: 0
      msb: 1
      lsb: 1
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_0_0
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 0
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mip
  description: >
    Machine Interrupt Pending
  address: 0x344
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_0
      description: >
         Always zero
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mnxti
  description: >
    Machine next interrupt
  address: 0x345
  privilege_mode: M
  rv32:
    - field_name: MNXTI
      description: >
        Machine next interrupt handler address and interrupt enable
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mintstatus
  description: >
    Machine interrupt status
  address: 0xFB1
  privilege_mode: M
  rv32:
    - field_name: MIL
      description: >
        Machine interrupt level
      type: R
      reset_val: 0
      msb: 31
      lsb: 24
    - field_name: RESERVED_23_16
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 23
      lsb: 16
    - field_name: SIL
      description: >
        Supervisor interrupt level
      type: R
      reset_val: 0
      msb: 15
      lsb: 8
    - field_name: UIL
      description: >
        User interrupt level
      type: R
      reset_val: 0
      msb: 7
      lsb: 0
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mintthresh
  description: >
    Machine interrupt threshold
  address: 0x347
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_8
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 31
      lsb: 8
    - field_name: TH
      description: >
        Threshold
      type: WARL
      reset_val: 0
      msb: 7
      lsb: 0
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mscratchcsw
  description: >
    Machine scratch swap for privilege mode change
  address: 0x348
  privilege_mode: M
  rv32:
    - field_name: MSCRATCHCSW
      description: >
        Machine scratch swap for privelege mode change
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(CLIC != 0), 1, [[[
- csr: mscratchcswl
  description: >
    Machine scratch swap for privilege level change
  address: 0x349
  privilege_mode: M
  rv32:
    - field_name: MSCRATCHCSWL
      description: >
        Machine scratch swap for privilege level change
      type: RW
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(DBG_NUM_TRIGGERS >= 1), 1, [[[
- csr: tselect
  description: >
    Trigger Select Register
  address: 0x7A0
  privilege_mode: M
  rv32:
    - field_name: Trigger
      description: >
         Trigger select field
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
ifelse(eval(DBG_NUM_TRIGGERS == 1), 1, [[[
        val_out = 0
]]])
ifelse(eval(DBG_NUM_TRIGGERS == 2), 1, [[[
        val_out = val_in if (val_in == 0 or val_in == 1) else val_orig
]]])
ifelse(eval(DBG_NUM_TRIGGERS == 3), 1, [[[
        val_out = val_in if (val_in == 0 or val_in == 1 or val_in == 2) else val_orig
]]])
ifelse(eval(DBG_NUM_TRIGGERS == 4), 1, [[[
        val_out = val_in if (val_in == 0 or val_in == 1 or val_in == 2 or val_in == 3) else val_orig
]]])
]]])

ifelse(eval(DBG_NUM_TRIGGERS >= 1), 1, [[[
- csr: tdata1
  description: >
    Trigger Data Register 1
  address: 0x7A1
  privilege_mode: M
  reset_val: 0x28001000
  rv32:
    - field_name: Type
      description: >
         Address/data match trigger type
      type: WARL
      reset_val: 2
      msb: 31
      lsb: 28
      values:
         mcontrol:   2
         etrigger:   5
         mcontrol6:  6
         disabled:  15
      warl_legalize: |
        val_out = val_in if (val_in == 2 or val_in == 5 or val_in == 6) else 0xF
    - field_name: dmode
      description: >
         Only debug mode can write tdata registers
      type: WARL
      reset_val: 1
      msb: 27
      lsb: 27
      warl_legalize: |
        val_out = 1
    - field_name: data
      description: >
         Only debug mode can write tdata registers
      type: WARL
      reset_val: 1
      msb: 26
      lsb: 0
]]])

ifelse(eval(DBG_NUM_TRIGGERS >= 1), 1, [[[
- csr: tdata2
  description: >
    Trigger Data Register 2
  address: 0x7A2
  privilege_mode: M
  rv32:
    - field_name: Data
      description: >
         Depending on tdata1.dmode
      type: WARL
      reset_val: 0
      warl_legalize: |
        val_out = val_in  # Note: Actual behavior depends on the values of tdata1.TYPE and tdata1.DMODE!
      msb: 31
      lsb: 0
]]])

ifelse(eval(DBG_NUM_TRIGGERS >= 1), 1, [[[
- csr: tdata3
  description: >
    Trigger Data Register 3
  address: 0x7A3
  privilege_mode: M
  rv32:
    - field_name: Zero
      description: >
        Not supported.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(DBG_NUM_TRIGGERS >= 1), 1, [[[
- csr: tinfo
  description: >
    Trigger Info
  address: 0x7A4
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_16
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 16
      warl_legalize: |
        val_out = 0
    - field_name: Info
      description: >
        Types 0x2, 0x5, 0x6 and 0xF are supported.
      type: R
      reset_val: 0x8064
      msb: 15
      lsb: 0
]]])

ifelse(eval(DBG_NUM_TRIGGERS >= 1), 1, [[[
- csr: tcontrol
  description: >
    Trigger control
  address: 0x7A5
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_8
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 8
      warl_legalize: |
        val_out = 0
    - field_name: MPTE
      description: >
        MPTE
      type: WARL
      reset_val: 0
      msb: 7
      lsb: 7
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_6_4
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 4
      warl_legalize: |
        val_out = 0
    - field_name: MTE
      description: >
        MTE
      type: WARL
      reset_val: 0
      msb: 3
      lsb: 3
      warl_legalize: |
        val_out = 0
    - field_name: RESERVED_2_0
      description: >
        Reserved
      type: WARL
      reset_val: 0
      msb: 2
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: jvt
  description: >
    Jump vector table
  address: 0x017
  privilege_mode: U
  rv32:
    - field_name: Base_31_10
      description: >
        Upper bits of vector table base address, 1024 byte aligned
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 10
    - field_name: Base_9_6
      description: >
        Lower bits of vector table base address, 1024 byte aligned always 0
      type: WARL
      reset_val: 0
      msb: 9
      lsb: 6
      warl_legalize: |
        val_out = val_in if val_in == 0 else val_orig
    - field_name: Mode
      description: >
        Jump table mode
      type: WARL
      reset_val: 0
      msb: 5
      lsb: 0
      warl_legalize: |
        val_out = val_in if val_in == 0 else val_orig
]]])


###############################################################################
# {mvendorid, marchid, mimpid, mhartid, mconfigptr} are MRO, and are hence
# marked with a conditional to denote that a write would give an exception.

ifelse(eval(READONLY != 0), 1, [[[
- csr: mvendorid
  description: >
    Machine Vendor ID
  address: 0xF11
  privilege_mode: M
  rv32:
    - field_name: Bank
      description: >
       Number of continuation codes in JEDEC manufacturer ID
      type: R
      reset_val: 12
      msb: 31
      lsb: 7
    - field_name: ID
      description: >
       Final byte of JEDEC manufacturer ID, discarding the parity bit.
      type: R
      reset_val: 2
      msb: 6
      lsb: 0
- csr: marchid
  description: >
    Machine Architecture ID
  address: 0xF12
  privilege_mode: M
  rv32:
    - field_name: ID
      description: >
        Machine Architecture ID of the core
      type: R
ifelse(eval(MARCHID == 0x14), 1, [[[
      reset_val: 0x14
]]])
ifelse(eval(MARCHID == 0x15), 1, [[[
      reset_val: 0x15
]]])
      msb: 31
      lsb: 0
- csr: mimpid
  description: >
    Machine Implementation ID
  address: 0xF13
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_20
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 31
      lsb: 20
    - field_name: MAJOR
      description: >
        Major
      type: R
      reset_val: 0
      msb: 19
      lsb: 16
    - field_name: RESERVED_15_12
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 15
      lsb: 12
    - field_name: MINOR
      description: >
        Minor
      type: R
      reset_val: 0
      msb: 11
      lsb: 8
    - field_name: RESERVED_7_4
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 7
      lsb: 4
    - field_name: PATCH
      description: >
        Patch value, depends on toplevel pins.
      type: R
      reset_val: unknown  # Note: Incompatible with access test generation
      msb: 3
      lsb: 0
- csr: mhartid
  description: >
    Machine Hart ID
  address: 0xF14
  privilege_mode: M
  rv32:
    - field_name: Hart
      description: >
        mhartid_i
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
- csr: mconfigptr
  description: >
    Machine configuration pointer
  address: 0xF15
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_0
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 31
      lsb: 0
]]])

ifelse(eval(XSECURE != 0), 1, [[[
- csr: cpuctrl
  description: >
    Controls CPU security features
  address: 0xBF0
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_20
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 31
      lsb: 20
    - field_name: RNDDUMMYFREQ
      description: >
        Controls dummy instruction frequency
      type: RW
      reset_val: 0
      msb: 19
      lsb: 16
    - field_name: RESERVED_15_5
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 15
      lsb: 5
    - field_name: INTEGRITY
      description: >
        Set to enable integrity checking
      type: RW
      reset_val: 1
      msb: 4
      lsb: 4
    - field_name: PCHARDEN
      description: >
        Set to enable PC hardening
      type: RW
      reset_val: 1
      msb: 3
      lsb: 3
    - field_name: RNDHINT
      description: >
        Set to enable random instruction for hint
      type: RW
      reset_val: 0
      msb: 2
      lsb: 2
    - field_name: RNDDUMMY
      description: >
        Set to enable dummy instruction insertion
      type: RW
      reset_val: 0
      msb: 1
      lsb: 1
    - field_name: DATAINDTIMING
      description: >
        Set to enable data independent timing
      type: RW
      reset_val: 1
      msb: 0
      lsb: 0
]]])

ifelse(eval(XSECURE != 0), 1, [[[
- csr: secureseed0
  description: >
    Seed for LSFR0
  address: 0xBF9
  privilege_mode: M
  rv32:
    - field_name: SEED
      description: >
        Seed for LSFR
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(XSECURE != 0), 1, [[[
- csr: secureseed1
  description: >
    Seed for LSFR1
  address: 0xBFA
  privilege_mode: M
  rv32:
    - field_name: SEED
      description: >
        Seed for LSFR
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(XSECURE != 0), 1, [[[
- csr: secureseed2
  description: >
    Seed for LSFR0
  address: 0xBFC
  privilege_mode: M
  rv32:
    - field_name: SEED
      description: >
        Seed for LSFR
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(UMODE != 0), 1, [[[
- csr: mcounteren
  description: >
    Machine counter enable
  address: 0x306
  privilege_mode: M
  rv32:
    - field_name: ENABLE
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(UMODE != 0), 1, [[[
- csr: menvcfg
  description: >
    Machine Environment Configuration
  address: 0x30A
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_8
      description: >
        Hardwired to 0
      type: WPRI
      reset_val: 0
      msb: 31
      lsb: 8
    - field_name: CBZE
      description: >
        Hardwired to 0
      type: R
      reset_val: 0
      msb: 7
      lsb: 7
    - field_name: CBCFE
      description: >
        Hardwired to 0
      type: R
      reset_val: 0
      msb: 6
      lsb: 6
    - field_name: CBIE
      description: >
        Hardwired to 0
      type: R
      reset_val: 0
      msb: 5
      lsb: 4
    - field_name: RESERVED_3_1
      description: >
        Always return zero
      type: R
      reset_val: 0
      msb: 3
      lsb: 1
    - field_name: FIOM
      description: >
        Hardwired to 0
      type: R
      reset_val: 0
      msb: 0
      lsb: 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen0
  description: >
    Machine state enable 0
  address: 0x30C
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_3
      description: >
        Hard coded zero
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 3
      warl_legalize: |
        val_out = 0
    - field_name: UMJVT
      description: >
        Controls user mode access to jvt register and legalness of cm.jt/cm.jalt.
      type: RW
      reset_val: 0
      msb: 2
      lsb: 2
    - field_name: RESERVED_1_0
      description: >
        Hard coded zero
      type: WARL
      reset_val: 0
      msb: 1
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen1
  description: >
    Machine state enable 1
  address: 0x30D
  privilege_mode: M
  rv32:
    - field_name: ZERO
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen2
  description: >
    Machine state enable 2
  address: 0x30E
  privilege_mode: M
  rv32:
    - field_name: ZERO
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen3
  description: >
    Machine state enable 3
  address: 0x30F
  privilege_mode: M
  rv32:
    - field_name: ZERO
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(UMODE != 0), 1, [[[
- csr: menvcfgh
  description: >
    Machine Environment Configuration upper 32 bits
  address: 0x31A
  privilege_mode: M
  rv32:
    - field_name: STCE
      description: >
        Hardwired to 0
      type: R
      reset_val: 0
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_0
      description: >
        Hardwired to 0
      type: WPRI
      reset_val: 0
      msb: 30
      lsb: 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen0h
  description: >
    Machine state enable 0 upper 32 bits
  address: 0x31C
  privilege_mode: M
  rv32:
    - field_name: ZEROO
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen1h
  description: >
    Machine state enable 1 upper 32 bits
  address: 0x31D
  privilege_mode: M
  rv32:
    - field_name: ZERO
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen2h
  description: >
    Machine state enable 2 upper 32 bits
  address: 0x31E
  privilege_mode: M
  rv32:
    - field_name: ZERO
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(ZC != 0), 1, [[[
- csr: mstateen3h
  description: >
    Machine state enable 3 upper 32 bits
  address: 0x31F
  privilege_mode: M
  rv32:
    - field_name: ZERO
      description: >
        Hardwired to 0.
      type: WARL
      reset_val: 0
      msb: 31
      lsb: 0
      warl_legalize: |
        val_out = 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 1), 1, [[[
- csr: mseccfg
  description: >
    Machine security configuration
  address: 0x747
  privilege_mode: M
  rv32:
    - field_name: RESERVED_31_10
      description: >
        Hardwired to 0
      type: WPRI
      reset_val: 0
      msb: 31
      lsb: 10
    - field_name: SSEED
      description: >
        Hardwired to 0.
      type: R
      reset_val: 0
      msb: 9
      lsb: 9
    - field_name: USEED
      description: >
        Hardwired to 0.
      type: R
      reset_val: 0
      msb: 8
      lsb: 8
    - field_name: RESERVED_7_3
      description: >
        Hardwired to 0
      type: WPRI
      reset_val: 0
      msb: 7
      lsb: 3
    - field_name: RLB
      description: >
        PMP Rule locking bypass
      type: WARL
      reset_val: 0  # Note: Based on MSECCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: MMWP
      description: >
        Machine Mode Whitelist Policy
      type: WARL
      reset_val: 0  # Note: Based on MSECCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: MML
      description: >
        Machine Mode Lockdown
      type: WARL
      reset_val: 0  # Note: Based on MSECCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 1), 1, [[[
- csr: mseccfgh
  description: >
    Machine security configuration upper 32 bits
  address: 0x757
  privilege_mode: M
  rv32:
    - field_name: ZERO
      description: >
        Hardwired to 0.
      type: WPRI
      reset_val: 0
      msb: 31
      lsb: 0
]]])


# Note: "pmpcfg*", is only defined in this file for 1) "PMP N" multiples of 4, and 2) non-warl0

ifelse(eval(PMP_NUM_REGIONS >= 4), 1, [[[
- csr: pmpcfg0
  description: >
    Physical memory protection configuration
  address: 0x3a0
  privilege_mode: M
  rv32:
    - field_name: PMPCFG3_L
      description: >
        PMP region 3 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG3_A
      description: >
        PMP region 3 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG3_X
      description: >
        PMP region 3 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG3_W
      description: >
        PMP region 3 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG3_R
      description: >
        PMP region 3 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG2_L
      description: >
        PMP region 2 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG2_A
      description: >
        PMP region 2 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG2_X
      description: >
        PMP region 2 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG2_W
      description: >
        PMP region 2 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG2_R
      description: >
        PMP region 2 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG1_L
      description: >
        PMP region 1 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG1_A
      description: >
        PMP region 1 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG1_X
      description: >
        PMP region 1 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG1_W
      description: >
        PMP region 1 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG1_R
      description: >
        PMP region 1 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG0_L
      description: >
        PMP region 0 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG0_A
      description: >
        PMP region 0 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG0_X
      description: >
        PMP region 0 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG0_W
      description: >
        PMP region 0 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG0_R
      description: >
        PMP region 0 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 8), 1, [[[
- csr: pmpcfg1
  description: >
    Physical memory protection configuration
  address: 0x3a1
  privilege_mode: M
  rv32:
    - field_name: PMPCFG7_L
      description: >
        PMP region 7 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG7_A
      description: >
        PMP region 7 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG7_X
      description: >
        PMP region 7 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG7_W
      description: >
        PMP region 7 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG7_R
      description: >
        PMP region 7 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG6_L
      description: >
        PMP region 6 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG6_A
      description: >
        PMP region 6 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG6_X
      description: >
        PMP region 6 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG6_W
      description: >
        PMP region 6 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG6_R
      description: >
        PMP region 6 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG5_L
      description: >
        PMP region 5 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG5_A
      description: >
        PMP region 5 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG5_X
      description: >
        PMP region 5 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG5_W
      description: >
        PMP region 5 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG5_R
      description: >
        PMP region 5 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG4_L
      description: >
        PMP region 4 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG4_A
      description: >
        PMP region 4 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG4_X
      description: >
        PMP region 4 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG4_W
      description: >
        PMP region 4 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG4_R
      description: >
        PMP region 4 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 12), 1, [[[
- csr: pmpcfg2
  description: >
    Physical memory protection configuration
  address: 0x3a2
  privilege_mode: M
  rv32:
    - field_name: PMPCFG11_L
      description: >
        PMP region 11 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG11_A
      description: >
        PMP region 11 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG11_X
      description: >
        PMP region 11 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG11_W
      description: >
        PMP region 11 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG11_R
      description: >
        PMP region 11 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG10_L
      description: >
        PMP region 10 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG10_A
      description: >
        PMP region 10 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG10_X
      description: >
        PMP region 10 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG10_W
      description: >
        PMP region 10 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG10_R
      description: >
        PMP region 10 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG9_L
      description: >
        PMP region 9 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG9_A
      description: >
        PMP region 9 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG9_X
      description: >
        PMP region 9 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG9_W
      description: >
        PMP region 9 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG9_R
      description: >
        PMP region 9 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG8_L
      description: >
        PMP region 8 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG8_A
      description: >
        PMP region 8 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG8_X
      description: >
        PMP region 8 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG8_W
      description: >
        PMP region 8 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG8_R
      description: >
        PMP region 8 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 16), 1, [[[
- csr: pmpcfg3
  description: >
    Physical memory protection configuration
  address: 0x3a3
  privilege_mode: M
  rv32:
    - field_name: PMPCFG15_L
      description: >
        PMP region 15 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG15_A
      description: >
        PMP region 15 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG15_X
      description: >
        PMP region 15 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG15_W
      description: >
        PMP region 15 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG15_R
      description: >
        PMP region 15 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG14_L
      description: >
        PMP region 14 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG14_A
      description: >
        PMP region 14 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG14_X
      description: >
        PMP region 14 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG14_W
      description: >
        PMP region 14 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG14_R
      description: >
        PMP region 14 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG13_L
      description: >
        PMP region 13 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG13_A
      description: >
        PMP region 13 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG13_X
      description: >
        PMP region 13 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG13_W
      description: >
        PMP region 13 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG13_R
      description: >
        PMP region 13 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG12_L
      description: >
        PMP region 12 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG12_A
      description: >
        PMP region 12 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG12_X
      description: >
        PMP region 12 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG12_W
      description: >
        PMP region 12 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG12_R
      description: >
        PMP region 12 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 20), 1, [[[
- csr: pmpcfg4
  description: >
    Physical memory protection configuration
  address: 0x3a4
  privilege_mode: M
  rv32:
    - field_name: PMPCFG19_L
      description: >
        PMP region 19 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG19_A
      description: >
        PMP region 19 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG19_X
      description: >
        PMP region 19 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG19_W
      description: >
        PMP region 19 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG19_R
      description: >
        PMP region 19 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG18_L
      description: >
        PMP region 18 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG18_A
      description: >
        PMP region 18 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG18_X
      description: >
        PMP region 18 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG18_W
      description: >
        PMP region 18 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG18_R
      description: >
        PMP region 18 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG17_L
      description: >
        PMP region 17 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG17_A
      description: >
        PMP region 17 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG17_X
      description: >
        PMP region 17 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG17_W
      description: >
        PMP region 17 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG17_R
      description: >
        PMP region 17 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG16_L
      description: >
        PMP region 16 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG16_A
      description: >
        PMP region 16 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG16_X
      description: >
        PMP region 16 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG16_W
      description: >
        PMP region 16 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG16_R
      description: >
        PMP region 16 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 24), 1, [[[
- csr: pmpcfg5
  description: >
    Physical memory protection configuration
  address: 0x3a5
  privilege_mode: M
  rv32:
    - field_name: PMPCFG23_L
      description: >
        PMP region 23 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG23_A
      description: >
        PMP region 23 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG23_X
      description: >
        PMP region 23 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG23_W
      description: >
        PMP region 23 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG23_R
      description: >
        PMP region 23 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG22_L
      description: >
        PMP region 22 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG22_A
      description: >
        PMP region 22 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG22_X
      description: >
        PMP region 22 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG22_W
      description: >
        PMP region 22 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG22_R
      description: >
        PMP region 22 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG21_L
      description: >
        PMP region 21 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG21_A
      description: >
        PMP region 21 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG21_X
      description: >
        PMP region 21 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG21_W
      description: >
        PMP region 21 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG21_R
      description: >
        PMP region 21 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG20_L
      description: >
        PMP region 20 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG20_A
      description: >
        PMP region 20 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG20_X
      description: >
        PMP region 20 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG20_W
      description: >
        PMP region 20 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG20_R
      description: >
        PMP region 20 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 28), 1, [[[
- csr: pmpcfg6
  description: >
    Physical memory protection configuration
  address: 0x3a6
  privilege_mode: M
  rv32:
    - field_name: PMPCFG27_L
      description: >
        PMP region 27 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG27_A
      description: >
        PMP region 27 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG27_X
      description: >
        PMP region 27 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG27_W
      description: >
        PMP region 27 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG27_R
      description: >
        PMP region 27 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG26_L
      description: >
        PMP region 26 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG26_A
      description: >
        PMP region 26 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG26_X
      description: >
        PMP region 26 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG26_W
      description: >
        PMP region 26 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG26_R
      description: >
        PMP region 26 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG25_L
      description: >
        PMP region 25 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG25_A
      description: >
        PMP region 25 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG25_X
      description: >
        PMP region 25 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG25_W
      description: >
        PMP region 25 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG25_R
      description: >
        PMP region 25 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG24_L
      description: >
        PMP region 24 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG24_A
      description: >
        PMP region 24 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG24_X
      description: >
        PMP region 24 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG24_W
      description: >
        PMP region 24 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG24_R
      description: >
        PMP region 24 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 32), 1, [[[
- csr: pmpcfg7
  description: >
    Physical memory protection configuration
  address: 0x3a7
  privilege_mode: M
  rv32:
    - field_name: PMPCFG31_L
      description: >
        PMP region 31 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG31_A
      description: >
        PMP region 31 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG31_X
      description: >
        PMP region 31 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG31_W
      description: >
        PMP region 31 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG31_R
      description: >
        PMP region 31 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG30_L
      description: >
        PMP region 30 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG30_A
      description: >
        PMP region 30 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG30_X
      description: >
        PMP region 30 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG30_W
      description: >
        PMP region 30 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG30_R
      description: >
        PMP region 30 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG29_L
      description: >
        PMP region 29 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG29_A
      description: >
        PMP region 29 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG29_X
      description: >
        PMP region 29 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG29_W
      description: >
        PMP region 29 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG29_R
      description: >
        PMP region 29 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG28_L
      description: >
        PMP region 28 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG28_A
      description: >
        PMP region 28 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG28_X
      description: >
        PMP region 28 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG28_W
      description: >
        PMP region 28 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG28_R
      description: >
        PMP region 28 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 36), 1, [[[
- csr: pmpcfg8
  description: >
    Physical memory protection configuration
  address: 0x3a8
  privilege_mode: M
  rv32:
    - field_name: PMPCFG35_L
      description: >
        PMP region 35 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG35_A
      description: >
        PMP region 35 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG35_X
      description: >
        PMP region 35 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG35_W
      description: >
        PMP region 35 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG35_R
      description: >
        PMP region 35 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG34_L
      description: >
        PMP region 34 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG34_A
      description: >
        PMP region 34 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG34_X
      description: >
        PMP region 34 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG34_W
      description: >
        PMP region 34 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG34_R
      description: >
        PMP region 34 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG33_L
      description: >
        PMP region 33 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG33_A
      description: >
        PMP region 33 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG33_X
      description: >
        PMP region 33 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG33_W
      description: >
        PMP region 33 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG33_R
      description: >
        PMP region 33 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG32_L
      description: >
        PMP region 32 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG32_A
      description: >
        PMP region 32 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG32_X
      description: >
        PMP region 32 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG32_W
      description: >
        PMP region 32 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG32_R
      description: >
        PMP region 32 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 40), 1, [[[
- csr: pmpcfg9
  description: >
    Physical memory protection configuration
  address: 0x3a9
  privilege_mode: M
  rv32:
    - field_name: PMPCFG39_L
      description: >
        PMP region 39 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG39_A
      description: >
        PMP region 39 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG39_X
      description: >
        PMP region 39 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG39_W
      description: >
        PMP region 39 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG39_R
      description: >
        PMP region 39 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG38_L
      description: >
        PMP region 38 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG38_A
      description: >
        PMP region 38 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG38_X
      description: >
        PMP region 38 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG38_W
      description: >
        PMP region 38 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG38_R
      description: >
        PMP region 38 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG37_L
      description: >
        PMP region 37 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG37_A
      description: >
        PMP region 37 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG37_X
      description: >
        PMP region 37 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG37_W
      description: >
        PMP region 37 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG37_R
      description: >
        PMP region 37 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG36_L
      description: >
        PMP region 36 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG36_A
      description: >
        PMP region 36 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG36_X
      description: >
        PMP region 36 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG36_W
      description: >
        PMP region 36 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG36_R
      description: >
        PMP region 36 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 44), 1, [[[
- csr: pmpcfg10
  description: >
    Physical memory protection configuration
  address: 0x3aa
  privilege_mode: M
  rv32:
    - field_name: PMPCFG43_L
      description: >
        PMP region 43 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG43_A
      description: >
        PMP region 43 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG43_X
      description: >
        PMP region 43 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG43_W
      description: >
        PMP region 43 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG43_R
      description: >
        PMP region 43 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG42_L
      description: >
        PMP region 42 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG42_A
      description: >
        PMP region 42 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG42_X
      description: >
        PMP region 42 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG42_W
      description: >
        PMP region 42 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG42_R
      description: >
        PMP region 42 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG41_L
      description: >
        PMP region 41 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG41_A
      description: >
        PMP region 41 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG41_X
      description: >
        PMP region 41 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG41_W
      description: >
        PMP region 41 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG41_R
      description: >
        PMP region 41 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG40_L
      description: >
        PMP region 40 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG40_A
      description: >
        PMP region 40 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG40_X
      description: >
        PMP region 40 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG40_W
      description: >
        PMP region 40 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG40_R
      description: >
        PMP region 40 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 48), 1, [[[
- csr: pmpcfg11
  description: >
    Physical memory protection configuration
  address: 0x3ab
  privilege_mode: M
  rv32:
    - field_name: PMPCFG47_L
      description: >
        PMP region 47 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG47_A
      description: >
        PMP region 47 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG47_X
      description: >
        PMP region 47 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG47_W
      description: >
        PMP region 47 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG47_R
      description: >
        PMP region 47 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG46_L
      description: >
        PMP region 46 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG46_A
      description: >
        PMP region 46 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG46_X
      description: >
        PMP region 46 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG46_W
      description: >
        PMP region 46 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG46_R
      description: >
        PMP region 46 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG45_L
      description: >
        PMP region 45 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG45_A
      description: >
        PMP region 45 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG45_X
      description: >
        PMP region 45 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG45_W
      description: >
        PMP region 45 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG45_R
      description: >
        PMP region 45 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG44_L
      description: >
        PMP region 44 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG44_A
      description: >
        PMP region 44 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG44_X
      description: >
        PMP region 44 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG44_W
      description: >
        PMP region 44 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG44_R
      description: >
        PMP region 44 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 52), 1, [[[
- csr: pmpcfg12
  description: >
    Physical memory protection configuration
  address: 0x3ac
  privilege_mode: M
  rv32:
    - field_name: PMPCFG51_L
      description: >
        PMP region 51 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG51_A
      description: >
        PMP region 51 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG51_X
      description: >
        PMP region 51 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG51_W
      description: >
        PMP region 51 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG51_R
      description: >
        PMP region 51 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG50_L
      description: >
        PMP region 50 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG50_A
      description: >
        PMP region 50 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG50_X
      description: >
        PMP region 50 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG50_W
      description: >
        PMP region 50 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG50_R
      description: >
        PMP region 50 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG49_L
      description: >
        PMP region 49 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG49_A
      description: >
        PMP region 49 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG49_X
      description: >
        PMP region 49 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG49_W
      description: >
        PMP region 49 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG49_R
      description: >
        PMP region 49 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG48_L
      description: >
        PMP region 48 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG48_A
      description: >
        PMP region 48 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG48_X
      description: >
        PMP region 48 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG48_W
      description: >
        PMP region 48 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG48_R
      description: >
        PMP region 48 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 56), 1, [[[
- csr: pmpcfg13
  description: >
    Physical memory protection configuration
  address: 0x3ad
  privilege_mode: M
  rv32:
    - field_name: PMPCFG55_L
      description: >
        PMP region 55 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG55_A
      description: >
        PMP region 55 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG55_X
      description: >
        PMP region 55 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG55_W
      description: >
        PMP region 55 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG55_R
      description: >
        PMP region 55 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG54_L
      description: >
        PMP region 54 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG54_A
      description: >
        PMP region 54 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG54_X
      description: >
        PMP region 54 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG54_W
      description: >
        PMP region 54 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG54_R
      description: >
        PMP region 54 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG53_L
      description: >
        PMP region 53 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG53_A
      description: >
        PMP region 53 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG53_X
      description: >
        PMP region 53 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG53_W
      description: >
        PMP region 53 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG53_R
      description: >
        PMP region 53 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG52_L
      description: >
        PMP region 52 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG52_A
      description: >
        PMP region 52 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG52_X
      description: >
        PMP region 52 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG52_W
      description: >
        PMP region 52 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG52_R
      description: >
        PMP region 52 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 60), 1, [[[
- csr: pmpcfg14
  description: >
    Physical memory protection configuration
  address: 0x3ae
  privilege_mode: M
  rv32:
    - field_name: PMPCFG59_L
      description: >
        PMP region 59 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG59_A
      description: >
        PMP region 59 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG59_X
      description: >
        PMP region 59 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG59_W
      description: >
        PMP region 59 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG59_R
      description: >
        PMP region 59 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG58_L
      description: >
        PMP region 58 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG58_A
      description: >
        PMP region 58 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG58_X
      description: >
        PMP region 58 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG58_W
      description: >
        PMP region 58 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG58_R
      description: >
        PMP region 58 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG57_L
      description: >
        PMP region 57 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG57_A
      description: >
        PMP region 57 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG57_X
      description: >
        PMP region 57 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG57_W
      description: >
        PMP region 57 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG57_R
      description: >
        PMP region 57 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG56_L
      description: >
        PMP region 56 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG56_A
      description: >
        PMP region 56 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG56_X
      description: >
        PMP region 56 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG56_W
      description: >
        PMP region 56 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG56_R
      description: >
        PMP region 56 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 64), 1, [[[
- csr: pmpcfg15
  description: >
    Physical memory protection configuration
  address: 0x3af
  privilege_mode: M
  rv32:
    - field_name: PMPCFG63_L
      description: >
        PMP region 63 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 31
      lsb: 31
    - field_name: RESERVED_30_29
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 30
      lsb: 29
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG63_A
      description: >
        PMP region 63 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 28
      lsb: 27
    - field_name: PMPCFG63_X
      description: >
        PMP region 63 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 26
      lsb: 26
    - field_name: PMPCFG63_W
      description: >
        PMP region 63 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 25
      lsb: 25
    - field_name: PMPCFG63_R
      description: >
        PMP region 63 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 24
      lsb: 24
    - field_name: PMPCFG62_L
      description: >
        PMP region 62 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 23
      lsb: 23
    - field_name: RESERVED_22_21
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 22
      lsb: 21
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG62_A
      description: >
        PMP region 62 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 20
      lsb: 19
    - field_name: PMPCFG62_X
      description: >
        PMP region 62 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 18
      lsb: 18
    - field_name: PMPCFG62_W
      description: >
        PMP region 62 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 17
      lsb: 17
    - field_name: PMPCFG62_R
      description: >
        PMP region 62 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 16
      lsb: 16
    - field_name: PMPCFG61_L
      description: >
        PMP region 61 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 15
      lsb: 15
    - field_name: RESERVED_14_13
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 14
      lsb: 13
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG61_A
      description: >
        PMP region 61 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 12
      lsb: 11
    - field_name: PMPCFG61_X
      description: >
        PMP region 61 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 10
      lsb: 10
    - field_name: PMPCFG61_W
      description: >
        PMP region 61 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 9
      lsb: 9
    - field_name: PMPCFG61_R
      description: >
        PMP region 61 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 8
      lsb: 8
    - field_name: PMPCFG60_L
      description: >
        PMP region 60 Lock
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 7
      lsb: 7
    - field_name: RESERVED_6_5
      description: >
        Always return zero
      type: WARL
      reset_val: 0
      msb: 6
      lsb: 5
      warl_legalize: |
        val_out = 0
    - field_name: PMPCFG60_A
      description: >
        PMP region 60 mode
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 4
      lsb: 3
    - field_name: PMPCFG60_X
      description: >
        PMP region 60 execute permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 2
      lsb: 2
    - field_name: PMPCFG60_W
      description: >
        PMP region 60 write permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 1
      lsb: 1
    - field_name: PMPCFG60_R
      description: >
        PMP region 60 read permission
      type: WARL
      reset_val: 0  # Note: Based on PMPNCFG_DEFAULT
      msb: 0
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 1), 1, [[[
- csr: pmpaddr0
  description: >
    Physical memory address configuration
  address: 0x3b0
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 2), 1, [[[
- csr: pmpaddr1
  description: >
    Physical memory address configuration
  address: 0x3b1
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 3), 1, [[[
- csr: pmpaddr2
  description: >
    Physical memory address configuration
  address: 0x3b2
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 4), 1, [[[
- csr: pmpaddr3
  description: >
    Physical memory address configuration
  address: 0x3b3
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 5), 1, [[[
- csr: pmpaddr4
  description: >
    Physical memory address configuration
  address: 0x3b4
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 6), 1, [[[
- csr: pmpaddr5
  description: >
    Physical memory address configuration
  address: 0x3b5
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 7), 1, [[[
- csr: pmpaddr6
  description: >
    Physical memory address configuration
  address: 0x3b6
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 8), 1, [[[
- csr: pmpaddr7
  description: >
    Physical memory address configuration
  address: 0x3b7
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 9), 1, [[[
- csr: pmpaddr8
  description: >
    Physical memory address configuration
  address: 0x3b8
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 10), 1, [[[
- csr: pmpaddr9
  description: >
    Physical memory address configuration
  address: 0x3b9
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 11), 1, [[[
- csr: pmpaddr10
  description: >
    Physical memory address configuration
  address: 0x3ba
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 12), 1, [[[
- csr: pmpaddr11
  description: >
    Physical memory address configuration
  address: 0x3bb
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 13), 1, [[[
- csr: pmpaddr12
  description: >
    Physical memory address configuration
  address: 0x3bc
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 14), 1, [[[
- csr: pmpaddr13
  description: >
    Physical memory address configuration
  address: 0x3bd
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 15), 1, [[[
- csr: pmpaddr14
  description: >
    Physical memory address configuration
  address: 0x3be
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 16), 1, [[[
- csr: pmpaddr15
  description: >
    Physical memory address configuration
  address: 0x3bf
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 17), 1, [[[
- csr: pmpaddr16
  description: >
    Physical memory address configuration
  address: 0x3c0
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 18), 1, [[[
- csr: pmpaddr17
  description: >
    Physical memory address configuration
  address: 0x3c1
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 19), 1, [[[
- csr: pmpaddr18
  description: >
    Physical memory address configuration
  address: 0x3c2
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 20), 1, [[[
- csr: pmpaddr19
  description: >
    Physical memory address configuration
  address: 0x3c3
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 21), 1, [[[
- csr: pmpaddr20
  description: >
    Physical memory address configuration
  address: 0x3c4
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 22), 1, [[[
- csr: pmpaddr21
  description: >
    Physical memory address configuration
  address: 0x3c5
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 23), 1, [[[
- csr: pmpaddr22
  description: >
    Physical memory address configuration
  address: 0x3c6
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 24), 1, [[[
- csr: pmpaddr23
  description: >
    Physical memory address configuration
  address: 0x3c7
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 25), 1, [[[
- csr: pmpaddr24
  description: >
    Physical memory address configuration
  address: 0x3c8
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 26), 1, [[[
- csr: pmpaddr25
  description: >
    Physical memory address configuration
  address: 0x3c9
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 27), 1, [[[
- csr: pmpaddr26
  description: >
    Physical memory address configuration
  address: 0x3ca
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 28), 1, [[[
- csr: pmpaddr27
  description: >
    Physical memory address configuration
  address: 0x3cb
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 29), 1, [[[
- csr: pmpaddr28
  description: >
    Physical memory address configuration
  address: 0x3cc
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 30), 1, [[[
- csr: pmpaddr29
  description: >
    Physical memory address configuration
  address: 0x3cd
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 31), 1, [[[
- csr: pmpaddr30
  description: >
    Physical memory address configuration
  address: 0x3ce
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 32), 1, [[[
- csr: pmpaddr31
  description: >
    Physical memory address configuration
  address: 0x3cf
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 33), 1, [[[
- csr: pmpaddr32
  description: >
    Physical memory address configuration
  address: 0x3d0
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 34), 1, [[[
- csr: pmpaddr33
  description: >
    Physical memory address configuration
  address: 0x3d1
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 35), 1, [[[
- csr: pmpaddr34
  description: >
    Physical memory address configuration
  address: 0x3d2
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 36), 1, [[[
- csr: pmpaddr35
  description: >
    Physical memory address configuration
  address: 0x3d3
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 37), 1, [[[
- csr: pmpaddr36
  description: >
    Physical memory address configuration
  address: 0x3d4
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 38), 1, [[[
- csr: pmpaddr37
  description: >
    Physical memory address configuration
  address: 0x3d5
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 39), 1, [[[
- csr: pmpaddr38
  description: >
    Physical memory address configuration
  address: 0x3d6
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 40), 1, [[[
- csr: pmpaddr39
  description: >
    Physical memory address configuration
  address: 0x3d7
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 41), 1, [[[
- csr: pmpaddr40
  description: >
    Physical memory address configuration
  address: 0x3d8
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 42), 1, [[[
- csr: pmpaddr41
  description: >
    Physical memory address configuration
  address: 0x3d9
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 43), 1, [[[
- csr: pmpaddr42
  description: >
    Physical memory address configuration
  address: 0x3da
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 44), 1, [[[
- csr: pmpaddr43
  description: >
    Physical memory address configuration
  address: 0x3db
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 45), 1, [[[
- csr: pmpaddr44
  description: >
    Physical memory address configuration
  address: 0x3dc
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 46), 1, [[[
- csr: pmpaddr45
  description: >
    Physical memory address configuration
  address: 0x3dd
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 47), 1, [[[
- csr: pmpaddr46
  description: >
    Physical memory address configuration
  address: 0x3de
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 48), 1, [[[
- csr: pmpaddr47
  description: >
    Physical memory address configuration
  address: 0x3df
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 49), 1, [[[
- csr: pmpaddr48
  description: >
    Physical memory address configuration
  address: 0x3e0
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 50), 1, [[[
- csr: pmpaddr49
  description: >
    Physical memory address configuration
  address: 0x3e1
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 51), 1, [[[
- csr: pmpaddr50
  description: >
    Physical memory address configuration
  address: 0x3e2
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 52), 1, [[[
- csr: pmpaddr51
  description: >
    Physical memory address configuration
  address: 0x3e3
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 53), 1, [[[
- csr: pmpaddr52
  description: >
    Physical memory address configuration
  address: 0x3e4
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 54), 1, [[[
- csr: pmpaddr53
  description: >
    Physical memory address configuration
  address: 0x3e5
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 55), 1, [[[
- csr: pmpaddr54
  description: >
    Physical memory address configuration
  address: 0x3e6
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 56), 1, [[[
- csr: pmpaddr55
  description: >
    Physical memory address configuration
  address: 0x3e7
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 57), 1, [[[
- csr: pmpaddr56
  description: >
    Physical memory address configuration
  address: 0x3e8
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 58), 1, [[[
- csr: pmpaddr57
  description: >
    Physical memory address configuration
  address: 0x3e9
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 59), 1, [[[
- csr: pmpaddr58
  description: >
    Physical memory address configuration
  address: 0x3ea
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 60), 1, [[[
- csr: pmpaddr59
  description: >
    Physical memory address configuration
  address: 0x3eb
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 61), 1, [[[
- csr: pmpaddr60
  description: >
    Physical memory address configuration
  address: 0x3ec
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 62), 1, [[[
- csr: pmpaddr61
  description: >
    Physical memory address configuration
  address: 0x3ed
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 63), 1, [[[
- csr: pmpaddr62
  description: >
    Physical memory address configuration
  address: 0x3ee
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])

ifelse(eval(PMP_NUM_REGIONS >= 64), 1, [[[
- csr: pmpaddr63
  description: >
    Physical memory address configuration
  address: 0x3ef
  privilege_mode: M
  rv32:
    - field_name: ADDRESS_33_2
      description: >
        PMP address register
      type: WARL
      reset_val: 0  # Note: Based on its default value
      msb: 31
      lsb: 0
]]])
