#!/usr/bin/env python3

# USAGE :
# python3 rtl/spi_subsystem_gen.py tpl_file out_file [axi] [obi] [w25_ctr]

import sys
from mako.template import Template


# -------------------------------------------------------
# Peripheral mapping from CLI flags
# -------------------------------------------------------

FLAG_TO_PERIPHERAL = {
    "axi": "axi_spi",
    "obi": "obi_spi",
    "w25_ctr": "w25q128jw_controller"
}


# -------------------------------------------------------
# Minimal mock objects to satisfy the template
# -------------------------------------------------------

class PeripheralDomain:

    def __init__(self, peripherals):
        self.peripherals = peripherals

    def contains_peripheral(self, name):
        return name in self.peripherals


class XHeep:

    def __init__(self, peripherals):
        self.domain = PeripheralDomain(peripherals)

    def get_base_peripheral_domain(self):
        return self.domain


# -------------------------------------------------------
# Main
# -------------------------------------------------------

def main():

    if len(sys.argv) < 3:
        print("Usage: python spi_subsystem_gen.py input.tpl output.sv [axi] [obi] [w25_ctr]")
        sys.exit(1)

    tpl_file = sys.argv[1]
    out_file = sys.argv[2]

    flags = sys.argv[3:]

    peripherals = []

    for flag in flags:
        if flag not in FLAG_TO_PERIPHERAL:
            print(f"Unknown flag: {flag}")
            sys.exit(1)
        peripherals.append(FLAG_TO_PERIPHERAL[flag])

    xheep = XHeep(peripherals)

    template = Template(filename=tpl_file)
    rendered = template.render(xheep=xheep)

    with open(out_file, "w") as f:
        f.write(rendered)

    print(f"Generated {out_file}")
    print(f"Enabled peripherals: {peripherals}")


if __name__ == "__main__":
    main()