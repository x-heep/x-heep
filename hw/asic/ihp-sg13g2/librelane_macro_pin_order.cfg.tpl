<%!
    from pads.pin import Input, Output, Inout
    from pads.pad import Pad
    from pads.floorplan import Side
%>

#N
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.TOP:
    continue

has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)

if not (has_input_pin or has_output_pin or has_inout_pin):
  continue
pin0_name = pad.pins[0].rtl_name()
%>\
% if has_inout_pin or (has_input_pin and has_output_pin):
${pin0_name}i
${pin0_name}oe
${pin0_name}o
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor

hart_id_i\[.*
xheep_instance_id_i\[.*

intr_vector_ext_i\[.*
intr_ext_peripheral_i.*

ext_xbar_master_req_i\[.*
ext_xbar_master_resp_o\[.*

ext_core_instr_req_o\[.*
ext_core_instr_resp_i\[.*
ext_core_data_req_o\[.*
ext_core_data_resp_i\[.*
ext_debug_master_req_o\[.*
ext_debug_master_resp_i\[.*

#W
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.LEFT:
    continue

has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)

if not (has_input_pin or has_output_pin or has_inout_pin):
  continue
pin0_name = pad.pins[0].rtl_name()
%>\
% if has_inout_pin or (has_input_pin and has_output_pin):
${pin0_name}i
${pin0_name}oe
${pin0_name}o
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor

ext_dma_read_req_o\[.*
ext_dma_read_resp_i\[.*
ext_dma_write_req_o\[.*
ext_dma_write_resp_i\[.*
ext_dma_addr_req_o\[.*
ext_dma_addr_resp_i\[.*

hw_fifo_req_o\[.*
hw_fifo_resp_i\[.*

ext_ao_peripheral_req_i\[.*
ext_ao_peripheral_resp_o\[.*

ext_peripheral_slave_req_o\[.*
ext_peripheral_slave_resp_i\[.*

#S
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.BOTTOM:
    continue

has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)

if not (has_input_pin or has_output_pin or has_inout_pin):
  continue
pin0_name = pad.pins[0].rtl_name()
%>\
% if has_inout_pin or (has_input_pin and has_output_pin):
${pin0_name}i
${pin0_name}oe
${pin0_name}o
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor

cpu_subsystem_powergate_switch_no.*
cpu_subsystem_powergate_switch_ack_ni.*
peripheral_subsystem_powergate_switch_no.*
peripheral_subsystem_powergate_switch_ack_ni.*

% if xheep.get_base_peripheral_domain().get_power_manager().get_external_domains() != 0:
external_subsystem_powergate_switch_no\[.*
external_subsystem_powergate_switch_ack_ni\[.*
external_subsystem_powergate_iso_no\[.*
external_subsystem_rst_no\[.*
external_ram_banks_set_retentive_no\[.*
external_subsystem_clkgate_en_no\[.*
% else:
external_subsystem_powergate_switch_no.*
external_subsystem_powergate_switch_ack_ni.*
external_subsystem_powergate_iso_no.*
external_subsystem_rst_no.*
external_ram_banks_set_retentive_no.*
external_subsystem_clkgate_en_no.*
% endif

exit_value_o\[.*

ext_dma_slot_tx_i\[.*
ext_dma_slot_rx_i\[.*
ext_dma_stop_i\[.*
hw_fifo_done_i\[.*

#E
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.RIGHT:
    continue

has_input_pin = any(isinstance(pin, Input) for pin in pad.pins)
has_output_pin = any(isinstance(pin, Output) for pin in pad.pins)
has_inout_pin = any(isinstance(pin, Inout) for pin in pad.pins)

if not (has_input_pin or has_output_pin or has_inout_pin):
  continue
pin0_name = pad.pins[0].rtl_name()
%>\
% if has_inout_pin or (has_input_pin and has_output_pin):
${pin0_name}i
${pin0_name}oe
${pin0_name}o
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor

xif_compressed_valid.*
xif_compressed_ready.*
xif_compressed_req\[.*
xif_compressed_resp\[.*

xif_issue_valid.*
xif_issue_ready.*
xif_issue_req\[.*
xif_issue_resp\[.*

xif_commit_valid.*
xif_commit\[.*

xif_mem_valid.*
xif_mem_ready.*
xif_mem_req\[.*
xif_mem_resp\[.*

xif_mem_result_valid.*
xif_mem_result\[.*

xif_result_valid.*
xif_result_ready.*
xif_result\[.*

dma_done_o\[.*
