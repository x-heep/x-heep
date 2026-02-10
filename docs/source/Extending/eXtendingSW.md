# eXtending software

If X-HEEP is vendorized into your project, you can still have software source files in any directory of your top-level repository and build them using X-HEEP's compilation flow.

## Repository structure

The following is an example repository folder structure focusing on extending the software flow.

    BASE
    ├── sw
    │   ├── applications
    │   │   └── your_app
    │   │       ├── main.c
    │   │       ├── your_app.c
    │   │       ├── your_app.h
    │   │       └── ...
    │   ├── build -> ../hw/vendor/esl_epfl_x_heep/sw/build
    │   ├── device -> ../hw/vendor/esl_epfl_x_heep/sw/device
    │   ├── linker -> ../hw/vendor/esl_epfl_x_heep/sw/linker
    │   └── external
    │       ├── drivers
    │       │   └── your_copro
    │       │   	├── your_copro.c
    │       │   	├── your_copro.h
    │       │   	└── your_copro_defs.h -> ../../../../hw/vendor/your_copro/sw/your_copro_defs.h
    │       └── extensions
    │       │   └── your_copro_x_heep.h
    │       └── lib
    │           └── crt
    │               └── external_crt0.S
    ├── hw
    │   └── vendor
    │       ├── your_copro
    │       ├── esl_epfl_x_heep.vendor.hjson
    │       └── esl_epfl_x_heep
    │           ├── hw
    │           ├── sw
    │           │   ├── applications
    │           │   ├── build
    │           │   ├── device
    │           │   └── ...
    │           ├── Makefile
    │           ├── external.mk
    │           └── ...
    ├── Makefile
    ├── util
    │   └── vendor.py
    └── ...

Where `BASE` is your repository's base directory, `esl_epfl_x_heep` is the vendorized X-HEEP repository and `your_app` is the name of the application you intend to build.

## The /sw/ folder

The `BASE/sw/` folder must comply with X-HEEP's repository structure and therefore include an `applications`, `build`, `device` and `linker` folder.
It is not compulsory for it to be on the `BASE` directory, although this is the default structure that X-HEEP's Makefiles will assume if no other path is specified through the `SOURCE` variable. If you plan to store source files in a different location that the one proposed, just call `make` making the `SOURCE` path explicit.
```
make app PROJECT=your_app SOURCE=<path_to_your_sw_relative_to_x_heep_sw>
```
Consider that, inside this `sw` folder, the same structure than the one proposed is required.

Inside the `applications` folder different projects can be stored (still respecting the `name_of_project/main.c` structure of X-HEEP).
The `build`, `device` and `linker` should be linked with the vendorized folders inside X-HEEP.
In this example that is done from the `BASE` directory as follows:
```
ln -s ../hw/vendor/esl_epfl_x_heep/sw/build sw/build
ln -s ../hw/vendor/esl_epfl_x_heep/sw/device sw/device
ln -s ../hw/vendor/esl_epfl_x_heep/sw/linker sw/linker
```

## The /sw/applications folder

Inside the `sw/applications/` folder you may have different applications that can be built separately. Each application is a directory named after your application, containing one and only one `main.c` file which is built during the compilation process. The folder can contain other source or header files (of any name but `main.c`).

## The /sw/external folder

In the (optional) `external` folder you can add whatever is necessary for software to work with your coprocessor/accelerator. This might include:

* Sources and header files.
* Soft links to folders or files.
* A `lib/crt/` directory with an `exteral_crt0.S` file (will be included inside `BASE/sw/device/lib/crt/crt0.S`).

The external folder or any of its subdirectories cannot contain neither a `device` nor an `applications` folder as it would collide with the respective folders inside `BASE/sw/`. It should also not contain a `main.c` file.

## Embedding binary data into X-HEEP firmware
The [`util/c_gen.py`](../../../util/c_gen.py) script is a versatile utility for converting binary files and NumPy arrays into C header files. This is particularly useful for embedding data directly into the X-HEEP firmware, such as the Firmware for your programmable accelerator or some Python-generated golden results for your application.

The utility can be used in two ways: as a straightforward command-line tool for simple conversions, or as a Python module for more complex and customized header generation.

### Command-Line Usage
For quick conversion of a single binary file (e.g., a compiled firmware blob), the command-line interface is ideal.
```bash
python c_gen.py <header_file> <bin_file> [<src_file> ...]
```

| Argument          | Description|
|-------------------|------------|
| `<header_file>`	| The path and name for the output C header file (e.g., `firmware.h`). |
| `<bin_file>`	    | The path to the input binary file to be converted (e.g., `firmware.bin`). |
| `[<src_file> ...]`| (Optional) One or more paths to C source files. The script will parse these files and copy any `#define` directives into the generated header. |

For example, to convert a compiled peripheral firmware dma_engine.bin into dma_engine.h and include definitions from its source code:
```bash
python c_gen.py sw/external/lib/driver/accel/firmware.h whatever/firmware.bin whatever/main.c
```
This will generate `sw/external/lib/driver/accel/firmware.h` containing the binary data as a `uint32_t` array named `firmware`, along with size macros (e.g, `FIRMWARE_SIZE`) and any macros defined in `whatever/main.c`. The application code can therefore copy this data to the accelerator memory when needed.

### Programmatic Usage (as a Python Module)
For more advanced use cases, you can import the CFileGen class into your Python scripts. This approach is highly recommended for test-bench generation and complex data embedding, as it provides much greater flexibility:
- __Multiple data sources__: add any number of binaries, matrices, or code arrays to an header file.
- __NumPy array conversion__: firectly convert NumPy arrays into C arrays, perfect for test vectors and golden models. The script automatically handles signed-to-unsigned conversion and formats values in hexadecimal.
- __Automatic size macros__: for each array, it automatically generates `_SIZE`, `_ROWS`, and `_COLS` macros.
- __Custom C attributes__: add GCC/Clang attributes (e.g., `__attribute__((section(".data_interleaved")))`) to place arrays in specific memory sections.

For example, here's how you could generate a header file containing both a firmware binary and a NumPy array of test vectors for an accelerator:

```python
import numpy as np
from c_gen import CFileGen

# 1. Create some test data as a NumPy array
# This could be input data for a near-memory accelerator test
test_vectors = np.array([
    [10, -20, 30],
    [40, -50, 60],
    [70, 80, -90]
], dtype=np.int16)

# 2. Instantiate the C code generator
header_gen = CFileGen()

# 3. Add the firmware binary for the accelerator
header_gen.add_binary('accelerator_fw', 'build/accelerator.bin')

# 4. Add the NumPy test vectors as an input matrix
# Let's also place this array in a specific memory section
header_gen.add_attribute('section(".data_interleaved")')
header_gen.add_input_matrix('input_vectors', test_vectors)

# 5. Write the final header file
header_gen.write_header('generated_tests', 'accelerator_test.h')

print("Generated accelerator_test.h successfully!")
```
This script would produce a file named `generated_tests/accelerator_test.h` with content similar to this:

```C
#ifndef ACCELERATOR_TEST_H_
#define ACCELERATOR_TEST_H_

#include <stdint.h>

// Input matrix size
#define INPUT_VECTORS_SIZE 18
#define INPUT_VECTORS_ROWS 3
#define INPUT_VECTORS_COLS 3

// Binary size
// -----------
#define ACCELERATOR_FW_SIZE 4096 // Example size

// Binary files
// ------------
uint32_t accelerator_fw[] = {
    0xDEADBEEF,
    // ... firmware data ...
};

// Input matrices
// --------------
int16_t input_vectors [] __attribute__((section(".data_interleaved"))) = {
    {0x000a, 0xffec, 0x001e},
    {0x0028, 0xffce, 0x003c},
    {0x0046, 0x0050, 0xffa6}
};

#endif // ACCELERATOR_TEST_H_
```

## The BASE/Makefile

The `BASE/Makefile` is your own custom Makefile. You can use it as a bridge to access the Makefile from X-HEEP. To do so, it MUST include the `external.mk` AFTER all your custom rules.


<details>
    <summary>Example of BASE/Makefile</summary>

```Makefile
MAKE     = make
.PHONY: custom
custom:
    @echo Nothing is executed from X-HEEP, as custom is not a target inside X-HEEP.

app:
    @echo This target will do something and then call the one inside X-HEEP.
    $(MAKE) -f $(XHEEP_MAKE) $(MAKECMDGOALS) PROJECT=hello_world SOURCE=.

verilator-build:
    @echo You will not access the verilator-build target from X-HEEP.

export HEEP_DIR = hw/vendor/esl_epfl_x_heep/
XHEEP_MAKE = $(HEEP_DIR)/external.mk
include $(XHEEP_MAKE)
```

- The `custom` rule will not use the X-HEEP Makefile in any way. Make the target a prerequisite of `.PHONY` to prevent X-HEEP's Makefile from attempting to run a non-existent target.
- The `app` rule will perform actions before calling X-HEEP Makefile's `app` rule. In this case, the project and where the source files are to be extracted from is being specified. The `SOURCE=.` argument will set X-HEEP's own `sw/` folder as the directory from which to fetch source files. This is an example of building inner sources from an external directory.
- The `verilator-build` rule will override the X-HEEP Makefile's one.
- Any other target will be passed straight to X-HEEP's Makefile. For example
```sh
make mcu-gen CPU=cv32e40px
```

If you plan to vendorize X-HEEP in a different directory than the one proposed, just update:
```
export HEEP_DIR = <path_to_x_heep_relative_to_this_directory>
```
</details><br>

## Extending the mcu-gen configuration

In your own `Makefile`, you can also extend the `mcu-gen` target to generate a custom MCU configuration for your application, includiing any `.tpl` files you might want to add. To do so, you can add an `mcu-gen` target in your `Makefile` like the following:

<details>
    <summary>Example of Makefile extending mcu-gen</summary>

```Makefile
# Global configuration
ROOT_DIR := $(realpath .)

# X-HEEP configuration
XHEEP_DIR        := $(ROOT_DIR)/hw/vendor/x-heep
X_HEEP_CFG       := $(ROOT_DIR)/config/python_unsupported.hjson
PYTHON_CHEEP_CFG := $(ROOT_DIR)/config/cheep_configs.py
PAD_CFG          ?= $(ROOT_DIR)/config/cheep_pads.py

# CHEEP templated files
# Collects all .tpl files in the project excluding certain directories
CHEEP_GEN_TPLS	:= $(shell find . \( -path './hw/vendor' -o -path './sw/vendor' -o -path './sw/linker' \) -prune -o -name '*.tpl' -print)
# Prefix the paths of the .tpl files with the relative path to X-HEEP to make them accessible from the mcu-gen target in X-HEEP's Makefile
# The HEEP_REL_PATH is defined in the `external.mk` makefile
EXTERNAL_MCU_GEN_TEMPLATES = $(addprefix $(HEEP_REL_PATH)/,$(CHEEP_GEN_TPLS))

## Generate X-HEEP MCU system files
.PHONY: mcu-gen
mcu-gen:
	$(MAKE) -f $(XHEEP_MAKE) mcu-gen \
		X_HEEP_CFG=$(X_HEEP_CFG) \
		PYTHON_X_HEEP_CFG=$(PYTHON_CHEEP_CFG) \
		PADS_CFG=$(PAD_CFG) \
		EXTERNAL_DOMAINS=$(EXTERNAL_DOMAINS) \
		EXTERNAL_MCU_GEN_TEMPLATES="$(EXTERNAL_MCU_GEN_TEMPLATES)"
	@echo "✅ DONE! X-HEEP MCU and CHEEP generated successfully"
```

</details>

## Excluding files from compilation

If you have files that need to be excluded from the GCC compilation flow, you can add them to a directory containing the keyword `exclude`, and/or rename the file to include the keyword `exclude`. 
In the following example, the files marked with ✅ will be compiled, and the ones marked with ❌ will not.

    BASE
    ├── sw
    │   ├── applications
    │   │   └── your_app
    │   │       ├── ✅ main.c      
    │   │       ├── ✅ your_app.c
    │   │       ├──    your_app.h
    │   │       ├── ❌ my_kernel_exclude.c
    │   │       ├──    my_kernel.h
    │   │       └── exclude_files
    │   │           └── ❌ kernel_asm.S

## Makefile help

If you want that the commands `make` or `make help` show the help for your external Makefile, add the following lines before the first `include` directive or target.

<details>
    <summary>Addition to print the target's help</summary>

```Makefile
# HEEP_DIR might already be defined, you may want to move it to the top
export HEEP_DIR = hw/vendor/esl_epfl_x_heep/

# Get the path of this Makefile to pass to the Makefile help generator
MKFILE_PATH = $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")
export FILE_FOR_HELP = $(MKFILE_PATH)/Makefile


## Call the help generator. Calling simply
## $ make
## or
## $ make help
## Will print the help of this project.
## With the parameter WHICH you can select to print
## either the help of X-HEEP (WHICH=xheep)
## or both this project's and X-HEEP's (WHICH=all)
help:
ifndef WHICH
	${HEEP_DIR}/util/MakefileHelp
else ifeq ($(filter $(WHICH),xheep x-heep),)
	${HEEP_DIR}/util/MakefileHelp
	$(MAKE) -C $(HEEP_DIR) help
else
	$(MAKE) -C $(HEEP_DIR) help
endif
```

</details><br>

> Remeber to add double hashes `##` on any comment you want printed on the help.
> Use `## @section SectionName` to divide the documentation in sections
