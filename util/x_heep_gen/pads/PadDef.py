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




class PadActive(Enum):
    HIGH = "high"
    LOW = "low"




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




##############################################
# PIN CLASSES

class Physical(Pin):
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

##############################################
# GENERATE A LIST OF ALL POSSIBLE PADS
# These do not include physical blocks yet

