module pad_cell_output #(
    parameter PADATTR = 16
) (
    input logic pad_in_i,
    input logic pad_oe_i,
    output logic pad_out_o,
    inout logic pad_io,
    input logic [PADATTR-1:0] pad_attributes_i
);

    sg13g2_IOPadOut4mA ihp_sg13g2_pad_out_inst (
        // `ifdef USE_POWER_PINS
        // .iovdd(),
        // .iovss(),
        // .vdd(),
        // .vss(),
        // `endif
        .pad(pad_io),
        .c2p(pad_out_o)
    );

endmodule
