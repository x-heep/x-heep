class CvXIf:
    """
    Represent the CORE-V eXtension Interface configuration.
    """

    def __init__(
        self,
        x_num_rs: int = 2,
        x_id_width: int = 4,
        x_mem_width: int = 32,
        x_rfr_width: int = 32,
        x_rfw_width: int = 32,
        x_misa: int = 0x0,
        x_ecs_xs: int = 0x0,
    ):
        self.x_num_rs = x_num_rs
        self.x_id_width = x_id_width
        self.x_mem_width = x_mem_width
        self.x_rfr_width = x_rfr_width
        self.x_rfw_width = x_rfw_width
        self.x_misa = x_misa
        self.x_ecs_xs = x_ecs_xs

        # Dictionary to hold optional parameter values
        self.params = {
            "x_num_rs": self.x_num_rs,
            "x_id_width": self.x_id_width,
            "x_mem_width": self.x_mem_width,
            "x_rfr_width": self.x_rfr_width,
            "x_rfw_width": self.x_rfw_width,
            "x_misa": self.x_misa,
            "x_ecs_xs": self.x_ecs_xs,
        }

    def get_param(self, param_name: str):
        """
        Get the value of a given parameter.
        :param param_name: Name of the parameter to get.
        :return: Value of the parameter or None if not defined.
        """
        return self.params.get(param_name, None)
