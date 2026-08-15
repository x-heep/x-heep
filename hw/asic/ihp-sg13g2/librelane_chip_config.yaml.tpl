<%
    if impl_target != "asic_ihp":
        return STOP_RENDERING
%>
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

# Bondpad
# WARNING: You need to put the bondpads directly in the build folder
# You can find it at (https://github.com/IHP-GmbH/ihp-sg13g2-librelane-template/tree/main/ip)
PAD_BONDPAD_NAME: bondpad_70x70_novias
EXTRA_GDS:
- dir::ip/bondpad_70x70_novias/gds/bondpad_70x70_novias.gds
EXTRA_LEFS:
- dir::ip/bondpad_70x70_novias/lef/bondpad_70x70_novias.lef
IGNORE_DISCONNECTED_MODULES:
- bondpad_70x70_novias

# Power settings
PDN_CORE_RING: True
PDN_CORE_RING_CONNECT_TO_PADS: True     # Connect the pads to the core ring
PDN_ENABLE_PINS: False                  # We only need the PDK power pins
VDD_NETS:
- VDD
GND_NETS:
- VSS
# Connect SRAMS to PDN
PDN_MACRO_CONNECTIONS:
% for bank in xheep.memory_ss().iter_ram_banks():
- "core_v_mini_mcu_i.memory_subsystem_i.ram${bank.map_idx()-1}_i.genblk2.sram_inst VDD VSS VDDARRAY! VSS!"
- "core_v_mini_mcu_i.memory_subsystem_i.ram${bank.map_idx()-1}_i.genblk2.sram_inst VDD VSS VDD! VSS!"
% endfor

OPENROAD_THREADS: 32

# Pads
PAD_NORTH: [
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.TOP:
    continue

pin0_name = pad.pins[0].rtl_name()
if pin0_name[-1] == 'n':
    pin0_name = pin0_name[0:-1]
%>\
  % if pad.iocell.rtl_wrapper == "pad_cell_inout":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_inout",
  % elif pad.iocell.rtl_wrapper == "pad_cell_input":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_input",
  % elif pad.iocell.rtl_wrapper == "pad_cell_output":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_output",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vss",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovss",
  % endif
% endfor
]

PAD_WEST: [
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.LEFT:
    continue

pin0_name = pad.pins[0].rtl_name()
if pin0_name[-1] == 'n':
    pin0_name = pin0_name[0:-1]
%>\
  % if pad.iocell.rtl_wrapper == "pad_cell_inout":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_inout",
  % elif pad.iocell.rtl_wrapper == "pad_cell_input":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_input",
  % elif pad.iocell.rtl_wrapper == "pad_cell_output":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_output",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vss",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovss",
  % endif
% endfor
]

PAD_SOUTH: [
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.BOTTOM:
    continue

pin0_name = pad.pins[0].rtl_name()
if pin0_name[-1] == 'n':
    pin0_name = pin0_name[0:-1]
%>\
  % if pad.iocell.rtl_wrapper == "pad_cell_inout":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_inout",
  % elif pad.iocell.rtl_wrapper == "pad_cell_input":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_input",
  % elif pad.iocell.rtl_wrapper == "pad_cell_output":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_output",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vss",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovss",
  % endif
% endfor
]

PAD_EAST: [
% for pad in xheep.get_padring().pad_list:
<%
if pad.side != Side.RIGHT:
    continue

pin0_name = pad.pins[0].rtl_name()
if pin0_name[-1] == 'n':
    pin0_name = pin0_name[0:-1]
%>\
  % if pad.iocell.rtl_wrapper == "pad_cell_inout":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_inout",
  % elif pad.iocell.rtl_wrapper == "pad_cell_input":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_input",
  % elif pad.iocell.rtl_wrapper == "pad_cell_output":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_output",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_vss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_vss",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovdd":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovdd",
  % elif pad.iocell.rtl_wrapper == "pad_cell_iovss":
  "pad_ring_i.u_pad_${pin0_name[0:-1]}.pad_cell_iovss",
  % endif
% endfor
]

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
