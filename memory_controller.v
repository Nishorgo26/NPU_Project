module memory_controller #(
    `include "npu_params.v"
) (     
    input  wire                            clk         ,
    input  wire                            reset_b     ,
`ifdef DEBUG
    input  wire                         debug_wr_en,
    input  wire [NPU_DATA_WIDTH - 1 :0] debug_data,
    input  wire [NPU_DATA_WIDTH - 1 :0] debug_addr,
`endif
    input  wire [ 1 : 0 ]                  mode        ,
    input  wire [NPU_DATA_WIDTH - 1 : 0 ]  spi_data_out,
    input  wire                            spi_wr_en   ,

    input   wire                           activion_valid,
    input wire                             start_transmission,
    input  wire                            initialization   ,
    input  wire [NPU_DATA_WIDTH - 1 : 0 ]  inner_count ,
    input  wire [NPU_DATA_WIDTH - 1 : 0 ]  weight_count ,
    input  wire [NPU_DATA_WIDTH - 1 : 0 ]  neurons_of_current_working_layer,
    input  wire                            layer_shift,  
    input  wire                            first_preload,
    input  wire                            layer_postion,

    input wire                             preload_read_fr_spi,
    input wire                             count_en_spi_read  ,

    input  wire                            load,
    output wire [NPU_DATA_WIDTH - 1 : 0 ]  addrs_a     ,
    output wire [NPU_DATA_WIDTH - 1 : 0 ]  addrs_b     ,
    output wire [NPU_DATA_WIDTH - 1 : 0 ]  data_in_a   ,
    // output wire [NPU_DATA_WIDTH - 1 : 0 ]  data_in_b   ,
    output wire                            we_a        ,
    output wire                            we_b        ,
    
    output wire                            last_layer,
    output wire                            all_transmitted,
    output wire  [NPU_DATA_WIDTH - 1 : 0 ] layer_number  ,
    output wire  [NPU_DATA_WIDTH - 1 : 0 ] input_number  
);

    localparam STATE_WIDTH = 3 ;
    reg [STATE_WIDTH - 1 : 0 ] nstate;
    wire [STATE_WIDTH - 1 : 0 ]  pstate;

    localparam [ STATE_WIDTH - 1 : 0 ] IDLE           = 0 ; 
    localparam [ STATE_WIDTH - 1 : 0 ] WT_FR_ADDR     = 1 ; 
    localparam [ STATE_WIDTH - 1 : 0 ] ADDR_WRT       = 2 ;
    localparam [ STATE_WIDTH - 1 : 0 ] WT_FR_DATA     = 3 ;
    localparam [ STATE_WIDTH - 1 : 0 ] DONE           = 4 ;
    localparam [ STATE_WIDTH - 1 : 0 ] ONLY_DATA_PHS  = 5 ;
    localparam [ STATE_WIDTH - 1 : 0 ] DONE_DATA_PHS  = 6 ;

    always @(*) begin

        case (pstate)
    /* 0 */ IDLE          : nstate = &mode ? IDLE : |mode ? (mode == 2'b10 ? WT_FR_ADDR : (mode == 2'b01 ? ONLY_DATA_PHS : IDLE)) : IDLE ;
    /* 1 */ WT_FR_ADDR    : nstate = &mode ? IDLE : |mode ? (spi_wr_en ? ADDR_WRT : WT_FR_ADDR )                                  : IDLE ;
    /* 2 */ ADDR_WRT      : nstate = &mode ? IDLE : |mode ? (WT_FR_DATA)                                                          : IDLE ;
    /* 3 */ WT_FR_DATA    : nstate = &mode ? IDLE : |mode ? (spi_wr_en ? DONE : WT_FR_DATA )                                      : IDLE ;
    /* 4 */ DONE          : nstate = &mode ? IDLE : |mode ? (mode == 2'b10 ? WT_FR_ADDR : (mode == 2'b01 ? ONLY_DATA_PHS : IDLE)) : IDLE ;
    /* 5 */ ONLY_DATA_PHS : nstate = &mode ? IDLE : |mode ? (spi_wr_en ? DONE_DATA_PHS : ONLY_DATA_PHS)                           : IDLE ;
    /* 6 */ DONE_DATA_PHS : nstate = &mode ? IDLE : |mode ? (mode == 2'b10 ? WT_FR_ADDR : (mode == 2'b01 ? ONLY_DATA_PHS : IDLE)) : IDLE ;
            default       : nstate = 'bx;
        endcase
    end
    
    wire addr_str_en;
    wire  [ NPU_DATA_WIDTH - 1 : 0 ] reg_addr;
    assign addr_str_en = pstate == ADDR_WRT;

    dff#(
        .FLOP_WIDTH ( NPU_DATA_WIDTH ),
        .RESET_VALUE ( 'b0 )
    )u_reg_store(
        .clk        ( clk          ),
        .reset_b    ( reset_b      ),
        .en         ( addr_str_en  ),
        .d          ( spi_data_out ),
        .q          ( reg_addr     )
    );


    assign reg_wr_en = pstate == DONE;

    wire memory_a_wr_en;
    assign memory_a_wr_en = pstate == DONE_DATA_PHS ;
    wire [14:0] count_addres ;
    
    counter#(
        .FLOP_WIDTH ( 15 )
    )address_counter_data_phase(
        .clk      ( clk             ),
        .reset_b  ( reset_b         ),
        .up_count ( 1'b1            ),
        .dn_count ( 1'b0            ),
        .clear    ( initialization  ),
        .enable   ( memory_a_wr_en  ),
        .count    ( count_addres    )
    );

    wire [14:0] count_layer;
    
    counter#(
        .FLOP_WIDTH ( 15 )
    )layer_counter(
        .clk      ( clk             ),
        .reset_b  ( reset_b         ),
        .up_count ( 1'b1            ),
        .dn_count ( 1'b0            ),
        .clear    ( clear           ),
        .enable   ( layer_shift     ),
        .count    ( count_layer     )
    );

    wire [NPU_DATA_WIDTH-1:0] value_addr_preload;
    assign value_addr_preload = layer_postion ? 20440 : 20400 ;
    wire [NPU_DATA_WIDTH-1:0] value_addr_count ;
    
    assign all_transmitted = value_addr_count == (value_addr_preload + neurons_of_current_working_layer - 1);
    
    assign last_layer = count_layer + 1 == (layer_number - 1);
    
    assign we_b    = activion_valid; 
    assign addrs_b = (start_transmission | activion_valid) ? value_addr_count : initialization ? count_layer + 1 : weight_count  ;

`ifdef DEBUG
    assign we_a      = debug_wr_en | (~debug_wr_en & memory_a_wr_en) ;
    assign addrs_a   = debug_wr_en ? debug_addr : (preload_read_fr_spi ? (layer_number - 1) : memory_a_wr_en ? count_addres : initialization ? count_layer : inner_count)  ;
    assign data_in_a = debug_wr_en ? debug_data : spi_data_out   ; 
`endif
    assign we_a      = memory_a_wr_en ;
    assign addrs_a   = preload_read_fr_spi ? (layer_number - 1) : memory_a_wr_en ? count_addres : initialization ? count_layer : inner_count  ;
    assign data_in_a = spi_data_out   ; 

    
    wire sel_layer_number ;
    wire sel_input_number ;

    assign sel_input_number   = memory_a_wr_en & count_addres == 15'b0;
    // assign sel_input_number   = reg_wr_en & reg_addr == 8'h04;
    assign sel_layer_number   = reg_wr_en & reg_addr == 8'h08;

    dff# (.FLOP_WIDTH (NPU_DATA_WIDTH),.RESET_VALUE(1'b0)) u3_dff  (.clk(clk),.reset_b(reset_b),.en(sel_layer_number),.d(spi_data_out),.q(layer_number ) );
    dff# (.FLOP_WIDTH (NPU_DATA_WIDTH),.RESET_VALUE(1'b0)) u4_dff  (.clk(clk),.reset_b(reset_b),.en(sel_input_number),.d(spi_data_out),.q(input_number ) );

    
    counter_m#(
        .FLOP_WIDTH    ( 16 ),
        .RESET_VALUE   ( 0 )
    )write_inner_values_counter(
        .clk           ( clk           ),
        .reset_b       ( reset_b       ),
        .enable        ( activion_valid | count_en_spi_read ),
        .direction     ( 1'b1          ),
        .preload       ( layer_shift | first_preload |  preload_read_fr_spi ),
        .preload_value ( value_addr_preload ),
        .clear         ( 1'b0         ),
        .count         ( value_addr_count  )
    );

    // Present state register
    dff # (
        .FLOP_WIDTH  ( STATE_WIDTH ),
        .RESET_VALUE ( IDLE )
    ) u_psr_mc (
        .clk        ( clk     ),
        .reset_b    ( reset_b ),
        .en         ( 1'b1    ),
        .d          ( nstate  ),
        .q          ( pstate  )
    );
    



endmodule
