- Bit Manipulation

 - CQ 23349, approved

   - ../rtl/cv32e40x_alu.sv - Contains commented out shifter based on
     https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_shifter/rvb_shifter.v 

 - CQ 23398, Reference code from https://github.com/riscv/riscv-bitmanip

   Git hash b2fd3b8d7d9e43054358b15b1d77011936addb65 (main-history branch)

   rvb_bextdep.v - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_bextdep/rvb_bextdep.v
   rvb_bitcnt.v  - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_bitcnt/rvb_bitcnt.v
   rvb_bmatxor.v - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_bmatxor/rvb_bmatxor.v
   rvb_clmul.v   - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_clmul/rvb_clmul.v
   rvb_crc.v     - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_crc/rvb_crc.v
   rvb_full.v    - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_full/rvb_full.v
   rvb_shifter.v - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_shifter/rvb_shifter.v
   rvb_simple.v  - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_simple/rvb_simple.v
   rvb_zbb32.v   - https://github.com/riscv/riscv-bitmanip/blob/main-history/verilog/rvb_zbb32/rvb_zbb32.v

 - Code from https://github.com/chipsalliance/Cores-SweRV-EL2

   Git hash 7045b803cab825bc3bb3dbca0cb019e55098acc4

   - el2_exu_mul_ctl.sv (CQ 23537, approved) - Swerv bit manipulation circuitry - https://github.com/chipsalliance/Cores-SweRV-EL2/blob/master/design/exu/el2_exu_mul_ctl.sv
   - el2_exu.sv (CQ 23532, approved) - Swerv execute unit/stage
   - el2_exu_alu_ctl.sv (CQ 23532, approved) - ALU of Swerv containing bit manipulation instructions
   - el2_exu_div_ctl.sv (CQ 23532, approved) - Divider circuit(s) of Swerv
   - beh_lib.sv (CQ 23532, approved) - Library with adders, ECC encoding, ECC decoding, etc.

- PMP (from https://github.com/lowRISC/ibex.git, 93a76b390081b6b3b6cea2671c469f9293b998f2)

 - CQ 23401, approved

 - ibex_pmp.sv - Core of the Physical Memory Protection unit
 - ibex_cs_registers.sv - Programming interface of PMP
 - ibex_pkg.sv - Helper types, constants, etc. for Physical Memory Protection unit 
 
- Random instructions (from https://github.com/lowRISC/ibex.git, 93a76b390081b6b3b6cea2671c469f9293b998f2)

 - CQ 23465, approved

 - prim_secded_39_32_enc.sv - ECC encoder for the register file
 - prim_secded_39_32_dec.sv - ECC decoder for the register file
 - ibex_dummy_instr.sv - Dummy instruction generator
 - ibex_if_stage.sv Dummy instruction generator instantiation
 - ibex_register_file_ff.sv - Register file
 - ibex_core.sv - Core (showing ECC encoder/decoder instantiations)

- Branch prediction (from https://github.com/chipsalliance/Cores-SweRV-EL2, 7045b803cab825bc3bb3dbca0cb019e55098acc4)

 - el2_ifu_bp_ctl.sv (CQ 23538, approved) - Branch predictor - https://github.com/chipsalliance/Cores-SweRV-EL2/blob/master/design/ifu/el2_ifu_bp_ctl.sv
 - el2_ifu.sv (CQ 23538, approved) - Fetch unit instantiating the branch predictor - https://github.com/chipsalliance/Cores-SweRV-EL2/blob/master/design/ifu/el2_ifu.sv
