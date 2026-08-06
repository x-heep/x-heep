# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): David Mallasén
# Description: Debug subsystem configuration.


class DebugSS:
    """
    Represents the debug subsystem.

    :param int has_spi_slave: Whether the debug subsystem has an SPI slave interface.
    """

    def __init__(self, has_spi_slave: int = 0):
        self._has_spi_slave = has_spi_slave

    def has_spi_slave(self) -> int:
        """
        :return: Whether the debug subsystem has an SPI slave interface.
        :rtype: int
        """
        return self._has_spi_slave

    def set_spi_slave(self, has_spi_slave: int):
        """
        Set whether the debug subsystem has an SPI slave interface.

        :param int has_spi_slave: Whether the debug subsystem has an SPI slave interface.
        """
        self._has_spi_slave = has_spi_slave
