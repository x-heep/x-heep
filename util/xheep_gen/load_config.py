# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): mBornand, Pacsort17, Davide Schiavone, marinPh, David Mallasén
# Description: Configuration loader to create the abstraction of the MCU.

import importlib
from pathlib import PurePath

from xheep import XHeep
from pads.pad_ring import PadRing


def load_cfg_file(f: PurePath) -> XHeep:
    """
    Load the Configuration from a Python file.

    The Python script should have a function config() that takes no parameters and
    returns an instance of the XHeep type.

    :param PurePath f: path of the configuration
    :return: the object representing the mcu configuration
    :rtype: XHeep
    :raise RuntimeError: when and invalid configuration is passed or when the sanity checks failed
    """
    if not isinstance(f, PurePath):
        raise TypeError("parameter should be of type PurePath")

    if f.suffix != ".py":
        raise RuntimeError(
            f"unsupported file extension {f.suffix}, only Python (.py) configurations are supported"
        )

    spec = importlib.util.spec_from_file_location("configs._config", f)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.config()


def load_pad_cfg(pad_cfg_path: PurePath, xheep: XHeep) -> PadRing:
    """
    Load pad configuration a Python file and build the PadRing.

    Imports the Python module and calls the config() function which must
    take an XHeep object as a parameter and return a PadRing instance.

    :param PurePath pad_cfg_path: Path to .py configuration file
    :param XHeep xheep: the XHeep object representing the system configuration
    :return: Built PadRing object ready for template generation
    """
    if not isinstance(pad_cfg_path, PurePath):
        raise TypeError("parameter should be of type PurePath")

    if pad_cfg_path.suffix != ".py":
        raise RuntimeError(f"unsupported file extension {pad_cfg_path.suffix}")

    spec = importlib.util.spec_from_file_location("configs._config", pad_cfg_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.config(xheep)
