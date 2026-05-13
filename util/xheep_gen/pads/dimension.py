# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Juan Sapriza, David Mallasen
# Description: Dimension definitions for X-HEEP padring generation.


class Dimension:
    """
    Represents the dimensions of, for example, a pad or cell.
    """

    def __init__(
        self,
        width: float,
        height: float,
    ):
        """
        Constructor for Dimension.

        :param width: The width.
        :param height: The height.
        """
        if width < 0 or height < 0:
            raise ValueError("Width and height must be positive values.")

        self.width = width
        self.height = height

    def __str__(self):
        return f"{self.height}×{self.width}µm"
