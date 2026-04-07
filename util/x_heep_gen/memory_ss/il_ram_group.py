from typing import List
from .ram_bank import Bank


class ILRamGroup:
    """
    Represents information about a group of interleaved memory banks.
    """

    start: int
    """start address of the group"""

    size: int
    """size of the group"""

    n: int
    """number of banks in the group"""

    group_name: str
    """name of the IL banks group"""

    id: int
    """id of the group, used to generate the name of the banks"""

    banks: List[Bank]

    def __init__(
        self, start: int, size: int, n: int, group_name: str, id: int, banks: List[Bank]
    ):
        self.start = start
        self.size = size
        self.n = n
        self.group_name = group_name
        self.id = id
        self.banks = banks

    def __str__(self) -> str:
        return f"ILRamGroup(start=0x{self.start:08X}, size={self.size:08X}, n={self.n}, group_name={self.group_name}, id={self.id})"
