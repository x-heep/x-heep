<%!
    from memory_ss.memory_ss import MemorySS
    from memory_ss.ram_bank import Bank
%>

<%
    margin       = 10.0
    size_2048x64 = [784.48, 626.7]
    current_x    = 500.0
    current_y    = 500.0
%>

## One 2048x64 macro per 16 KiB of bank (see sram_wrapper_ihp_sg13g2.sv), all in one row.
## ponytail: single row, wrap into more rows if large banks overflow the die.
% for bank in xheep.memory_ss().iter_ram_banks():
% for i in range(bank.size() // 16384):
core_v_mini_mcu_i.memory_subsystem_i.ram${bank.map_idx()-1}_i.gen_2048x64.gen_macro[${i}].sram_inst ${current_x} ${current_y} S
<% current_x += size_2048x64[0] + margin %>
% endfor
% endfor
