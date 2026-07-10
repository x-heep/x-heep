<%!
    from memory_ss.memory_ss import MemorySS
    from memory_ss.ram_bank import Bank
%>

<%
    size_8192x32 = [1520.16,618.3]
    current_x    = 500.0
    current_y    = 500.0
%>

% for bank in xheep.memory_ss().iter_ram_banks():
% if bank.size() == 32768:
x_heep_system_inst.core_v_mini_mcu_i.memory_subsystem_i.ram${bank.map_idx()-1}_i.genblk2.sram_inst ${current_x} ${current_y} S
<% current_x += size_8192x32[0] %>
% endif
% endfor
