from .Pad import Pad
from .Pin import Pin
from .Floorplan import FloorplanDimensions, Side, Orientation, SIDE_DEFAULT_ROTATION
from collections import Counter


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
        self.default_pin   = next((pin for pin in pin_list if hasattr(pin, "default")), None)
        self.build()

    def build(self):
        # The pad list will have one more item, then we will remove item 0.
        # This is simply because the standard is to number pads from 1 through N
        for global_index in range(1,len(self.pad_list)):
            self.pad_list[global_index] = Pad( global_index )

        # Assign pins to pads
        for pin in self.pin_list:
            if pin.pads != []:   [self.pad_list[padIdx].pins.append(pin) for padIdx in pin.pads]
            else:                 print(f"\033[33m Unconnected pin:\033[0m {pin.name}")
                
        # Build the pad list now that they have their assigned pins
        for pad in self.pad_list[1:]: pad.build(default_pin=self.default_pin)
        # In case of duplicate pad names (because the same pin is assigned to several pads)
        # rename them by adding an index
        self.rename_duplicate_pads()


    def space_side_by_pitch( self, side, space_from_corner_cell, pitch ):

        # Take only the pads from the selected side
        pads_sublist = [pad for pad in self.pad_list if pad.side == side]

        if any(p.side_index == None for p in pads_sublist):
            raise ValueError("All pads must have a side_index assigned")
        
        if pads_sublist[0].bondpad == None:
            raise ValueError("Sorry, we did not contemplate the possibility of starting the side with a cell without bondpad. \
                             But you can finish the side with one if you like :) ")

        # Get the distances to the margins
        side_iocell_margin  = self.floorplan_dimensions.iocell_margin[side]  
        side_bondpad_margin = self.floorplan_dimensions.bondpad_margin[side] 

        pads_sublist.sort(key=lambda x: x.side_index)

        # The first pad needs to be spaced a special distance from the corner cell.
        # Custom spacing to this cell can be given by changing this value
        pads_sublist[0].space               = space_from_corner_cell
        # We assume that the corner is the same width as the pad is high (wouldn't make much sense otherwise)
        corner_width   = pads_sublist[0].iocell.dimension.height
        # The center of this pad will be given by the distance from the ring's edge to the end of the corner,
        # the extra space, and half the pad's width
        pads_sublist[0].iocell_center_to_ring_edge = corner_width \
                                                        + space_from_corner_cell \
                                                        + pads_sublist[0].iocell.dimension.width/2

        # First compute each pad's position and spacing
        # We assume that the pitch was decided based on the bondpads
        for i,pad in enumerate(pads_sublist[1:]):
            # If a cell has already defined a hardcoded position, then respect that
            if pad.iocell_center_to_ring_edge != None:
                pad.space = (pad.iocell_center_to_ring_edge - pads_sublist[i].iocell_center_to_ring_edge) \
                            - (pads_sublist[i].iocell.dimension.width/2 + pads_sublist[i+1].iocell.dimension.width/2)
            else:
            # Otherwise compute the space based on the default pitch between bondpads.
            # Accept that PRCUTs will not have bondpads, and thus they do not need to respect the pitch.
                if pads_sublist[i+1].bondpad == None:
                    pad.space           = 0
                elif pads_sublist[i].bondpad == None:
                    last_prcut_width    = pads_sublist[i].iocell.dimension.width
                    gap                 = pads_sublist[i-1].iocell.dimension.width/2 \
                                            + last_prcut_width \
                                            + pads_sublist[i+1].iocell.dimension.width/2
                    pad.space           = max(pitch - gap, 0)
                else:
                    pad.space           = pitch \
                                            - (pads_sublist[i].iocell.dimension.width/2 \
                                            + pads_sublist[i+1].iocell.dimension.width/2)

            pad.iocell_center_to_ring_edge  = pads_sublist[i].iocell_center_to_ring_edge \
                                                + pad.space \
                                                + pads_sublist[i].iocell.dimension.width/2 \
                                                + pads_sublist[i+1].iocell.dimension.width/2

        # The first bondpad needs to be offset to be aligned to the cell pad
        last_bp                         = 0
        width_diff_bp_pc                = pads_sublist[0].iocell.dimension.width - pads_sublist[0].bondpad.dimension.width
        margin_diff                     = side_iocell_margin - side_bondpad_margin
        first_bp_offset                 = margin_diff + corner_width + space_from_corner_cell + width_diff_bp_pc/2
        pads_sublist[0].offset          = first_bp_offset
        pads_sublist[0].bp_space        = 0

        pads_sublist[0].bondpad_center_to_ring_edge = first_bp_offset + pads_sublist[0].bondpad.dimension.width/2

        for i,pad in enumerate(pads_sublist[1:]):
            pad_cell_center                 = pads_sublist[i+1].iocell_center_to_ring_edge
            bond_pad_center                 = pad_cell_center + margin_diff
            pad.bondpad_center_to_ring_edge = bond_pad_center

            if pad.layout.bond_pad.name is not None:
                distance                = bond_pad_center - pads_sublist[last_bp].bondpad_center_to_ring_edge
                space                   = distance \
                                            - pads_sublist[last_bp].bondpad.dimension.width/2 \
                                            - pad.bondpad.dimension.width/2
                pad.bp_space            = space
                last_bp                 = i+1


    def rename_duplicate_pads(self):
        # Pass 1: Handle missing names immediately
        for pad in self.pad_list:
            if not hasattr(pad, 'name') or pad.name is None:
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


def assign_to_side( pads_sublist, side ):
    # Layout indexes are counted clockwise (opposite to the convention)
    for idx, pad in enumerate(pads_sublist):
        pad.side        = side
        pad.side_index  = idx
        pad.orientation = SIDE_DEFAULT_ROTATION[side]
            



def print_pad_frame(pads):
    print("\n")
    # Separate pads by their mapping
    top     = sorted([p for p in pads if p.mapping == Side.TOP],       key=lambda x: x.layout_index, reverse=True)
    bottom  = sorted([p for p in pads if p.mapping == Side.BOTTOM],    key=lambda x: x.layout_index, reverse=False)
    left    = sorted([p for p in pads if p.mapping == Side.LEFT],      key=lambda x: x.layout_index, reverse=False)
    right   = sorted([p for p in pads if p.mapping == Side.RIGHT],     key=lambda x: x.layout_index, reverse=True)

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


def print_pad_table(pads):
    print("\n")
    rows = {}
    for pad in pads:
        idx = pad.layout_index
        if idx not in rows:
            rows[idx] = {Side.LEFT: '', Side.BOTTOM: '', Side.RIGHT: '', Side.TOP: ''}

        # Join all pin names for this specific pad into a string
        pin_names = f"({pad.global_index}) "+", ".join([pin[0] for pin in pad.alts]) if pad.alts else f"({pad.global_index}) "+ pad.name
        rows[idx][pad.mapping] = pin_names

    # Print Header
    header = f"{'Idx':<4} | {Side.LEFT.value:<40} | {Side.BOTTOM.value:<40} | {Side.RIGHT.value:<40} | {Side.TOP.value:<40}"
    print(header)
    print("-" * len(header))

    # Print Rows sorted by layout_index
    for idx in sorted(rows.keys()):
        r = rows[idx]
        print(f"{idx:<4} | {r[Side.LEFT]:<40} | {r[Side.BOTTOM]:<40} | {r[Side.RIGHT]:<40} | {r[Side.TOP]:<40}")
    print("\n")