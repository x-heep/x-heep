from .cpu import CPU


class cv32e20(CPU):
    """
    Represents the CV32E20 CPU configuration with optional parameters.
    """

    RV32M_MODES = {"RV32MNone", "RV32MSlow", "RV32MFast", "RV32MSingleCycle"}

    def __init__(self, rv32e=None, rv32m=None):
        super().__init__("cv32e20")

        if rv32e is not None:
            if isinstance(rv32e, str):
                if rv32e.lower() not in ("true", "false", "1", "0"):
                    raise ValueError(
                        f"rv32e must be 0, 1, True, or False, got '{rv32e}'"
                    )
                rv32e = rv32e.lower() in ("true", "1")

            if rv32e not in (0, 1, True, False):
                raise ValueError(f"rv32e must be 0, 1, True, or False, got '{rv32e}'")

            self.params["rv32e"] = bool(rv32e)

        if rv32m is not None:
            if rv32m not in self.RV32M_MODES:
                raise ValueError(
                    f"rv32m must be one of {', '.join(self.RV32M_MODES)}, got '{rv32m}'"
                )
            self.params["rv32m"] = rv32m

    def get_sv_str(self, param_name: str) -> str:
        """
        Get the string representation of the param_name parameter to be used in the SystemVerilog templates.
        :param param_name: Name of the parameter.
        :return: String representation of the parameter for SystemVerilog or an empty string if not defined.
        """
        if not self.is_defined(param_name):
            return ""

        value = self.params[param_name]
        if param_name == "rv32e":
            return "1'b1" if value else "1'b0"
        elif param_name == "rv32m":
            return value
        else:
            return str(value)
