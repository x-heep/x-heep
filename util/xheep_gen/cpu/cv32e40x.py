from .cpu import CPU


class cv32e40x(CPU):

    def __init__(self, num_mhpmcounters=None):
        super().__init__("cv32e40x")

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
        return str(value)
