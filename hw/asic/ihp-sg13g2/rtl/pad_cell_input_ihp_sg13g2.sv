module pad_cell_input #(
    parameter PADATTR = 16
) (
    input logic pad_in_i,
    input logic pad_oe_i,
    output logic pad_out_o,
    inout logic pad_io,
    input logic [PADATTR-1:0] pad_attributes_i
);

    (* keep *)
    sg13g2_IOPadIn pad_cell_input (
        // `ifdef USE_POWER_PINS
        // .iovdd(),
        // .iovss(),
        // .vdd(),
        // .vss(),
        // `endif
        .pad(pad_io),
        .p2c(pad_out_o)
    );

endmodule
