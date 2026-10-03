module pad_cell_vdd (
    `ifdef USE_POWER_PINS
    inout logic iovdd,
    inout logic iovss,
    inout logic vdd,
    inout logic vss
    `endif
);

    (* keep *)
    sg13g2_IOPadVdd pad_cell_vdd (
        `ifdef USE_POWER_PINS
        .iovdd,
        .iovss,
        .vdd,
        .vss
        `endif
    );

endmodule

module pad_cell_vss (
    `ifdef USE_POWER_PINS
    inout logic iovdd,
    inout logic iovss,
    inout logic vdd,
    inout logic vss
    `endif
);

    (* keep *)
    sg13g2_IOPadVss pad_cell_vss (
        `ifdef USE_POWER_PINS
        .iovdd,
        .iovss,
        .vdd,
        .vss
        `endif
    );

endmodule

module pad_cell_iovdd (
    `ifdef USE_POWER_PINS
    inout logic iovdd,
    inout logic iovss,
    inout logic vdd,
    inout logic vss
    `endif
);

    (* keep *)
    sg13g2_IOPadIOVdd pad_cell_iovdd (
        `ifdef USE_POWER_PINS
        .iovdd,
        .iovss,
        .vdd,
        .vss
        `endif
    );

endmodule

module pad_cell_iovss (
    `ifdef USE_POWER_PINS
    inout logic iovdd,
    inout logic iovss,
    inout logic vdd,
    inout logic vss
    `endif
);

    (* keep *)
    sg13g2_IOPadIOVss pad_cell_iovss (
        `ifdef USE_POWER_PINS
        .iovdd,
        .iovss,
        .vdd,
        .vss
        `endif
    );

endmodule
