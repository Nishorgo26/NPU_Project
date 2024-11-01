module neural_arithmetic_unit #(
    `include "npu_params.v"
) (
    input  wire                      clk,                  // System clock
    input  wire                      reset_b,              // System reset
            
    input  wire                      calculator_start,     // Calculator FSM start
    input  wire [NPU_DATA_WIDTH-1:0] input_value,          // Layer Input value
    input  wire [NPU_DATA_WIDTH-1:0] weight_value,         // Layer Weight value
    input  wire                      calculator_clear,     // Clear signal for the calculated result register

    output wire                      calculator_valid,     // Calculator result is valid
    output wire [NPU_DATA_WIDTH-1:0] calculator_result     // Calculator result
);

    wire multiplier_valid;
    wire adder_valid;

    wire [NPU_DATA_WIDTH-1:0] added_result_reg_d;
    wire [NPU_DATA_WIDTH-1:0] added_result_reg_q;

//  +----------------------+
//  |    Calculator FSM    |
//  +----------------------+

    localparam STATE_WIDTH = 2;
    reg  [STATE_WIDTH-1:0] nstate;
    wire [STATE_WIDTH-1:0] pstate;

    localparam [STATE_WIDTH-1:0] IDLE               = 2'b00,
                                 MULTIPLY           = 2'b01,
                                 ADDITION           = 2'b10,
                                 VALID              = 2'b11;

    // Next State Logic
    always @(*) begin
        casez( pstate )
            IDLE      : nstate[STATE_WIDTH-1:0] = calculator_start    ? MULTIPLY : IDLE;
            MULTIPLY  : nstate[STATE_WIDTH-1:0] = multiplier_valid    ? ADDITION : MULTIPLY;
            ADDITION  : nstate[STATE_WIDTH-1:0] = adder_valid         ? VALID    : ADDITION;
            VALID     : nstate[STATE_WIDTH-1:0] = IDLE;
            default   : nstate[STATE_WIDTH-1:0] = 'bx;
        endcase
    end

    // Present state register
    dff # (
        .FLOP_WIDTH  ( STATE_WIDTH ),
        .RESET_VALUE ( IDLE )
    ) u_psr (
        .clk        ( clk     ),
        .reset_b    ( reset_b ),
        .en         ( 1'b1    ),
        .d          ( nstate  ),
        .q          ( pstate  )
    );

//  +---------------------------------------------------+
//  |    Multiplication results from fp16_multiplier    |
//  +---------------------------------------------------+

    wire [NPU_DATA_WIDTH-1:0] multiplier_result;

//  +-------------------------+
//  |    Multiplier Blocks    |
//  +-------------------------+

    wire   multiplier_start;
    assign multiplier_start = ( pstate == IDLE ) & calculator_start;

    fp16_multiplier u_multiplier  (
        .clk        ( clk                                   ),
        .reset_b    ( reset_b                               ),
        .input_a    ( input_value                           ),
        .input_b    ( weight_value                          ),
        .start      ( multiplier_start                      ),
        .valid      ( multiplier_valid                      ),
        .result     ( multiplier_result[NPU_DATA_WIDTH-1:0] )
    );

//  +----------------------+
//  |    Addition block    |
//  +----------------------+

    wire [NPU_DATA_WIDTH-1:0] adder_result;
    
//  +-------------+
//  |    Adder    |
//  +-------------+

    wire   addition_start;
    assign addition_start = ( pstate == MULTIPLY ) & multiplier_valid;

    fp16_adder u_fp16_adder (
        .clk            ( clk                                     ),
        .reset_b        ( reset_b                                 ),
        .clear          ( adder_valid                             ),
        .start_addition ( addition_start                          ),
        .input_a        ( multiplier_result[NPU_DATA_WIDTH-1:0]   ),
        .input_b        ( added_result_reg_q[NPU_DATA_WIDTH-1:0]  ),
        .valid          ( adder_valid                             ),
        .result         ( adder_result[NPU_DATA_WIDTH-1:0]        )
    );

//  +-----------------------------+
//  |    Added Result Register    |
//  +-----------------------------+

    wire   added_result_wr_en;
    assign added_result_wr_en = ( pstate == ADDITION ) & adder_valid;

    wire   [1:0] added_result_reg_d_sel;
    assign       added_result_reg_d_sel[1:0] = { calculator_clear, added_result_wr_en };

    mux_4x1 # (
        .PORT_WIDTH ( NPU_DATA_WIDTH )
    ) u_mux_4x1 (
        .in0 ( added_result_reg_q[NPU_DATA_WIDTH-1:0] ),
        .in1 ( adder_result[NPU_DATA_WIDTH-1:0]       ),
        .in2 ( 16'b0                                  ),
        .in3 ( 16'b0                                  ),
        .sel ( added_result_reg_d_sel[1:0]            ),
        .out ( added_result_reg_d[NPU_DATA_WIDTH-1:0] )
    );

    dff # (
        .FLOP_WIDTH  ( NPU_DATA_WIDTH ),
        .RESET_VALUE ( 16'b0          )
    ) u_added_result_reg (
        .clk        ( clk                      ),
        .reset_b    ( reset_b                  ),
        .en         ( 1'b1                     ),
        .d          ( added_result_reg_d[NPU_DATA_WIDTH-1:0] ),
        .q          ( added_result_reg_q[NPU_DATA_WIDTH-1:0] )
    );

    assign calculator_result[NPU_DATA_WIDTH-1:0] = added_result_reg_q[NPU_DATA_WIDTH-1:0];
    assign calculator_valid                      = pstate == VALID;
    
endmodule
