// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

<%!
    from x_heep_gen.pads.pin import PinDigital
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    attribute_resval = xheep.get_padring().attributes.get("resval")
    any_muxed_pads = xheep.get_padring().num_muxed_pads() > 0
%>

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

% if attribute_bits:
  % for pad in xheep.get_padring().pad_list:
    % if pad.pins and isinstance(pad.pins[0], PinDigital):
      % if pad.attributes.get("constant_attribute") != True:
    { name:     "PAD_ATTRIBUTE_${pad.name.upper()}",
      desc:     "${pad.name} Attributes (Pull Up En, Pull Down En, etc. It is technology specific.",
      resval:   "${attribute_resval}"
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "${attribute_bits}", name: "PAD_ATTRIBUTE_${pad.name.upper()}", desc: "Pad Attribute ${pad.name.upper()} Reg" }
      ]
    }
      % endif
    % endif
  % endfor
% endif
   ]
}
