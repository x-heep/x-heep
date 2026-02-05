from .cell import Cell
from .pin import Pin, PinType
from .floorplan import Side, Orientation
from .pin import *

import copy


class Pad:

    pins: list = [Pin]
    name: str = ""
    iocell: Cell = None
    bondpad: Cell = None
    global_index: int = None
    side: Side = None
    side_index: float = None
    space: float = None
    offset: float = 0
    bp_space: float = 0
    orientation: Orientation = None
    iocell_center_to_ring_edge: float = None
    bondpad_center_to_ring_edge: float = None
    user_domain: str = ""

    def __init__(self, global_index, pins=[], attributes={}):
        self.global_index = global_index
        self.pins = pins
        for key, value in attributes.items():
            setattr(self, key, value)

    def build(self):
        if self.pins != []:
            # The pins assigned to this pad are sorted by priority.
            # Priority is an optional attribute and the highest priority will be used as main pin
            # (will be placed first on the list)
            self.pins = sorted(
                self.pins,
                key=lambda pin: (
                    pin.attributes.get("priority") or -self.pins.index(pin)
                ),
                reverse=True,
            )

            # Make the pad inherit the properties and attributes of its main pin (the one with the highest priority)
            self.inherit_attributes()

        print(
            f"{self.global_index}: {[a.name for a in self.pins]} = {self.iocell.name}"
        )

    def is_muxed(self):
        """
        Returns True if the pad is multiplexed (i.e., has more than one pin assigned).
        """
        return len(self.pins) > 1

    def inherit_attributes(self):
        for key, value in vars(self.pins[0]).items():
            setattr(self, key, value)

    def copy(self):
        return copy.deepcopy(self)


class Physical(Pad):
    def __init__(self, name, iocell, bondpad, attributes={}):
        self.global_index = 0
        self.name = name
        self.iocell = iocell
        self.bondpad = bondpad
        self.pins = []
        self.attributes = attributes


class Corner(Physical):
    pass
