from typing import Dict, List, Optional, Iterable, Tuple, Mapping, Any
from enum import Enum
from dataclasses import dataclass, field
from collections import Counter



class ValidationError(ValueError):
    """Exception raised when pad configuration validation fails."""
    pass


class PadType(Enum):
    INPUT = "input"
    OUTPUT = "output"
    INOUT = "inout"
    BYPASS_INPUT = "bypass_input"
    BYPASS_OUTPUT = "bypass_output"
    BYPASS_INOUT = "bypass_inout"
    SUPPLY = "supply"


class PadMapping(Enum):
    TOP = "top"
    RIGHT = "right"
    BOTTOM = "bottom"
    LEFT = "left"


class Orientation(Enum):
    """
    Physical orientation/rotation of pad cell.

    Values:
        R0: No rotation (0 degrees)
        R90: 90 degree rotation
        R180: 180 degree rotation
        R270: 270 degree rotation
        MX: Mirror around X axis
        MY: Mirror around Y axis
        MX90: Mirror X + 90 degree rotation
        MY90: Mirror Y + 90 degree rotation
    """

    R0 = "R0"
    R90 = "R90"
    R180 = "R180"
    R270 = "R270"
    MX = "MX"
    MY = "MY"
    MX90 = "MX90"
    MY90 = "MY90"


class PadActive(Enum):
    HIGH = "high"
    LOW = "low"


VALID_TYPES = {t.value for t in PadType}

VALID_ORIENTATIONS = {o.value for o in Orientation}.union({None})
VALID_MAPPINGS = {m.value for m in PadMapping}

VALID_ACTIVES = {a.value for a in PadActive}




@dataclass(frozen=True)
class Dimension:
    """
    Physical dimension specification for pads.

    Attributes:
        width: Width in micrometers (required)
        name: Optional name identifier for this dimension
        length: Optional length in micrometers

    Raises:
        ValidationError: If width or length are negative
    """

    width: int
    name: Optional[str] = None
    length: Optional[int] = None

    def __post_init__(self):
        if self.width < 0 or (self.length and self.length < 0):
            raise ValidationError(
                f"Dimension: width and length must be positive. Got width={self.width}, length={self.length}"
            )

@dataclass
class Layout:
    """
    Physical layout attributes for a pad.

    Attributes:
        bond_pad: Optional bond pad dimensions
        cell_pad: Optional cell pad dimensions
        offset: Optional offset from edge in micrometers
        skip: Optional spacing to next pad in micrometers
    """

    bond_pad: Optional[Dimension] = None
    cell_pad: Optional[Dimension] = None
    offset: Optional[float] = None
    skip: Optional[float] = None

    def copy(self):
        """
        Create a shallow copy of this Layout.

        :return: New Layout instance with same attributes
        :rtype: Layout
        """
        return Layout(
            bond_pad=self.bond_pad,
            cell_pad=self.cell_pad,
            offset=self.offset,
            skip=self.skip,
        )


@dataclass(frozen=False)
class PadDef:
    """
    Configuration-time pad description.

    This is the user-facing representation of a pad, containing logical
    information about the pad's purpose, direction, and configuration.
    Physical details (indices, banks) are computed later by PadRing.

    Attributes:
        name: Unique pad name (required)
        type: Pad type/direction (required)
        mapping: Physical edge placement (top/bottom/left/right)
        layout_index: Index for ordering pads on same edge
        layout: Physical layout attributes
        layers: Optional list of metal layers
        properties: Additional key-value properties
        active: Active level (high/low)
        orient: Physical orientation
        driven_manually: Whether pad is manually driven (not auto-generated)
        keep_internal: Whether to keep internal signals
        skip: Whether to skip this pad
        constant_attribute: Whether pad has constant attributes

    Raises:
        ValidationError: If validation fails (invalid type, mapping, orientation,
                        or if bond_pad defined without cell_pad)
    """

    name: str
    type: PadType
    mapping: Optional[PadMapping] = None
    layout_index: Optional[int] = 0
    layout: Optional[Layout] = None
    layers: Optional[List[str]] = None
    properties: Dict[str, Any] = field(default_factory=dict)
    active: Optional[str] = PadActive.HIGH.value
    orient: Optional[Orientation] = None
    driven_manually: Optional[bool] = False
    keep_internal: Optional[bool] = None
    skip: Optional[bool] = None
    constant_attribute: Optional[bool] = None

    def __post_init__(self):
        # _assert_type(self.type, f"PadDef '{self.name}'")
        # _assert_mapping(self.mapping, f"PadDef '{self.name}'")
        # _assert_orientation(self.orient, f"PadDef '{self.name}'")
        if self.layout is not None:
            self.layout = (
                self.layout.copy() if isinstance(self.layout, Layout) else None
            )
        if (
            self.layout is not None
            and self.layout.bond_pad is not None
            and self.layout.cell_pad is None
        ):
            raise ValidationError(
                f"PadDef '{self.name}': bond_pad is defined but cell_pad is not."
            )

    def is_bond_pad_defined(self) -> bool:
        """Check if bond pad dimensions are defined."""
        return self.layout.bond_pad is not None

    def is_cell_pad_defined(self) -> bool:
        """Check if cell pad dimensions are defined."""
        return self.layout.cell_pad is not None


@dataclass(frozen=False)
class MultiplexedPad(PadDef):
    """
    Pad with multiple mux options.

    Allows a single physical pad to be configured for different functions
    at runtime via multiplexing.

    Attributes:
        alts: List of (alternative_name, alternative_PadDef) tuples

    Example:
        MultiplexedPad(
            name="pad_mux_0",
            type=PadType.INOUT,
            alts=[("spi_mosi", spi_pad), ("gpio_5", gpio_pad)]
        )
    """

    alts: Optional[List[Tuple[str, PadDef]]] = None  # List of (alt_name, alt_type)



##############################################
# Default PAD and BONDPAD and PHYSICALS' layouts

bp_a            = Dimension(width=20, length=30, name="BP_ANALOG")
bp_d            = Dimension(width=20, length=30, name="BP_DIGITAL")

pad_d           = Dimension(width=25, length=32, name="PAD_DIGITAL")
pad_clk         = Dimension(width=25, length=32, name="PAD_CLOCK")
pad_dVdd        = Dimension(width=25, length=32, name="PAD_DVDD")
pad_ioVdd       = Dimension(width=25, length=32, name="PAD_IOVDD")
pad_ioPoc       = Dimension(width=25, length=32, name="PAD_IOPOC")
pad_dVss        = Dimension(width=25, length=32, name="PAD_DVSS")
pad_ioVss       = Dimension(width=25, length=32, name="PAD_IOVSS")

pad_a           = Dimension(width=20, length=32, name="PAD_ANALOG")
pad_aVdd        = Dimension(width=20, length=32, name="PAD_AVDD")
pad_aVss        = Dimension(width=20, length=32, name="PAD_AVSS")

aPrcut          = Dimension(width=25, length=32, name="APRCUT")
aPrcut          = Dimension(width=25, length=32, name="DPRCUT")

aCorner         = Dimension(width=32, length=32, name="ACORNER")
dCorner         = Dimension(width=32, length=32, name="DCORNER")

bp_skip         = Dimension(width=20, length=30, name=None)
pad_skip        = Dimension(width=20, length=32, name=None)


##############################################
# PIN CLASSES

class PinDigital(PadDef):
    def __init__(self, name, pads, attr):
        global bp_d, pad_d
        self.name       = name
        self.layout     = Layout( bond_pad=bp_d, cell_pad=pad_d )
        self.properties = {}
        self.pads       = pads
        for key, value in attr.items(): setattr(self, key, value)
        self.pad_cell   = f"u_pad_cell_{self.type.value}/pad_{self.type.value}_i"

class Input(PinDigital):
    def __init__(self, name, pads, attr):
        self.type = PadType.INPUT
        super().__init__(name, pads, attr)

class Output(PinDigital):
    def __init__(self, name, pads, attr):
        self.type = PadType.OUTPUT
        super().__init__(name, pads, attr)

class Inout(PinDigital):
    def __init__(self, name, pads, attr):
        self.type = PadType.INOUT
        super().__init__(name, pads, attr)

class PinSupply(PadDef):
    def __init__(self, name, pads, attr):
        self.name       = name
        self.properties = {}
        self.pads       = pads
        self.type       = PadType.SUPPLY
        for key, value in attr.items(): setattr(self, key, value)
        if not hasattr(self,"pad_cell"):
            self.pad_cell = "u_pad_cell_supply/pad_supply_i"

class DVdd(PinSupply):
    def __init__(self, name, pads, attr):
        global bp_d, pad_dVdd
        self.layout = Layout(bond_pad=bp_d, cell_pad=pad_dVdd)
        super().__init__(name, pads, attr)

class DVddIO(PinSupply):
    def __init__(self, name, pads, attr):
        global bp_d, pad_ioVdd
        self.layout = Layout(bond_pad=bp_d, cell_pad=pad_ioVdd)
        super().__init__(name, pads, attr)

class DVddPOC(PinSupply):
    def __init__(self, name, pads, attr):
        global bp_d, pad_ioPoc
        self.layout = Layout(bond_pad=bp_d, cell_pad=pad_ioPoc)
        super().__init__(name, pads, attr)

class DVss(PinSupply):
    def __init__(self, name, pads, attr):
        global bp_d, pad_dVss
        self.layout = Layout(bond_pad=bp_d, cell_pad=pad_dVss)
        super().__init__(name, pads, attr)

class PinAnalog(PadDef):
    def __init__(self, name, pads, attr):
        self.name               = name
        self.properties         = {}
        self.pads               = pads
        self.type               = PadType.SUPPLY
        self.driven_manually    = True
        for key, value in attr.items(): setattr(self, key, value)

class AVdd(PinAnalog):
    def __init__(self, name, pads, attr):
        global bp_d, pad_aVdd
        self.layout = Layout(bond_pad=bp_a, cell_pad=pad_aVdd)
        self.pad_cell   = "u_pad_cell_analog_vdd"
        super().__init__(name, pads, attr)

class AVss(PinAnalog):
    def __init__(self, name, pads, attr):
        global bp_d, pad_aVss
        self.layout     = Layout(bond_pad=bp_a, cell_pad=pad_aVss)
        self.pad_cell   = "u_pad_cell_analog_vss"
        super().__init__(name, pads, attr)

class Asignal(PinAnalog):
    def __init__(self, name, pads, attr):
        global bp_d, pad_a
        self.layout     = Layout(bond_pad=bp_a, cell_pad=pad_a)
        self.pad_cell   = f"u_pad_cell_analog"
        super().__init__(name, pads, attr)

class Physical(PadDef):
    def __init__(self, name, layout, side, orient, layout_index, offset=None, space=None, bp_space=None ):
        self.name               = name
        self.layout             = layout
        self.mapping            = side
        self.orient             = orient
        self.layout_index       = layout_index
        self.global_index       = 0
        self.alts               = []
        self.type               = PadType.SUPPLY
        self.driven_manually    = True
        self.offset             = offset
        self.space              = space
        self.bp_space           = bp_space
        self.pad_cell           = "u_pad_cell_supply/pad_supply_i"

class Pad(PadDef):

    def __init__(self, global_index):
        self.global_index   = global_index
        self.alts           = []
        self.alts           = []
        self.offset         = 0
        self.space          = None
        self.bp_space       = None

    def fix_assignment(self, default_pin):
        if   len(self.alts) == 0:
            self.alts.append((default_pin.name,default_pin))
            print(f"\033[31m Floating pad:\033[0m {self.global_index}, assigining to {default_pin.name}")

        self.alts = sorted( self.alts,
                                key=lambda pin: (getattr(pin, 'priority', None) or -self.alts.index(pin)),
                                reverse=True )

        self.flatten_attr(self.alts[0][1])

        if self.alts and all(p[1].type == self.alts[0][1].type for p in self.alts):
            self.type = self.alts[0][1].type
        else:
            self.type = PadType.INOUT
        if isinstance(self.alts[0][1], PinDigital):
            self.pad_cell   =f"u_pad_cell_{self.type.value}/pad_{self.type.value}_i"

        if len(self.alts) > 1:
            self.__class__ = MultiplexedPad
        else:
            self.__class__ = type(self.alts[0][1])
        print(f"{self.global_index}: {[a[0] for a in self.alts]} | {self.type} = {self.pad_cell}")

    def flatten_attr(self, pin):
        for key, value in vars(pin).items():
            setattr(self, key, value)
                # if not hasattr(self, key) or getattr(self, key) is None:


##############################################
# GENERATE A LIST OF ALL POSSIBLE PADS
# These do not include physical blocks yet

def generate_padlist(pins, PAD_QTY, default_pin):
    # The pad list will have one more item, then we will remove item 0.
    # This is simply because the standard is to number pads from 1 through N
    pads = [None]
    for global_index in range(1,PAD_QTY+1):
        pads.append( Pad( global_index ) )

    # ASSIGN PINS TO PADS
    for pin in pins.values():
        if pin.pads == []: print(f"\033[33m Unconnected pin:\033[0m {pin.name}")
        else:
            for padIdx in pin.pads:
                pads[padIdx].alts.append((pin.name,pin))
                # print(f"appended {pin.name} in {pads[padIdx].global_index}")

    # check if any of them was left floating
    # (not connected to any pin)
    for pad in pads[1:]:
        pad.fix_assignment(default_pin)

    rename_duplicate_pads(pads[1:])
    return pads

def rename_duplicate_pads(pads):
    # Pass 1: Handle missing names immediately
    for pad in pads:
        if not hasattr(pad, 'name') or pad.name is None:
            pad.name = f"NC_{getattr(pad, 'global_index', 'unknown')}"

    # Pass 2: Count frequencies of the now-populated names
    counts = Counter(pad.name for pad in pads)

    # Pass 3: Apply indexing only to duplicates
    seen_track = {}

    for pad in pads:
        original_name = pad.name

        if counts[original_name] > 1:
            # Increment tracking for this specific name
            seen_track[original_name] = seen_track.get(original_name, 0) + 1

            # Apply the _x suffix
            pad.name = f"{original_name}_{seen_track[original_name]}"

def assign_to_side( pads_sublist, side ):
    # Layout indexes are counted clockwise (opposite to the convention)
    for idx, pad in enumerate(pads_sublist):
        pad.mapping = side
        if side == PadMapping.TOP:
            pad.layout_index    = idx
            pad.orient          = Orientation.R0
        elif side == PadMapping.RIGHT:
            pad.layout_index    = idx
            pad.orient          = Orientation.R270
        elif side == PadMapping.BOTTOM:
            pad.layout_index    = idx
            pad.orient          = Orientation.R180
        elif side == PadMapping.LEFT:
            pad.layout_index    = idx
            pad.orient          = Orientation.R90

def space_by_pitch( pads_sublist, margins, space_from_corner, pitch ):

    # Get the distances to the margins
    side_io_margin  = margins[4]    # pad margin
    side_bp_margin  = margins[3]    # bondpad margin
    pads_sublist.sort(key=lambda x: x.layout_index)
    # We assume that the corner is the same length af the pad (wouldnt make much sense otherwise)
    corner_length   = pads_sublist[0].layout.cell_pad.length

    # The first pad needs to be spaced a special qty from the corner cell.
    # Custom spacing to this cell can be given by changing this value
    pads_sublist[0].space               = space_from_corner
    # The center of this pad will be given by the distance from the ring's edge to the end of the corner,
    # the extra space, and half the pad's width
    pads_sublist[0].pc_center_from_ring = corner_length+space_from_corner + pads_sublist[0].layout.cell_pad.width/2

    # First compute each pad's position and spacing
    # We assume that the pitch was decided based on the bondpads
    for i,pad in enumerate(pads_sublist[1:]):
        # If a cell has already defined a hardcoded position, then respect that
        if hasattr(pad,"pc_center_from_ring"):
            space = (pad.pc_center_from_ring - pads_sublist[i].pc_center_from_ring) - (pads_sublist[i].layout.cell_pad.width/2 + pads_sublist[i+1].layout.cell_pad.width/2)
        else:
        # Otherwise compute the space based on the default pitch between bondpads.
        # Accept that PRCUTs will not have bondpads, and thus they do not need to respect the pitch.
            if "PRCUT" in pads_sublist[i+1].name:
                space               = 0
            elif "PRCUT" in pads_sublist[i].name:
                last_prcut_width    = pads_sublist[i].layout.cell_pad.width
                gap                 =  pads_sublist[i-1].layout.cell_pad.width/2 + last_prcut_width + pads_sublist[i+1].layout.cell_pad.width/2
                space               = max(pitch - gap, 0)
            else:
                space               = pitch - (pads_sublist[i].layout.cell_pad.width/2 + pads_sublist[i+1].layout.cell_pad.width/2)

        pad.space               = space
        pad.pc_center_from_ring = ( pads_sublist[i].pc_center_from_ring + pad.space + pads_sublist[i].layout.cell_pad.width/2 + pads_sublist[i+1].layout.cell_pad.width/2 )


    # The first bondpad needs to be offset to be aligned to the cell pad
    last_bp                         = 0
    width_diff_bp_pc                = pads_sublist[0].layout.cell_pad.width - pads_sublist[0].layout.bond_pad.width
    margin_diff                     = side_io_margin - side_bp_margin
    first_bp_offset                 = margin_diff + corner_length + space_from_corner + width_diff_bp_pc/2
    pads_sublist[0].offset          = first_bp_offset
    pads_sublist[0].bp_space        = 0

    # Just make sure the ring does not start with a prcut!
    pads_sublist[0].bp_center_from_ring   = first_bp_offset + pads_sublist[0].layout.bond_pad.width/2

    for i,pad in enumerate(pads_sublist[1:]):
        pad_cell_center             = pads_sublist[i+1].pc_center_from_ring
        bond_pad_center             = pad_cell_center + margin_diff
        pad.bp_center_from_ring     = bond_pad_center

        if pad.layout.bond_pad.name is not None:
            distance                = bond_pad_center - pads_sublist[last_bp].bp_center_from_ring
            space                   = distance - pads_sublist[last_bp].layout.bond_pad.width/2 - pad.layout.bond_pad.width/2
            pad.bp_space            = space
            last_bp                 = i+1


def print_pad_frame(pads):
    print("\n")
    # Separate pads by their mapping
    top     = sorted([p for p in pads if p.mapping == PadMapping.TOP],       key=lambda x: x.layout_index, reverse=True)
    bottom  = sorted([p for p in pads if p.mapping == PadMapping.BOTTOM],    key=lambda x: x.layout_index, reverse=False)
    left    = sorted([p for p in pads if p.mapping == PadMapping.LEFT],      key=lambda x: x.layout_index, reverse=False)
    right   = sorted([p for p in pads if p.mapping == PadMapping.RIGHT],     key=lambda x: x.layout_index, reverse=True)

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
            rows[idx] = {PadMapping.LEFT: '', PadMapping.BOTTOM: '', PadMapping.RIGHT: '', PadMapping.TOP: ''}

        # Join all pin names for this specific pad into a string
        pin_names = f"({pad.global_index}) "+", ".join([pin[0] for pin in pad.alts]) if pad.alts else f"({pad.global_index}) "+ pad.name
        rows[idx][pad.mapping] = pin_names

    # Print Header
    header = f"{'Idx':<4} | {PadMapping.LEFT.value:<40} | {PadMapping.BOTTOM.value:<40} | {PadMapping.RIGHT.value:<40} | {PadMapping.TOP.value:<40}"
    print(header)
    print("-" * len(header))

    # Print Rows sorted by layout_index
    for idx in sorted(rows.keys()):
        r = rows[idx]
        print(f"{idx:<4} | {r[PadMapping.LEFT]:<40} | {r[PadMapping.BOTTOM]:<40} | {r[PadMapping.RIGHT]:<40} | {r[PadMapping.TOP]:<40}")
    print("\n")