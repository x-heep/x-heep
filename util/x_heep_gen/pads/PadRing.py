from .Pad import Pad
from .Pin import Pin
from .FloorplanDimensions import FloorplanDimensions


class PadRing:
    """
    Top-level container for the pad ring.
    """

    def __init__(
        self,
        floorplan_dimensions: FloorplanDimensions,
        pad_list: list[Pad],
        pin_list: list[Pin],
    ):
        """
        Constructor for PadRing.

        :param floorplan_dimensions: Floorplan dimensions of the pad ring.
        :param pad_list: A list containing all pads that will conform the padring.
        :param pin_list: A list of all pins which can be (but not necessarily are) connected to a Pad. The unconnected pads can be treated as bypass.
        """
        self.floorplan_dimensions = floorplan_dimensions
        self.pad_list = pad_list
        self.pin_list = pin_list

    def build(self):
        pass
