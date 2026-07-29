from enum import Enum


class ReliabilityMode(Enum):
    """Reliability combinations currently supported by X-HEEP."""

    NONE = "none"
    BUS_REDUNDANT = "bus_redundant"
    MEMORY_ECC = "memory_ecc"
    BUS_AND_MEMORY_ECC = "bus_and_memory_ecc"


class Reliability:
    """Reliability configuration for an X-HEEP system.

    The mode describes the supported bus/memory combinations.  Future tuning
    options (for example peripheral or core TMR) can be added to this class
    without changing the XHeep constructor or passing unrelated flags to it.
    """

    def __init__(self, mode=ReliabilityMode.NONE):
        if not isinstance(mode, ReliabilityMode):
            raise TypeError(
                "Reliability.mode should be of type ReliabilityMode, "
                f"not {type(mode)}"
            )
        self._mode = mode

    @property
    def mode(self) -> ReliabilityMode:
        return self._mode

    @property
    def bus_redundant(self) -> bool:
        return self.mode in (
            ReliabilityMode.BUS_REDUNDANT,
            ReliabilityMode.BUS_AND_MEMORY_ECC,
        )

    @property
    def memory_ecc(self) -> bool:
        return self.mode in (
            ReliabilityMode.MEMORY_ECC,
            ReliabilityMode.BUS_AND_MEMORY_ECC,
        )

    def __bool__(self) -> bool:
        """Keep aggregate checks safe while templates migrate to properties."""

        return self.mode is not ReliabilityMode.NONE
