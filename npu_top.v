// `define DEBUG
module npu_top #(
    `include "npu_params.v"
) (
`ifdef DEBUG
    input  wire                         debug_wr_en,
    input  wire [NPU_DATA_WIDTH - 1 :0] debug_data,
    input  wire [NPU_DATA_WIDTH - 1 :0] debug_addr,
`endif
//=========== SPI INTERFACE =============//
    input  wire         spi_ss,
    input  wire         spi_sclk,
    input  wire         spi_mosi,
    output wire         spi_miso,

    input  wire         clk,
    input  wire         reset_b,

//============ DIRECT LINE ==============//
    input  wire [1:0]   mode,
    output wire         start_transmission
    // input  wire        soft_reset

);
wire [NPU_DATA_WIDTH-1 : 0 ] data_out_a;
wire [NPU_DATA_WIDTH-1 : 0 ] data_out_b;
wire [NPU_DATA_WIDTH-1 : 0 ] calculation_result;
wire                         layer_shift;
wire [1:0]                   layer_postion;

memory_vault u_memory_vault(
    .clk               ( clk               ),
    .reset_b           ( reset_b           ),
    .spi_ss            ( spi_ss            ),
    .spi_sclk          ( spi_sclk          ),
    .mosi              ( spi_mosi          ),
    .miso              ( spi_miso          ),
    .mode              ( mode              ),
    .layer_postion     ( layer_postion     ),
    .initialization    ( initialization    ),
    .layer_shift       ( layer_shift       ),
    .load              ( load              ),
    .inner_preload     ( inner_preload     ),
    .all_transmitted   ( all_transmitted   ),
    .outter_clear      ( outter_clear      ),
    .activion_valid    ( activion_valid    ),
    .inner_cycle_match ( inner_cycle_match ),
    .outer_cycle_match ( outer_cycle_match ),
    .data_out_a        ( data_out_a        ),
    .data_out_b        ( data_out_b        ),
    .last_layer        ( last_layer        ),
    .calculation_result( calculation_result),
    .first_preload     ( first_preload     ),
    .start_transmission( start_transmission),
    .preload_read_fr_spi(preload_read_fr_spi),
    .count_en_spi_read  (count_en_spi_read  ),
    .spi_16_bit_transmitted (spi_16_bit_transmitted)
);

npu_fsm u_npu_fsm(
    .clk               ( clk               ),
    .reset_b           ( reset_b           ),
    .mode              ( mode              ),
    .inner_cycle_match ( inner_cycle_match ),
    .outer_cycle_match ( outer_cycle_match ),
    .calulcator_valid  ( calulcator_valid  ),
    .activion_valid    ( activion_valid    ),
    .all_transmitted   ( all_transmitted   ),
    .add_activation    ( add_activation    ),
    .initialization    ( initialization    ),
    .load              ( load              ),
    .start             ( start             ),
    .layer_postion     ( layer_postion     ),
    .layer_shift       ( layer_shift       ),
    .inner_preload     ( inner_preload     ),
    .outter_clear      ( outter_clear      ),
    .last_layer        ( last_layer        ),
    .first_preload     ( first_preload     ),
    .start_transmission( start_transmission),
    .preload_read_fr_spi(preload_read_fr_spi),
    .count_en_spi_read  (count_en_spi_read  ),
    .spi_16_bit_transmitted (spi_16_bit_transmitted)

);

math_calculation_core u_math_calculation_core (
    .clk                ( clk                 ),
    .reset_b            ( reset_b             ),
    .calculator_start   ( start               ),
    .sigmoid_start      ( add_activation      ),
    .input_value        ( data_out_a          ),
    .weight_value       ( data_out_b          ),
    .calculator_valid   ( calulcator_valid    ),
    .sigmoid_valid      ( activion_valid      ),
    .calculation_result ( calculation_result  )
);


    
endmodule
