module pad_cell_output #(
    parameter PADATTR = 0
) (
    `ifdef USE_POWER_PINS
    inout logic iovdd,
    inout logic iovss,
    inout logic vdd,
    inout logic vss,
    `endif
    input logic pad_in_i,
    input logic pad_oe_i,
    output logic pad_out_o,
    inout logic pad_io,
    input logic [PADATTR-1:0] pad_attributes_i
);

    (* keep *)
    sg13g2_IOPadOut4mA pad_cell_output (
        `ifdef USE_POWER_PINS
        .iovdd,
        .iovss,
        .vdd,
        .vss,
        `endif
        .pad(pad_io),
        .c2p(pad_in_i)
    );

endmodule
