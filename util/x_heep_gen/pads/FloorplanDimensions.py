from .Dimension import Dimension


class FloorplanDimensions:
    """
    Container for the dimensions of the different elements involved in the floorplan.
    """

    def __init__(
        self,
        die_dimensions: Dimension,
        bondpad_margin: list[float],
        iocell_margin: list[float],
        core_margin: list[float],
    ):
        """
        Constructor for FloorplanDimensions.

        :param die_dimensions: Dimensions of the die.
        :param bondpad_margin: List [left, bottom, right, top] of margins (float) from the bondpad edge to the die edge.
        :param iocell_margin: List [left, bottom, right, top] of margins (float) from the iocell edge to the bondpad edge.
        :param core_margin: List [left, bottom, right, top] of margins (float) from the core edge to the iocell edge.
        """

        self.die_dimensions = die_dimensions
        self.bondpad_margin = bondpad_margin
        self.iocell_margin = iocell_margin
        self.core_margin = core_margin

        # Validate margins
        for margin, name in zip(
            [bondpad_margin, iocell_margin, core_margin],
            ["bondpad_margin", "iocell_margin", "core_margin"],
        ):
            if len(margin) != 4:
                raise ValueError(
                    f"{name} must be a list of four float values: [left, bottom, right, top]."
                )

            for value in margin:
                if value < 0:
                    raise ValueError(f"All values in {name} must be non-negative.")
