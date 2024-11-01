module fp16_multiplier_alt (
    input  wire        clk,
    input  wire        reset_b,
    input  wire [15:0] input_a,
    input  wire [15:0] input_b,
    input  wire        start,
    
    output wire        valid,
    output wire [15:0] result
);
    
    wire [9:0] significand_a;
    wire [9:0] significand_b;
    wire       sign_bit_a;
    wire       sign_bit_b;   
    wire [4:0] exponent_a;
    wire [4:0] exponent_b;

//  +------------------------+
//  |    Sign Bit Handler    |
//  +------------------------+

    wire result_sign_bit;
    wire a_or_b_zero;

    assign sign_bit_a = input_a[15];
    assign sign_bit_b = input_b[15];
    
    assign result_sign_bit = a_or_b_zero ? 'b0 : sign_bit_a ^ sign_bit_b;

//  +---------------------------+
//  |    Significand Handler    |
//  +---------------------------+

    wire       hidden_bit_a;
    wire       hidden_bit_b;
    wire [9:0] result_significand;
    wire       significand_msb;
    
    assign significand_a[9:0] = input_a[9:0];
    assign significand_b[9:0] = input_b[9:0];

    assign hidden_bit_a = |exponent_a;
    assign hidden_bit_b = |exponent_b;

    wire a_absolute_zero;
    wire b_absolute_zero;

    assign a_absolute_zero = ( ~|significand_a  ) & ( ~|exponent_a );
    assign b_absolute_zero = ( ~|significand_b  ) & ( ~|exponent_b );

    
    assign a_or_b_zero = a_absolute_zero | b_absolute_zero;

    wire valid_int;

    significand_handler # (
        .BIT_WIDTH  ( 10 )
    ) u_significand_handler (
        .clk             ( clk                ),
        .reset_b         ( reset_b            ),
        .start           ( start              ),
        .sign_bit        ( result_sign_bit    ),
        .hidden_bit_a    ( hidden_bit_a       ),
        .hidden_bit_b    ( hidden_bit_b       ),
        .input_a         ( significand_a      ),
        .input_b         ( significand_b      ),
        .result          ( result_significand ),
        .valid           ( valid_int          ),
        .significand_msb ( significand_msb    )
    );
    
//  +------------------------+
//  |    Exponent Handler    |
//  +------------------------+

    wire [4:0] result_exponent;
    
    assign exponent_a[4:0] = input_a[14:10];
    assign exponent_b[4:0] = input_b[14:10];
    
    exponent_handler # (
        .EXPONENT_WIDTH ( 5 )
    ) u_exponent_handler (
        .exponent_a         ( exponent_a      ),
        .exponent_b         ( exponent_b      ),
        .a_or_b_zero        ( a_or_b_zero     ),
        .significand_msb    ( significand_msb ),
        .resultant_exponent ( result_exponent )
    );
    
//  +--------------------+
//  |    Output Logic    |
//  +--------------------+
    wire [15:0] result_d;
    wire [15:0] result_q;

    assign result_d[15:0] = valid_int ? { result_sign_bit, result_exponent, result_significand } : result_q[15:0];

    dff # (
        .FLOP_WIDTH ( 16 ),
        .RESET_VALUE ( 1'b0 )
    ) u_result_reg (
        .clk        ( clk        ),
        .reset_b    ( reset_b    ),
        .en         ( 1'b1       ),
        .d          ( result_d   ),
        .q          ( result_q   )
    );

    assign result[15:0] = result_q[15:0];

    dff # (
        .FLOP_WIDTH ( 1 ),
        .RESET_VALUE ( 1'b0 )
    ) u_valid_reg (
        .clk        ( clk        ),
        .reset_b    ( reset_b    ),
        .en         ( 1'b1       ),
        .d          ( valid_int  ),
        .q          ( valid      )
    );

endmodule
