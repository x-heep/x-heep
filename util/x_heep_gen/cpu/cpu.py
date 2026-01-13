class CPU:
    """
    Represents a CPU configuration.
    """

    AVAILABLE_CPUS = {"cv32e20", "cv32e40p", "cv32e40px", "cv32e40x"}

    def __init__(self, name: str):
        if name not in self.AVAILABLE_CPUS:
            raise ValueError(
                f"Invalid CPU name '{name}'. Must be one of: {', '.join(self.AVAILABLE_CPUS)}"
            )
        self.name = name

        # Dictionary to hold optional parameter values
        self.params = {}

    def get_name(self) -> str:
        """
        Get the name of the CPU.
        :return: Name of the CPU.
        """
        return self.name

    def is_defined(self, param_name: str) -> bool:
        """
        Check if a given parameter is defined.
        :param param_name: Name of the parameter to check.
        :return: True if the parameter is defined, False otherwise.
        """
        return param_name in self.params

    def get_param(self, param_name: str):
        """
        Get the value of a given parameter.
        :param param_name: Name of the parameter to get.
        :return: Value of the parameter or None if not defined.
        """
        return self.params.get(param_name, None)
