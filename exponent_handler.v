module exponent_handler # (
    parameter EXPONENT_WIDTH = 5
) (
    input   wire   [EXPONENT_WIDTH-1:0] exponent_a,
    input   wire   [EXPONENT_WIDTH-1:0] exponent_b,
    input   wire                        significand_msb,
    input   wire                        a_or_b_zero,
    output  wire   [EXPONENT_WIDTH-1:0] resultant_exponent
);

    wire [EXPONENT_WIDTH:0] sum;

    assign  sum                 [EXPONENT_WIDTH:0]   = { 1'b0, exponent_a[EXPONENT_WIDTH-1:0] } + { 1'b0, exponent_b[EXPONENT_WIDTH-1:0] } - 6'd15 + {5'd0, significand_msb};
    assign  resultant_exponent  [EXPONENT_WIDTH-1:0] = a_or_b_zero ? 'b0 : sum[EXPONENT_WIDTH-1:0];

endmodule
