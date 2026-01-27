class Pad:

    def __init__(
        self,
        attached_pins=[],
        type=None,
        physical_props={},
    ):
        self.attached_pins = attached_pins
        self.type = type
        self.physical_props = physical_props
