# VerifHeep

## Introduction

**VerifHeep** is a Python library designed to provide various methods for implementing a verification and testing environment tailored specifically for X-Heep. You can find it in `test/verifheep`.

In particular, VerifHeep enables **on FPGA** verification, testing and performance estimation, offering a tenfold speed improvement compared to traditional simulation tools like Verilator or QuestaSim. 
This library employs a _software-based_ verification approach, meaning it conducts its tests by compiling a specific software application, running it on the target unit, and analyzing the results. The user is required to develop an application that can test and verify the target unit and display the data in accordance with specific formats.

This library has been developed with a focus on verifying and characterizing external accelerators, such as the _im2col Smart Peripheral Controller_ (SPC). 
In fact, the `test/verifheep/examples` folder contains the verification environment for this very accelerator, `im2col_spc_verification.py`, along with `im2col_spc_plotter.py` to plot the acquired data. 
Users are encouraged to refer to this file as a real-world example of how to use the library and can use it as starting point to develop their own verification environment.

> :warning: Make sure to follow the preliminary steps explained in `im2col_spc_verification.py` in order to test it!

This guide aims to address any questions that might arise from studying the *im2col_spc* example. It provides a detailed explanation of each method in VerifHeep, along with the parameters required for its proper functioning.

> :bulb: The FPGA synthesis must be performed with the **Xilinx scan chains** enabled, as these will be used to load the program. 
Additionally, the EPFL programmer will be used for serial communication with the board. Without these two lines of communication, it would be impossible to load the program and read the serial stream.

## Methods description

### <i> __init__ </i>

_Purpose_:
The initialization function is used to create the VerifHeep object. During this process, it's required to indicate the target of the verification and its directory. Furthermore, an optimization flag can be set when synthesis or simulation module building will be performed.

_Parameters_:
- **target**: Indicated the target of the verification environment, must be one of the following: 
  - `pynq-z2`
  - `questasim`
  - `verilator`
- **xheep_dir**: Sets the directory of the X-Heep project, necessary to run scripts.
- **opt_en**: By default set to _false_, this flag indicates whether optimization should be performed when building the simulation model. Available **only** with QuestaSim!

### <i> compileModel </i>

_Purpose_:
This method is used to compile a simulation model for both Verilator and QuestaSim, i.e. run _make mcu-gen_, provided they are properly installed on the host system.

_Parameters_:
- **mem_banks**: By default set to 6, this flag indicates how many memory banks will be included in the X-Heep model. No interleaved banks are supported.
- **cpu**: By default set to `cv32e40px`, this flags indicates which CPU will be included in the model.
- **bus**: By default set to `1toN`, this flag indicates the bus type.

### <i> buildModel </i>

_Purpose_:
This method is used to either build a simulation model for Verilator or QuestaSim or to synthesize the project with Xilinx Vivado, provided they are properly installed on the host system.

_Parameters_:
- **mem_banks**: By default set to *6*, this flag indicates how many memory banks will be included. No interleaved banks are supported.
- **cpu**: By default set to `cv32e40px`, this flags indicates which CPU will be included.
- **bus**: By default set to `1toN`, this flag indicates the bus type.

### <i> serialBegin </i>

_Purpose_:
This method is used to set up the serial communication with the _pynq-z2_ FPGA board.

> :bulb: **Tip:** Checkout which USB port is connected to the _pynq-z2_ by running a simple hello world (no flash load since the scan chains are used). 
Set the USB port parameter of the verification environment as a global variable to quickly modify it. Its value might change!

_Parameters_:
- **port**: Indicates the USB port connected to the EPFL programmer for the pynq-z2.
- **baudrate**: Indicates the connection speed, usually set to 9600.

_Return value_:
- **Outcome of the connection**, which is _False_ for unsuccessful.

### <i> setupDeb </i>

_Purpose_:
This method is used to set up the GDB debugger. It creates a process on which the debug communication will be run, thus making this function conveniently non-blocking. 

> :warning: This method should obviously be called at the beginning of the verification process, but not only then! Empirical evidence suggests **resetting the debug connection** approximately **every 100 iterations** to ensure reliable operation.

_Parameters_:
None

### <i> stopDeb </i>

_Purpose_:
This method is used to close the debugger. Useful both at the end of a script or during the cyclical reset of the debug connection, as explained before. 

_Parameters_:
None

### <i> genInputDataset </i>

_Purpose_:
This method is used to generate random data that the application can use to perform verification. It's possible to set the range of the data, the dimension of the array, the datatype and its variable identifier. In addition, it's possible to obtain a single _.h_ file or both a _.c_ and a _.h_ file.

_Parameters_:
- **dataset_size**: Indicates the size of the input array to be generated.
- **parameters**: This optional argument is a *dictionary* of parameters that might be useful for the application. It has *no impact on the value generation* but it will be written in the *.h* file.
- **row_size**: By default set to *0*, this parameter is used to organize the array in the case of matrix generation. In other words, every *row_size* words, the matrix will have a new line. 
- **range_min** / **range_max**: These are used to set the range of the random data. They can be both negative and float, if the datatype supports it.
- **dataset_dir**: Indicates the directory in which the generated file will be saved, including the name of the file itself.
- **dataset_dir_c**: By default *empty*, when set to a directory it forces the method to generate both a _.c_ and a _.h_, the first with the data definition and the second with its declaration.
- **dataset_name**: Indicates the name of the dataset.
- **datatype**: By default set to *uint32_t*, indicates the datatype of the array to be generated.

### <i> genGoldenResult </i>

_Purpose_:
This method is used to generate golden data from an input dataset, enabling applications to verify the functionality of a unit or accelerator. This feature is performed by a user-defined function, passed as a parameter, which processes the input data.

Similar to input generation, users can specify the data range, array dimensions, data type, and variable identifier. Additionally, the output can be configured to produce either a single _.h_ file or both a _.c_ and a _.h_ file.

_Parameters_:
- **function**: This function is the one used by the method to generate the golden results.
- **golden_size**: Indicates the size of the output array to be computed.
- **parameters**:This optional argument is a *dictionary* of parameters that might be useful for the application. It has no impact on the golden result computation but it will be written in the *.h* file.
- **row_size**: By default set to *0*, this parameter is used to organize the array in the case of matrix generation. In other words, every *row_size* words, the matrix will have a new line. 
- **range_min** / **range_max**: These are used to set the range of the random data. They can be both negative and float, if the datatype supports it.
- **golden_dir**: Indicates the directory in which the generated file will be saved, including the name of the file itself.
- **golden_dir_c**: By default *empty*, when set to a directory it forces the method to generate both a _.c_ and a _.h_, the first with the data definition and the second with its declaration.
- **input_dir**: Indicates the input data used to generate the golden result.
- **golden_name**: Indicates the name of the golden result array.
- **output_datatype**: By default set to *uint32_t*, indicates the datatype of the array to be computed.

### <i> modifyFile </i>

_Purpose_:
This method is simple yet very useful in particular situations. It allows the user to modify a row with a replacement of its choice. It can be used to modify _#define_ that could change the behaviour of the application.

For example, the im2col SPC verification example makes use of this feature twice. The first time it modifies the format of the output of the application to be adherent to the verification procedure (which by default it is not).
The second time it reduces the verification times, by avoiding to repeat unnecessary tests.

_Parameters_:
- **file_dir**: Indicates the directory of the file that the user wants to modify.
- **pattern**: Indicates the pattern to look for in the file, using the library **re**.
- **replacement**: Indicates the row that will be put in place instead of the pattern found.

### <i> chronoStart/chronoStop </i>

_Purpose_:This method is used to track the execution time of an iteration and, by extension, to estimate the total execution time of the verification process.

_Parameters_:
None

### <i> chronoExecutionEst </i>

_Purpose_:This method estimates the total execution time of the verification process, assuming the verification consists of a loop with N iterations. It requires that the `_chronoStart_` method is called at the beginning and the `_chronoStop_` method is called at the end of each iteration.

_Parameters_:
- **loop_size**: Size of the loop, i.e. number of iterations of the entire verification process. If it's composed of nested loops, the total number of iterations is obtained by multiplying the size of each loop.

_Return value_:
- **Remaining time**, a _dictionary_:
  - _"hours"_
  - _"minutes"_
  - _"seconds"_

### <i> launchTest </i>

_Purpose_:
This method is crucial in the verification process, as it's in charge of compiling the application, loading it on the FPGA using the scan chains and GDB, waiting for the results and storing then in *self.results*.

Its important to note that this method expects a **specific output format** from the application, which needs to be strictly respected otherwise the whole verification would be disrupted.
By default, this is the format expected:

<div style="text-align: center;">
  <pre style="display: inline-block; text-align: center;"><code> test_id:cycles:outcome
  ...
  & </code></pre>
</div>

An application can send N lines composed of:
- **test_id**: the ID of the test being performed. A single application can test multiple aspects or features, so different tests can be performed in a single run. In the **im2col_spc** application, this is exactly what happens: three different tests are performed each run.
- **cycles**: the number of cycles needed by the system to perform that specific test. In order to keep track of the execution cycles, a `timer_sdk` has been developed. Please refer to `example_timer_sdk` for a practical implementation.
- **outcome**: the outcome of the verification performed by the application itself. For example, the application might set up the DMA to perform a transaction and then check that the result corresponds to the golden result.

Each of these fields can be **left blank** or with whatever ASCII character, but the format has to be followed nonetheless. For example, one could be interested only in verify its design, avoiding the performance estimation. In such case, _cycles_ could be always set to _0_.

At the end of the run, the application **must send the end character** `&`.

If needed, the format of the data sent by the application can be modified by changing the _pattern_ parameter.

_Parameters_:
- **example_name**: Name of the example folder in X-Heep sw/application. e.g. For the DMA verification, this field would have been *example_dma*.
- **input_size**: This field will be appended to the data obtained by the simulation, not mandatory but might be useful for data processing.
- **pattern**: By default set to *test_id:cycles:outcome*. It can be changed by the user, with **caution**.
- **en_timeout_term**: By default set to _False_, if enabled it terminates the application in case that the board doesn't reply in time.

