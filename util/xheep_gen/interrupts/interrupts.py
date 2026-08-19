# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): David Mallasén
# Description: List of interrupts of the system.

from typing import Dict


class Interrupts:
    """
    A list of interrupts of the system.
    """

    # Do not change this number!
    PLIC_NUM_INTERRUPTS = 64

    def __init__(self):
        self.interrupts: Dict[str, int] = {}
        self._num_used_interrupts = 0

    def add_interrupt(self, name: str, id: int):
        """
        Add an interrupt to the list.

        :param str name: The name of the interrupt.
        :param int id: The ID of the interrupt.
        :raise ValueError: when the ID is not in the range [0, PLIC_NUM_INTERRUPTS).
        """
        if id < 0 or id >= self.PLIC_NUM_INTERRUPTS:
            raise ValueError(
                "[MCU-GEN - Interrupts] ERROR: Interrupt ID should be in the range [0, {0})".format(
                    self.PLIC_NUM_INTERRUPTS
                )
            )
        self.interrupts[name] = id
        self._num_used_interrupts += 1

    def get_interrupt(self, name: str) -> int:
        """
        Get the ID of the interrupt with the given name.

        :param str name: The name of the interrupt to look for.
        :return: The ID of the interrupt with the given name, or `None` if no such interrupt exists.
        :rtype: int
        """
        return self.interrupts.get(name, None)

    def get_interrupts(self) -> Dict[str, int]:
        """
        :return: A copy of the dictionary of interrupts.
        :rtype: dict[str, int]
        """
        return self.interrupts

    def get_num_used_interrupts(self) -> int:
        """
        :return: The number of user-defined interrupts in the list (excluding external interrupts).
        :rtype: int
        """
        return self._num_used_interrupts

    def build(self):
        """
        Add remaining interrupts as external interrupts (EXT_INTR_x)
        """
        num_used_interrupts = self.get_num_used_interrupts()
        for i in range(num_used_interrupts, self.PLIC_NUM_INTERRUPTS):
            self.add_interrupt(f"EXT_INTR_{i - num_used_interrupts}", i)

        # Update the number of used interrupts after adding external interrupts. This number is only
        # the user-defined interrupts, not the external interrupts.
        self._num_used_interrupts = num_used_interrupts
