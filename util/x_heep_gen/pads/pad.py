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

    def build(self, default_pin=None):
        """
        # If any pad has no pins assigned, then it will be tied to a default pin. 
        # This is done just for the sake of going on with the process, but is a major
        # issue that needs to be resolved, thus is printed out in red. 
        # If there is no default pin set, then raise an error
        if len(self.pins) == 0:
            if default_pin is None:
                raise ValueError("Failed to assing default pin to floating pad: No pin was defined as 'default'.\n\
                                 You can add an attribute to one of your pins \{'default':True\} to make assign to this the unassigned pads.")
            self.pins.append(default_pin)
            print(f"\033[31m Floating pad:\033[0m {self.global_index}, assigining to {default_pin.name}")
        """
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
            f"{self.global_index}: {[a.name for a in self.pins]} | {self.type} = {self.iocell.name}"
        )
    
    def is_muxed(self):
        """
        Returns True if the pad is multiplexed (i.e., has more than one pin assigned).
        """
        return len(self.pins) > 1

    def inherit_attributes(self):
        for key, value in vars(self.pins[0]).items():
            setattr(self, key, value)

    def decide_type(self):
        if self.pins and all(p.type == self.pins[0].type for p in self.pins):
            self.type = self.pins[0].type
        else:
            self.type = PinType.DIGITAL_INOUT
        if isinstance(self.pins[0], PinDigital):
            self.sv_pad_cell_name = (
                f"u_pad_cell_{self.type.value}/pad_{self.type.value}_i"
            )

        """
        self.__class__ = type(self.pins[0])
        ToDo_padspy FIXME
        if len(self.pins) > 1:
            self.__class__ = MultiplexedPad
        else:
            self.__class__ = type(self.pins[0])
        """

    def copy(self):
        return copy.deepcopy(self)


class Physical(Pad):
    def __init__(self, name, iocell, bondpad, attributes={}):
        self.global_index = 0
        self.name = name
        self.iocell = iocell
        self.bondpad = bondpad
        self.pins = []
        self.type = PinType.PHYSICAL
        self.sv_pad_cell_name = "u_pad_cell_supply/pad_supply_i"
        self.attributes = attributes


class Corner(Physical):
    pass
