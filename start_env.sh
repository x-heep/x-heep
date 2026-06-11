#!/usr/bin/env bash



# BEFORE FIRST USE

# mkdir tools 
# cd tools 
# wget https://buildbot.embecosm.com/job/corev-gcc-rocky8/48/artifact/corev-openhw-gcc-rocky8-20240530.tar.gz
# tar -xzvf corev-openhw-gcc-rocky8-20240530.tar.gz 
# rm *.tar.gz
# mv corev-openhw-gcc-rocky8-20240530 risc-v
# cd ..


# install miniforge "opensource conda"
# add cmake to conda dependencies in util/conda_environment.yml
# make sure the directory where  you git clone x-heep has execution rights. for example in Document (nfs4_setfacl -s A::OWNER@:rwaDxtTnNcCy Document)

# make conda CMAKE_POLICY_VERSION_MINIMUM=3.5 # NOT NEEDED ?????
 

this_script_dir=$(realpath "$(dirname "$0")")

# usage: source start_env.sh
CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate core-v-mini-mcu

oss_cad_suit_topdir_abs=/softs/oss-cad-suite/2026-03-16/
PATH="$oss_cad_suit_topdir_abs/bin:$PATH"
PATH="/softs/verilator/v5.040/bin:$PATH"
PATH="/softs/verible/latest/bin:$PATH"


export XILINX_VIVADO="/softs/xilinx/vivado/2023.1_lin64/"
export XILINXD_LICENSE_FILE=17003@edalicsrv.epfl.ch
PATH="$XILINX_VIVADO/bin:/edadk_repo/softs/xilinx/DocNav:$PATH"

export PATH

export RISCV_XHEEP="$this_script_dir/../tools/risc-v"

module load siemens/questa_sim/2025.1 # load questasim module # comment if not needed
