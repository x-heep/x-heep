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
${pin0_name}io
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor

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
${pin0_name}io
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor

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
${pin0_name}io
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor

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
${pin0_name}io
% elif has_input_pin:
${pin0_name}i
% elif has_output_pin:
${pin0_name}o
% endif
% endfor
