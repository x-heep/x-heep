#!/usr/bin/env python3

from string import Template
import argparse
import os.path
import sys


parser = argparse.ArgumentParser(description='Convert binary file to a verilog OBI ROM')
parser.add_argument('filename', metavar='filename', nargs=1,
                   help='filename of input binary')

args = parser.parse_args()
file = args.filename[0]

if not os.path.isfile(file):
    print("File {} does not exist.".format(file))
    sys.exit(1)

filename = os.path.splitext(file)[0]

# The module is always named ext_rom and always written to rtl/ext_rom.sv,
# regardless of the input image's basename - this is what example_ext_rom.core
# expects (files_rtl: rtl/ext_rom.sv).
module_name = "ext_rom"
out_dir = os.path.join(os.path.dirname(os.path.abspath(file)), "rtl")
os.makedirs(out_dir, exist_ok=True)
out_sv_path = os.path.join(out_dir, module_name + ".sv")

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
 * Description: Auto-generated external ROM example
 */

// Auto-generated code
"""

module = """\
module $filename (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        req_i,
    input  logic        we_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic [ 3:0] be_i,
    output logic        gnt_o,
    output logic [31:0] rdata_o,
    output logic        rvalid_o
);

  localparam int unsigned RomSize = $size;
  // $$clog2(1) == 0, which would make word_addr a negative-width vector.
  localparam int unsigned AddrWidth = (RomSize > 1) ? $$clog2(RomSize) : 1;

  logic [RomSize-1:0][31:0] mem;
  assign mem = {
$content
  };

  logic [AddrWidth-1:0] word_addr;
  assign word_addr = addr_i[AddrWidth+1:2];

  assign gnt_o = req_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid_o <= 1'b0;
    end else begin
      rvalid_o <= req_i;
    end
  end

  always_ff @(posedge clk_i) begin
    if (req_i) begin
      if (32'(word_addr) > (RomSize-1)) begin
        rdata_o <= '0;
      end else begin
        rdata_o <= mem[word_addr];
      end
    end
  end

endmodule
"""


def read_bin():
    with open(filename + ".img", 'rb') as f:
        rom = bytes.hex(f.read())
        rom = list(map(''.join, zip(rom[::2], rom[1::2])))

    # align to 32 bit
    align = (int((len(rom) + 3) / 4)) * 4

    for i in range(len(rom), align):
        rom.append("00")

    return rom


rom = read_bin()

""" Generate SystemVerilog ROM for simulation
"""
with open(out_sv_path, "w") as f:
    rom_str = ""
    # process in chunks of 32 bit (4 byte), little-endian words, MSB-first array literal
    for i in reversed(range(int(len(rom) / 4))):
        rom_str += "    32'h" + "".join(rom[i * 4:i * 4 + 4][::-1]) + ",\n"

    # remove the trailing comma
    rom_str = rom_str[:-2]

    f.write(license)
    s = Template(module)
    f.write(s.substitute(filename=module_name, size=int(len(rom) / 4), content=rom_str))

print("Wrote {}".format(out_sv_path))
