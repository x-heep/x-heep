# Setup

There are two ways of setting up X-HEEP. You can either use the provided Docker image or install and configure the environment manually.

## Docker setup

A Docker image containing all the required software dependencies is available on [github-packages](https://ghcr.io/x-heep/x-heep/x-heep-toolchain:latest).

It is only required to [install Docker](https://docs.docker.com/engine/install/), pull the image and run the container. The pull and run steps are wrapped in dedicated `makefile` targets that you can access from the top-level directory as:
```bash
make -C util/docker docker-pull # pull the latest available X-HEEP image
make -C util/docker docker-run #  mount the current X-HEEP clone to '/workspace/x-heep'
```

In particular, the `docker-pull` target tries to infer your X-HEEP revision using `git describe` and pull the corresponding image. If it fails, it defaults to the `latest` image available, that is the one used by the upstream `main` branch.

The Docker image provides built-in shortcuts (as Bash functions) to select among the available software compilation flows, as an alternative to providing the `COMPILER`, `COMPILER_PREFIX`, and `ARCH` variable when compiling an application with `make app`. Here is a brief description of the shortcut defined in `util/docker/env.sh`:

| Shortcut | Description | Configuration |
| -------- | ----------- | ------------- |
| `init_corev` | Use the Embecosm CORE-V toolchain with PULP extension | `COMPILER=gcc`<br>`COMPILER_PREFIX=riscv32-corev-`<br>`ARCH=rv32imc_zicsr_zifencei_xcvhwlp_xcvmem_xcvmac_xcvbi_xcvalu_xcvsimd_xcvbitmanip` |
| `init_gcc` | Use the GCC toolchain | `COMPILER=gcc`<br>`COMPILER_PREFIX=riscv32-unknown-`<br>`ARCH=rv32imc_zicsr` |
| `init_clang` | Use the LLVM/Clang toolchain | `COMPILER=clang`<br>`COMPILER_PREFIX=riscv32-unknown-`<br>`ARCH=rv32imc_zicsr` |

For example, if you want to compile and link the `hello_world` application using LLVM/Clang:
```bash
init_clang
make app PROJECT=hello_world
```

The Docker setup has certain limitations. For example, the following are not supported:

- Simulation with Questasim and VCS, synthesis with Design Compiler. Licenses are required to use these tools, so they are not installed in the container.

- OpenRoad flow is not installed in the container, so it is not possible to run the related make commands.

- Synthesis with Vivado could be possible, but currently is untested.

## Manual setup

### 1. OS requirements

To use `X-HEEP`, first you will need to install some OS dependencies.

#### Linux
The following command `apt` command should install every required package (tested on an Ubuntu 22.04 distribution):
```bash
sudo apt install autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libslirp-dev help2man perl make g++ libfl2 libfl-dev zlibc zlib1g zlib1g-dev ccache mold libgoogle-perftools-dev numactl libelf-dev
```

Errors occurring when installing the following packages may be ignored:
```bash
libfl2 libfl-dev zlibc zlib1g zlib1g-dev
```

Links for the packages relative to each software can also be found under the corresponding section of this guide. In general, make sure to have a look at the [Check system requirements](https://opentitan.org/book/doc/getting_started/index.html) section of the OpenTitan documentation.

The script `util/install_tools_and_conda_env.sh` can be used to install the required dependencies and set up the Conda environment on Linux. It uses `apt` to install the required packages and then sets up a Conda environment with the necessary Python dependencies. It also installs the CORE-V toolchain, Verilator and the oss-cad-suite. You can select the versions of the tools you want to install by changing the corresponding variables at the beginning of the script. After running the script, you can activate the environment with `source util/start_env.sh`.

#### MacOS
If you are using a MacOS with M series chip or intel chip, you can use the `util/install_tools_and_conda_env.zsh` script to install the required dependencies and set up the Conda environment. The script uses [Homebrew (make sure you have it installed)](https://brew.sh/) to install the required packages and then sets up a [Conda environment](https://conda-forge.org/download/) with the necessary Python dependencies. It also installs the CORE-V toolchain, Verilator and the oss-cad-suite. You can select the versions of the tools you want to install by changing the corresponding variables at the beginning of the script. After running the script, you can activate the environment with `source util/start_env.zsh`.

```zsh
./util/install_tools_and_conda_env.zsh
```

then to use the environment:

```zsh
source util/start_env.zsh
```


### 2. Python

We rely on either (a) `miniconda`, or (b) `virtual environment` environment.

Choose between `2.a` or `2.b` to setup your environment.

#### 2.a Miniconda

Install [Miniconda](https://www.anaconda.com/docs/getting-started/miniconda/install#quickstart-install-instructions) Python 3.8 version by downloading an older version and selecting the latest `py38` version [here](https://repo.anaconda.com/miniconda/). Then, create the Conda environment from inside the x-heep folder:

```bash
make conda
```

You need to do it only the first time, then just activate the environment every time you work with `X-HEEP` as

```bash
conda activate core-v-mini-mcu
```
or put the command directly in the `~/.bashrc` file.

#### 2.b Virtual Environment

```{note}
The Python environment has only been tested on Python 3.8.
```

Install the Python virtual environment just as:

```bash
make venv
```

You need to do it only the first time, then just activate the environment every time you work with `X-HEEP` as

```bash
source .venv/bin/activate
```

### 3. Install the RISC-V Compiler:

```{warning}
The RISC-V toolchain environment variable name has changed. Use `RISCV_XHEEP` instead of `RISCV` to avoid conflicts with other projects. If you previously exported `RISCV` for X-HEEP, update your shell initialization files (e.g., `~/.bashrc`, `~/.zshrc`) or environment modules to export `RISCV_XHEEP` and remove or adjust any old `RISCV` definitions accordingly.
```

X-HEEP supports the [CORE-V toolchain from Embecosm](https://embecosm.com/downloads/tool-chain-downloads/#core-v-top-of-tree-compilers), but you can also use the standard RISC-V GCC or CLANG toolchains.

You can download and install the CORE-V toolchain by following the instructions on the [Embecosm download page](https://embecosm.com/downloads/tool-chain-downloads/#core-v-top-of-tree-compilers). This is the recommended option since it includes support for the PULP extensions that can be enabled in X-HEEP and is the default toolchain for the provided compilation flow.

Optionally, you can also build and install the standard RISC-V GCC toolchain from source.

The RISC-V compiler requires the [following packages](https://github.com/riscv-collab/riscv-gnu-toolchain) to be installed (Check [OS requirements](#1-os-requirements) for Ubuntu distribution). The GitHub page contains instructions for other linux distributions.

Then the installation can proceed with the following commands :
```
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
git checkout 2023.01.03
./configure --prefix=/home/$USER/tools/riscv --with-abi=ilp32 --with-arch=rv32imc --with-cmodel=medlow
make -j $(nproc)
```

If you target `RVE` systems (i.e. using only RISC-V registers from `x0-x15`), then use instead:

```
./configure --prefix=/home/$USER/tools/riscv --with-abi=ilp32e --with-arch=rv32emc --with-cmodel=medlow
make newlib
```

where the `abi` flag has changed to `ilp32e` and arc to `rv32emc`.
This has been tested with a different compiler version (`4e7952b5f6c106c01b2e1c056476687e1390105d`, which is why make newlib instead of just make.)

You need to set the `RISCV_XHEEP` environment variable like this:

```
export RISCV_XHEEP=/home/$USER/tools/riscv
```
Also consider adding it to your `~/.bashrc` or equivalent so that it's set automatically in the future. 

Optionally you can also compile and link with Clang/LLVM instead of GCC. For that you must install the Clang compiler (and the LLVM LLD linker) into the same `RISCV_XHEEP` path. The binaries of GCC and Clang do not collide so you can have both residing in the same `RISCV_XHEEP` directory. For this you can set the `-DCMAKE_INSTALL_PREFIX` cmake variable to `$RISCV_XHEEP` when building LLVM. This can be accomplished by doing the following:

```bash
INSTALL_DIR=${RISCV_XHEEP}
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
git checkout llvmorg-19.1.4
cmake -S llvm -B build -G "Ninja" -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DLLVM_TARGETS_TO_BUILD="RISCV" -DLLVM_USE_LINKER=lld
cmake --build build --target install # or ninja -C build install
```

By default, when compiling an application with Clang, X-HEEP will link with the LLD linker.
If you want to use the GCC linker, you will need to pass to the `make app` target the
`CLANG_LINKER_USE_LD=1` option.

### 4. Install Verilator:

X-HEEP supports Verilator version 5.040, which requires the [following packages](https://verilator.org/guide/latest/install.html) to be installed (Check [OS requirements](#1-os-requirements) for Ubuntu distribution). The [documentation](https://verilator.org/guide/latest/install.html) page contains instructions for other linux distributions. 

```{warning}
Backward compatibility with Verilator 4.210 is currently maintained, yet _this is very likely to change_ in future releases, so we strongly suggest against using it. Also, Verilator 4.210 _requires GCC older than 12.0_, so make sure to configure your environment accordingly if you choose to use it anyway.
```

To proceed with the installation, use the following command:

```bash
export VERILATOR_VERSION=5.040

git clone https://github.com/verilator/verilator.git
cd verilator
git checkout v$VERILATOR_VERSION

autoconf
./configure --prefix=/home/$USER/tools/verilator/$VERILATOR_VERSION
make
make install
```

After installation you need to add `/home/$USER/tools/verilator/$VERILATOR_VERSION/bin` to your `PATH` environment variable. Also consider adding it to your `~/.bashrc` or equivalent environment initialization script so that it's on the `PATH` in the future, like this:

```
export VERILATOR_VERSION=5.040
export PATH=/home/$USER/tools/verilator/$VERILATOR_VERSION/bin:$PATH
```

In general, have a look at the [Install Verilator](https://opentitan.org/book/doc/getting_started/setup_verilator.html) section of the OpenTitan documentation.

If you want to see the waveforms generated by the Verilator simulation (FST format), install GTKWAVE:

```
sudo apt install libcanberra-gtk-module libcanberra-gtk3-module
sudo apt-get install -y gtkwave
```

### 5. Install Verible

Files are formatted with Verible. We use version v0.0-4023-gc1271a00

```
export VERIBLE_VERSION=v0.0-4023-gc1271a00
wget https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz
tar -xf verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz
mkdir -p /home/$USER/tools/verible/${VERIBLE_VERSION}/
mv verible-${VERIBLE_VERSION}/* /home/$USER/tools/verible/${VERIBLE_VERSION}/
rm verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz
rm -r verible-${VERIBLE_VERSION}
```

After installation you need to add `/home/$USER/tools/verible/${VERIBLE_VERSION}/bin` to your `PATH` environment variable. Also consider adding it to your `~/.bashrc` or equivalent so that it's on the `PATH` in the future, like this:

```
export VERIBLE_VERSION=v0.0-4023-gc1271a00
export PATH=/home/$USER/tools/verible/${VERIBLE_VERSION}/bin:$PATH
```

In general, have a look at the [Install Verible](https://opentitan.org/book/doc/getting_started/index.html#step-7a-install-verible-optional) section of the OpenTitan documentation (the version referenced there is _not_ the one we use in X-HEEP).
