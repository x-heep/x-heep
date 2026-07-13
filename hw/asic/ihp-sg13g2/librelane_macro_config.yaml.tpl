<%!
    from pads.pin import Input, Output, Inout
    from pads.pad import Pad
    from pads.floorplan import Side
    from memory_ss.memory_ss import MemorySS
    from memory_ss.ram_bank import Bank
%>

# SystemVerilog support
USE_SLANG: True
SLANG_ARGUMENTS: ['--allow-use-before-declare', '--keep-hierarchy']

# Power settings
PDN_CORE_RING: True
VDD_NETS:
- VDD
GND_NETS:
- VSS
# Connect SRAMS to PDN
PDN_MACRO_CONNECTIONS:
% for bank in xheep.memory_ss().iter_ram_banks():
- "x_heep_system_inst.core_v_mini_mcu_i.memory_subsystem_i.ram${bank.map_idx()-1}_i.genblk2.sram_inst VDD VSS VDDARRAY! VSS!"
- "x_heep_system_inst.core_v_mini_mcu_i.memory_subsystem_i.ram${bank.map_idx()-1}_i.genblk2.sram_inst VDD VSS VDD! VSS!"
% endfor

# SRAM Macros
MACROS:
  RM_IHPSG13_1P_256x32_c2_bm_bist:
    gds:
      - pdk_dir::libs.ref/sg13g2_sram/gds/RM_IHPSG13_1P_256x32_c2_bm_bist.gds
    lef:
      - pdk_dir::libs.ref/sg13g2_sram/lef/RM_IHPSG13_1P_256x32_c2_bm_bist.lef
    lib:
      "*_typ_1p20V_25C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_256x32_c2_bm_bist_typ_1p20V_25C.lib
      "*_fast_1p32V_m40C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_256x32_c2_bm_bist_fast_1p32V_m55C.lib
      "*_slow_1p08V_125C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_256x32_c2_bm_bist_slow_1p08V_125C.lib
  RM_IHPSG13_1P_512x32_c2_bm_bist:
    gds:
      - pdk_dir::libs.ref/sg13g2_sram/gds/RM_IHPSG13_1P_512x32_c2_bm_bist.gds
    lef:
      - pdk_dir::libs.ref/sg13g2_sram/lef/RM_IHPSG13_1P_512x32_c2_bm_bist.lef
    lib:
      "*_typ_1p20V_25C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_512x32_c2_bm_bist_typ_1p20V_25C.lib
      "*_fast_1p32V_m40C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_512x32_c2_bm_bist_fast_1p32V_m55C.lib
      "*_slow_1p08V_125C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_512x32_c2_bm_bist_slow_1p08V_125C.lib
  RM_IHPSG13_1P_1024x32_c2_bm_bist:
    gds:
      - pdk_dir::libs.ref/sg13g2_sram/gds/RM_IHPSG13_1P_1024x32_c2_bm_bist.gds
    lef:
      - pdk_dir::libs.ref/sg13g2_sram/lef/RM_IHPSG13_1P_1024x32_c2_bm_bist.lef
    lib:
      "*_typ_1p20V_25C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_1024x32_c2_bm_bist_typ_1p20V_25C.lib
      "*_fast_1p32V_m40C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_1024x32_c2_bm_bist_fast_1p32V_m55C.lib
      "*_slow_1p08V_125C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_1024x32_c2_bm_bist_slow_1p08V_125C.lib
  RM_IHPSG13_1P_8192x32_c4:
    gds:
      - pdk_dir::libs.ref/sg13g2_sram/gds/RM_IHPSG13_1P_8192x32_c4.gds
    lef:
      - pdk_dir::libs.ref/sg13g2_sram/lef/RM_IHPSG13_1P_8192x32_c4.lef
    lib:
      "*_typ_1p20V_25C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_8192x32_c4_typ_1p20V_25C.lib
      "*_fast_1p32V_m40C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_8192x32_c4_fast_1p32V_m55C.lib
      "*_slow_1p08V_125C":
        - pdk_dir::libs.ref/sg13g2_sram/lib/RM_IHPSG13_1P_8192x32_c4_slow_1p08V_125C.lib
