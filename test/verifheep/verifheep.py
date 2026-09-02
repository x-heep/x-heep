#
#     Copyright EPFL contributors.
#     Licensed under the Apache License, Version 2.0, see LICENSE for details.
#     SPDX-License-Identifier: Apache-2.0
#
#     Author: Tommaso Terzano <tommaso.terzano@epfl.ch>
#                             <tommaso.terzano@gmail.com>
#
#     Info: This library can be used to implement a software-based verification of X-Heep on a variety of targets,
#           including Verilator, QuestaSim and FPGA (pynq-z2), using gdb and OpenOCD. 
#           Some useful information:
#
#           1) In order to enable the elaboration of the outcome of a test, the SW testbench should produce data using
#              the following format:
#              - 1st line to n line: "<ID>:<cycles>:<outcome>"
#              - last line: "&"
#              Of course it is not mandatory to count the cycles, or to provide an outcome, or even to use different IDs.
#              The crucial thing is to use the format, even if only one of its fields is relevant for your usecase.
#
#           2) The library provides methods to generate a random input dataset + a golden output dataset
#              using a provided function. 
#              This is particularly useful for data-processing applications and accelerators, but could be used to test other
#              units with some workarounds.
#              If the function returns a dictionary of parameters that might be useful for the application (if not, return None), 
#              they will be written in the same header file as the golden output.
#              The application has to be written in order to use an external output, defined in a header file, 
#              and to compare it against a golden output, also defined in a header. 
#              Both the name and directories of these datasets can be provided as arguments.
#              It is also possible to generate a golden result starting from a custom input dataset, provided that it was produced
#              using the same structure.#              
#
#           3) The library provides methods to estimate the remaining time of the execution of a loop, based on the average duration
#              of the iterations that have already been executed. 
#              This is useful to estimate the remaining time of the execution of a multi-iteration test.
#           

import subprocess
import re
import time
import serial
import pexpect
import threading
import queue
import random
import os

# Set this to True to enable debugging prints
DEBUG_MODE = False

def PRINT_DEB(*args, **kwargs):
    if DEBUG_MODE:
        print(*args, **kwargs)

class VerifHeep:
    def __init__(self, target, xheep_dir, opt_en=False):
        self.target = target
        if target not in ['verilator', 'questasim', 'pynq-z2']:
            raise Exception(f'Target {target} not supported. Choose one among:\n- verilator\n- questasim (with optional optimization)\n- pynq-z2\n')
        if (target != 'pynq-z2' and opt_en) or (target != 'verilator' and opt_en):
            raise Exception(f'Target {target} not supported with {opt_en}. Choose one among:\n- verilator\n- questasim (with optional optimization)\n- pynq-z2\n')

        self.opt_en = opt_en
        self.xheep_dir = xheep_dir
        self.results = []
        self.it_times = []

    def resetAll(self):
        self.results = []
        self.it_times = []
        if self.ser.is_open:
          self.ser.close()
        self.ser = None
        self.serial_queue = None
        self.serial_thread = None
        self.gdb = None
        self.xheep_dir = None

    def clearResults(self):
        self.results = []

    # Synthesis & Simulation methods
    
    def compileModel(self, mem_banks=6, cpu="cv32e40px", bus="1toN"):
        mcu_gen_cmd = f"cd {self.xheep_dir} ; make mcu-gen MEMORY_BANKS={mem_banks} CPU={cpu} BUS={bus}"
        subprocess.run(mcu_gen_cmd, shell=True, capture_output=True, text=True)
        if ("ERROR" in mcu_gen_cmd.stderr) or ("error" in mcu_gen_cmd.stderr):
            print(mcu_gen_cmd.stderr)
            exit(1)
    
    def buildModel(self):
        if self.target == 'verilator':
            cmd = f'cd {self.xheep_dir} ; make verilator-build FUSESOC_PARAM=--JTAG_DPI=1'
        elif self.target == 'questasim' and self.opt_en:
            cmd = f'cd {self.xheep_dir} ; make questasim-build-opt FUSESOC_PARAM=--JTAG_DPI=1'
        elif self.target == 'questasim' and not self.opt_en:
            cmd = f'cd {self.xheep_dir} ; make questasim-build'
        elif self.target == 'pynq-z2':
            cmd = f"cd {self.xheep_dir} ; make vivado-fpga FPGA_BOARD={self.target} FUSESOC_FLAGS=--flag=use_bscane_xilinx"
        result_synth = subprocess.run(cmd, shell=True, capture_output=True, text=True, executable="/bin/bash")
        if ("ERROR" in result_synth.stderr) or ("error" in result_synth.stderr):
            print(result_synth.stderr)
            exit(1)

    # FPGA programming & debugging methods
    
    def serialBegin(self, port, baudrate):
        try:
            self.ser = serial.Serial(port, baudrate, timeout=1)
            self.serial_queue = queue.Queue()
            
            if self.ser.is_open:
                print("Connection successful")
                return True
            else:
                print("Failed to open the connection")
                return False
        except serial.SerialException as e:
            print(f"Serial exception: {e}")
            return False
        except Exception as e:
            print(f"An error occurred: {e}")
            return False

    def setUpDeb(self):
        gdb_cmd = f"""
        cd {self.xheep_dir}
        $RISCV_XHEEP/bin/riscv32-unknown-elf-gdb ./sw/build/main.elf
        """
        self.gdb = pexpect.spawn(f"/bin/bash -c '{gdb_cmd}'")
        self.gdb.expect('(gdb)')
        self.gdb.sendline('set remotetimeout 2000')
        self.gdb.expect('(gdb)')
        self.gdb.sendline('target remote localhost:3333')
        self.gdb.expect('(gdb)')

        if self.gdb.isalive():
            PRINT_DEB("GDB process is still running.")
        else:
            PRINT_DEB("GDB process has terminated.")
            if self.gdb.exitstatus is not None:
                print(f"GDB exit status: {self.gdb.exitstatus}")
            if self.gdb.signalstatus is not None:
                print(f"GDB terminated by signal: {self.gdb.signalstatus}")
            exit(1)
            
    def stopDeb(self):
        self.gdb.sendcontrol('c')
        self.gdb.terminate()

    def launchTest(self, example_name, input_size=0, pattern=r'(\d+):(\d+):(\d+)', en_timeout_term=False):
        PRINT_DEB(f"Running test {example_name} with input size {input_size}...")

        # Check that the serial connection is still open
        if not self.ser.is_open:
            print("Error: Serial port is not open!")
            exit(1) 

        # Set up the serial communication thread and attach it the serial queue
        self.serial_thread = threading.Thread(target=SerialReceiver, args=(self.ser, self.serial_queue,))

        # Start the serial thread
        self.serial_thread.start()

        # Compile the application
        if self.target == 'verilator' or self.target == 'questasim':
          app_compile_run_com = f"cd {self.xheep_dir} ; make app PROJECT={example_name}"
        else:
          app_compile_run_com = f"cd {self.xheep_dir} ; make app PROJECT={example_name} TARGET={self.target}"

        result_compilation = subprocess.run(app_compile_run_com, shell=True, capture_output=True, text=True)

        if ("Error" in result_compilation.stderr) or ("error" in result_compilation.stderr):
            print(result_compilation.stderr)
            return
        else:
            PRINT_DEB("Compilation successful!")
        
        # Run the testbench with gdb
        self.gdb.sendline('load')
        self.gdb.expect('(gdb)')

        try:
          output = self.gdb.read_nonblocking(size=100, timeout=1)
          PRINT_DEB("Current gdb output:", output)
        except pexpect.TIMEOUT:
          PRINT_DEB("No new output from GDB.")

        # Set a breakpoint at the exit and wait for it
        self.gdb.sendline('b _exit')
        self.gdb.expect('(gdb)')
        self.gdb.sendline('continue')
        try:
          self.gdb.expect('Breakpoint', timeout=600)
        except pexpect.TIMEOUT:
          print("Timeout! Program didn't answer in time, exiting...")
          self.gdb.terminate()
          if en_timeout_term:
            exit(1)
          return
        
        # Wait for serial to finish
        self.serial_thread.join()

        # Recover the lines
        lines = []
        while not self.serial_queue.empty():
            lines.append(self.serial_queue.get())

        # Analyse the results
        pattern = re.compile(pattern)  
        test_id = None
        for line in lines:
            match = pattern.search(line)
            if match:
                test_id = match.group(1)
                cycle_count = match.group(2)
                outcome = match.group(3)
                self.results.append({ "ID" : test_id, "Cycles": cycle_count, "Outcome": outcome, "Input size": input_size })

    def dumpResults(self, filename="results.txt"):
        with open(filename, 'w') as f:
            for result in self.results:
                f.write(result + '\n')

    # Performance estimation methods
    
    def chronoStart(self):
        self.start_time = time.time()
    
    def chronoStop(self):
        self.end_time = time.time()
        self.it_times.append(self.end_time - self.start_time)
        return self.end_time - self.start_time
    
    def chronoExecutionEst(self, loop_size):
        avg_duration = sum(self.it_times) / len(self.it_times)
        remaining_it = loop_size - len(self.it_times)
        remaining_time_raw = remaining_it * avg_duration
        remaining_time = {}
        remaining_time["hours"], remainder = divmod(remaining_time_raw, 3600)
        remaining_time["minutes"], remaining_time["seconds"] = divmod(remainder, 60)
        return remaining_time
    
    # Data generation methods

    def genInputDataset(self, dataset_size, parameters="", row_size=0, range_min=0, range_max=1, dataset_dir="input_dataset.h", dataset_dir_c="", dataset_name="input_dataset", datatype="uint32_t"):
        
        if dataset_dir_c == "":
          with open(dataset_dir, 'w') as f:
            # Add license
            f.write(f"#ifndef {dataset_name.upper()}_H\n")
            f.write(f"#define {dataset_name.upper()}_H\n\n")
            license = "/*\n\tCopyright EPFL contributors.\n\tLicensed under the Apache License, Version 2.0, see LICENSE for details.\n\tSPDX-License-Identifier: Apache-2.0\n*/\n\n"
            f.write(license)
            f.write(f"#include <stdint.h>\n\n")

            # Write the parameters, if there are any
            if parameters:
                for key, value in parameters.items():
                    f.write(f"#define {key} {value}\n")

            # Vector declaration
            f.write(f"const {datatype} {dataset_name}[{dataset_size}] = " + "{\n")
            
            # Generate the random vector
            for i in range(dataset_size):
                if 'float' in datatype:
                    value = random.uniform(range_min, range_max)  # float
                elif 'uint' in datatype:
                    if ('8' in datatype or '16' in datatype or '32' in datatype) and range_min >= 0 and range_max > 0:
                        value = random.randint(range_min, range_max)
                    else:
                        print("Error: invalid datatype. Choose one among:\n- float\n- u/int8_t\n- u/int16_t\n- u/int32_t\n")
                        exit(1)
                elif 'int' in datatype:
                    if ('8' in datatype or '16' in datatype or '32' in datatype):
                        value = random.randint(range_min, range_max)
                    else:
                        print("Error: invalid datatype. Choose one among:\n- float\n- u/int8_t\n- u/int16_t\n- u/int32_t\n")
                        exit(1)
                else:
                  print("Error: invalid datatype. Choose one among:\n- float\n- u/int8_t\n- u/int16_t\n- u/int32_t\n")
                  exit(1)

                if i < dataset_size - 1:
                    f.write(f" {value},")
                else:
                    f.write(f" {value}")
              
                if row_size > 0 and (i + 1) % row_size == 0:
                  f.write("\n")
            
            # Close the file
            f.write("};\n\n")
            f.write(f"#endif // {dataset_name.upper()}_H\n")
        else:
          with open(dataset_dir_c, 'w') as f:
            # Add license
            license = "/*\n\tCopyright EPFL contributors.\n\tLicensed under the Apache License, Version 2.0, see LICENSE for details.\n\tSPDX-License-Identifier: Apache-2.0\n*/\n\n"
            f.write(license)
            f.write(f'#include "{os.path.basename(dataset_dir)}"\n\n')
            
            # Vector declaration
            f.write(f"const {datatype} {dataset_name}[{dataset_size}] = " + "{\n")
            
            # Generate the random vector
            for i in range(dataset_size):
                if 'float' in datatype:
                    value = random.uniform(range_min, range_max)  # float
                elif 'uint' in datatype:
                    if ('8' in datatype or '16' in datatype or '32' in datatype) and range_min >= 0 and range_max > 0:
                        value = random.randint(range_min, range_max)
                    else:
                        print("Error: invalid datatype. Choose one among:\n- float\n- u/int8_t\n- u/int16_t\n- u/int32_t\n")
                        exit(1)
                elif 'int' in datatype:
                    if ('8' in datatype or '16' in datatype or '32' in datatype):
                        value = random.randint(range_min, range_max)
                    else:
                        print("Error: invalid datatype. Choose one among:\n- float\n- u/int8_t\n- u/int16_t\n- u/int32_t\n")
                        exit(1)
                else:
                  print("Error: invalid datatype. Choose one among:\n- float\n- u/int8_t\n- u/int16_t\n- u/int32_t\n")
                  exit(1)

                if i < dataset_size - 1:
                    f.write(f" {value},")
                else:
                    f.write(f" {value}")
              
                if row_size > 0 and (i + 1) % row_size == 0:
                  f.write("\n")
              
            # Close the file
            f.write("};\n\n")
          
          with open(dataset_dir, 'w') as f:
            # Add license
            f.write(f"#ifndef {dataset_name.upper()}_H\n")
            f.write(f"#define {dataset_name.upper()}_H\n\n")
            license = "/*\n\tCopyright EPFL contributors.\n\tLicensed under the Apache License, Version 2.0, see LICENSE for details.\n\tSPDX-License-Identifier: Apache-2.0\n*/\n\n"
            f.write(license)
            f.write(f"#include <stdint.h>\n\n")

            # Write the parameters, if there are any
            if parameters:
                for key, value in parameters.items():
                    f.write(f"#define {key} {value}\n")
            
            f.write("\n")

            # Vector declaration
            f.write(f"extern const {datatype} {dataset_name}[{dataset_size}];\n\n")
            
            # Close the file
            f.write(f"#endif // {dataset_name.upper()}_H\n")

    def genGoldenResult(self, function, golden_size, parameters, row_size=0, output_datatype="uint32_t",  input_dataset_dir="input_dataset.h", golden_dir_c="", golden_dir="golden_output.h", golden_name = "golden_output"):
        
        # Recover the input dataset
        with open(input_dataset_dir, 'r') as f:
            content = f.read()

        # Use regular expressions to find the array data
        pattern = re.compile(r"{(.*?)}", re.DOTALL)
        match = pattern.search(content)

        if not match:
            raise ValueError("No array data found in the file.")

        array_data = match.group(1)
        # Remove extra whitespace and split the string into individual values
        array_data = array_data.replace('\n', '').replace(' ', '')
        values = array_data.split(',')

        # Convert values to the appropriate type
        if "float" in content:
            values = [float(value) for value in values]
        elif "uint8_t" in content or "uint16_t" in content or "uint32_t" in content:
            values = [int(value) for value in values]
        elif "int8_t" in content or "int16_t" in content or "int32_t" in content:
            values = [int(value) for value in values]

        # Generate the golden result
        (golden_values, output_parameters) = function(values, parameters)

        if golden_dir_c == "":
          with open(golden_dir, 'w') as f:
            # Write the golden result to a file
            f.write(f"#ifndef {golden_name.upper()}_H\n")
            f.write(f"#define {golden_name.upper()}_H\n\n")
            license = "/*\n\tCopyright EPFL contributors.\n\tLicensed under the Apache License, Version 2.0, see LICENSE for details.\n\tSPDX-License-Identifier: Apache-2.0\n*/\n\n"
            f.write(license)
            f.write(f"#include <stdint.h>\n\n")

            # Write the parameters that could have been returned from the function
            if output_parameters:
              for key, value in output_parameters.items():
                  f.write(f"#define {key} {value}\n")
            
            f.write("\n")

            # Vector declaration
            f.write(f"const {output_datatype} {golden_name}[{golden_size}] = " + "{\n")

            for i in range(golden_size):
              if i < golden_size - 1:
                f.write(f" {golden_values[i]},")
              else:
                f.write(f" {golden_values[i]}")
              
              if row_size > 0 and (i + 1) % row_size == 0:
                f.write("\n")

            # Close the file
            f.write("};\n\n")
            f.write(f"#endif // {golden_name.upper()}_H\n")
        else:
          with open(golden_dir_c, 'w') as f:
            # Write the golden result to a file
            license = "/*\n\tCopyright EPFL contributors.\n\tLicensed under the Apache License, Version 2.0, see LICENSE for details.\n\tSPDX-License-Identifier: Apache-2.0\n*/\n\n"
            f.write(license)
            f.write(f'#include "{os.path.basename(golden_dir)}"\n\n')
            
            # Vector declaration
            f.write(f"const {output_datatype} {golden_name}[{golden_size}] = " + "{\n")

            for i in range(golden_size):
              if i < golden_size - 1:
                f.write(f" {golden_values[i]},")
              else:
                f.write(f" {golden_values[i]}")
                
              if row_size > 0 and (i + 1) % row_size == 0:
                f.write("\n")

            # Close the file
            f.write("};\n\n")

          with open(golden_dir, 'w') as f:
            # Write the golden result to a file
            f.write(f"#ifndef {golden_name.upper()}_H\n")
            f.write(f"#define {golden_name.upper()}_H\n\n")
            license = "/*\n\tCopyright EPFL contributors.\n\tLicensed under the Apache License, Version 2.0, see LICENSE for details.\n\tSPDX-License-Identifier: Apache-2.0\n*/\n\n"
            f.write(license)
            f.write(f"#include <stdint.h>\n\n")

            # Write the parameters that could have been returned from the function
            if output_parameters:
              for key, value in output_parameters.items():
                  f.write(f"#define {key} {value}\n")

            # Vector declaration
            f.write(f"extern const {output_datatype} {golden_name}[{golden_size}];\n\n")

            # Close the file
            f.write(f"#endif // {golden_name.upper()}_H\n")

    def modifyFile(self, file_dir, pattern, replacement):
        
        with open(file_dir, 'r') as f:
          content = f.read()

        # Replace the pattern with the replacement
        new_content = re.sub(pattern, replacement, content)

        with open(file_dir, 'w') as f:
          f.write(new_content)

# Serial communication thread

def SerialReceiver(ser, serial_queue, endword="&"):
    try:
        if not ser.is_open:
            raise serial.SerialException("Serial port not open")
        
        received = False
        while not received:
            # Read the data from the serial port
            line = ser.readline().decode('utf-8').rstrip()
            serial_queue.put(line)
            PRINT_DEB(f">: {line}")
            if line:
                if endword in line:
                    received = True
                    PRINT_DEB(f"Received {endword}: end of serial transmission thread")
                    return
                elif "ERROR" in line:
                    print("FAILED VERIFICATION!")
                    exit(1)
    except serial.SerialException as e:
        print(f"Serial exception: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")
    except KeyboardInterrupt:
        print("Keyboard interruption")
    finally:
        pass