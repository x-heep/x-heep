// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%!
    from x_heep_gen.pads.pin import Input, Output, Inout
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    num_attribute_bits = (
                int(attribute_bits.split(":")[0]) - int(attribute_bits.split(":")[1]) + 1
                if attribute_bits != None
                else 0
            )
%>

module pad_ring (
    % for pin in xheep.get_padring().get_connected_main_pins():
        inout wire ${pin.rtl_name()}io,
        % if isinstance(pin, (Input, Inout)):
            output logic ${pin.rtl_name()}o,
        % endif
        % if isinstance(pin, (Output, Inout)):
            input logic ${pin.rtl_name()}i,
        % endif
        % if isinstance(pin, Inout):
            input logic ${pin.rtl_name()}oe_i,
        % endif
    % endfor

    % if attribute_bits != None:
        input logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][${attribute_bits}] pad_attributes_i
    % else:
        // here just for simplicity
        /* verilator lint_off UNUSED */
        input logic [core_v_mini_mcu_pkg::NUM_PAD-1:0][0:0] pad_attributes_i
    % endif
);

% for pad in xheep.get_padring().pad_list:
    <%
        # Check all pins in the pad
        has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
        has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
        has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)
        
        # Determine pad type
        if has_inout_pin or (has_input_pin and has_output_pin):
            pad_type = 'inout'
        elif has_input_pin:
            pad_type = 'input'
        elif has_output_pin:
            pad_type = 'output'
        else:
            pad_type = None
    %>
    % if pad_type == 'input':
        pad_cell_input #(
            .PADATTR(${num_attribute_bits})
            % if pad.side != None:
                , .SIDE(core_v_mini_mcu_pkg::${pad.side})
            % endif
## // ToDo_padspy: should this be pad_${pad.rtl_name()}i like in pins?
        ) pad_${pad.name}_i (
            .pad_in_i(1'b0),
            .pad_oe_i(1'b0),
            .pad_out_o(${pad.name}_o),
            .pad_io(${pad.name}_io),
            % if attribute_bits != None:
                .pad_attributes_i(pad_attributes_i[core_v_mini_mcu_pkg::PAD_${pad.name.upper()}])
            % else:
                .pad_attributes_i('0)
            % endif
        );
    % elif pad_type == 'output':
        pad_cell_output #(
            .PADATTR(${num_attribute_bits})
            % if pad.side != None:
                , .SIDE(core_v_mini_mcu_pkg::${pad.side})
            % endif
## // ToDo_padspy: should this be pad_${pad.rtl_name()}i like in pins?
        ) pad_${pad.name}_i (
            .pad_in_i(${pad.name}_i),
            .pad_oe_i(1'b1),
            .pad_out_o(),
            .pad_io(${pad.name}_io),
            % if attribute_bits != None:
                .pad_attributes_i(pad_attributes_i[core_v_mini_mcu_pkg::PAD_${pad.name.upper()}])
            % else:
                .pad_attributes_i('0)
            % endif
        );
    % elif pad_type == 'inout':
        pad_cell_inout #(
            .PADATTR(${num_attribute_bits})
            % if pad.side != None:
                , .SIDE(core_v_mini_mcu_pkg::${pad.side})
            % endif
## // ToDo_padspy: should this be pad_${pad.rtl_name()}i like in pins?
        ) pad_${pad.name}_i (
            .pad_in_i(${pad.name}_i),
            .pad_oe_i(${pad.name}_oe_i),
            .pad_out_o(${pad.name}_o),
            .pad_io(${pad.name}_io),
            % if attribute_bits != None:
                .pad_attributes_i(pad_attributes_i[core_v_mini_mcu_pkg::PAD_${pad.name.upper()}])
            % else:
                .pad_attributes_i('0)
            % endif
        );
    % endif
% endfor

endmodule  // pad_ring
