# Peripheral Configuration

The default configuration of the peripherals can be found in either [configs/general.hjson](https://github.com/x-heep/x-heep/blob/main/configs/general.hjson) or [configs/general.py](https://github.com/x-heep/x-heep/blob/main/configs/general.py). A custom configuration can be created through Python configuration.

## Overall structure

Peripherals are split between two domains :
 - Base peripheral domain ({py:class}`peripherals.base_peripherals.BasePeripheralDomain`)
 - User peripheral domain ({py:class}`peripherals.user_peripherals.UserPeripheralDomain`)

 Each domain contains a base address and a length, representing the memory space they occupy.

Each domain has its corresponding peripherals : 
 - Base peripherals (Mandatory peripherals)
 - User peripherals (Optional peripherals)

Every peripheral has at least an offset and a length, which represent its position in the corresponding domain. Some peripherals have their own registers, and thus have a linked `hjson` configuration file. Each peripheral must be stored in the corresponding domain. Every peripheral is represented as a Python class, more information about each peripheral can be found [here](https://x-heep.readthedocs.io/en/latest/Configuration/xheep_gen/index.html)

## Adding a custom configuration

An example is shown in [configs/general.py](https://github.com/x-heep/x-heep/blob/main/configs/general.py). First, both domains must be created. If a domain is not created, X-HEEP will be built with the provided HJSON configuration. Base Peripheral domain starts from 0x20000000, User peripheral domain starts from 0x30000000, and each fills 1MB.

Each peripheral has its own class, that must be imported from `peripherals.base_peripherals.py`or `peripherals.user_peripherals.py`.

When creating a peripheral, the offset, length, and other peripheral dependent information can be passed to the constructor. If not, default values will be assigned. Concerning the offsets, they will not be assigned until {py:meth}`system.XHeep.build` is called. In the same domain, peripherals with specific offsets and peripherals without a specified offset can coexist.

{py:meth}`system.XHeep.build` computes automatically the non defined offsets. A greedy algorithm places peripherals on free memory spaces in the corresponding peripheral domain, from the peripheral that takes the most memory to the one that takes the less. If there is not enough space, an error is thrown.

When the peripheral is configured, it can be added to the corresponding domain with {py:meth}`peripherals.abstractions.PeripheralDomain.add_peripheral`. All changes made after this call to the peripheral will not be recorded.

Since all base peripherals are mandatory, there is a method to add all base peripherals that were not added previously : {py:meth}`peripherals.base_peripherals.add_missing_peripherals`. The missing base peripherals are added with a default configuration based on [mcu_cfg.hjson](https://github.com/x-heep/x-heep/blob/main/mcu_cfg.hjson), but with undefined offsets (they will be computed during {py:meth}`system.XHeep.build`).

When method {py:meth}`system.XHeep.validate` is called, it performs basic sanity checks (all configuration files must exist, no peripheral should overlap another one, peripherals shouldn't be outside the domain, ...).

