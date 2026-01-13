import importlib
from pathlib import PurePath
from typing import List, Union
import hjson
import os
import sys
from jsonref import JsonRef

from .cpu.cpu import CPU
from .cpu.cv32e20 import cv32e20
from .cpu.cv32e40p import cv32e40p
from .cpu.cv32e40px import cv32e40px
from .cpu.cv32e40x import cv32e40x
from .memory_ss.memory_ss import MemorySS
from .memory_ss.linker_section import LinkerSection
from .xheep import BusType, XHeep
from .peripherals.base_peripherals_domain import BasePeripheralDomain
from .peripherals.user_peripherals_domain import UserPeripheralDomain
from .peripherals.base_peripherals import (
    SOC_ctrl,
    Bootrom,
    SPI_flash,
    SPI_memio,
    DMA,
    Power_manager,
    RV_timer_ao,
    Fast_intr_ctrl,
    Ext_peripheral,
    Pad_control,
    GPIO_ao,
)


from .peripherals.user_peripherals import (
    RV_plic,
    SPI_host,
    GPIO,
    I2C,
    RV_timer,
    SPI2,
    PDM2PCM,
    I2S,
    UART,
)


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


def load_peripherals_config(system: XHeep, config_path: str):
    """
    Reads the whole peripherals configuration.

    :param XHeep system: the system object where the peripherals should be added.
    :param str config_path: The path to the configuration file.
    :raise ValueError: If config file does not exist or if peripheral name doesn't match a peripheral class.
    """

    if not os.path.exists(config_path):
        raise ValueError(
            f"Peripherals configuration file {config_path} does not exist."
        )

    with open(config_path, "r") as file:
        try:
            srcfull = file.read()
            config = hjson.loads(srcfull, use_decimal=True)
            config = JsonRef.replace_refs(config)
        except ValueError:
            raise SystemExit(sys.exc_info()[1])

    for name, fields in config.items():
        # Base Peripherals
        if name == "ao_peripherals":
            base_peripherals = (
                BasePeripheralDomain(
                    int(fields["address"], 16), int(fields["length"], 16)
                )
                if not system.are_base_peripherals_configured()
                else None
            )
            if base_peripherals is not None:
                # iterate over all peripherals and create corresponding objects
                for peripheral_name, peripheral_config in fields.items():
                    if peripheral_name == "address" or peripheral_name == "length":
                        continue
                    # Skip if peripheral was already added by python configuration
                    if (
                        system.are_base_peripherals_configured()
                        and system._base_peripheral_domain.contains_peripheral(
                            peripheral_name
                        )
                    ):
                        continue

                    offset = int(peripheral_config["offset"], 16)
                    length = int(peripheral_config["length"], 16)
                    try:
                        if (
                            peripheral_config["is_included"] == "no"
                            and peripheral_name != "dma"
                        ):
                            continue
                    except KeyError:
                        pass
                    if peripheral_name == "soc_ctrl":
                        peripheral = SOC_ctrl(offset, length)
                    elif peripheral_name == "bootrom":
                        peripheral = Bootrom(offset, length)
                    elif peripheral_name == "spi_flash":
                        peripheral = SPI_flash(offset, length)
                    elif peripheral_name == "spi_memio":
                        peripheral = SPI_memio(offset, length)
                    elif peripheral_name == "dma":
                        try:
                            if peripheral_config["is_included"] == "yes":
                                dma_is_included = "yes"
                            else:
                                dma_is_included = "no"
                        except KeyError:
                            dma_is_included = "yes"

                        if dma_is_included == "yes":
                            addr_mode_en = peripheral_config["addr_mode_en"]
                            subaddr_mode_en = peripheral_config["subaddr_mode_en"]
                            hw_fifo_mode_en = peripheral_config["hw_fifo_mode_en"]
                            zero_padding_en = peripheral_config["zero_padding_en"]
                            if addr_mode_en != "no" and addr_mode_en != "yes":
                                raise ValueError("addr_mode_en should be no or yes")
                            if subaddr_mode_en != "no" and subaddr_mode_en != "yes":
                                raise ValueError("subaddr_mode_en should be no or yes")
                            if hw_fifo_mode_en != "no" and hw_fifo_mode_en != "yes":
                                raise ValueError("hw_fifo_mode_en should be no or yes")
                            if zero_padding_en != "no" and zero_padding_en != "yes":
                                raise ValueError("zero_padding_en should be no or yes")
                            ch_length = int(peripheral_config["ch_length"], 16)
                            num_channels = int(peripheral_config["num_channels"], 16)
                            num_master_ports = int(
                                peripheral_config["num_master_ports"], 16
                            )
                            num_channels_per_master_port = int(
                                peripheral_config["num_channels_per_master_port"], 16
                            )
                            fifo_depth = int(peripheral_config["fifo_depth"], 16)
                        else:
                            addr_mode_en = "no"
                            subaddr_mode_en = "no"
                            hw_fifo_mode_en = "no"
                            zero_padding_en = "no"
                            ch_length = int("0x100", 16)
                            num_channels = int("0x1", 16)
                            num_master_ports = int("0x1", 16)
                            num_channels_per_master_port = int("0x1", 16)
                            fifo_depth = int("0x4", 16)

                        peripheral = DMA(
                            is_included=dma_is_included,
                            address=offset,
                            length=length,
                            ch_length=ch_length,
                            num_channels=num_channels,
                            num_master_ports=num_master_ports,
                            num_channels_per_master_port=num_channels_per_master_port,
                            fifo_depth=fifo_depth,
                            addr_mode=addr_mode_en,
                            subaddr_mode=subaddr_mode_en,
                            hw_fifo_mode=hw_fifo_mode_en,
                            zero_padding=zero_padding_en,
                        )
                    elif peripheral_name == "power_manager":
                        peripheral = Power_manager(offset, length)
                    elif peripheral_name == "rv_timer_ao":
                        peripheral = RV_timer_ao(offset, length)
                    elif peripheral_name == "fast_intr_ctrl":
                        peripheral = Fast_intr_ctrl(offset, length)
                    elif peripheral_name == "ext_peripheral":
                        peripheral = Ext_peripheral(offset, length)
                    elif peripheral_name == "pad_control":
                        peripheral = Pad_control(offset, length)
                    elif peripheral_name == "gpio_ao":
                        peripheral = GPIO_ao(offset, length)
                    else:
                        raise ValueError(
                            f"Peripheral {peripheral_name} does not exist."
                        )
                    # Adding peripheral to domain
                    base_peripherals.add_peripheral(peripheral)

                # All peripherals in configuration file have been added
                system.add_peripheral_domain(base_peripherals)

        # User Peripherals
        elif name == "peripherals":
            user_peripherals = (
                UserPeripheralDomain(
                    int(fields["address"], 16), int(fields["length"], 16)
                )
                if not system.are_user_peripherals_configured()
                else None
            )
            if user_peripherals is not None:
                # iterate over all peripherals and create corresponding objects
                for peripheral_name, peripheral_config in fields.items():
                    if peripheral_name == "address" or peripheral_name == "length":
                        continue
                    # Skip if peripheral was already added by python configuration
                    if (
                        system.are_user_peripherals_configured()
                        and system._user_peripheral_domain.contains_peripheral(
                            peripheral_name
                        )
                    ):
                        continue

                    offset = int(peripheral_config["offset"], 16)
                    length = int(peripheral_config["length"], 16)
                    # Skip if the peripheral is not included
                    if peripheral_config["is_included"] == "no":
                        continue
                    if peripheral_name == "rv_plic":
                        peripheral = RV_plic(offset, length)
                    elif peripheral_name == "spi_host":
                        peripheral = SPI_host(offset, length)
                    elif peripheral_name == "gpio":
                        peripheral = GPIO(offset, length)
                    elif peripheral_name == "i2c":
                        peripheral = I2C(offset, length)
                    elif peripheral_name == "rv_timer":
                        peripheral = RV_timer(offset, length)
                    elif peripheral_name == "spi2":
                        peripheral = SPI2(offset, length)
                    elif peripheral_name == "pdm2pcm":
                        peripheral = PDM2PCM(offset, length)
                    elif peripheral_name == "i2s":
                        peripheral = I2S(offset, length)
                    elif peripheral_name == "uart":
                        peripheral = UART(offset, length)
                    else:
                        raise ValueError(
                            f"Peripheral {peripheral_name} does not exist."
                        )
                    # Adding peripheral to domain
                    user_peripherals.add_peripheral(peripheral)
                # All peripherals in configuration file have been added
                system.add_peripheral_domain(user_peripherals)


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
            cv_x_if=cpu_features_config.get("cv_x_if", None),
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
            cv_x_if=cpu_features_config.get("cv_x_if", None),
        )
    elif cpu_type_config == "cv32e40x":
        cpu = cv32e40x(
            cv_x_if=cpu_features_config.get("cv_x_if", None),
        )
    else:
        cpu = CPU(cpu_type_config)

    system.set_cpu(cpu)


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
