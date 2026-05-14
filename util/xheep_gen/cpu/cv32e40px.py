from .cv32e40p import cv32e40p


class cv32e40px(cv32e40p):

    def __init__(
        self,
        fpu=None,
        fpu_addmul_lat=None,
        fpu_others_lat=None,
        zfinx=None,
        corev_pulp=None,
        num_mhpmcounters=None,
    ):
        super().__init__(
            fpu, fpu_addmul_lat, fpu_others_lat, zfinx, corev_pulp, num_mhpmcounters
        )
        self.name = "cv32e40px"

    def get_sv_str(self, param_name: str) -> str:
        """
        Get the SystemVerilog string representation of a parameter.
        :param param_name: Name of the parameter.
        :return: SystemVerilog string representation of the parameter.
        """
        if not self.is_defined(param_name):
            return ""

        return super().get_sv_str(param_name)
