# Copyright 2026 Politecnico di Torino
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Luigi Giuffrida
# Description: AXI master endpoint on the bus (e.g. CPU, debug module, external master).


class AxiMaster:
    """
    An AXI master endpoint on the bus (e.g. CPU, debug module, external master).

    Masters carry no address; they are enumerated to assign crossbar master
    indices.

    :param str name: The name of the master.
    """

    def __init__(self, name: str):
        if type(name) is not str or name == "":
            raise ValueError("AxiMaster name should be a non-empty string")
        self._name = name

    def get_name(self) -> str:
        """:return: the name of the master."""
        return self._name
