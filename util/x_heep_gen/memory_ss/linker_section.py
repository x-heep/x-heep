from typing import List, Optional
from .linker_subsection import LinkerSubsection


class LinkerSection:
    """
    Object representing a section in the linker configuration.

    If the end address is set to `None` it will be infered in the building process.
    """

    name: str
    """
    The name of the section
    
    The name can be anything that does not collide with section names used by the linker,
    except code and data that are used to configure the size of the code and data part.
    code and data do not only contain the actual .code and .data section but other related sections.
    """

    start: int
    """The start address"""

    end: Optional[int]
    """The end address"""

    subsections: List[LinkerSubsection]
    """The list of subsections that should be included in this section"""

    def __init__(
        self,
        name: str,
        start: int,
        end: Optional[int],
        subsections: Optional[List[LinkerSubsection]] = None,
    ):
        self.name = name
        self.start = start
        self.end = end
        # Default to a single input section with the same name as the region.
        self.subsections = (
            [LinkerSubsection(name, [name])]
            if subsections is None
            else list(subsections)
        )

        self.check()

    def __str__(self) -> str:
        return f"LinkerSection(name={self.name}, start=0x{self.start:08X}, end={'None' if self.end is None else f'0x{self.end:08X}'})"

    def check(self):
        """
        Does basic type checking and sanity checking.

        - Checks the type of all members
        - Checks that the name is not empty
        - Checks that the start address and size are positive

        :raise TypeError: when the type of a member is not the correct ine.
        :raise ValueError: when the name is empty or start or size are negative
        """
        if type(self.name) is not str:
            raise TypeError("name should be of type str")
        if type(self.start) is not int:
            raise TypeError("start should be of type int")
        if type(self.end) is not int and self.end is not None:
            raise TypeError("end should be of type int")
        if type(self.subsections) is not list:
            raise TypeError("subsections should be of type list")
        if not all(
            type(subsection) is LinkerSubsection for subsection in self.subsections
        ):
            raise TypeError("subsections should contain only LinkerSubsection objects")

        if self.name == "":
            raise ValueError("name should not be empty")
        if self.start < 0:
            raise ValueError("start address should be positif")
        if self.end is not None and self.end <= self.start:
            raise ValueError("end address should be bigger than the start address")

    @staticmethod
    def by_size(name: str, start: int, size: int) -> "LinkerSection":
        """
        Creates a Linker Section by it's size rather than end address.

        :param str name: the name of the section
        :param int start: the start address
        :param int size: the size of the section
        :return: the linker section
        :rtype: LinkerSection
        """
        if type(name) is not str:
            raise TypeError("name should be of type str")
        if type(start) is not int:
            raise TypeError("start should be of type int")
        if type(size) is not int:
            raise TypeError("size should be of type int")

        return LinkerSection(name, start, start + size)

    @property
    def size(self) -> Optional[int]:
        """The size in Bytes"""
        if self.end is not None:
            return self.end - self.start
        return None
