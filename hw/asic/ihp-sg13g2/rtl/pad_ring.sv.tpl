// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// MODIFICATION NOTICE:
// This file has been modified by Nathan Chandanson on 31/07/2026.
// Brief description of changes: Add the power pins/pads for ASIC flow.
//

<%
    if impl_target != "asic_ihp":
        return STOP_RENDERING
%>
<%!
    from pads.pin import Input, Output, Inout, PinDigital, Asignal
    from pad_definition import PinVdd, PinVss, PinIoVdd, PinIoVss, PinPower
%>

<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    num_attribute_bits = (
                int(attribute_bits.split(":")[0]) - int(attribute_bits.split(":")[1]) + 1
                if attribute_bits != None
                else 0
            )
    analog_signal_pads = [ pad for pad in xheep.get_padring().pad_list if any(isinstance(pin, Asignal) for pin in pad.pins) ] 
    power_pads = [ pad for pad in xheep.get_padring().pad_list if any(isinstance(pin, PinPower) for pin in pad.pins) ] 
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

    `ifdef USE_POWER_PINS
    inout wire vdd_io,
    inout wire vss_io,
    inout wire iovdd_io,
    inout wire iovss_io,
    `endif

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
    if has_input_pin and not has_output_pin and not has_inout_pin:
        pad_in_i = "1\'b0"
        pad_oe_i = "1\'b0"
    elif has_output_pin and not has_input_pin and not has_inout_pin:
        pad_oe_i = "1\'b1"
        pad_out_o = ""
    %>
    ${pad.iocell.rtl_wrapper} #(
        .PADATTR(${num_attribute_bits})
    ) u_pad_${pad.name} (
        `ifdef USE_POWER_PINS
        .iovdd(iovdd_io),
        .iovss(iovss_io),
        .vdd(vdd_io),
        .vss(vss_io),
        `endif
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

% if len(power_pads) > 0:
        // POWER PADS
        % for pad in power_pads:
            <%
            has_vdd = any(isinstance(pin, PinVdd) for pad in power_pads for pin in pad.pins)
            has_vss = any(isinstance(pin, PinVss) for pad in power_pads for pin in pad.pins)
            has_iovdd = any(isinstance(pin, PinIoVdd) for pad in power_pads for pin in pad.pins)
            has_iovss = any(isinstance(pin, PinIoVss) for pad in power_pads for pin in pad.pins)

            pad_vdd_io = "vdd_io"
            pad_vss_io = "vss_io"
            pad_iovdd_io = "iovdd_io"
            pad_iovss_io = "iovss_io"
            %>
            ${pad.iocell.rtl_wrapper} u_pad_${pad.name}(
                `ifdef USE_POWER_PINS
                .iovdd(${pad_iovdd_io}),
                .iovss(${pad_iovss_io}),
                .vdd(${pad_vdd_io}),
                .vss(${pad_vss_io})
                `endif
            );
        % endfor
% endif

endmodule //pad_ring
