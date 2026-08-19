# Program the FLASH on the EPFL Programmer

```{note}
Windows/WSL2 users should configure usbipd, as outlined in the [Additional steps](#additional-steps-for-windowswsl2-users) section, before proceeding.
```

Install the required linux tools:

```
$ sudo apt install pkg-config libftdi1-2
```

Compile the iceprog program by doing

```
cd sw/vendor/yosyshq_icestorm/iceprog
make
```

Plug a micro-USB into the [EPFL programmer](https://github.com/esl-epfl/x-heep-programmer-pmod), and connect the EPFL programmer to the Pynq-z2 FPGA PMODs.

We use the the `FT4232H` which has Vendor ID `0x0403` and Product ID `0x6011`.

On your Linux shell, execute `lsusb`, you should see something like:

```
Bus 001 Device 006: ID 0403:6011 Future Technology Devices International, Ltd FT4232H Quad HS USB-UART/FIFO IC
```

and by executing `dmesg --time-format iso | grep FTDI` you should see something like:

```
2022-07-14T11:32:47,136453+02:00 usb 1-1.6: FTDI USB Serial Device converter now attached to ttyUSB4
2022-07-14T11:32:47,136543+02:00 ftdi_sio 1-1.6:1.3: FTDI USB Serial Device converter detected
2022-07-14T11:32:47,136878+02:00 usb 1-1.6: FTDI USB Serial Device converter now attached to ttyUSB5
```

Now do this, use B for the SPI, -t to read the FLASH ID

```
./iceprog -d i:0x0403:0x6011 -I B -t
```

You can also do this by running the following command

```
make flash-readid
```


The output should be:

```
init..
cdone: high
reset..
cdone: high
flash ID: 0xEF 0x70 0x18 0x00
cdone: high
Bye.
```

If you get:

```
init..
Can't find iCE FTDI USB device (device string i:0x0403:0x6011).
ABORT.
```

create a file called `61-ftdi4.rules` (or whatever) in the folder `/etc/udev/rules.d/` (you need sudo permits).

Write the following text in the created file to describe the attributes of the FT4232H chip:

```
# ftdi4
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6011", MODE="666", GROUP="plugdev"
```

You may also need to run `sudo usermod -a -G plugdev yourusername` and restart the utility with `sudo udevadm control --reload`.

You may want to unplug and plug back the USB cable and repeat the iceprog command.


Reset the bitstream of the FPGA, and build it as

```
make vivado-fpga FPGA_BOARD=pynq-z2
```

You need to reset the bitstream to avoid conflicts when programming the FLASH from the FTDI chip.


Generate the C program you want to execute as described in the [ExecuteFromFlash](ExecuteFromFlash.md),

then program the FLASH as:

```
make flash-prog
```

You can read the content of the FLASH as:

```
make flash-read FLASHREAD_ADDR=0x10000 FLASHREAD_BYTES=16; xxd flashcontent.hex
```

In this example, we are reading `16` bytes from the flash address `0x10000`.


Now program the FPGA with the x-heep bitstream:


```
make vivado-fpga-pgm FPGA_BOARD=pynq-z2
```

Remember to set `boot_sel_i` to `1` if you `load from flash`.

Reset the logic (so the x-heep reset and not the bitstream reset) and enjoy.

Additional note: To use the flash directly from X-HEEP, you first need to execute from the PC any iceprog command targeting the Flash. On the exit of any iceprog program, the FTDI pins will be set to high impedance. If this is not performed, the pins from the FTDI won't be on high impedance and the SPI signals cannot be driven from X-HEEP (or any other device).

## Additional steps for Windows/WSL2 users:

Windows/WSL2 users can also use this tutorial, but need to forward the USB connection from the Windows host to WSL2. Once the USB is forwarded, `iceprog` can program the EPFL programmer.

1. **Install `usbipd-win`**  
   Follow the instructions in the [official guide](https://learn.microsoft.com/en-us/windows/wsl/connect-usb).

2. **Add Auto-Bind Policies**  
   Configure USBIP policies to automatically bind supported hardware in PowerShell:

   - **For ZCU104 and EPFL programmer** (which share the same hardware ID):  
     ```sh
     usbipd policy add --effect Allow --operation AutoBind --hardware-id 0403:6011
     ```
   - **For PYNQ-Z2**:  
     ```sh
     usbipd policy add --effect Allow --operation AutoBind --hardware-id 0403:6010
     ```
    For more information, please refer to [USBIPD Policy Configuration](https://github.com/dorssel/usbipd-win/wiki/New-design:-policies).

   This can be done manually by listing the devices with `usbipd list` and then attaching the device with the correct busid with:

   ```sh
   usbipd attach --wsl --busid 1-4
   ```

3. **Using VS Code for USB Control**  
   If you're using **VS Code**, you can manage USB attach/detach more conveniently using the **[USBIP Connect](https://marketplace.visualstudio.com/items?itemName=thecreativedodo.usbip-connect)** extension.
