from .Pad import Pad


class PadRing:
    def __init__(
        self,
        pads=[],
        pins=[],
        physical_props={},
    ):
        self.pads = pads
        self.pins = pins
        self.physical_props = physical_props
