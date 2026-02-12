# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Juan Sapriza, David Mallasen
# Description: Top-level container for the pad ring in the X-HEEP generation.

from .pad import Pad, Physical
from .pad import Corner
from .pin import Pin
from .floorplan import FloorplanDimensions, Side, SIDE_DEFAULT_ROTATION

from collections import Counter
from typing import List


class PadRing:
    """
    Top-level container for the pad ring.
    """

    cornerclass = Corner

    def __init__(
        self,
        floorplan_dimensions: FloorplanDimensions,
        mapping: dict,
        pin_list: List[Pin],
        attributes: dict,
    ):
        """
        Constructor for PadRing.

        :param floorplan_dimensions: Floorplan dimensions of the pad ring.
        :param mapping: A dicitonary containing each Side, and in each one of them, a list of a
            combination of List[Pin] and Pad.
        :param pin_list: A list of all pins which can be (but not necessarily are) connected to a
            Pad. The unconnected pads can be treated as bypass.
        :param attributes: User-defined dictionary of attributes of the pad ring. For example,
            depending on the technology used, some pads cells require additional I/Os other than the
            basic input and output ports. This can be defined in a "bits" field with value "7:0" of
            the attributes dictionary.
        """
        self.floorplan_dimensions = floorplan_dimensions
        self.pin_list = pin_list
        self.attributes = attributes

        # List[Pad] containing all pads in the pad ring
        self.pad_list = []

        global_index = 0
        side_indexes = {Side.LEFT: 0, Side.BOTTOM: 0, Side.RIGHT: 0, Side.TOP: 0}

        for side in Side:
            if side not in mapping:
                continue
            pin_mapping_side = mapping[side]
            for x in pin_mapping_side:
                if isinstance(x, Pad):
                    pad = x.copy()
                    if pad.global_index is None:
                        if isinstance(x, Physical):
                            pad.global_index = None
                        else:
                            pad.global_index = global_index
                            global_index += 1
                elif isinstance(x, list) and all(isinstance(p, Pin) for p in x):
                    pad = Pad(global_index=global_index, pins=x)
                    global_index += 1
                else:
                    raise ValueError(
                        "Elements in mapping must be either list[Pin] or Pad"
                    )

                pad.side = side
                if pad.side_index is None:
                    pad.side_index = side_indexes[side]
                    side_indexes[side] += 1
                if pad.orientation is None:
                    pad.orientation = SIDE_DEFAULT_ROTATION[side]
                self.pad_list.append(pad)

        # Build the pad list now that they have their assigned pins
        for pad in self.pad_list:
            pad.build()
        # In case of duplicate pad names (because the same pin is assigned to several pads)
        # rename them by adding an index
        self.rename_duplicate_pads()

    def rename_duplicate_pads(self):
        """
        Rename pads with duplicate names by adding an index suffix.
        For example, if two pads are named "GPIO_0", they will be renamed to "GPIO_0_1" and
        "GPIO_0_2".
        Pads without a name will be assigned a default name "NC_<global_index>".
        """
        # Pass 1: Handle missing names immediately
        for pad in self.pad_list:
            if not hasattr(pad, "name") or pad.name is None:
                pad.name = f"NC_{getattr(pad, 'global_index', 'unknown')}"

        # Pass 2: Count frequencies of the now-populated names
        counts = Counter(pad.name for pad in self.pad_list)

        # Pass 3: Apply indexing only to duplicates
        seen_track = {}
        for pad in self.pad_list:
            original_name = pad.name
            if counts[original_name] > 1:
                # Increment tracking for this specific name
                seen_track[original_name] = seen_track.get(original_name, 0) + 1
                # Apply the _x suffix
                pad.name = f"{original_name}_{seen_track[original_name]}"

    def print_pin_summary(self):
        """
        Print a list of pads, which pins they have assigned, and a list of pins that are not
        assigned to any pads.
        """
        RESET = "\033[0m"
        YELLOW = "\033[93m"
        BOLD = "\033[1m"
        print(
            f"{BOLD}Idx | Name{'':<25}| IO cell{'':<13}| Bondpad{'':<13}| # pins | Pins{RESET}"
        )
        for pad in self.pad_list:
            print(
                f"{pad.global_index if pad.global_index is not None else '':<3} |{pad.name:<30}| {pad.iocell.name if pad.iocell is not None else '':<20}| {pad.bondpad.name if pad.bondpad is not None else '':<20}| {len(pad.pins):<7}| {', '.join([pin.name for pin in pad.pins])}"
            )

        connected_pins = self.get_connected_pins()
        if any(pin not in connected_pins for pin in self.pin_list):
            print(f"\n⚠️{YELLOW}{BOLD}  UNCONNCETED PINS{RESET}")
        for pin in self.pin_list:
            if pin not in connected_pins:
                print(f" - {pin.name}")

    def get_connected_pins(self):
        """
        Returns the list of pins that are connected to pads in the pad ring. In the case of
        multiplexed pads, returns all pins.
        """
        connected_pins = []
        for pad in self.pad_list:
            for pin in pad.pins:
                if pin not in connected_pins:
                    connected_pins.append(pin)
        return connected_pins

    def get_connected_main_pins(self):
        """
        Returns the list of pins that are connected to pads in the pad ring. In the case of
        multiplexed pads, only the first (main) pin is returned.
        """
        connected_pins = []
        for pad in self.pad_list:
            if pad.pins and pad.pins[0] not in connected_pins:
                connected_pins.append(pad.pins[0])
        return connected_pins

    def num_muxed_pads(self):
        """
        Returns the number of pads that are multiplexed (i.e., connected to more than one pin).
        """
        count = 0
        for pad in self.pad_list:
            if len(pad.pins) > 1:
                count += 1
        return count

    def get_muxed_pad_select_width(self):
        """
        Return the number of bits needed to select between pins in multiplexed pads.
        """
        pad_muxed_list = [pad for pad in self.pad_list if len(pad.pins) > 1]
        if not pad_muxed_list:
            return 0
        return max(
            (len(muxed_pad.pins) - 1).bit_length() for muxed_pad in pad_muxed_list
        )

    def space_side_by_pitch(
        self, side: Side, space_from_corner_cell: float, pitch: float
    ):
        """
        Space the pads on a given side by a given pitch.

        :param side: The side to space the pads on.
        :param space_from_corner_cell: The space from the corner cell to the first pad.
        :param pitch: The pitch to space the pads by.
        """

        # Take only the pads from the selected side, and sorted by their side index
        pads_sublist = [pad for pad in self.pad_list if pad.side == side]
        pads_sublist.sort(key=lambda x: x.side_index)

        # Remove corners, as they are managed separately
        pads_sublist = [pad for pad in pads_sublist if not isinstance(pad, Corner)]

        if len(pads_sublist) == 0:
            print(
                f"⚠️  No pads found for {side.value} side. Will skip spacing by pitch."
            )
            return

        if any(p.side_index == None for p in pads_sublist):
            raise ValueError("All pads must have a side_index assigned")

        # ToDo_padspy: remove this constraint. The problem is that to compute the offset of the first bondpad,
        # if the cell has no bondpad, the offset should be computed for the second pad, which is a pain to leave tidy.

        if pads_sublist[0].bondpad == None:
            raise ValueError(
                "Sorry, we did not contemplate the possibility of starting the side with a cell without bondpad. \
                             But you can finish the side with one if you like :) "
            )

        # Get the distances to the margins
        side_iocell_margin = self.floorplan_dimensions.iocell_margin[side]
        side_bondpad_margin = self.floorplan_dimensions.bondpad_margin[side]

        # The first pad needs to be spaced a special distance from the corner cell.
        # Custom spacing to this cell can be given by changing this value
        pads_sublist[0].space = space_from_corner_cell
        # We assume that the corner is the same width as the pad is high (wouldn't make much sense otherwise)
        corner_width = pads_sublist[0].iocell.dimension.height
        # The center of this pad will be given by the distance from the ring's edge to the end of the corner,
        # the extra space, and half the pad's width
        pads_sublist[0].iocell_center_to_ring_edge = (
            corner_width
            + space_from_corner_cell
            + pads_sublist[0].iocell.dimension.width / 2
        )

        # First compute each pad's position and spacing
        # We assume that the pitch was decided based on the bondpads
        for i, pad in enumerate(pads_sublist[1:]):
            # If a cell has already defined a hardcoded position, then respect that
            if pad.iocell_center_to_ring_edge != None:
                pad.space = (
                    pad.iocell_center_to_ring_edge
                    - pads_sublist[i].iocell_center_to_ring_edge
                ) - (
                    pads_sublist[i].iocell.dimension.width / 2
                    + pads_sublist[i + 1].iocell.dimension.width / 2
                )
            else:
                # Otherwise compute the space based on the default pitch between bondpads.
                # Accept that PRCUTs will not have bondpads, and thus they do not need to respect the pitch.
                if pads_sublist[i + 1].bondpad == None:
                    pad.space = 0
                elif pads_sublist[i].bondpad == None:
                    last_prcut_width = pads_sublist[i].iocell.dimension.width
                    gap = (
                        pads_sublist[i - 1].iocell.dimension.width / 2
                        + last_prcut_width
                        + pads_sublist[i + 1].iocell.dimension.width / 2
                    )
                    pad.space = max(pitch - gap, 0)
                else:
                    pad.space = pitch - (
                        pads_sublist[i].iocell.dimension.width / 2
                        + pads_sublist[i + 1].iocell.dimension.width / 2
                    )

            pad.iocell_center_to_ring_edge = (
                pads_sublist[i].iocell_center_to_ring_edge
                + pad.space
                + pads_sublist[i].iocell.dimension.width / 2
                + pads_sublist[i + 1].iocell.dimension.width / 2
            )

        # The first bondpad needs to be offset to be aligned to the cell pad
        last_bp = 0
        width_diff_bp_pc = (
            pads_sublist[0].iocell.dimension.width
            - pads_sublist[0].bondpad.dimension.width
        )
        margin_diff = side_iocell_margin - side_bondpad_margin
        first_bp_offset = (
            margin_diff + corner_width + space_from_corner_cell + width_diff_bp_pc / 2
        )
        pads_sublist[0].offset = first_bp_offset
        pads_sublist[0].bp_space = 0

        pads_sublist[0].bondpad_center_to_ring_edge = (
            first_bp_offset + pads_sublist[0].bondpad.dimension.width / 2
        )

        for i, pad in enumerate(pads_sublist[1:]):
            pad_cell_center = pads_sublist[i + 1].iocell_center_to_ring_edge
            bond_pad_center = pad_cell_center + margin_diff
            pad.bondpad_center_to_ring_edge = bond_pad_center

            if pad.bondpad is not None:
                distance = (
                    bond_pad_center - pads_sublist[last_bp].bondpad_center_to_ring_edge
                )
                space = (
                    distance
                    - pads_sublist[last_bp].bondpad.dimension.width / 2
                    - pad.bondpad.dimension.width / 2
                )
                pad.bp_space = space
                last_bp = i + 1

    def validate(self):
        """
        Validate the pad ring configuration.
        """
        # Check that the "bits" field, if defined, is in the correct format "msb:lsb" and that msb >= lsb
        if "bits" in self.attributes:
            bits_str = self.attributes["bits"]
            if not isinstance(bits_str, str) or ":" not in bits_str:
                raise RuntimeError(
                    "[MCU-GEN - PadRing] ERROR: The 'bits' field in the padring attributes is defined but is not a string in the format 'msb:lsb'."
                )
            msb_str, lsb_str = bits_str.split(":")
            if not msb_str.isdigit() or not lsb_str.isdigit():
                raise RuntimeError(
                    "[MCU-GEN - PadRing] ERROR: The 'bits' field in the padring attributes is defined but does not contain valid integers for msb and lsb."
                )
            msb = int(msb_str)
            lsb = int(lsb_str)
            if msb < lsb:
                raise RuntimeError(
                    "[MCU-GEN - PadRing] ERROR: The 'bits' field in the padring attributes is defined but msb is less than lsb."
                )

        # If the "bits" field is defined in the padring attributes, also the "resval" field has to
        # be defined, and its value has to fit in the number of bits defined by the "bits" field.
        if "bits" in self.attributes:
            if "resval" not in self.attributes:
                raise RuntimeError(
                    "[MCU-GEN - PadRing] ERROR: The padring has a 'bits' field defined in its attributes but does not have a 'resval' field defined."
                )
            bits_str = self.attributes["bits"]
            msb, lsb = map(int, bits_str.split(":"))
            num_bits = msb - lsb + 1

            resval = self.attributes["resval"]
            if resval >= (1 << num_bits):
                raise RuntimeError(
                    f"[MCU-GEN - PadRing] ERROR: The padring has a 'bits' field with {num_bits} bits, but the 'resval' field has a value of {resval} which does not fit in {num_bits} bits."
                )
