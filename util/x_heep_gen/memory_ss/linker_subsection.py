from typing import List


class LinkerSubsection:
    """
    Object representing a subsection in the linker configuration.
    It's a group of input sections that are placed together in the same linker section.

    If the end address is set to `None` it will be infered in the building process.
    """

    name: str
    """The main name of the subsection"""

    subsections_names: List[str]
    """
    The names of the subsections
    
    The name can be anything that does not collide with subsection names used by the linker,
    except code and data that are used to configure the size of the code and data part.
    code and data do not only contain the actual .code and .data section but other related sections.

    If None, it defaults to [name]
    """

    provide_start: bool
    """Provides the start compile time address"""

    provide_end: bool
    """Provides the end compile time address"""

    def __init__(
        self,
        name: str,
        subsections_names: List[str] = None,
        provide_start: bool = False,
        provide_end: bool = False,
    ):
        self.name = name
        # Default to a single input section with the same name as the region.
        self.subsections_names = (
            [name] if subsections_names is None else list(subsections_names)
        )
        self.provide_start = provide_start
        self.provide_end = provide_end

        self.check()

    def check(self):
        """
        Does basic type checking and sanity checking.

        - Checks the type of all members
        - Checks that the subsection list is not empty
        - Checks that all subsection names are non-empty strings

        :raise TypeError: when the type of a member is not the correct one.
        :raise ValueError: when the names list is empty or contains empty names
        """
        if type(self.name) is not str:
            raise TypeError("name should be of type str")
        if type(self.subsections_names) is not list:
            raise TypeError("subsections_names should be of type list")
        if not all(type(subsection) is str for subsection in self.subsections_names):
            raise TypeError("subsections_names should contain only strings")
        if type(self.provide_start) is not bool:
            raise TypeError("provide_start should be of type bool")
        if type(self.provide_end) is not bool:
            raise TypeError("provide_end should be of type bool")

        if len(self.subsections_names) == 0:
            raise ValueError("subsections_names should not be empty")
        if any(subsection == "" for subsection in self.subsections_names):
            raise ValueError("subsections_names should not contain empty strings")
