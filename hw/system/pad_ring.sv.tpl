// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%
  attribute_bits = xheep.get_padring().attributes.get("bits")
  num_attribute_bits = (
            int(attribute_bits.split(":")[0]) - int(attribute_bits.split(":")[1]) + 1
            if attribute_bits != None
            else 0
        )
%>

module pad_ring (
% for pin in xheep.get_padring().pins_with_pads():
    inout wire ${pin.rtl_name()}_io,
    % if isinstance(pin, (Input, Inout)):
        output logic ${pin.rtl_name()}_o,
    % endif
    % if pin.type in [PinType.DIGITAL_OUTPUT, PinType.DIGITAL_INOUT]:
        input logic ${pin.rtl_name()}_i,
    % endif
    % if pin.type in [PinType.DIGITAL_INOUT]:
        input logic ${pin.rtl_name()}_oe_i,
    % endif
% endfor

% if xheep.get_padring().attributes.get("bits") != None:
    input logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][${xheep.get_padring().attributes["bits"]}] pad_attributes_i
% else:
    // here just for simplicity
    /* verilator lint_off UNUSED */
    input logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][0:0] pad_attributes_i
% endif

);

% for pad in xheep.get_padring().pad_list:
${pad.pad_ring_instance}

pad_cell_input #(
      .PADATTR(0)
  ) pad_clk_i (
      .pad_in_i(1'b0),
      .pad_oe_i(1'b0),
      .pad_out_o(clk_o),
      .pad_io(clk_io),
      .pad_attributes_i('0)
  );

% endfor

% for pad in xheep.get_padring().pad_list:
    % if pad.type == PinType.DIGITAL_INPUT:
        pad_cell_input #(
            .PADATTR(${num_attribute_bits})
            % if pad.side != None:
                , .SIDE(core_v_mini_mcu_pkg::${pad.side})
            % endif
        ) ${pad.cell_name} (
            .pad_in_i(1'b0),
            .pad_oe_i(1'b0),
            .pad_out_o(${pad.rtl_name()}_o),
            .pad_io(${pad.rtl_name()}_io),
            % if pad.has_attribute:
            .pad_attributes_i(
                pad_attributes_i[
                    core_v_mini_mcu_pkg::${pad.localparam}
                ]
            )
            % else:
            .pad_attributes_i('0)
            % endif
        );
    % elif pad.type == PinType.DIGITAL_OUTPUT:

    % elif pad.type == PinType.DIGITAL_INOUT:

    % endif  # ToDo_padspy: implement other pad types
% endfor

% for external_pad in xheep.get_padring().external_pad_list:
${external_pad.pad_ring_instance}
% endfor

endmodule  // pad_ring
