from typing import Optional


class LinkerScript:
    """
    Configuration for linker-script-managed runtime memory.

    If either stack_size or heap_size is omitted, it is inferred from the
    configured data linker region during XHeep.build().
    """

    _ALIGNMENT = 16

    def __init__(
        self, stack_size: Optional[int] = None, heap_size: Optional[int] = None
    ):
        self._stack_size = self._check_size("stack_size", stack_size)
        self._heap_size = self._check_size("heap_size", heap_size)

    @staticmethod
    def _check_size(name: str, size: Optional[int]) -> Optional[int]:
        if size is None:
            return None
        if type(size) is not int:
            raise TypeError(f"{name} should be an int")
        if size <= 0:
            raise ValueError(f"{name} should be strictly positive")
        return size

    @staticmethod
    def _align_down(size: int) -> int:
        return size - (size % LinkerScript._ALIGNMENT)

    def build(self, available_size: int):
        """
        Infer missing values from the data linker region size.

        When both values are omitted, half of the available data region is kept
        for static data/BSS and the other half is split equally between heap and
        stack. If only one value is omitted, half of the remaining space is used
        for the missing value.
        """
        if type(available_size) is not int:
            raise TypeError(
                "[MCU-GEN - LinkerScript] ERROR: available_size should be an int"
            )
        if available_size <= 0:
            raise ValueError(
                "[MCU-GEN - LinkerScript] ERROR: available_size should be strictly positive"
            )

        stack_size = self._stack_size
        heap_size = self._heap_size

        if stack_size is None and heap_size is None:
            inferred_size = self._align_down(available_size // 4)
            stack_size = inferred_size
            heap_size = inferred_size
        elif stack_size is None:
            stack_size = self._align_down((available_size - heap_size) // 2)
        elif heap_size is None:
            heap_size = self._align_down((available_size - stack_size) // 2)

        self._stack_size = stack_size
        self._heap_size = heap_size

    def validate(self, available_size: int):
        if self._stack_size is None or self._heap_size is None:
            raise RuntimeError(
                "[MCU-GEN - LinkerScript] ERROR: stack_size and heap_size must be configured or inferred"
            )
        if self._stack_size <= 0:
            raise ValueError(
                "[MCU-GEN - LinkerScript] ERROR: stack_size should be strictly positive"
            )
        if self._heap_size <= 0:
            raise ValueError(
                "[MCU-GEN - LinkerScript] ERROR: heap_size should be strictly positive"
            )
        if self._stack_size + self._heap_size > available_size:
            raise RuntimeError(
                "[MCU-GEN - LinkerScript] ERROR: "
                + "The stack and heap section must fit in the linker data region, "
                + f"instead they take {self._stack_size + self._heap_size} bytes "
                + f"while the data region size is {available_size} bytes."
            )

    def stack_size(self) -> int:
        if self._stack_size is None:
            raise RuntimeError(
                "[MCU-GEN - LinkerScript] ERROR: stack_size has not been configured or inferred"
            )
        return self._stack_size

    def heap_size(self) -> int:
        if self._heap_size is None:
            raise RuntimeError(
                "[MCU-GEN - LinkerScript] ERROR: heap_size has not been configured or inferred"
            )
        return self._heap_size
