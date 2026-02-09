// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%!
    from x_heep_gen.pads.pin import Input, Output, Inout, PinDigital, Asignal
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    num_attribute_bits = (
                int(attribute_bits.split(":")[0]) - int(attribute_bits.split(":")[1]) + 1
                if attribute_bits != None
                else 0
            )
    analog_signal_pads = [ pad for pad in xheep.get_padring().pad_list if any(isinstance(pin, Asignal) for pin in pad.pins) ] 
%>

module pad_ring (
    % for pad in xheep.get_padring().pad_list:
        <%
        has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
        has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
        has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)

        if not (has_input_pin or has_output_pin or has_inout_pin): 
            continue
        pin0_name = pad.pins[0].rtl_name()
        %>
        % if has_inout_pin or (has_input_pin and has_output_pin):
            input logic ${pin0_name}i,
            input logic ${pin0_name}oe_i,
            output logic ${pin0_name}o,
            inout wire ${pin0_name}io,
        % elif has_input_pin:
            output logic ${pin0_name}o,
            inout wire ${pin0_name}io,
        % elif has_output_pin:
            input logic ${pin0_name}i,
            inout wire ${pin0_name}io,
        % endif
    % endfor
    % if len(analog_signal_pads) > 0:
        `ifdef SYNTHESIS
            % for pad in analog_signal_pads:
                (* dont_touch = "true" *) inout wire ${pad.name.lower()}_io,
            % endfor
        `endif
    %endif

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

    if not (has_input_pin or has_output_pin or has_inout_pin):
        continue

    pin0_name = pad.pins[0].rtl_name()

    # Default pad attributes to be added in the pad instance
    pad_in_i = pin0_name + "i"
    pad_oe_i = pin0_name + "oe_i"
    pad_out_o = pin0_name + "o"
    pad_io = pin0_name + "io"
    pad_attributes_i = f"pad_attributes_i[core_v_mini_mcu_pkg::PAD_{pad.name.upper()}]" if attribute_bits != None else "\'0"

    # Determine pad type and assign specific attributes
    if has_inout_pin or (has_input_pin and has_output_pin):
        pad_type = 'inout'
    elif has_input_pin:
        pad_type = 'input'
        pad_in_i = "1\'b0"
        pad_oe_i = "1\'b0"
    elif has_output_pin:
        pad_type = 'output'
        pad_oe_i = "1\'b1"
        pad_out_o = ""
    else:
        continue
    %>
    pad_cell_${pad_type} #(
        .PADATTR(${num_attribute_bits})
    ) u_pad_${pad.name} (
        .pad_in_i(${pad_in_i}),
        .pad_oe_i(${pad_oe_i}),
        .pad_out_o(${pad_out_o}),
        .pad_io(${pad_io}),
        .pad_attributes_i(${pad_attributes_i})
    );   
% endfor

% if len(analog_signal_pads) > 0:
    `ifdef SYNTHESIS
        // ANALOG PADS
        % for pad in analog_signal_pads:
            ${pad.iocell.rtl_wrapper} pad_${pad.name}( .io(${pad.name.lower()}_io));
        % endfor
    `endif
% endif #len(analog_signal_pads) > 0:

endmodule //pad_ring