// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
{ name: "pad_control",
  clock_primary: "clk_i",
  bus_interfaces: [
    { protocol: "reg_iface", direction: "device" }
  ],
  regwidth: "32",
  registers: [

% for pad in xheep.get_padring().pad_list:
  % if len(pad.pins) > 1:
    { name:     "PAD_MUX_${pad.name.upper()}",
      desc:     "Used to mux pad ${pad.name.upper()}",
      resval:   "0x0"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "${(len(pad.pins)-1).bit_length()-1}:0", name: "PAD_MUX_${pad.name.upper()}", desc: "Pad Mux ${pad.name.upper()} Reg" }
      ]
    }
  % endif
% endfor

% if "bits" in xheep.get_padring().attributes:
  % for pad in xheep.get_padring().pad_list:
    % if pad.pins and is_instance(pad.pins[0], PinDigital):
      % if "constant_attribute" not in pad.attributes:
    { name:     "PAD_ATTRIBUTE_${pad.name.upper()}",
      desc:     "${pad.name} Attributes (Pull Up En, Pull Down En, etc. It is technology specific.",
      resval:   "${pad.attributes["constant_attribute"]}"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "${xheep.get_padring().pads_attributes['bits']}", name: "PAD_ATTRIBUTE_${pad.name.upper()}", desc: "Pad Attribute ${pad.name.upper()} Reg" }
      ]
    }
      % endif
    % endif
  % endfor
% endif
   ]
}
