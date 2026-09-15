# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Luigi Giuffrida
# Description: AXI last-level cache, used as the memory subsystem of X-ALP.

from memory_ss.linker_section import LinkerSection
from memory_ss.memory_ss import MemorySS

from ..abstractions import BasePeripheral


class LLC(BasePeripheral, MemorySS):
    """
    The AXI last-level cache.

    The LLC is two things at once and the distinction matters when reading the
    address map:

    * a *memory subsystem*: instead of on-chip RAM banks it gives the system
      two windows, its scratchpad (SPM, whose size is fixed by the cache
      geometry) and the cached region it backs with the DRAM hanging off its
      master port. Both windows answer on a single crossbar port. Connect it
      with :meth:`XAlp.connect_memory_ss`.
    * a *peripheral*, i.e. a register-interface node inside a peripheral
      domain. ``offset``/``length`` describe that configuration register
      window. Add the same object to the peripheral domain to get it.

    Every parameter of the cache is configurable here: the geometry
    (``set_assoc``, ``num_lines``, ``num_blocks``, ``data_width``) drives the
    ``axi_llc`` instance in the RTL and fixes the SPM size, while
    ``spm_start``, ``cached_start`` and ``cached_size`` place the two windows.

    Unless the configuration adds linker sections of its own, the whole SPM
    and the whole cached region are declared as sections, which is what marks
    them cacheable and executable for the CPU.

    :param int offset: Offset of the configuration register window in its domain. `None` places it automatically.
    :param int length: Size of the configuration register window in bytes.
    :param int set_assoc: Number of ways.
    :param int num_lines: Number of lines per way.
    :param int num_blocks: Number of blocks per line.
    :param int data_width: AXI data width in bits (one block).
    :param int spm_start: Base address of the SPM window.
    :param int cached_start: Base address of the cached (DRAM) window.
    :param int cached_size: Size of the cached (DRAM) window in bytes.
    """

    _name = "axi_llc"

    def __init__(
        self,
        offset: int = None,
        length: int = 0x10000,
        set_assoc: int = 16,
        num_lines: int = 256,
        num_blocks: int = 8,
        data_width: int = 64,
        spm_start: int = 0x10000000,
        cached_start: int = 0x80000000,
        cached_size: int = 0x10000000,
    ):
        MemorySS.__init__(self)
        BasePeripheral.__init__(self, offset=offset, length=length)

        for name, value in (
            ("set_assoc", set_assoc),
            ("num_lines", num_lines),
            ("num_blocks", num_blocks),
            ("data_width", data_width),
            ("spm_start", spm_start),
            ("cached_start", cached_start),
            ("cached_size", cached_size),
        ):
            if type(value) is not int or value <= 0:
                raise ValueError(f"LLC.{name} should be a strictly positive integer")
        if data_width % 8 != 0:
            raise ValueError("LLC.data_width should be a whole number of bytes")

        self._set_assoc = set_assoc
        self._num_lines = num_lines
        self._num_blocks = num_blocks
        self._data_width = data_width
        self._spm_start = spm_start
        self._cached_start = cached_start
        self._cached_size = cached_size

    # ------------------------------------------------------------
    # Cache geometry
    # ------------------------------------------------------------

    def get_set_assoc(self) -> int:
        """:return: the number of ways."""
        return self._set_assoc

    def get_num_lines(self) -> int:
        """:return: the number of lines per way."""
        return self._num_lines

    def get_num_blocks(self) -> int:
        """:return: the number of blocks per line."""
        return self._num_blocks

    def get_data_width(self) -> int:
        """:return: the AXI data width in bits, which is also one block."""
        return self._data_width

    # ------------------------------------------------------------
    # Address windows
    # ------------------------------------------------------------

    def get_spm_start(self) -> int:
        """:return: the base address of the SPM window."""
        return self._spm_start

    def get_spm_size(self) -> int:
        """
        :return: the size of the SPM window in bytes. Every way is usable as
            scratchpad, so this is the whole cache capacity.
        """
        return (
            self._set_assoc * self._num_lines * self._num_blocks * self._data_width // 8
        )

    def get_cached_start(self) -> int:
        """:return: the base address of the cached (DRAM) window."""
        return self._cached_start

    def get_cached_size(self) -> int:
        """:return: the size of the cached (DRAM) window in bytes."""
        return self._cached_size

    def bus_windows(self, start_address: int):
        """
        The LLC is a single crossbar port answering two disjoint windows: the
        scratchpad ("llc") and the cached region ("dram") it backs with the
        memory on its master port. Both are placed by hand, so the address the
        system reserves for the memory subsystem is ignored.

        :param int start_address: Unused, see above.
        :return: The two windows as ``(name, base, size)`` tuples.
        :rtype: list[tuple[str, int, int]]
        """
        return [
            ("llc", self._spm_start, self.get_spm_size()),
            ("dram", self._cached_start, self._cached_size),
        ]

    def build(self):
        """
        Declares the whole SPM and the whole cached region as linker sections
        when the configuration did not add any of its own, then finalizes the
        memory subsystem.
        """
        if not self._linker_sections:
            for name, base, size in self.bus_windows(self._spm_start):
                self.add_linker_section(LinkerSection(name, base, base + size))
        MemorySS.build(self)


def _self_check():
    """Runnable sanity check: `python3 -m peripherals.base_peripherals.llc`."""
    llc = LLC(
        set_assoc=8, num_lines=128, num_blocks=4, data_width=64, spm_start=0x40000000
    )
    # 8 ways * 128 lines * 4 blocks * 8 B = 32 KiB
    assert llc.get_spm_size() == 32 * 1024, hex(llc.get_spm_size())
    assert llc.bus_windows(0) == [
        ("llc", 0x40000000, 32 * 1024),
        ("dram", 0x80000000, 0x10000000),
    ]
    # Left alone, the cache declares its whole SPM and cached region.
    llc.build()
    assert [(s.name, s.start, s.end) for s in llc.iter_linker_sections()] == [
        ("llc", 0x40000000, 0x40008000),
        ("dram", 0x80000000, 0x90000000),
    ]
    # A configuration that adds sections of its own keeps them.
    custom = LLC()
    custom.add_linker_section(LinkerSection("code", 0x10000000, 0x10008000))
    custom.build()
    assert [s.name for s in custom.iter_linker_sections()] == ["code"]
    print("LLC self-check OK")


if __name__ == "__main__":
    _self_check()
