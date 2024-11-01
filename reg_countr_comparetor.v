module reg_cntr_cmprtr #(
    `include "npu_params.v"
) (
    input  wire                          clk         ,
    input  wire                          reset_b     ,

    input  wire                          initialization   ,
    input  wire [1:0]                    mode   ,
    input  wire [1:0]                    layer_postion  ,   //From fsm
    output  wire                         load,
    input  wire                          first_preload,


    input  wire                          inner_preload,
    input  wire                          outter_clear,
    input  wire                          activion_valid,

    input wire [NPU_DATA_WIDTH - 1 : 0 ] douta ,
    input wire [NPU_DATA_WIDTH - 1 : 0 ] doutb ,

    input wire [NPU_DATA_WIDTH - 1 : 0 ] layer_number ,
    input wire [NPU_DATA_WIDTH - 1 : 0 ] input_number ,

    output wire [NPU_DATA_WIDTH - 1 : 0 ] inner_count ,
    output wire [NPU_DATA_WIDTH - 1 : 0 ] weight_count ,
    output wire [NPU_DATA_WIDTH - 1 : 0 ] neurons_of_current_working_layer,

    output wire  inner_cycle_match ,
    output wire  outer_cycle_match 
    
);
    
    wire  [NPU_DATA_WIDTH - 1 : 0 ]  inputs_of_current_working_layer;

    dff# (.FLOP_WIDTH (NPU_DATA_WIDTH),.RESET_VALUE(1'b0)) u31_dff  (.clk(clk),.reset_b(reset_b),.en(initialization   ),.d(douta),.q(inputs_of_current_working_layer  ) );
    dff# (.FLOP_WIDTH (NPU_DATA_WIDTH),.RESET_VALUE(1'b0)) u32_dff  (.clk(clk),.reset_b(reset_b),.en(initialization   ),.d(doutb),.q(neurons_of_current_working_layer  ) );

    wire  [NPU_DATA_WIDTH - 1 : 0 ]  outer_count;

    counter_m #(
        .FLOP_WIDTH ( 16 )
    )outer_counter(
        .clk           ( clk           ),
        .reset_b       ( reset_b       ),
        .enable        ( outer_enable  ),
        .direction     ( 1'b1          ),
        .preload       ( 1'b0          ),
        .preload_value ( 16'b0         ),
        .clear         ( outter_clear  ),
        .count         ( outer_count   )
    );
    
    wire [NPU_DATA_WIDTH - 1 : 0 ] inner_preload_value ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] weight_preload_value ;
     
    counter_m#(
        .FLOP_WIDTH    ( 16 ),
        .RESET_VALUE   ( 'b0 )
    )inner_counter(
        .clk           ( clk           ),
        .reset_b       ( reset_b       ),
        .enable        ( inner_enable        ),
        .direction     ( 1'b1          ),
        .preload       ( inner_preload),
        .preload_value ( inner_preload_value ),
        .clear         ( 1'b0         ),
        .count         ( inner_count   )
    );

    counter_m#(
        .FLOP_WIDTH    ( 16 ),
        .RESET_VALUE   ( 0 )
    )weight_counter(
        .clk           ( clk           ),
        .reset_b       ( reset_b       ),
        .enable        ( weight_enable      ),
        .direction     ( 1'b1                   ),
        .preload       ( first_preload         ),
        .preload_value ( weight_preload_value   ),
        .clear         ( weight_clear           ),
        .count         ( weight_count           )
    );


    assign weight_preload_value = input_number+layer_number;
    assign inner_preload_value = layer_postion[1:0] == 2'b00 ? layer_number 
                                                       : (layer_postion[1] == 1'b1 ? (layer_postion[0] == 1'b1 ? 20400 
                                                                                   : (layer_postion[0] == 1'b0 ? 20440 : 'bx)): 'bx);

                                                                                   
    assign inner_cycle_match = inner_count == (inner_preload_value + inputs_of_current_working_layer - 1 );
    assign outer_cycle_match = outer_count == neurons_of_current_working_layer - 1 ;

    assign outer_enable  = activion_valid;
    assign inner_enable  = load & ~inner_cycle_match;
    assign weight_enable = load & ~inner_cycle_match | inner_preload & inner_cycle_match;
endmodule