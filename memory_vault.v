module memory_vault #(
    `include "npu_params.v"
) (
    input  wire                            clk,
    input  wire                            reset_b,
`ifdef DEBUG
    input  wire                         debug_wr_en,
    input  wire [NPU_DATA_WIDTH - 1 :0] debug_data,
    input  wire [NPU_DATA_WIDTH - 1 :0] debug_addr,
`endif
    input  wire                            spi_ss,
    input  wire                            spi_sclk,
    input  wire                            mosi,
    output wire                            miso,         
    input  wire                            initialization   ,
    input  wire [1:0]                      mode,
    input  wire                            layer_shift,
    input  wire  [1:0]                     layer_postion ,
    input  wire                            load          ,
    input  wire                            inner_preload ,
    input  wire                            outter_clear ,
    input  wire                            activion_valid,
    input  wire                            start_transmission,

    input  wire                            preload_read_fr_spi,
    input  wire                            count_en_spi_read  ,

    output wire                            inner_cycle_match,
    output wire                            outer_cycle_match,
    output wire                            last_layer,
    output wire                            first_preload,
    output wire                            all_transmitted,
    output wire                            spi_16_bit_transmitted,

    output wire [NPU_DATA_WIDTH -1 : 0]    data_out_a,
    output wire [NPU_DATA_WIDTH -1 : 0]    data_out_b,
    input  wire [NPU_DATA_WIDTH -1 : 0]    calculation_result

);
    wire [NPU_DATA_WIDTH - 1 : 0 ] spi_data_out;
    wire                           spi_wr_en   ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] addrs_a     ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] addrs_b     ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] data_in_a   ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] data_in_b   ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] weight_count   ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] inner_count   ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] layer_number   ;
    wire [NPU_DATA_WIDTH - 1 : 0 ] input_number   ;
    wire [NPU_DATA_WIDTH - 1 : 0 ]  neurons_of_current_working_layer;

    

    spi_slave u_spi_slave(
        .clk                             ( clk            ),
        .reset_b                         ( reset_b        ),
        .spi_ss                          ( spi_ss         ),
        .spi_sclk                        ( spi_sclk       ),
        .spi_mosi                        ( mosi       ),
        .spi_load                        ( start_transmission  ), 
        .spi_load_data                   ( data_out_b ), 
        .spi_miso                        ( miso       ),
        .spi_data_out                    ( spi_data_out   ),
        .spi_fifo_wr_en                  ( spi_fifo_wr_en ),
        .spi_16_bit_transmitted          ( spi_16_bit_transmitted  )
    );


memory_controller u_memory_controller(
            .clk             ( clk             ),
            .reset_b         ( reset_b         ),
            .mode            ( mode            ),
            .spi_data_out    ( spi_data_out    ),
            .spi_wr_en       ( spi_fifo_wr_en  ),

            .initialization  ( initialization  ),
            .start_transmission  ( start_transmission  ),
            .weight_count    ( weight_count    ),
            .inner_count     ( inner_count     ),
            .layer_shift     ( layer_shift     ),
            .layer_postion   ( layer_postion[0]),
            .last_layer      ( last_layer      ),
            .addrs_a         ( addrs_a         ),
            .addrs_b         ( addrs_b         ),
            .data_in_a       ( data_in_a       ),
            // .data_in_b       ( data_in_b       ),
            .we_a            ( we_a            ),
            .load            ( load            ),
            .we_b            ( we_b            ),            
            .activion_valid      ( activion_valid     ),
            .preload_read_fr_spi (preload_read_fr_spi ),    
            .all_transmitted   ( all_transmitted   ),

            .count_en_spi_read   (count_en_spi_read   ),

            .neurons_of_current_working_layer ( neurons_of_current_working_layer ),
            .layer_number        ( layer_number       ),
            .input_number        ( input_number       ),
            .first_preload       ( first_preload      )
);



    dummy_tdp u_dummy_tdp (
            .clka                    ( clk               ),
            .clkb                    ( clk               ),
            .addra                   ( addrs_a           ),
            .addrb                   ( addrs_b           ),
            .dina                    ( data_in_a         ),
            .dinb                    ( calculation_result),
            .wea                     ( we_a              ),
            .web                     ( we_b              ),

            .douta                   ( data_out_a        ),
            .doutb                   ( data_out_b        )
    );


reg_cntr_cmprtr u_reg_cntr_cmprtr(
            .clk                ( clk                ),
            .reset_b            ( reset_b            ),

            .initialization     ( initialization     ),
            .mode               ( mode               ),
            .layer_postion      ( layer_postion      ),
            .load               ( load               ),
            .outter_clear       ( outter_clear      ),
            .inner_preload      ( inner_preload      ),
            .activion_valid     ( activion_valid     ),
            .douta              ( data_out_a              ),
            .doutb              ( data_out_b              ),

            .layer_number       ( layer_number       ),
            .input_number       ( input_number       ),
            .inner_count        ( inner_count        ),
            .weight_count       ( weight_count       ),
            .neurons_of_current_working_layer ( neurons_of_current_working_layer ),
            .inner_cycle_match  ( inner_cycle_match  ),
            .outer_cycle_match  ( outer_cycle_match  ),
            .first_preload      ( first_preload      )
);

        
endmodule