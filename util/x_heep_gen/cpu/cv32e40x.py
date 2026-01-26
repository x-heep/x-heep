from .cpu import CPU


class cv32e40x(CPU):

    def __init__(self, cv_x_if=None, num_mhpmcounters=None):
        super().__init__("cv32e40x")

        if cv_x_if is not None:
            if isinstance(cv_x_if, str):
                if cv_x_if.lower() not in ("true", "false", "1", "0"):
                    raise ValueError(
                        f"cv_x_if must be 0, 1, True, or False, got '{cv_x_if}'"
                    )
                cv_x_if = cv_x_if.lower() in ("true", "1")

            if cv_x_if not in (0, 1, True, False):
                raise ValueError(
                    f"cv_x_if must be 0, 1, True, or False, got '{cv_x_if}'"
                )

            self.params["cv_x_if"] = bool(cv_x_if)

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

        value = self.params.get(param_name)
        if param_name == "cv_x_if":
            return "1" if value else "0"
        else:
            return str(value)
