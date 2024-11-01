module significand_handler # (
    parameter BIT_WIDTH = 10
)(
    input  wire                     clk,
    input  wire                     reset_b,
    input  wire                     start,
    input  wire [BIT_WIDTH-1:0]     input_a,
    input  wire [BIT_WIDTH-1:0]     input_b,
    input  wire                     hidden_bit_a,
    input  wire                     hidden_bit_b,
    input  wire                     sign_bit,
    
    output wire [BIT_WIDTH-1:0]     result,
    output wire                     valid,
    output wire                     significand_msb
);

    wire [2*BIT_WIDTH+1:0] value_a_d;
    wire [BIT_WIDTH:0]     value_b_d;
    wire [2*BIT_WIDTH+1:0] value_a_d_int;
    wire [BIT_WIDTH:0]     value_b_d_int;
    reg  [2*BIT_WIDTH+1:0] value_a_q;
    wire [BIT_WIDTH:0]     value_b_q;

    assign value_a_d[2*BIT_WIDTH+1:0] = { 11'b0, hidden_bit_a, input_a[BIT_WIDTH-1:0] };
    assign value_b_d[BIT_WIDTH:0]     = { hidden_bit_b, input_b[BIT_WIDTH-1:0] };
    
    wire       shift_cntr_en;
    wire       shift_limit_reached;
    wire [3:0] shift_count;

    counter#(
        .FLOP_WIDTH ( 4 )
    ) u_shift_counter (
        .clk      ( clk                 ),
        .reset_b  ( reset_b             ),
        .up_count ( 1'b1                ),
        .dn_count ( 1'b0                ),
        .clear    ( shift_limit_reached ),
        .enable   ( shift_cntr_en       ),
        .count    ( shift_count         )
    );

    assign shift_limit_reached = shift_count[3:0] == 11;

    // logic multiplication_complete;
    // assign multiplication_complete = ~|value_b_q;
    
//  +---------------------+
//  |    State Machine    |
//  +---------------------+

    // State variables
    localparam STATE_WIDTH = 2;
    reg [STATE_WIDTH-1:0] pstate, nstate;
    
    // State declaration
    localparam [STATE_WIDTH-1:0] IDLE   = 2'b00,
                                 CHECK  = 2'b01,
                                 VALID  = 2'b10;
                                 
    // Next state logic
    always @(*) begin
        casez( pstate )
            IDLE    : nstate[STATE_WIDTH-1:0] = start               ? CHECK : IDLE;
            CHECK   : nstate[STATE_WIDTH-1:0] = shift_limit_reached ? VALID : CHECK;
            VALID   : nstate[STATE_WIDTH-1:0] = IDLE;
            default : nstate[STATE_WIDTH-1:0] = 'bx;
        endcase
    end
    
    //Present State Register
    dff # (
        .FLOP_WIDTH  ( STATE_WIDTH ),
        .RESET_VALUE ( IDLE        )
    ) u_psr (
        .clk        ( clk     ),
        .reset_b    ( reset_b ),
        .en         ( 1'b1    ),
        .d          ( nstate  ),
        .q          ( pstate  )
    );
    
    assign shift_cntr_en = pstate == CHECK;

//  +------------------------------+
//  |    Value A Shift Register    |
//  +------------------------------+

    wire       value_a_load;
    wire       value_a_shift_en;
    
    assign value_a_load     = ( pstate == IDLE ) & start | ( pstate == VALID );
    assign value_a_shift_en = ( pstate == CHECK );
    
    assign value_a_d_int[2*BIT_WIDTH+1:0] = pstate == VALID ? 'b0 : value_a_d[2*BIT_WIDTH+1:0];
    
    always @(posedge clk or negedge reset_b) begin
        if(~reset_b) begin
            value_a_q[2*BIT_WIDTH+1:0] <= 'b0;
        end
        else begin
            casez ( { value_a_load, value_a_shift_en } )
                2'b00   : value_a_q[2*BIT_WIDTH+1:0] <= value_a_q[2*BIT_WIDTH+1:0];
                2'b01   : value_a_q[2*BIT_WIDTH+1:0] <= { value_a_q[2*BIT_WIDTH:0], 1'b0 };
                2'b10   : value_a_q[2*BIT_WIDTH+1:0] <= value_a_d_int[2*BIT_WIDTH+1:0];
                2'b11   : value_a_q[2*BIT_WIDTH+1:0] <= value_a_d_int[2*BIT_WIDTH+1:0];
                default : value_a_q[2*BIT_WIDTH+1:0] <= 'bx;
            endcase
        end
    end

    // shift_register # (
    //     .FLOP_WIDTH ( 2*BIT_WIDTH+2 )
    // ) u_value_a_shifter (
    //     .clk        ( clk              ),
    //     .reset_b    ( reset_b          ),
    //     .load       ( value_a_load     ),
    //     .shift      ( value_a_shift_en ),
    //     .data_in    ( value_a_d_int    ),
    //     .data_out   ( value_a_q        )
    // );
        
//  +------------------------------+
//  |    Value B Shift Register    |
//  +------------------------------+

    wire       value_b_load;
    wire       value_b_shift_en;
    
    assign value_b_load      = ( pstate == IDLE ) & start | ( pstate == VALID );
    assign value_b_shift_en  = ( pstate == CHECK );

    assign value_b_d_int[BIT_WIDTH:0] = pstate == VALID ? 'b0 : value_b_d[BIT_WIDTH:0];

    shift_register # (
        .FLOP_WIDTH ( BIT_WIDTH+1 )
    ) u_value_b_shifter (
        .clk        ( clk              ),
        .reset_b    ( reset_b          ),
        .load       ( value_b_load     ),
        .shift      ( value_b_shift_en ),
        .data_in    ( value_b_d_int    ),
        .data_out   ( value_b_q        )
    );

//  +----------------------+
//  |    Quotiont Adder    |
//  +----------------------+

    wire                   quotiont_adder_en;
    wire [2*BIT_WIDTH+1:0] quotiont_d;
    wire [2*BIT_WIDTH+1:0] quotiont_d_int;
    wire [2*BIT_WIDTH+1:0] quotiont_q;
    
    assign quotiont_adder_en               = ( pstate == CHECK ) & value_b_q[0];
    assign quotiont_d[2*BIT_WIDTH+1:0]     = quotiont_adder_en ? quotiont_q[2*BIT_WIDTH+1:0] + value_a_q[2*BIT_WIDTH+1:0] : quotiont_q[2*BIT_WIDTH+1:0];
    assign quotiont_d_int[2*BIT_WIDTH+1:0] = pstate == VALID ? 'b0 : quotiont_d[2*BIT_WIDTH+1:0];

//  +-------------------------+
//  |    Quotiont Register    |
//  +-------------------------+
    
    dff # (
        .FLOP_WIDTH ( 2*BIT_WIDTH+2 )
    ) u_quotiont_reg (
        .clk        ( clk            ),
        .reset_b    ( reset_b        ),
        .en         ( 1'b1           ),
        .d          ( quotiont_d_int ),
        .q          ( quotiont_q     )
    );
    
    wire [BIT_WIDTH-1:0] result_int;
    wire                 guard_bit;
    wire                 round_bit;
    wire                 sticky_bit;
    wire                 halfway_case;

    assign halfway_case = ({ guard_bit, round_bit, sticky_bit } == 3'b100);
    
    assign result_int[BIT_WIDTH-1:0] = quotiont_q[2*BIT_WIDTH+1] ? quotiont_q[2*BIT_WIDTH:BIT_WIDTH+1] : quotiont_q[2*BIT_WIDTH-1:BIT_WIDTH];
    assign guard_bit                 = quotiont_q[2*BIT_WIDTH+1] ? quotiont_q[BIT_WIDTH]   : quotiont_q[BIT_WIDTH-1];
    assign round_bit                 = quotiont_q[2*BIT_WIDTH+1] ? quotiont_q[BIT_WIDTH-1] : quotiont_q[BIT_WIDTH-2];
    assign sticky_bit                = quotiont_q[2*BIT_WIDTH+1] ? quotiont_q[BIT_WIDTH-2] : quotiont_q[BIT_WIDTH-3];
    assign result[BIT_WIDTH-1:0]     = halfway_case ? ( result_int[0] ? result_int[BIT_WIDTH-1:0] + guard_bit : result_int[BIT_WIDTH-1:0]) : result_int[BIT_WIDTH-1:0] + guard_bit;
    assign valid                     = pstate == VALID;
    assign significand_msb           = quotiont_q[2*BIT_WIDTH+1];
    
endmodule
//               9876543210
// 01 1110010000 0111111101
//              A9876543210
// 1 0010101001 10010011010
// 01 1010100110 1011100100
