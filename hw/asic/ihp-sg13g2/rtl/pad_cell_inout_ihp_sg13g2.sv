module pad_cell_inout #(
    parameter PADATTR = 16
) (
    input logic pad_in_i,
    input logic pad_oe_i,
    output logic pad_out_o,
    inout logic pad_io,
    input logic [PADATTR-1:0] pad_attributes_i
);

    (* keep *)
    sg13g2_IOPadInOut4mA pad_cell_inout (
        // `ifdef USE_POWER_PINS
        // .iovdd(),
        // .iovss(),
        // .vdd(),
        // .vss(),
        // `endif
        .pad(pad_io),
        .c2p(pad_in_i),
        .c2p_en(pad_oe_i),
        .p2c(pad_out_o)
    );

endmodule
