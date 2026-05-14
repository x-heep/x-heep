def is_pow2(n: int) -> bool:
    """
    check if n is a power of two

    :param int n: number to be checked
    :return: True if n is a power of two
    :rtype: bool
    """
    return n > 0 and (n & (n - 1)) == 0


class Bank:
    """
    Represents a ram bank

    :param int size_k: size in kiB
    :param int start_address: start address of the bank, in interleaved mode it should be the start address od the whole group
    :param int map_idx: index in the global address map. Has to be unique. Interleaved mode banks should have consecutive indices.
    :param int il_level: number of bits used for interleaving.
    :param int il_offset: position in interleaved bank group if in any else 0. Should be consistent with map_idx.
    :raise TypeError: when parameters don't have the right type.
    :raise ValueError: when size_k isn't a power of two.
    :raise ValueError: when start_address is not aligned on size.
    :raise ValueError: when il_offset is to big for the given il_level().
    """

    def __init__(
        self,
        size_k: int,
        start_address: int,
        map_idx: int,
        il_level: int = 0,
        il_offset: int = 0,
    ):
        if not type(size_k) is int:
            raise TypeError("Bank size should be an int")

        if not type(start_address) is int:
            raise TypeError("Start address should be an int")

        if not type(map_idx) is int:
            raise TypeError("map_idx size should be an int")

        if not type(il_level) is int:
            raise TypeError("il_level should be an int")

        if not type(il_offset) is int:
            raise TypeError("il_offset size should be an int")

        self._size_k: int = size_k
        self._start_address: int = start_address
        self._map_idx: int = map_idx
        self._il_level: int = il_level
        self._il_offset: int = il_offset

        # check if power of 2
        if not is_pow2(self._size_k):
            raise ValueError(
                f"Bank size {self._size_k}kiB is not a positive power of two"
            )

        if self._il_offset >= 2**self._il_level:
            raise ValueError(f"il_offset is to big for an il_level of {self._il_level}")

        mask = 0b11
        if not self._start_address & mask == 0:
            raise ValueError(f"start_address is not aligned on word size")

        # TODO: Validate start address

        self._end_address = (
            self._start_address + self._size_k * 1024 * 2**self._il_level
        )

    def __str__(self) -> str:
        return f"Bank(size_k={self._size_k}, start_address=0x{self._start_address:08X}, end_address=0x{self._end_address:08X}, map_idx={self._map_idx}, il_level={self._il_level}, il_offset={self._il_offset})"

    def size(self) -> int:
        """
        :return: the bank size in Bytes
        :rtype: int
        """
        return self._size_k * 1024

    def name(self) -> str:
        """
        :return: the bank name
        :rtype: str
        """
        return str(self._map_idx - 1)  # TODO: do something better

    def start_address(self) -> int:
        """
        :return: the start address
        :rtype: int
        """
        return self._start_address

    def end_address(self) -> int:
        """
        :return: the end address
        :rtype: int
        """
        return self._end_address

    def map_idx(self) -> int:
        """
        :return: the index used in global bus
        :rtype: int
        """
        return self._map_idx

    def il_level(self) -> int:
        """
        :return: the number of bits used to choose the bank when it is in an interleaved group else 0
        :rtype: int
        """
        return self._il_level

    def il_offset(self) -> int:
        """
        :return: the position of the bank in an interleaved group.
        :rtype: int
        """
        return self._il_offset
