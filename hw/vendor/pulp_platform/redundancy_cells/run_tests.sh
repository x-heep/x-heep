#!/usr/bin/env bash
# Copyright (c) 2021 ETH Zurich, University of Bologna
#
# Copyright and related rights are licensed under the Solderpad Hardware
# License, Version 0.51 (the "License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
# or agreed to in writing, software, hardware and materials distributed under
# this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.
# 
# Testing script for redundancy cells

set -e

[ ! -z "$VSIM" ] || VSIM=vsim

VSIM_LOGFILE=vsim.log

bender script vsim -t test -t rtl --vlog-arg="-svinputport=compat" -t deprecated > compile.tcl
echo "return 0" >> compile.tcl

$VSIM -c -do 'quit -code [source compile.tcl]' > vcom.log

rm -f $VSIM_LOGFILE

call_vsim() {
  if [ $1 == tb_ecc_sram ]; then
    echo "source test/ecc_sram_fault_injection.tcl; run -all" | $VSIM "$@" >> $VSIM_LOGFILE 2>&1
  else
    echo "run -all" | $VSIM "$@" >> $VSIM_LOGFILE 2>&1
  fi
  echo "  --> $@"
  tail -7 $VSIM_LOGFILE
  echo ""
  tail -1 vsim.log | grep "Errors: 0," > /dev/null
}

call_vsim tb_tmr_voter
call_vsim tb_tmr_voter_fail
call_vsim tb_tmr_voter_detect
call_vsim tb_tmr_word_voter
call_vsim tb_bitwise_tmr_voter
call_vsim tb_bitwise_tmr_voter_fail
call_vsim tb_ecc_sram -voptargs="+acc=nr"
call_vsim -GDataWidth=8 tb_ecc_secded
call_vsim -GDataWidth=16 tb_ecc_secded
call_vsim -GDataWidth=32 tb_ecc_secded
call_vsim -GDataWidth=64 tb_ecc_secded
call_vsim tb_ecc_scrubber
call_vsim tb_voter_macros
call_vsim tb_rel_fifo
