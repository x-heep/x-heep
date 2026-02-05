class Dimension:
    def __init__(
        self,
        width: float,
        height: float,
    ):
        if width < 0 or height < 0:
            raise ValueError("Width and height must be positive values.")

        self.width = width
        self.height = height


    def __str__(self):
        return f"{self.height}×{self.width}µm"