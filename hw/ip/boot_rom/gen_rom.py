#!/usr/bin/env python3

from string import Template
import argparse
import os.path
import sys
import binascii


parser = argparse.ArgumentParser(description='Convert binary file to verilog rom')
parser.add_argument('filename', metavar='filename', nargs=1,
                   help='filename of input binary')

args = parser.parse_args()
file = args.filename[0];

# check that file exists
if not os.path.isfile(file):
    print("File {} does not exist.".format(filename))
    sys.exit(1)

filename = os.path.splitext(file)[0]

license = """\
/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File: $filename.v
 *
 * Description: Auto-generated bootrom
 */

// Auto-generated code
"""

module = """\
module $filename #(
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic
) (
  input  reg_req_t     reg_req_i,
  output reg_rsp_t     reg_rsp_o
);
  import core_v_mini_mcu_pkg::*;

  localparam int unsigned RomSize = $size;

  logic [RomSize-1:0][31:0] mem;
  assign mem = {
$content
  };

  logic [$$clog2(core_v_mini_mcu_pkg::BOOTROM_SIZE)-1-2:0] word_addr;
  logic [$$clog2(RomSize)-1:0] rom_addr;

  assign word_addr = reg_req_i.addr[$$clog2(core_v_mini_mcu_pkg::BOOTROM_SIZE)-1:2];
  assign rom_addr  = word_addr[$$clog2(RomSize)-1:0];

  assign reg_rsp_o.error = 1'b0;
  assign reg_rsp_o.ready = 1'b1;

  always_comb begin
    if (word_addr > (RomSize-1)) begin
      reg_rsp_o.rdata = '0;
    end else begin
      reg_rsp_o.rdata = mem[rom_addr];
    end
  end

endmodule
"""

c_var = """\
// Auto-generated code

const int reset_vec_size = $size;

uint32_t reset_vec[reset_vec_size] = {
$content
};
"""

def read_bin():

    with open(filename + ".img", 'rb') as f:
        rom = bytes.hex(f.read())
        rom = list(map(''.join, zip(rom[::2], rom[1::2])))

    # align to 32 bit
    align = (int((len(rom) + 3) / 4 )) * 4;

    for i in range(len(rom), align):
        rom.append("00")

    return rom

rom = read_bin()

""" Generate C header file for simulator
"""
with open(filename + ".h", "w") as f:
    rom_str = ""
    # process in junks of 32 bit (4 byte)
    for i in range(0, int(len(rom)/4)):
        rom_str += "    0x" + "".join(rom[i*4:i*4+4][::-1]) + ",\n"

    # remove the trailing comma
    rom_str = rom_str[:-2]

    s = Template(c_var)
    f.write(s.substitute(filename=filename, size=int(len(rom)/4), content=rom_str))

    f.close()

""" Generate SystemVerilog bootcode for FPGA and ASIC
"""
with open(filename + ".sv", "w") as f:
    rom_str = ""
    # process in junks of 32 bit (4 byte)
    for i in reversed(range(int(len(rom)/4))):
        rom_str += "    32'h" + "".join(rom[i*4:i*4+4][::-1]) + ",\n"

    # remove the trailing comma
    rom_str = rom_str[:-2]

    f.write(license)
    s = Template(module)
    f.write(s.substitute(filename=filename, size=int(len(rom)/4), content=rom_str))
