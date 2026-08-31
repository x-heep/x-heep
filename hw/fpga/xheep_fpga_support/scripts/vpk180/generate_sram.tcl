
set ipName xilinx_mem_gen_8192

create_ip \
  -name emb_mem_gen \
  -vendor xilinx.com \
  -library ip \
  -version 1.0 \
  -module_name $ipName

set_property -dict [list \
  CONFIG.USE_MEMORY_BLOCK {Stand_Alone} \
  CONFIG.MEMORY_TYPE {Single_Port_RAM} \
  CONFIG.ENABLE_32BIT_ADDRESS {false} \
  CONFIG.MEMORY_DEPTH {8192} \
  CONFIG.WRITE_DATA_WIDTH_A {32} \
  CONFIG.READ_DATA_WIDTH_A {32} \
  CONFIG.ENABLE_BYTE_WRITES_A {true} \
  CONFIG.BYTE_WRITE_WIDTH_A {8} \
  CONFIG.WRITE_MODE_A {WRITE_FIRST} \
  CONFIG.READ_LATENCY_A {1} \
  CONFIG.ALGORITHM {Minimum_Area} \
  CONFIG.MEMORY_PRIMITIVE {AUTO} \
] [get_ips $ipName]

#
generate_target {instantiation_template} [get_ips $ipName]

#export_ip_user_files -of_objects [get_ips $ipName] -no_script -sync -force -quiet

create_ip_run [get_ips $ipName]



launch_runs -jobs 8  xilinx_mem_gen_8192_synth_1

wait_on_run xilinx_mem_gen_8192_synth_1




set ipName xilinx_mem_gen_llc_cache

create_ip \
  -name emb_mem_gen \
  -vendor xilinx.com \
  -library ip \
  -version 1.0 \
  -module_name $ipName

set_property -dict [list \
  CONFIG.USE_MEMORY_BLOCK {Stand_Alone} \
  CONFIG.MEMORY_TYPE {Single_Port_RAM} \
  CONFIG.ENABLE_32BIT_ADDRESS {false} \
  CONFIG.MEMORY_DEPTH {4096} \
  CONFIG.WRITE_DATA_WIDTH_A {32} \
  CONFIG.READ_DATA_WIDTH_A {32} \
  CONFIG.ENABLE_BYTE_WRITES_A {true} \
  CONFIG.BYTE_WRITE_WIDTH_A {8} \
  CONFIG.WRITE_MODE_A {WRITE_FIRST} \
  CONFIG.READ_LATENCY_A {1} \
  CONFIG.ALGORITHM {Minimum_Area} \
  CONFIG.MEMORY_PRIMITIVE {AUTO} \
] [get_ips $ipName]

#
generate_target {instantiation_template} [get_ips $ipName]

#export_ip_user_files -of_objects [get_ips $ipName] -no_script -sync -force -quiet

create_ip_run [get_ips $ipName]

launch_runs -jobs 8 xilinx_mem_gen_llc_cache_synth_1

wait_on_run xilinx_mem_gen_llc_cache_synth_1

