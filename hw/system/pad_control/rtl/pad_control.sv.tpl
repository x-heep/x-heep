// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

<%!
    from x_heep_gen.pads.pin import PinDigital
%>
<%
    attribute_bits = xheep.get_padring().attributes.get("bits")
    attribute_resval = xheep.get_padring().attributes.get("resval")
    any_muxed_pads = xheep.get_padring().num_muxed_pads() > 0
%>

module pad_control #(
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,
    % if not (any_muxed_pads or attribute_bits != None):
        /* verilator lint_off UNUSED */
    % endif
    parameter NUM_PAD = 1
) (

    % if not (any_muxed_pads or attribute_bits != None):
        /* verilator lint_off UNUSED */
    % endif
    input logic clk_i,
    % if not (any_muxed_pads or attribute_bits != None):
        /* verilator lint_off UNUSED */
    % endif
    input logic rst_ni,

    // Bus Interface
    % if not (any_muxed_pads or attribute_bits != None):
        /* verilator lint_off UNUSED */
    % endif
    input  reg_req_t reg_req_i,
    % if not (any_muxed_pads or attribute_bits != None):
        /* verilator lint_off UNDRIVEN */
    % endif
    output reg_rsp_t reg_rsp_o${"," if any_muxed_pads or attribute_bits != None else ""}
    % if attribute_bits != None:
        output logic [NUM_PAD-1:0][${attribute_bits}] pad_attributes_o${"," if any_muxed_pads > 0 else ""}
    % endif
    % if any_muxed_pads > 0:
        output logic [NUM_PAD-1:0][${xheep.get_padring().get_muxed_pad_select_width()-1}:0] pad_muxes_o
    % endif
);

% if any_muxed_pads or attribute_bits != None:

  import core_v_mini_mcu_pkg::*;

  import pad_control_reg_pkg::*;

  pad_control_reg2hw_t reg2hw;

  pad_control_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) pad_control_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg_req_i,
      .reg_rsp_o,
      .reg2hw,
      .devmode_i(1'b1)
  );
% endif

% if attribute_bits != None:
    % for pad in xheep.get_padring().pad_list:
        % if pad.pins and isinstance(pad.pins[0], PinDigital):
            % if pad.attributes.get("constant_attribute"):
                assign pad_attributes_o[PAD_${pad.name.upper()}] = ${int(attribute_resval, 16)};
            % else:
                assign pad_attributes_o[PAD_${pad.name.upper()}] = reg2hw.pad_attribute_${pad.name.lower()}.q;
            % endif
        % endif
    % endfor
% endif

% for pad in xheep.get_padring().pad_list:
    % if len(pad.pins) > 1:
        assign pad_muxes_o[PAD_${pad.name.upper()}] = $unsigned(reg2hw.pad_mux_${pad.name.lower()}.q);
    % endif
% endfor

endmodule : pad_control
