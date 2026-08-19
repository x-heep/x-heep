# Address Map

The address map defines how the full 32-bit memory space of X-HEEP is partitioned into regions. It is used by the generator to place memories, peripherals, and other addressable components, and to produce consistent hardware constants, linker scripts, and software headers.

The default address map can be found in [configs/general.py](https://github.com/x-heep/x-heep/blob/main/configs/general.py). A custom configuration can be created through the Python configuration approach.

## Address space

X-HEEP uses a 32-bit memory map that spans the full address space:

* Start address: `0x0000_0000`
* End address: `0xFFFF_FFFF` (inclusive)
* Total length: `0x1_0000_0000` bytes (4 GiB)

The address map is represented by the {py:class}`address_map.address_map.AddressMap` class, which contains an ordered collection of {py:class}`address_map.address_region.AddressRegion` objects.

## Overall structure

Each address region is comprised of:

* `name`: a unique identifier for the region.
* `start_address`: the first byte of the region.
* `length`: the size of the region in bytes.

The inclusive end address of a region is computed as `start_address + length - 1`.

Regions must not overlap, and the last region must not extend beyond `0xFFFF_FFFF`. Adjacent regions (where the `start_address + length` of one equals the `start address` of the next) are valid.

## Relationship with peripherals

Peripheral domains ({py:class}`peripherals.base_peripherals.BasePeripheralDomain` and {py:class}`peripherals.user_peripherals.UserPeripheralDomain`) must be included in the address map as regions. Each domain has a base address and a length that define the memory space occupied by its peripherals. The individual peripherals inside a domain contain their own offsets and lengths, which are relative to the base address of the domain, so they do not have to be specified in the address map. The generator uses this information to compute the absolute addresses of each peripheral.

For more information on how to configure peripherals, see the [Peripheral Configuration](./PeripheralConfiguration) guide.

## Accessing regions

Once the address map is populated, regions can be retrieved by name using {py:meth}`address_map.address_map.AddressMap.get_region`. The full list of regions can be accessed with {py:meth}`address_map.address_map.AddressMap.get_regions`.

These methods are typically used internally by the generator and from Mako templates.
