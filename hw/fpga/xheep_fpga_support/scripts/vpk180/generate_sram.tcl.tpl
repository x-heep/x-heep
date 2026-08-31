% for num_words in xheep.memory_ss().iter_bank_numwords():

set ipName xilinx_mem_gen_${num_words}

create_ip \\

  -name emb_mem_gen \\
  
  -vendor xilinx.com \\
  
  -library ip \\
  
  -version 1.0 \\
  
  -module_name $ipName

set_property -dict [list \\

  CONFIG.USE_MEMORY_BLOCK {Stand_Alone} \\
  
  CONFIG.MEMORY_TYPE {Single_Port_RAM} \\
  
  CONFIG.ENABLE_32BIT_ADDRESS {false} \\
  
  CONFIG.MEMORY_DEPTH {${num_words}} \\
  
  CONFIG.WRITE_DATA_WIDTH_A {32} \\
  
  CONFIG.READ_DATA_WIDTH_A {32} \\
  
  CONFIG.ENABLE_BYTE_WRITES_A {true} \\
  
  CONFIG.BYTE_WRITE_WIDTH_A {8} \\
  
  CONFIG.WRITE_MODE_A {WRITE_FIRST} \\
  
  CONFIG.READ_LATENCY_A {1} \\
  
  CONFIG.ALGORITHM {Minimum_Area} \\
  
  CONFIG.MEMORY_PRIMITIVE {AUTO} \\
  
] [get_ips $ipName]

#
generate_target {instantiation_template} [get_ips $ipName]

#export_ip_user_files -of_objects [get_ips $ipName] -no_script -sync -force -quiet

create_ip_run [get_ips $ipName]

% endfor

<%ips = ""
for num_words in xheep.memory_ss().iter_bank_numwords():
    ips += f" xilinx_mem_gen_{num_words}_synth_1"%>
launch_runs -jobs 8 ${ips}

% for num_words in xheep.memory_ss().iter_bank_numwords():
wait_on_run xilinx_mem_gen_${num_words}_synth_1
% endfor

<%
  base_peripheral_domain = xheep.get_base_peripheral_domain()
  if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):
    w25 = xheep.get_base_peripheral_domain().get_W25Q128JW_controller()
    cache = w25.get_cache()
  else:
    cache = 0
%>

% if cache:

set ipName xilinx_mem_gen_llc_cache

create_ip \\

  -name emb_mem_gen \\

  -vendor xilinx.com \\

  -library ip \\

  -version 1.0 \\

  -module_name $ipName

set_property -dict [list \\

  CONFIG.USE_MEMORY_BLOCK {Stand_Alone} \\

  CONFIG.MEMORY_TYPE {Single_Port_RAM} \\

  CONFIG.ENABLE_32BIT_ADDRESS {false} \\

  CONFIG.MEMORY_DEPTH {4096} \\

  CONFIG.WRITE_DATA_WIDTH_A {32} \\

  CONFIG.READ_DATA_WIDTH_A {32} \\

  CONFIG.ENABLE_BYTE_WRITES_A {true} \\

  CONFIG.BYTE_WRITE_WIDTH_A {8} \\

  CONFIG.WRITE_MODE_A {WRITE_FIRST} \\

  CONFIG.READ_LATENCY_A {1} \\

  CONFIG.ALGORITHM {Minimum_Area} \\

  CONFIG.MEMORY_PRIMITIVE {AUTO} \\

] [get_ips $ipName]

#
generate_target {instantiation_template} [get_ips $ipName]

#export_ip_user_files -of_objects [get_ips $ipName] -no_script -sync -force -quiet

create_ip_run [get_ips $ipName]

launch_runs -jobs 4 xilinx_mem_gen_llc_cache_synth_1

wait_on_run xilinx_mem_gen_llc_cache_synth_1

% endif