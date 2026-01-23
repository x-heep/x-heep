class Pin:

    def __init__(
        self,
        name,
        attached_pads=[],
        attributes={},
    ):
        self.name = name
        self.attached_pads = attached_pads
        self.attributes = attributes


class PinDigital(Pin):
    def __init__(self, name, attached_pads, attributes):
        super().__init__(name, attached_pads, attributes)
        self.properties = {}
        self.pad_cell = f"u_pad_cell_{self.type.value}/pad_{self.type.value}_i"