module npu_fsm #(
    `include "npu_params.v"
) (
    input   wire                clk,
    input   wire                reset_b,

    input   wire [1:0]          mode,
    input   wire                inner_cycle_match,
    input   wire                outer_cycle_match,
    input   wire                calulcator_valid,
    input   wire                activion_valid,
    input   wire                all_transmitted,
    input   wire                last_layer,
    input   wire                spi_16_bit_transmitted,

    output  wire                add_activation,
    output  wire                initialization,
    output  wire                load,
    output  wire                start,
    output  reg [1:0]           layer_postion,
    output  wire                layer_shift,
    output  wire                inner_preload,
    output  wire                outter_clear,
    output  wire                first_preload,
    output  wire                start_transmission,
    output wire                 preload_read_fr_spi,
    output wire                 count_en_spi_read  
);

    localparam STATE_WIDTH = 4 ;
    reg [STATE_WIDTH - 1 : 0 ] nstate  ;
    wire [STATE_WIDTH - 1 : 0 ] pstate ;
    

    localparam [STATE_WIDTH - 1 : 0] IDLE           = 0; 
    localparam [STATE_WIDTH - 1 : 0] INIT           = 1; 
    localparam [STATE_WIDTH - 1 : 0] START          = 2;
    localparam [STATE_WIDTH - 1 : 0] WAITING_MULTI  = 3;
    localparam [STATE_WIDTH - 1 : 0] ADD_ACTIVATION = 5;
    localparam [STATE_WIDTH - 1 : 0] WAIT_ACTIV     = 6;
    localparam [STATE_WIDTH - 1 : 0] LAYER_SHIFT    = 7;
    localparam [STATE_WIDTH - 1 : 0] TRANSMISSION   = 8; 
    localparam [STATE_WIDTH - 1 : 0] WAITING_TRANS  = 9; 

    assign add_activation      = pstate == ADD_ACTIVATION ;
    assign first_preload       = (layer_postion == 2'b00 & initialization) ;
    assign initialization      = pstate == INIT;
    assign load                = calulcator_valid;
    assign start               = pstate == START;
    assign layer_shift         = pstate == LAYER_SHIFT;
    assign inner_preload       = first_preload | activion_valid | initialization;
    assign outter_clear        = initialization;
    assign start_transmission  = pstate == TRANSMISSION;
    assign preload_read_fr_spi = activion_valid & outer_cycle_match & last_layer;
    assign count_en_spi_read   = pstate == WAITING_TRANS & spi_16_bit_transmitted ;

    always @(*) begin

        case (pstate)

    /* 0 */  IDLE             : nstate = &mode ? INIT : IDLE ;
    /* 1 */  INIT             : nstate = START;
    /* 2 */  START            : nstate = WAITING_MULTI ;
    
    /* 3 */  WAITING_MULTI    : nstate = calulcator_valid ? inner_cycle_match ? ADD_ACTIVATION 
                                                                              : START
                                                          : WAITING_MULTI ;
    
    /* 5 */  ADD_ACTIVATION   : nstate = WAIT_ACTIV ;

    /* 6 */  WAIT_ACTIV       : nstate = activion_valid ? outer_cycle_match ? last_layer ? TRANSMISSION 
                                                                                            : LAYER_SHIFT
                                                                            : START 
                                                        : WAIT_ACTIV ; 

    /* 7 */  LAYER_SHIFT      : nstate = INIT ;

    /* 8 */  TRANSMISSION     : nstate = WAITING_TRANS ;

    /* 9 */  WAITING_TRANS    : nstate = spi_16_bit_transmitted ? all_transmitted ? IDLE : TRANSMISSION : WAITING_TRANS ;
            
            default           : nstate = 'bx;

        endcase
    end

    always @(posedge clk or negedge reset_b) begin
        if (~reset_b) begin
           layer_postion <= 2'b00;
        end
        else begin
            layer_postion[0] <= activion_valid & outer_cycle_match & ~last_layer ? ~layer_postion[0] : layer_postion[0] ;
            layer_postion[1] <= activion_valid & outer_cycle_match & ~last_layer ? 1'b1 : layer_postion[1] ;
        end 
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

    
endmodule 