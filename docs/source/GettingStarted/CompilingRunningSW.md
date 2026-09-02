# Compiling and running software

Here we will show how to compile and simulate with verilator a `hello_world` application.

## Compiling applications

To compile the `hello_world` application, you simply have to run:

```
make app
```

```{warning}
Don't forget to set the `RISCV_XHEEP` env variable to the compiler folder (without the `/bin` included).
```

You can find all the documentation and parameters for compiling applications in the [compiling applications guide](/How_to/CompileApps.md).

## Running applications

Once you know how to generate the MCU and compile the `hello_world` application, you can run it on X-HEEP using the open-source Verilator simulator. This can be easily done with:

```
make verilator-run-helloworld
```

After a couple of minutes, you should see a "hello world!" output.

All of the detailed documentation for simulating applications with the different tools can be found in the [simulating guide](/How_to/Simulate.md). Furthermore, you are now ready to [run applications on FPGA](./../FPGA/RunOnFPGA.md) and to follow the rest of the "How to..." guides.
