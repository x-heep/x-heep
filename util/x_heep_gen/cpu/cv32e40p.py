from .cpu import CPU


class cv32e40p(CPU):
    """
    Represents the CV32E40P CPU configuration with optional parameters.
    """

    def __init__(
        self,
        fpu=None,
        fpu_addmul_lat=None,
        fpu_others_lat=None,
        zfinx=None,
        corev_pulp=None,
        num_mhpmcounters=None,
    ):
        super().__init__("cv32e40p")

        if fpu is not None:
            if isinstance(fpu, str):
                if fpu.lower() not in ("true", "false", "1", "0"):
                    raise ValueError(f"fpu must be 0, 1, True, or False, got '{fpu}'")
                fpu = fpu.lower() in ("true", "1")

            if fpu not in (0, 1, True, False):
                raise ValueError(f"fpu must be 0, 1, True, or False, got '{fpu}'")

            self.params["fpu"] = bool(fpu)

        if fpu_addmul_lat is not None:
            if fpu is None or fpu in (0, False):
                raise ValueError("fpu_addmul_lat requires fpu enabled")
            if isinstance(fpu_addmul_lat, str):
                try:
                    fpu_addmul_lat = int(fpu_addmul_lat.lower())
                except:
                    raise ValueError(
                        f"fpu_addmul_lat must be a number, got '{fpu_addmul_lat}'"
                    )

            if fpu_addmul_lat < 0:
                raise ValueError(
                    f"fpu_addmul_lat must be a positive number, got '{fpu_addmul_lat}'"
                )

            self.params["fpu_addmul_lat"] = fpu_addmul_lat

        if fpu_others_lat is not None:
            if fpu is None or fpu in (0, False):
                raise ValueError("fpu_others_lat requires fpu enabled")
            if isinstance(fpu_others_lat, str):
                try:
                    fpu_others_lat = int(fpu_others_lat.lower())
                except:
                    raise ValueError(
                        f"fpu_others_lat must be a number, got '{fpu_others_lat}'"
                    )

            if fpu_others_lat < 0:
                raise ValueError(
                    f"fpu_others_lat must be a positive number, got '{fpu_others_lat}'"
                )

            self.params["fpu_others_lat"] = fpu_others_lat

        if zfinx is not None:
            if fpu is None or fpu in (0, False):
                raise ValueError("zfinx requires fpu enabled")
            if isinstance(zfinx, str):
                if zfinx.lower() not in ("true", "false", "1", "0"):
                    raise ValueError(
                        f"zfinx must be 0, 1, True, or False, got '{zfinx}'"
                    )
                zfinx = zfinx.lower() in ("true", "1")

            if zfinx not in (0, 1, True, False):
                raise ValueError(f"zfinx must be 0, 1, True, or False, got '{zfinx}'")

            self.params["zfinx"] = bool(zfinx)

        if corev_pulp is not None:
            if isinstance(corev_pulp, str):
                if corev_pulp.lower() not in ("true", "false", "1", "0"):
                    raise ValueError(
                        f"corev_pulp must be 0, 1, True, or False, got '{corev_pulp}'"
                    )
                corev_pulp = corev_pulp.lower() in ("true", "1")

            if corev_pulp not in (0, 1, True, False):
                raise ValueError(
                    f"corev_pulp must be 0, 1, True, or False, got '{corev_pulp}'"
                )

            self.params["corev_pulp"] = bool(corev_pulp)

        if num_mhpmcounters is not None:
            if isinstance(num_mhpmcounters, str):
                try:
                    num_mhpmcounters = int(num_mhpmcounters.lower())
                except:
                    raise ValueError(
                        f"num_mhpmcounters must be a number, got '{num_mhpmcounters}'"
                    )

            if num_mhpmcounters < 0:
                raise ValueError(
                    f"num_mhpmcounters must be a positive number, got '{num_mhpmcounters}'"
                )

            self.params["num_mhpmcounters"] = num_mhpmcounters

    def get_sv_str(self, param_name: str) -> str:
        """
        Get the string representation of the param_name parameter to be used in the SystemVerilog templates.
        :param param_name: Name of the parameter.
        :return: String representation of the parameter for SystemVerilog or an empty string if not defined.
        """
        if not self.is_defined(param_name):
            return ""

        value = self.params[param_name]
        if param_name == "fpu":
            return "1" if value else "0"
        elif param_name == "zfinx":
            return "1" if value else "0"
        elif param_name == "corev_pulp":
            return "1" if value else "0"
        else:
            return str(value)
