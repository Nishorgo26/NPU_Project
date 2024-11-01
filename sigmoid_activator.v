module sigmoid_activator (
    input  wire        clk,
    input  wire        reset_b,
    input  wire [15:0] neuron_val,
    input  wire        add_activation,

    output wire        valid,
    output wire [15:0] result      
);

wire        multiplier_valid;
wire        adder_valid;
wire        subtractor_valid;

//  +--------------------------------+
//  |    extraction of fp16 parts    |
//  +--------------------------------+

wire        sign_bit;
wire  [4:0] exponent;
wire  [9:0] significand;

assign {sign_bit, exponent[4:0], significand[9:0]} = neuron_val[15:0];


//  +------------------------------+
//  |    significand comparator    |
//  +------------------------------+

wire  msb;
wire  msb_2;
wire  less_than_p375;
wire  greater_than_p375;

assign msb               = significand[9];
assign msb_2             = significand[8];
assign less_than_p375    = significand[8:0] < 9'd384;
assign greater_than_p375 = significand[8:0] >= 9'd384; 


//  +---------------------------+
//  |    exponent comparator    |
//  +---------------------------+

wire  less_than_15;
wire  equal_to_15;
wire  equal_to_16;
wire  equal_to_17;
wire  greater_than_17;

assign less_than_15    = exponent <  5'd15;
assign equal_to_15     = exponent == 5'd15;
assign equal_to_16     = exponent == 5'd16;
assign equal_to_17     = exponent == 5'd17;
assign greater_than_17 = exponent >  5'd17;


//  +---------------------------------------------------------+
//  |    peicewise linear approximation range specification   |
//  +---------------------------------------------------------+

localparam RANGE_WIDTH = 4;

wire [RANGE_WIDTH-1:0] range;

//range: 0 to 1
assign range[0] = less_than_15;
//range: 1 to 2.375
assign range[1] = (~msb & equal_to_16 & less_than_p375)    | equal_to_15;
//range: 2.375 to 5
assign range[2] = (~msb & equal_to_16 & greater_than_p375) | (msb & equal_to_16) | (~msb_2 & ~msb & equal_to_17);
//range: 5 to infinity
assign range[3] = ((msb_2|msb) & equal_to_17)              | greater_than_17;    


//  +----------------------+
//  |    4 to 2 encoder    |
//  +----------------------+

reg [1:0]  func_select;

always @ (*) begin
    casez (range[3:0])
        4'b0001: func_select = 2'b00;
        4'b001?: func_select = 2'b01;
        4'b01??: func_select = 2'b10;
        4'b1???: func_select = 2'b11;
        default: func_select = 'bx;
    endcase
end


//  +--------------------------------------------+
//  |    multiplication factor selector mux41    |
//  +--------------------------------------------+

reg [15:0] multi_factor;

always @ (*) begin
    casez (func_select)
        2'b00:   multi_factor = 16'h3400;
        2'b01:   multi_factor = 16'h3000;
        2'b10:   multi_factor = 16'h2800;
        2'b11:   multi_factor = 16'h0001;
        default: multi_factor = 'bx;
    endcase
end


//  +--------------------------------------+
//  |    addition factor selector mux41    |
//  +--------------------------------------+

reg [15:0] add_factor;

always @ (*) begin
    casez (func_select)
        2'b00:   add_factor = 16'h3800;
        2'b01:   add_factor = 16'h3900;
        2'b10:   add_factor = 16'h3ac0;
        2'b11:   add_factor = 16'h3c00;
        default: add_factor = 'bx;
    endcase
end


//  +-------------------------------+
//  |    activation function FSM    |
//  +-------------------------------+

localparam STATE_WIDTH = 3;

wire [STATE_WIDTH-1:0] pstate; 
reg  [STATE_WIDTH-1:0] nstate;

localparam [STATE_WIDTH-1:0] IDLE             = 3'b000,
                             MULTIPLIER_START = 3'b001,
                             WAIT_1           = 3'b010,
                             ADDER_START      = 3'b011,
                             WAIT_2           = 3'b100,
                             SUBTRACTOR_START = 3'b101,
                             WAIT_3           = 3'b110,
                             VALID            = 3'b111;

// Present state register
dff # (
    .FLOP_WIDTH  ( STATE_WIDTH ),
    .RESET_VALUE ( IDLE        )
) u_psr (
    .clk         ( clk         ),
    .reset_b     ( reset_b     ),
    .en          ( 1'b1        ),
    .d           ( nstate      ),
    .q           ( pstate      )
);

// Next state logic
always @(*) begin
    casez( pstate )
        IDLE             : nstate[STATE_WIDTH-1:0] = add_activation   ? MULTIPLIER_START : IDLE;
        MULTIPLIER_START : nstate[STATE_WIDTH-1:0] = WAIT_1;
        WAIT_1           : nstate[STATE_WIDTH-1:0] = multiplier_valid ? ADDER_START                               : WAIT_1;
        ADDER_START      : nstate[STATE_WIDTH-1:0] = WAIT_2;
        WAIT_2           : nstate[STATE_WIDTH-1:0] = adder_valid      ? (sign_bit ? SUBTRACTOR_START : VALID)     : WAIT_2;
        SUBTRACTOR_START : nstate[STATE_WIDTH-1:0] = WAIT_3;
        WAIT_3           : nstate[STATE_WIDTH-1:0] = subtractor_valid ? VALID                                     : WAIT_3;
        // VALID            : nstate[STATE_WIDTH-1:0] = ~add_activation  ? IDLE                                      : VALID;
        VALID            : nstate[STATE_WIDTH-1:0] = IDLE;//                                      : VALID;
        default          : nstate[STATE_WIDTH-1:0] = 'bx;
    endcase
end

// Output logic
wire  start_multiplier;
wire  start_adder;
wire  start_subtractor;

wire  adder_clear;
wire  subtractor_clear;

assign adder_clear = ( pstate == WAIT_2 ) & adder_valid;
assign subtractor_clear = ( pstate == WAIT_3 ) & subtractor_valid;

assign start_multiplier = (pstate == MULTIPLIER_START);
assign start_adder      = (pstate == ADDER_START);
assign start_subtractor = (pstate == SUBTRACTOR_START);

assign valid            = (pstate == VALID);

//  +-------------------------------------------------------+
//  |    piecewise linear approximation function handler    |
//  +-------------------------------------------------------+

wire [15:0] m_to_a;
wire [15:0] result_pos;
wire [15:0] result_neg;

fp16_multiplier factor_multiplier(
    .clk            ( clk                      ),
    .reset_b        ( reset_b                  ),
    .input_a        ( neuron_val               ),
    .input_b        ( multi_factor             ),
    .start          ( start_multiplier         ),
    
    .valid          ( multiplier_valid         ),
    .result         ( m_to_a                   )
);

fp16_adder factor_adder(
    .clk            ( clk                      ),
    .reset_b        ( reset_b                  ),
    .start_addition ( start_adder              ),
    .input_a        ( m_to_a                   ),
    .input_b        ( add_factor               ),
    .clear          ( adder_clear              ),
    .valid          ( adder_valid              ),
    .result         ( result_pos               )
);      

fp16_adder negative_neuron_value_function(
    .clk            ( clk                      ),
    .reset_b        ( reset_b                  ),
    .start_addition ( start_subtractor         ),
    .input_a        ( 16'h3c00                 ),
    .input_b        ( {1'b1, result_pos[14:0]} ),
    .clear          ( subtractor_clear         ),
    .valid          ( subtractor_valid         ),
    .result         ( result_neg               )
);

assign result[15:0] = valid ? (sign_bit ? result_neg[15:0] : result_pos[15:0]) : 16'd0;

endmodule
