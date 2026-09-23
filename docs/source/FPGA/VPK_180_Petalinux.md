# FPGA VPK180: Building Linux Image

Unlike some other X-HEEP-supported platforms, the VPK180 target may need a locally built Linux image instead of a pre-built package. This page gives brief instructions for building a minimal VPK180 Linux image with PetaLinux 2024.2. For more information, see:

* [PetaLinux Installation Guide](https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Installing-the-PetaLinux-Tool)
* [Example PetaLinux project for Versal targets](https://docs.amd.com/r/2024.2-English/ug1305-versal-embedded-tutorial/System-Design-Example-using-Scalar-Engine-and-Adaptable-Engine?section=example-project-creating-linux-images-using-petalinux)

## Creating and Configuring the Project


### Create the project
1. Download the Board Support Package (BSP) file for the VPK180 XSCT flow from [this link](https://www.xilinx.com/support/download.html/content/xilinx/en/downloadNav/embedded-design-tools/2024-2.html).

2. Create a new PetaLinux project from the BSP:

```bash
petalinux-create project -s /path/to/BSP/file.bsp -n xheep_versal_linux
```

This creates a fresh project from the BSP with the board-specific configuration needed by PetaLinux.

### Configure the project with your synthesized hardware platform.

PetaLinux needs the `.xsa` file exported from Vivado so it can import the PS/PL design configuration. The XSA is exported by the X-HEEP Vivado build flow when you run `make vivado-fpga FPGA_BOARD=vpk180`; it can be found under the FuseSoC build directory, for example `build/openhwgroup.org_systems_core-v-mini-mcu_<xheep_version>/vpk180-vivado`.


You can also export the XSA from Vivado with:

```tcl
write_hw_platform -fixed -include_bit -force -file file_name.xsa
```

Alternatively, in the Vivado GUI, use `File > Export > Export Hardware ...` and enable the option to include the device image/PDI.


After the XSA is available, run the following commands from the PetaLinux project directory:

```bash
cd xheep_versal_linux
petalinux-config --get-hw-description /path/to/XSA/file.xsa
```

`petalinux-config` opens the project configuration menu after importing the hardware description. For the SD-card flow below, check at least the following settings before saving and exiting:

- `Image Packaging Configuration > Root File System Type`: select `EXT4 (SD/eMMC/SATA/USB)` so the build generates an ext4 root file system image.
- `FPGA Manager`: enable FPGA manager support if you plan to load PL images or device-tree overlays from Linux.
- User and network settings: configure a Linux user and password, and set up networking if you plan to log in through SSH.

<!-- Then configure the root file system packages:

```bash
petalinux-config -c rootfs
```

Enable the packages needed by your runtime flow. At a minimum, OpenOCD must be available for JTAG access, and the UART runtime overlay flow requires `dtc` and `fpgautil` to be available on the target. Depending on the BSP's package menu, `fpgautil` may be provided by the `fpga-manager-script` package. -->

### Configuring the rootfs
Configure the rootfs to include the packages required by your application. This section describes a minimal configuration for the VPK180 programming flow. Add any other packages required by your application.

From the PetaLinux project directory, run:

```sh
petalinux-config -c rootfs
```

This command opens the rootfs configuration menu. Figure 1 shows this menu:

![PetaLinux rootfs configuration menu](../images/Petalinux/rootfs-page.png)

To add an additional user and set its password, go to `PetaLinux RootFS Settings > Add Extra Users`. The default user is `root`; configure an explicit password before booting the image.

#### Packages to Add
Enable the following packages to run the X-HEEP programmer SDK, program the FPGA, and connect to the board remotely. Search for these packages in the rootfs configuration menu, or use the repository-provided `rootfs_config` file at `hw/fpga/xheep_fpga_support/scripts/vpk180/Petalinux/rootfs_config` as a reference.

| # | Package to Enable |
|---:|---|
| 1 | `sudo` |
| 2 | `e2fsprogs-mke2fs` |
| 3 | `fpga-manager-script` |
| 4 | `dfx-mgr` |
| 5 | `init-ifupdown` |
| 6 | `iproute2` |
| 7 | `iproute2-ss` |
| 8 | `mtd-utils` |
| 9 | `procps` |
| 10 | `bash` |
| 11 | `can-utils` |
| 12 | `ethtool` |
| 13 | `nfs-utils` |
| 14 | `openssh` |
| 15 | `openssh-ssh` |
| 16 | `openssh-sftp` |
| 17 | `openssh-sftp-server` |
| 18 | `openssh-keygen` |
| 19 | `openssh-misc` |
| 20 | `openssh-sshd` |
| 21 | `openssh-scp` |
| 22 | `git` |
| 23 | `git-bash-completion` |
| 24 | `git-perltools` |
| 25 | `pciutils` |
| 26 | `screen` |
| 27 | `make` |
| 28 | `run-postinsts` |
| 29 | `libdfx` |
| 30 | `libgpiod` |
| 31 | `libusb-compat` |
| 32 | `libusb-compat-dev` |
| 33 | `libusb1` |
| 34 | `libusb1-dev` |
| 35 | `udev-extraconf` |
| 36 | `linux-xlnx-udev-rules` |
| 37 | `gdb` |
| 38 | `gdbserver` |
| 39 | `net-tools` |
| 40 | `packagegroup-core-boot` |
| 41 | `packagegroup-core-buildessential` |
| 42 | `python3` |
| 43 | `python3-numbers` |
| 44 | `python3-netclient` |
| 45 | `python3-math` |
| 46 | `python3-compression` |
| 47 | `python3-core` |
| 48 | `python3-shell` |
| 49 | `python3-threading` |
| 50 | `python3-mmap` |
| 51 | `python3-json` |
| 52 | `python3-multiprocessing` |
| 53 | `python3-logging` |
| 54 | `python3-ctypes` |
| 55 | `python3-sqlite3` |
| 56 | `python3-fcntl` |
| 57 | `python3-pickle` |
| 58 | `python3-setuptools` |
| 59 | `tcf-agent` |
| 60 | `bridge-utils` |
| 61 | `dosfstools` |
| 62 | `patch` |
| 63 | `u-boot-tools` |
| 64 | `pl-app` |
| 65 | `ssh-server-openssh` |
| 66 | `hwcodecs` |
| 67 | `debug-tweaks` |
| 68 | `systemd` |


```{Warning}
To reprogram the FPGA after Linux has booted using segmented configuration, enable the `fpga-manager-script` package.
```

### Limit Linux Memory

The VPK180 hardware configuration used by this project exposes a 4 GiB DDR region. After importing the XSA, verify that `petalinux-config` shows the following memory settings:

- `Subsystem Hardware Settings > Memory Settings`: select `axi_noc_0_C3_DDR_LOW1`.
- DDR base address: `0x800000000`.
- DDR size: `0x100000000` (4 GiB).


Linux normally treats the entire 4 GiB DDR region as system memory. If the DDR region used by X-HEEP overlaps this range, the kernel or user-space processes may allocate pages from it and later overwrite or reuse the data stored there.
To keep the last 1 GiB of the configured DDR region available for X-HEEP, limit the memory managed by Linux through the kernel boot arguments.
To do this, open the configuration menu by running:

```sh
petalinux-config
```

Then go to `DTG Settings > Kernel Bootargs > Add Extra bootargs` and add `mem=3G` to the boot arguments. Save the changes before exiting.

The `mem=3G` boot argument restricts Linux to the first 3 GiB of the 4 GiB DDR region, leaving the remaining 1 GiB outside the memory managed by Linux. This prevents normal Linux activity from overwriting X-HEEP data while the system is running. It does not preserve the data across a reboot or power cycle, and it does not prevent other hardware masters from accessing the region. The resulting project configuration contains:

```text
CONFIG_SUBSYSTEM_MEMORY_AXI_NOC_0_C3_DDR_LOW1_SIZE=0x100000000
CONFIG_SUBSYSTEM_EXTRA_BOOTARGS="mem=3G"
```


### Add OpenOCD Package

To program X-HEEP on VPK180, OpenOCD is used to access JTAG and load the `main.elf` file into X-HEEP. The root file system does not include OpenOCD by default, and the OpenOCD recipe needs an X-HEEP-specific patch and configuration options. Add the Yocto override as follows:

1. Create this directory:

```sh
mkdir -p project-spec/meta-user/recipes-devtools/openocd/files
```

2. Create `project-spec/meta-user/recipes-devtools/openocd/openocd_%.bbappend` with:

```text
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Use the OpenOCD upstream repo/revision expected by the X-HEEP helper flow.
SRC_URI:remove = "git://repo.or.cz/openocd.git;protocol=http;name=openocd;branch=master"
SRC_URI:prepend = "git://github.com/openocd-org/openocd.git;protocol=https;name=openocd;branch=master "
SRC_URI:append = " file://openocd-xheep.patch"
SRCREV_openocd = "b9e40161613fd880fc85fdb357365b70e646ff23"

# Needed for AXI JTAG access through the Xilinx AXI XVC OpenOCD driver.
EXTRA_OECONF:append = " --enable-xlnx-axi-xvc --enable-internal-jimtcl"
```

3. Copy [`hw/fpga/xheep_fpga_support/scripts/vpk180/Petalinux/openocd-xheep.patch`](../../../hw/fpga/xheep_fpga_support/scripts/vpk180/Petalinux/openocd-xheep.patch) to:

```text
project-spec/meta-user/recipes-devtools/openocd/files/openocd-xheep.patch
```

That patch changes OpenOCD RISC-V register probing for X-HEEP:

- checks `misa` before probing `vlenb`
- skips unsupported `mtopi` and `mtopei` probing
- avoids an assertion when those registers are treated as unavailable

4. Add OpenOCD to the root file system package menu and enable it:

```sh
grep -qxF "CONFIG_openocd" project-spec/meta-user/conf/user-rootfsconfig || \
    printf '%s\n' "CONFIG_openocd" >> project-spec/meta-user/conf/user-rootfsconfig
petalinux-config -c rootfs
```

In the menu, select `user packages > openocd`, then save and exit.

5. Rebuild OpenOCD after adding or changing this override:

```sh
petalinux-build -c openocd -x cleansstate
petalinux-build -c openocd
``` 

### Ensure a Consistent U-Boot Address Offset
Based on your hardware configuration, you may need to manually take care of the U-Boot address offset. In some projects using PetaLinux 2024.2, the default offset may not lie within the physical address range.

To prevent this, you can configure BitBake variables. For example, since the default VPK180 settings in X-HEEP have the DDR start address at `0x8_0000_0000`, we will set the U-Boot start address to `0x8_0020_0000`. To do so, append the following variables to `petalinuxbsp.conf`:

```
FIT_ADDRESS_CELLS = "2"
UBOOT_LOADADDRESS = "0x8 0x200000"
UBOOT_ENTRYPOINT = "0x8 0x200000"
```



## Building the PetaLinux Image
### Petalinux project build
Build Linux and package the boot image:

```sh
petalinux-build
petalinux-package boot --u-boot --force
```

For designs using Versal segmented configuration, `petalinux-package boot --u-boot` packages the boot PDI into `BOOT.BIN`; the PLD PDI can be loaded later after Linux is running.


### Create the SD Card Image
With the EXT4 root file system selected, the SD-card boot files are generated in `images/linux/`: `BOOT.BIN`, `image.ub`, `boot.scr`, and `rootfs.ext4`.

Create an SD card with two partitions: a FAT32 `BOOT` partition for `BOOT.BIN`, `image.ub`, and `boot.scr`, and an ext4 `rootfs` partition for `rootfs.ext4`.

The commands below erase the selected device. Replace `/dev/sdc`, `/dev/sdc1`, and `/dev/sdc2` with the device and partition names for your SD card.

1. Identify the SD card and create the partitions:

```sh
lsblk -p
```

In this example, the SD card is `/dev/sdc`. First, unmount any mounted SD-card partitions:

```sh
sudo umount /dev/sdc* 2>/dev/null
```

Create the partitions:

```sh
sudo parted /dev/sdc --script mklabel msdos
sudo parted /dev/sdc --script mkpart primary fat32 1MiB 1025MiB
sudo parted /dev/sdc --script set 1 boot on
sudo parted /dev/sdc --script mkpart primary ext4 1025MiB 100%
sudo partprobe /dev/sdc
```

This creates `/dev/sdc1` and `/dev/sdc2` in this example. Format the boot partition:

```sh
sudo mkfs.vfat -F 32 -n BOOT /dev/sdc1
sudo mkfs.ext4 -F -L rootfs /dev/sdc2
```

2. Mount the boot partition and copy the boot files:

```sh
sudo mkdir -p /tmp/vpk180_boot
sudo mount /dev/sdc1 /tmp/vpk180_boot
```

Copy the boot files into this partition:

```sh
sudo cp images/linux/BOOT.BIN /tmp/vpk180_boot/
sudo cp images/linux/image.ub /tmp/vpk180_boot/
sudo cp images/linux/boot.scr /tmp/vpk180_boot/
```

Unmount the boot partition:

```sh
sync
sudo umount /tmp/vpk180_boot
```

Write the root file system image directly to the second partition:

```sh
sudo dd if=images/linux/rootfs.ext4 of=/dev/sdc2 bs=4M status=progress conv=fsync
sync
```

To check the second partition and perform any necessary repairs, then resize it to occupy all remaining available space, run the following commands:

```sh
sudo e2fsck -fy /dev/sdc2   # Replace `sdc` with your SD card's device name
sudo resize2fs /dev/sdc2    # Replace `sdc` with your SD card's device name
```
The SD card is now ready. Insert it into the VPK180 and boot the system.

## VPK180 Boot

To boot from the SD card, insert the card into the VPK180 slot. Set SW1 to `ON OFF OFF OFF` and SW11 to `ON OFF ON ON`.

Connect the board to your host machine with a USB-C cable. The board exposes several USB serial devices under the host `/dev` tree; one of them is the Linux serial console. Open the console with a terminal program such as `screen` at the configured baud rate, typically `115200`:

```sh
screen /dev/ttyUSB<N> 115200
```

The serial console shows the boot log and eventually provides a Linux login prompt. It is useful for debugging boot issues and for finding the board IP address. If networking is configured and the board IP address is known, you can also log in through SSH using the Linux username and password configured during the PetaLinux build.

## Programming the PL from Linux

If segmented configuration was enabled during synthesis and implementation, the Linux boot image contains only the boot configuration, including `boot.pdi`; it does not configure the PL. After Linux has booted, run `fpgautil` to load the PLD PDI:

```sh
sudo fpgautil -b /path/to/pld.pdi
```

```{Note}
In this flow, the PLD PDI (`openhwgroup.org_systems_core-v-mini-mcu_<version>_pld.pdi`) is analogous to the bitstream used to configure the PL in a Zynq-based flow. For more information, see [Running X-HEEP on the FPGA](RunOnFPGA.md).
```

## Registering UART on Linux Runtime
Since the UART device is a PL IP, the generated Linux image does not initially identify the UARTLite module's physical address range as a UART device. Although it is possible to add this address range to the device tree before building the PetaLinux image, doing so can result in a boot fault if segmented configuration is enabled for your Vivado project. The reason is that the boot PDI file does not activate the address range related to the PL region, including the region dedicated to the UARTLite IP. Therefore, Linux may fault during boot while checking for all available devices.

A solution is to compile and add the device tree overlay after the Linux image has been built and successfully booted and the PL has been successfully programmed. To do this, create a `.dts` file with the following content:

```
/dts-v1/;
/plugin/;

/ {
    fragment@0 {
        target-path = "/amba_pl@0";

        __overlay__ {
            serial@a4040000 {
                compatible = "xlnx,xps-uartlite-1.00.a";

                reg = <0x0 0xa4040000 0x0 0x10000>;

                interrupt-parent = <&gic>;
                interrupts = <0 92 4>;

                current-speed = <9600>;

                xlnx,data-bits = <8>;
                xlnx,use-parity = <0>;
                xlnx,odd-parity = <0>;

                status = "okay";
            };
        };
    };
};
```

``` {Note}
The DTS file is also available in [`hw/fpga/xheep_fpga_support/scripts/vpk180/Petalinux/uart_fs_overlay.dts`](../../../hw/fpga/xheep_fpga_support/scripts/vpk180/Petalinux/uart_fs_overlay.dts)
```

Make sure to configure the physical address of the UART module, the address range size, and the baud rate based on your design. This file contains the default values from `hw/fpga/xheep_fpga_support/scripts/vpk180/xilinx_generate_ps_wizard.tcl`.


Then compile the device tree file using the following command:

```bash
    dtc -@ -I dts -O dtb \
        -o uart_overlay.dtbo \
        <DTS_FILE_NAME>.dts
```

Finally, add the overlay using Xilinx's `fpgautil` tool:

```bash
    sudo fpgautil -o "$(pwd)/uart_overlay.dtbo"
```


Verify that the device has been registered:

```bash
    ls /dev/ttyUL*
```

You should see a new device listed, `ttyUL0`.


You are now ready to use the [xheep-Xilinx-SoCs-interface SDK](https://github.com/x-heep/xheep-Xilinx-SoCs-interface) to program X-HEEP. For instructions on using the SDK from the Linux Processing System (PS), see [Programming the Board](./VPK_180.md#programming-the-board) in the VPK180 guide.
