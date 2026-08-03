X-HEEP
======

.. image:: /images/x-heep-outline.png

``X-HEEP`` (eXtensible Heterogeneous Energy-Efficient Platform) is a RISC-V microcontroller described in SystemVerilog that can be configured to target small and tiny platforms as well as extended to support accelerators.
The cool thing about X-HEEP is that we provide a simple customizable MCU, with CPUs, common peripherals, memories, etc. so that you can extend it with your own accelerator without modifying the MCU, but just instantiating it in your design.
By doing so, you inherit an IP capable of booting RTOS (such as FreeRTOS) with the whole FW stack, including HAL drivers and SDK, and you can focus on building your special HW or APP supported by the microcontroller.

X-HEEP supports simulation with Verilator, QuestaSim, VCS, and Xcelium. Moreover, FW can be built and linked by using CMake either with GCC or with Clang and/or SEGGER Embedded Studio using gcc. It can be implemented on FPGA, and it supports implementation in Silicon, which is its main (but not only) target.
You are welcome to explore our `X-HEEP repository <https://github.com/x-heep/x-heep>`_ or our `X-HEEP paper <https://infoscience.epfl.ch/record/302127>`_ for a deeper description of the platform.

Architecture
^^^^^^^^^^^^
The architecture is divided into the following power domains: CPU subsystem domain, memory banks domains, peripheral subsystem domain and always-on peripheral subsystem domain. The following image highlights each power domain with a different colour. IPs are carefully selected and grouped in the mentioned power domains in order to maximize energy savings during the processing and acquisition phases of our target ultra-low-power edge-computing applications. We reused several IPs from the most important open-source projects, such as `PULP <https://github.com/pulp-platform>`_, `OpenHW <https://github.com/openhwgroup>`_ and `lowRISC <https://github.com/lowRISC>`_. Moreover, we custom-designed some specific IPs to meet our architectural needs.

.. image:: /images/xheep_diagram.svg

You can access an editable version of this diagram for your use in presentations or publications `here <https://viewer.diagrams.net/?tags=%7B%7D&lightbox=1&highlight=0000FF&edit=_blank&layers=1&nav=1&title=X-HEEP-general-diagram.drawio&dark=auto#Uhttps%3A%2F%2Fdrive.google.com%2Fuc%3Fid%3D1FxAmuywf1zneG0PeiYe_IHTJCv-3kLPI%26export%3Ddownload>`_.

CPU subsystem domain
^^^^^^^^^^^^^^^^^^^^

The CPU subsystem is based on the RISC-V OpenHW Group CPUs: `CVE2 <https://github.com/openhwgroup/cve2>`_, `CV32E40P <https://github.com/openhwgroup/cv32e40p>`_ and its variant with the CORE-V-X-Interface called `CV32E40PX <https://github.com/x-heep/cv32e40px>`_, and finally the `CV32E40X <https://github.com/openhwgroup/cv32e40x>`_ CPU, also with the X-IF. All the CPUs are embedded class 32-bit open-source low-power cores, the first three originally designed by ETH Zurich.
You can select your core among those ones. We selected these cores as the first two are mature, verified, implemented in silicon several times, while the latter is extendible with the X-IF. They all feature a Harvard architecture with two separate bus interfaces for instructions and data implementing the open bus interface (OBI) protocol. No caches are present in the system. The domain can be easily clock-gated, but it is also designed to be completely switched off when not used for long periods of time.

Memory banks domains
^^^^^^^^^^^^^^^^^^^^

The memory subsystem is divided into multiple banks that can have different sizes of memory used for both program instructions and data. Banks are connected to the bus with dedicated interfaces and this allows you to access multiple banks at the same time without conflicts. Each bank can be individually clock-gated or set in retention to save dynamic and leakage power, respectively. Moreover, the memory subsystem is designed for fine-grained power gating, switching off each bank that is not needed.

Peripheral subsystem domain
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The peripheral subsystem includes the general-purpose peripherals that are not commonly used during the processing or acquisition phases but that are a nice-to-have in a multi-functional microcontroller. It includes a general-purpose timer, a platform-level interrupt controller (PLIC), an inter-integrated circuit (I2C) interface, two serial peripheral interfaces (SPI and SPI2) and 24 general-purpose input-output (GPIO). This subsystem is connected to the bus through a single interface but features an internal second level of decoding to direct the request to the proper peripheral. The subsystem can be clock-gated to save dynamic power or it can be switched off when not used for a long time.

Always-on peripheral subsystem domain
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The always-on peripheral subsystem includes all IPs we want to keep on for the entire time. We custom-designed the SoC controller, the boot ROM, the power manager, the fast interrupt controller and the DMA in order to meet our needs and requirements. The remaining peripheral IPs, i.e., a general-purpose timer, a universal asynchronous receiver transmitter (UART), an SPI (SPI Flash), and 8 GPIOs, come from important open-source projects. No power-gating strategy is applied to this domain.

Index
^^^^^

.. toctree::
   :maxdepth: 2

   /GettingStarted/index
   /How_to/index
   /Configuration/index
   /Extending/index
   /Testing/index
   /Peripherals/index
   /ExternalPeripherals/index
   /FPGA/index
   /ASIC/index
