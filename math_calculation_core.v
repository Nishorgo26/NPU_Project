// This block will contain calculator block and activcation function
module math_calculation_core # (
    `include "npu_params.v"
)(
    input  wire                      clk,                    // System clock
    input  wire                      reset_b,                // System reset
    input  wire                      calculator_start,       // Calculator FSM start
    input  wire                      sigmoid_start,          // Sigmoid activator start
    input  wire [NPU_DATA_WIDTH-1:0] input_value,            // Layer Input value
    input  wire [NPU_DATA_WIDTH-1:0] weight_value,           // Layer Weight value

    output wire                      calculator_valid,       // Calculated output valid    
    output wire                      sigmoid_valid,          // Sigmoid output valid
    output wire [NPU_DATA_WIDTH-1:0] calculation_result      // Calculation result after sigmoid
);

    wire                      sigmoid_valid_int;
    wire [NPU_DATA_WIDTH-1:0] sigmoid_result;
    wire [NPU_DATA_WIDTH-1:0] calculated_result;

    wire [NPU_DATA_WIDTH-1:0] neuron_value_d;
    wire [NPU_DATA_WIDTH-1:0] neuron_value_q;

    neural_arithmetic_unit u_neural_arithmetic_unit (
        .clk                ( clk                  ),
        .reset_b            ( reset_b              ),
        .calculator_start   ( calculator_start     ),
        .input_value        ( input_value          ),
        .weight_value       ( weight_value         ),
        .calculator_clear   ( sigmoid_valid_int    ),
        .calculator_valid   ( calculator_valid     ),
        .calculator_result  ( calculated_result    )
    );

    sigmoid_activator u_sigmoid_activator (
        .clk            ( clk                ),
        .reset_b        ( reset_b            ),
        .neuron_val     ( calculated_result  ),
        .add_activation ( sigmoid_start      ),
        .valid          ( sigmoid_valid_int  ),
        .result         ( sigmoid_result     )
    );

    assign neuron_value_d[NPU_DATA_WIDTH-1:0] = sigmoid_valid_int ? sigmoid_result[NPU_DATA_WIDTH-1:0] : neuron_value_q[NPU_DATA_WIDTH-1:0];

    dff # (
        .FLOP_WIDTH  ( 16    ),
        .RESET_VALUE ( 16'h0 )
    ) u_neuron_reg (
        .clk        ( clk                                ),
        .reset_b    ( reset_b                            ),
        .en         ( 1'b1                               ),
        .d          ( neuron_value_d[NPU_DATA_WIDTH-1:0] ),
        .q          ( neuron_value_q[NPU_DATA_WIDTH-1:0] )
    );

    dff # (
        .FLOP_WIDTH  ( 1    ),
        .RESET_VALUE ( 1'b0 )
    ) u_sigmoid_valid_reg (
        .clk        ( clk                ),
        .reset_b    ( reset_b            ),
        .en         ( 1'b1               ),
        .d          ( sigmoid_valid_int  ),
        .q          ( sigmoid_valid      )
    );

    assign calculation_result[NPU_DATA_WIDTH-1:0] = neuron_value_q[NPU_DATA_WIDTH-1:0];

endmodule
