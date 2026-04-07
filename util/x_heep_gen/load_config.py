import importlib
from pathlib import PurePath
from typing import List, Union
import hjson

from .cpu.cpu import CPU
from .cpu.cv32e20 import cv32e20
from .cpu.cv32e40p import cv32e40p
from .cpu.cv32e40px import cv32e40px
from .cpu.cv32e40x import cv32e40x
from .memory_ss.memory_ss import MemorySS
from .memory_ss.linker_section import LinkerSection
from .memory_ss.linker_subsection import LinkerSubsection
from .peripherals.peripheral_config_loader import load_peripherals_config
from .xheep import BusType, XHeep, CvXIf


def to_int(input) -> Union[int, None]:
    if type(input) is int:
        return input

    if type(input) is str:
        base = 10
        if len(input) >= 2:
            if input[0:2].upper() == "0X":
                base = 16
                input = input[2:]
            elif input[0:2] == "0o":
                base = 8
                input = input[2:]
            elif input[0:2].upper() == "0b":
                base = 2
                input = input[2:]

        return int(input, base)
    return None


def ram_list(l: "List[int]", entry):
    """
    Parses the hjson ram bank configuration in continuous mode.

    :param List[int] l: the list where bank sizes in kiB should be added
    :enrtry: the entry to be parsed. It should be a list an integer or an continuous dictionary
    :raise RuntimeError: when an invalid configuration is processed.
    """
    if type(l) is not list:
        raise TypeError("l should be of type list")

    if type(entry) is int:
        l.append(entry)
        return

    if type(entry) is list:
        for i in entry:
            ram_list(l, i)
        return

    if type(entry) is hjson.OrderedDict:
        num = 1
        if "num" in entry:
            if type(entry["num"]) is not int:
                raise RuntimeError(
                    "if the num field is present in ram configuration it should be an integer"
                )
            num = entry["num"]

        if "sizes" in entry:
            for _ in range(num):
                ram_list(l, entry["sizes"])
            return
        else:
            raise RuntimeError(
                "dictionaries in continuous ram configuration sections should at least have a sizes entry"
            )

    raise RuntimeError(
        "entries in ram configuration should either be integer, lists, or dictionaries"
    )


def load_ram_config(memory_ss: MemorySS, mem: hjson.OrderedDict):
    """
    Reads the whole ram configuration.

    :param MemorySS memory_ss: the memory_ss object where the ram should be added.
    :param hjson.OrderedDict mem: The configuration part with the ram informations.
    :raise TypeError: when arguments do not have the right type
    :raise RuntimeError: when an invalid configuration is processed.
    """
    if not isinstance(memory_ss, MemorySS):
        raise TypeError("memory_ss should be an instance of MemorySS")
    if type(mem) is not hjson.OrderedDict:
        raise TypeError("mem should be of type hjson.OrderedDict")

    for key, value in mem.items():
        if type(value) is not hjson.OrderedDict:
            raise RuntimeError("Ram configuration entries should be dictionaries")

        section_name = ""
        if "auto_section" in value and value["auto_section"] == "auto":
            section_name = key

        t = "continuous"
        if "type" in value:
            t = value["type"]
            if type(t) is not str:
                raise TypeError("ram type should be a string")
            if t != "continuous" and t != "interleaved":
                raise RuntimeError(
                    f"ram type should be continuous or interleaved not {t}"
                )

        if t == "interleaved":
            if "num" not in value or type(value["num"]) is not int:
                raise RuntimeError(
                    "The num field is required for interleaved ram section and should be an integer"
                )

            if "size" not in value or type(value["size"]) is not int:
                raise RuntimeError(
                    "The size field is required for interleaved ram section and should be an integer"
                )

            memory_ss.add_ram_banks_il(
                int(value["num"]), int(value["size"]), section_name
            )

            if section_name != "":
                memory_ss.add_linker_section_for_banks(
                    section_name,
                    subsections=[LinkerSubsection(f"xheep_{section_name}")],
                    interleaved=True,
                    il_group_name=section_name,
                )

        elif t == "continuous":
            banks: List[int] = []
            ram_list(banks, value)
            memory_ss.add_ram_banks(banks, section_name)


def load_linker_config(memory_ss: MemorySS, config: list):
    """
    Reads the whole linker section configuration.

    :param MemorySS memory_ss: the memory_ss object where the sections should be added.
    :param hjson.OrderedDict mem: The configuration part with the section informations.
    :raise TypeError: when arguments do not have the right type
    :raise RuntimeError: when an invalid configuration is processed.
    """
    if type(config) is not list:
        raise TypeError("Linker Section configuraiton should be a list.")

    for l in config:
        if type(l) is not hjson.OrderedDict:
            raise TypeError("Sections should be represented as Dictionaries")
        if "name" not in l:
            raise RuntimeError("All sections should have names")

        if "start" not in l:
            raise RuntimeError("All sections should have a start")

        name = l["name"]
        start = to_int(l["start"])

        if type(name) is not str:
            raise TypeError("Section names should be strings")

        if name == "":
            raise RuntimeError("Section names should not be empty")

        if type(start) is not int:
            raise TypeError("The start of a section should be an integer")

        if "size" in l and "end" in l:
            raise RuntimeError("Each section should only specify end or size.")

        end = 0
        if "size" in l:
            size = to_int(l["size"])
            if size is None:
                raise RuntimeError("Section sizes should be an integer")
            if size <= 0:
                raise RuntimeError("Section sizes should be strictly positive")
            end = start + size

        elif "end" in l:
            end = to_int(l["end"])
            if end is None:
                raise RuntimeError("End address should be an integer")
            if end <= start:
                raise RuntimeError("Sections should end after their start")
        else:
            end = None

        memory_ss.add_linker_section(LinkerSection(name, start, end))


def load_cpu_config(
    system: XHeep, cpu_type_config: str, cpu_features_config: hjson.OrderedDict
):
    """
    Reads the cpu configuration.
    :param XHeep system: the system object where the cpu should be set.
    :param str cpu_type_config: The cpu type configuration.
    :param hjson.OrderedDict cpu_features_config: The cpu features configuration.
    """
    if type(cpu_type_config) is not str:
        raise TypeError("cpu_type_config should be a string")
    if type(cpu_features_config) is not hjson.OrderedDict:
        raise TypeError(f"cpu_features_config should be an hjson.OrderedDict")

    if cpu_type_config == "cv32e20":
        cpu = cv32e20(
            rv32e=cpu_features_config.get("cve2_rv32e", None),
            rv32m=cpu_features_config.get("cve2_rv32m", None),
        )
    elif cpu_type_config == "cv32e40p":
        cpu = cv32e40p(
            fpu=cpu_features_config.get("fpu", None),
            zfinx=cpu_features_config.get("zfinx", None),
            corev_pulp=cpu_features_config.get("corev_pulp", None),
        )
    elif cpu_type_config == "cv32e40px":
        cpu = cv32e40px(
            fpu=cpu_features_config.get("fpu", None),
            zfinx=cpu_features_config.get("zfinx", None),
            corev_pulp=cpu_features_config.get("corev_pulp", None),
        )
    elif cpu_type_config == "cv32e40x":
        cpu = cv32e40x()
    else:
        cpu = CPU(cpu_type_config)

    system.set_cpu(cpu)
    if cpu_features_config.get("cv_x_if", None) is not None and cpu_type_config in [
        "cv32e20",
        "cv32e40px",
        "cv32e40x",
    ]:
        system.set_xif(CvXIf())  # use default parameters


def load_cfg_hjson(src: str) -> XHeep:
    """
    Loads the configuration passed as a hjson string and creates an object representing the mcu.

    :param str src: configuration content
    :return: the object representing the mcu configuration
    :rtype: XHeep
    :raise RuntimeError: when and invalid configuration is passed or when the sanity checks failed
    """
    config = hjson.loads(src, parse_int=int, object_pairs_hook=hjson.OrderedDict)

    mem_config = None
    bus_config = None
    linker_config = None

    cpu_type_config = None
    cpu_features_config = hjson.OrderedDict()

    for key, value in config.items():
        if key == "ram_banks":
            mem_config = value
        elif key == "bus_type":
            bus_config = value
        elif key == "linker_sections":
            linker_config = value
        elif key == "cpu_type":
            cpu_type_config = value
        elif key == "cpu_features":
            cpu_features_config = value

    if mem_config is None:
        raise RuntimeError("No memory configuration found")
    if bus_config is None:
        raise RuntimeError("No bus type configuration found")
    if cpu_type_config is None:
        raise RuntimeError("No CPU type configuration found")

    system = XHeep(BusType(bus_config))
    memory_ss = MemorySS()

    load_ram_config(memory_ss, mem_config)

    if linker_config is not None:
        load_linker_config(memory_ss, linker_config)

    system.set_memory_ss(memory_ss)

    load_cpu_config(system, cpu_type_config, cpu_features_config)

    load_peripherals_config(system, config)

    return system


def load_cfg_file(f: PurePath) -> XHeep:
    """
    Load the Configuration by extension type. It currently supports .hjson and .py

    :param PurePath f: path of the configuration
    :return: the object representing the mcu configuration
    :rtype: XHeep
    :raise RuntimeError: when and invalid configuration is passed or when the sanity checks failed
    """
    if not isinstance(f, PurePath):
        raise TypeError("parameter should be of type PurePath")

    if f.suffix == ".hjson":
        with open(f, "r") as file:
            return load_cfg_hjson(file.read())

    elif f.suffix == ".py":
        # The python script should have a function config() that takes no parameters and
        # returns an instance of the XHeep type.
        spec = importlib.util.spec_from_file_location("configs._config", f)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod.config()

    else:
        raise RuntimeError(f"unsupported file extension {f.suffix}")


def load_pad_cfg(pad_cfg_path: PurePath):
    """
    Load pad configuration a Python file and build the PadRing.

    Imports the Python module and calls the config() function which must
    not take any parameters and return a PadRing instance.

    :param PurePath pad_cfg_path: Path to .py configuration file
    :return: Built PadRing object ready for template generation
    """
    if not isinstance(pad_cfg_path, PurePath):
        raise TypeError("parameter should be of type PurePath")

    if pad_cfg_path.suffix != ".py":
        raise RuntimeError(f"unsupported file extension {pad_cfg_path.suffix}")

    spec = importlib.util.spec_from_file_location("configs._config", pad_cfg_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.config()
