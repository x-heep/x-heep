# Copyright 2026 EPFL
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author(s): Juan Sapriza, David Mallasen
# Description: Top-level container for the pad ring in the X-HEEP generation.

from .pad import Pad
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

        """
        ToDo_padspy: Check unconnected pins! and pads (which have both iocell and bondapd)
        """

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

    def print_pad_frame(self):
        """
        Print a visual representation of the pad ring layout in the console.
        """
        # ToDo_padspy: Do not print corners as if they were pads as well!
        # ToDo_padspy: Do we still need this? Move to graphic module?

        print("\n")

        # Separate pads by their side
        top = sorted(
            [p for p in self.pad_list if p.side == Side.TOP],
            key=lambda x: x.side_index,
            reverse=True,
        )
        bottom = sorted(
            [p for p in self.pad_list if p.side == Side.BOTTOM],
            key=lambda x: x.side_index,
            reverse=False,
        )
        left = sorted(
            [p for p in self.pad_list if p.side == Side.LEFT],
            key=lambda x: x.side_index,
            reverse=False,
        )
        right = sorted(
            [p for p in self.pad_list if p.side == Side.RIGHT],
            key=lambda x: x.side_index,
            reverse=True,
        )

        # Determine dimensions
        height = max(len(left), len(right))

        # Helper to format the global_index into [XXX]
        def fmt(pad):
            return f"[{pad.global_index:3}]" if pad else "     "

        # 1. Print Top Row
        top_row = "      " + "".join(fmt(p) for p in top)
        print(top_row)

        # 2. Print Middle Rows (Left and Right sides)
        for i in range(height):
            l_pad = left[i] if i < len(left) else None
            r_pad = right[i] if i < len(right) else None

            # Calculate spacing between left and right pads
            # Spacing depends on how many pads are on the top/bottom
            middle_gap = "     " * len(top)
            print(f"{fmt(l_pad)}{middle_gap}{fmt(r_pad)}")

        # 3. Print Bottom Row
        bottom_row = "      " + "".join(fmt(p) for p in bottom)
        print(bottom_row)
        print("\n")

    def print_pad_table(self):
        """
        Print a table representation of the pad ring layout in the console.
        """
        # ToDo_padspy: Do we still need this? Move to graphic module?
        print("\n")
        rows = {}
        for pad in self.pad_list:
            idx = pad.side_index
            if idx not in rows:
                rows[idx] = {
                    Side.LEFT: "",
                    Side.BOTTOM: "",
                    Side.RIGHT: "",
                    Side.TOP: "",
                }

            # Join all pin names for this specific pad into a string
            pin_names = (
                f"({pad.global_index}) " + ", ".join([pin.name for pin in pad.pins])
                if pad.pins
                else f"({pad.global_index}) " + pad.name
            )
            rows[idx][pad.side] = pin_names

        # Print Header
        header = f"{'Idx':<4} | {Side.LEFT.value:<40} | {Side.BOTTOM.value:<40} | {Side.RIGHT.value:<40} | {Side.TOP.value:<40}"
        print(header)
        print("-" * len(header))

        # Print Rows sorted by side_index
        for idx in sorted(rows.keys()):
            r = rows[idx]
            print(
                f"{idx:<4} | {r[Side.LEFT]:<40} | {r[Side.BOTTOM]:<40} | {r[Side.RIGHT]:<40} | {r[Side.TOP]:<40}"
            )
        print("\n")
