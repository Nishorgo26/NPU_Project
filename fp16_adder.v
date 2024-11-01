//  +--------------------------------------------------------------------------------------------------------------------+
//  |                                                                                                                    |
//  |   This module contains the logic to add two fp16 numbers. The Steps of                                             |
//  |   adding to fp16 numbers are:                                                                                      |
//  |                                                                                                                    |
//  |   1.  Decode the two numbers into sign - exponent - significand form.                                              |
//  |   2.  Subtract 15 from both exponents.                                                                             |
//  |   3.  Determine if the exponent match.                                                                             |
//  |   4.  If they dont match, Determine which exponent is greater.                                                     |
//  |       Also concat { 1, significand } to normalize values.                                                          |
//  |   5.  Depending on the greater exponent determine the smaller significand and the greater significand.             |
//  |       Note. The significand with the smaller exponent is the smaller significand                                   |
//  |   6.  Shift the smaller significand right by the amount equal to the (greater exponent - smaller exponent)         |
//  |       At the same time increase the smaller exponent by 1 to match the greater exponent.                           |
//  |   7.  When both exponents are same, Add the significands to get result significand. Depending on the carry bit     |
//  |       result significand may need to be shifted. In that case, add carry bit to exponents.                         |
//  |   8.  Take the greater exponent, add 15 and carry bit(if needed) to get the result exponent.                       |
//  |   9.  Take the sign bit of greater exponent as the result sign bit.                                                |
//  |   10. Concatanate the result sign bit, result exponent, result significand to get the final result.                |
//  |                                                                                                                    |
//  +--------------------------------------------------------------------------------------------------------------------+

module fp16_adder (
    input  wire        clk,
    input  wire        reset_b,
    input  wire        start_addition,
    input  wire [15:0] input_a,
    input  wire [15:0] input_b,
    input  wire        clear,

    output wire        valid,
    output wire [15:0] result
);

    wire [9:0]  significand_a;
    wire [9:0]  significand_b;
    wire [4:0]  exponent_a;
    wire [4:0]  exponent_b;
    wire        sign_bit_a;
    wire        sign_bit_b;
 
    wire        a_absolute_zero;
    wire        b_absolute_zero;
 
    wire        valid_operation;
    wire        exponent_match;
 
    wire        hidden_bit_a;
    wire        hidden_bit_b;
 
    wire        input_a_greater;
    wire        input_equal;

    wire [15:0] greater_input;
    wire [15:0] smaller_input;

    wire        greater_hidden_bit;
    wire        smaller_hidden_bit;

    wire        start_match;
    wire        operation;

    wire [11:0] added_result;
    wire [10:0] subtracted_result;

    wire        increamented_exponent_match;

    wire        shift_en;
    wire        load_shifter;

    wire [10:0] significand_shifter_d;
    wire [10:0] shifted_smaller_significand;

    wire [4:0]  greater_exponent;
    wire [4:0]  smaller_exponent;
    reg [4:0]  increamented_exponent;
    wire [10:0] value_1_significand;
    wire [10:0] value_2_significand;
    wire [4:0]  added_exponent;
    wire [9:0]  added_significand;
    wire        subtracted_result_zero;

    wire        load_subtracted_shifter;
    wire        shift_subtracted_shifter;
    reg [10:0] shifted_subtracted_result;

    wire        normalizer_start_condition;
    wire [15:0] result_int;
    wire        input_same_sign_different;

    assign significand_a[9:0] = input_a[9:0];
    assign significand_b[9:0] = input_b[9:0];
    assign exponent_a[4:0]    = input_a[14:10];
    assign exponent_b[4:0]    = input_b[14:10];
    assign sign_bit_a         = input_a[15];
    assign sign_bit_b         = input_b[15];

    assign a_absolute_zero    = ~|input_a[14:0];
    assign b_absolute_zero    = ~|input_b[14:0];

    assign exponent_match     = exponent_a[4:0] == exponent_b[4:0];
    assign significand_match  = significand_a[9:0] == significand_b[9:0];
    assign hidden_bit_a       = |exponent_a;
    assign hidden_bit_b       = |exponent_b;

    assign input_equal      = input_a[14:0] == input_b[14:0];
    assign input_a_greater  = input_a[14:0] > input_b[14:0];

    assign greater_input[15:0] = input_a_greater ? input_a[15:0] : input_b[15:0];
    assign smaller_input[15:0] = input_a_greater ? input_b[15:0] : input_a[15:0];
    assign greater_hidden_bit  = input_a_greater ? hidden_bit_a  : hidden_bit_b;
    assign smaller_hidden_bit  = input_a_greater ? hidden_bit_b  : hidden_bit_a;

    assign start_match = ~exponent_match;
    assign operation = sign_bit_a ^ sign_bit_b; // 1: Subtraction | 0: addition

    assign input_same_sign_different = operation & exponent_match & significand_match;
    assign valid_operation           = ~(a_absolute_zero | b_absolute_zero | input_same_sign_different);
//  +-----------------+
//  |    Adder FSM    |
//  +-----------------+

    localparam STATE_WIDTH = 3;
    reg  [STATE_WIDTH-1:0] nstate;
    wire [STATE_WIDTH-1:0] pstate;

    localparam [STATE_WIDTH-1:0] IDLE               = 3'b000,
                                 CHECK_MATCH        = 3'b001,
                                 SHIFT_SIGNIFICAND  = 3'b010,
                                 SIGNIFICAND_VALID  = 3'b011,
                                 NORMALIZER_LOAD    = 3'b100,
                                 NORMALIZER_SHIFT   = 3'b101,
                                 RESULT_VALID       = 3'b110,
                                 FINAL_VALID        = 3'b111;

    // Next state logic
    always @(*) begin
        casez( pstate )
            IDLE              : nstate[STATE_WIDTH-1:0] = start_addition               ? CHECK_MATCH       : IDLE;
            CHECK_MATCH       : nstate[STATE_WIDTH-1:0] = valid_operation              ? (start_match ? SHIFT_SIGNIFICAND : SIGNIFICAND_VALID ) : RESULT_VALID;
            SHIFT_SIGNIFICAND : nstate[STATE_WIDTH-1:0] = increamented_exponent_match  ? SIGNIFICAND_VALID : SHIFT_SIGNIFICAND;
            SIGNIFICAND_VALID : nstate[STATE_WIDTH-1:0] = operation                    ? ( normalizer_start_condition ? NORMALIZER_LOAD : RESULT_VALID ) : RESULT_VALID ;
            NORMALIZER_LOAD   : nstate[STATE_WIDTH-1:0] = NORMALIZER_SHIFT;
            NORMALIZER_SHIFT  : nstate[STATE_WIDTH-1:0] = shifted_subtracted_result[9] ? RESULT_VALID      : NORMALIZER_SHIFT;
            RESULT_VALID      : nstate[STATE_WIDTH-1:0] = FINAL_VALID;
            FINAL_VALID       : nstate[STATE_WIDTH-1:0] = clear                        ? IDLE              : FINAL_VALID;
            default           : nstate[STATE_WIDTH-1:0] = 'bx;
        endcase
    end

    // Present state register
    dff # (
        .FLOP_WIDTH  ( STATE_WIDTH ),
        .RESET_VALUE ( 1'b0 )
    ) u_psr (
        .clk        ( clk     ),
        .reset_b    ( reset_b ),
        .en         ( 1'b1    ),
        .d          ( nstate  ),
        .q          ( pstate  )
    );

    // Output logic
    assign shift_en     = pstate == SHIFT_SIGNIFICAND;
    assign load_shifter = (pstate == CHECK_MATCH & start_match);

    // assign significand_valid = exponent_match | ( pstate == VALID );

//  +---------------------------+
//  |    Significand Shifter    |
//  +---------------------------+

    assign significand_shifter_d[10:0] = { smaller_hidden_bit, smaller_input[9:0] };

    shift_register # (
        .FLOP_WIDTH ( 11 )
    ) u_significand_shifter (
        .clk       ( clk                         ),
        .reset_b   ( reset_b                     ),
        .load      ( load_shifter                ),
        .shift     ( shift_en                    ),
        .data_in   ( significand_shifter_d       ),
        .data_out  ( shifted_smaller_significand )
    );

//  +-----------------------------+
//  |    Exponent Increamentor    |
//  +-----------------------------+

    assign greater_exponent[4:0] = greater_input[14:10] - 4'd15;
    assign smaller_exponent[4:0] = smaller_input[14:10] - 4'd15;

    always @(posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            increamented_exponent[4:0] <= 5'b0;
        end
        else begin
            increamented_exponent[4:0] <= load_shifter ? smaller_exponent : increamented_exponent[4:0] + shift_en;
        end
    end

    assign increamented_exponent_match = increamented_exponent[4:0] == ( greater_exponent[4:0] - 1'b1);

//  +-----------------------------+
//  |    Value Adder Subtractor   |
//  +-----------------------------+

    // logic [4:0] extra_bit;


    assign value_1_significand[10:0] = { greater_hidden_bit, greater_input[9:0] };
    assign value_2_significand[10:0] = exponent_match ? { smaller_hidden_bit, smaller_input[9:0] } : shifted_smaller_significand[10:0];

    assign added_result[11:0]   = value_1_significand[10:0] + value_2_significand[10:0];
    assign added_exponent[4:0]  = greater_input[14:10] + added_result[11];

    assign added_significand[9:0] = added_result[11] ? added_result[10:1] : added_result[9:0];
    assign subtracted_result[10:0] = value_1_significand[10:0] - value_2_significand[10:0];

    assign subtracted_result_zero = ~|subtracted_result[10:0];

//  +--------------------------------------+
//  |    Subtracted result normalizer      | 
//  +--------------------------------------+
    wire   first_bit_not_normalized;
    assign first_bit_not_normalized = ~subtracted_result_zero & ~subtracted_result[10];
    assign normalizer_start_condition = first_bit_not_normalized & (pstate == SIGNIFICAND_VALID);

    assign load_subtracted_shifter  = pstate == NORMALIZER_LOAD;
    assign shift_subtracted_shifter = pstate == NORMALIZER_SHIFT;

    always @(posedge clk or negedge reset_b) begin
        if(~reset_b) begin
            shifted_subtracted_result[10:0] <= 'b0;
        end
        else begin
            casez ( { load_subtracted_shifter, shift_subtracted_shifter } )
                2'b00   : shifted_subtracted_result[10:0] <= shifted_subtracted_result[10:0];
                2'b01   : shifted_subtracted_result[10:0] <= { shifted_subtracted_result[9:0], 1'b0 };
                2'b10   : shifted_subtracted_result[10:0] <= subtracted_result[10:0];
                2'b11   : shifted_subtracted_result[10:0] <= subtracted_result[10:0];
                default : shifted_subtracted_result[10:0] <= 'bx;
            endcase
        end
    end

    wire   [4:0] subtracted_exponent;
    assign subtracted_exponent = greater_input[14:10];

    reg [4:0] increamented_subtracted_exponent;

    always @(posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            increamented_subtracted_exponent[4:0] <= 5'b0;
        end
        else begin
            increamented_subtracted_exponent[4:0] <= load_subtracted_shifter ? subtracted_exponent[4:0] : increamented_subtracted_exponent[4:0] - shift_subtracted_shifter;
        end
    end

//  +--------------------+
//  |    Output Logic    |
//  +--------------------+

    wire [4:0] result_exponent;
    wire [9:0] result_significand;
    wire       result_sign_bit;

    assign result_sign_bit = greater_input[15];

    mux_4x1 # (
        .PORT_WIDTH ( 5 )
    ) u_result_exponent_sel (
        .in0 ( added_exponent                        ),
        .in1 ( added_exponent                        ),
        .in2 ( subtracted_exponent                   ),
        .in3 ( increamented_subtracted_exponent      ),
        // .sel ( { operation, ~subtracted_result[10] } ),
        .sel ( { operation, first_bit_not_normalized } ),
        .out ( result_exponent                       )
    );

    mux_4x1 # (
        .PORT_WIDTH ( 10 )
    ) u_result_significand_sel (
        .in0 ( added_significand                     ),
        .in1 ( added_significand                     ),
        .in2 ( subtracted_result[9:0]               ),
        .in3 ( shifted_subtracted_result[9:0]       ),
        // .sel ( { operation, ~subtracted_result[10] } ),
        .sel ( { operation, first_bit_not_normalized } ),
        .out ( result_significand                    )
    );

    assign result_int[15:0] = { result_sign_bit, result_exponent, result_significand};

    wire [15:0] result_d_int;
    wire [15:0] result_d_after_valid_op_check;

    mux_4x1 # (
        .PORT_WIDTH ( 16 )
    ) u_result_sel (
        .in0 ( result_int   ),
        .in1 ( input_a      ),
        .in2 ( input_b      ),
        .in3 ( 16'b0        ),
        .sel ( { a_absolute_zero, b_absolute_zero } ),
        .out ( result_d_int )
    );

    assign result_d_after_valid_op_check[15:0] = input_same_sign_different ? 16'b0 : result_d_int[15:0];

    wire   valid_int;
    assign valid_int = pstate == RESULT_VALID;
    
    wire [15:0] result_d;
    wire [15:0] result_q;

    assign result_d[15:0] = valid_int ? result_d_after_valid_op_check[15:0] : result_q[15:0];

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

    assign valid = pstate == FINAL_VALID;


endmodule
