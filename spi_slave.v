module spi_slave # (
    `include "npu_params.v"
)(
    input  wire                            clk,
    input  wire                            reset_b,
         
    input  wire                            spi_ss,
    input  wire                            spi_sclk,
    input  wire                            spi_mosi,
    input  wire                            spi_load, // To be controlled by controller
    input  wire [NPU_DATA_WIDTH - 1 : 0]   spi_load_data,
    
    output wire                            spi_miso,
    output wire [NPU_DATA_WIDTH - 1 :0]    spi_data_out,
    output wire                            spi_fifo_wr_en,
    output wire                            spi_16_bit_transmitted
);

    wire       bit_cntr_clear;
    wire       spi_clk_posedge;
    wire [3:0] spi_bit_count;
    wire       bit_16_received;

    //  +---------------------+
    //  |     Bit Counter     |
    //  +---------------------+

    counter # (
        .FLOP_WIDTH ( 4 )
    ) u_spi_bit_counter (
        .clk      ( clk             ),
        .reset_b  ( reset_b         ),
        .up_count ( 1'b1            ),
        .dn_count ( 1'b0            ),
        .clear    ( bit_cntr_clear  ),
        .enable   ( spi_clk_posedge ),
        .count    ( spi_bit_count   )
    );

    assign bit_cntr_clear = spi_bit_count == 4'b1000;

    //  +-----------------+
    //  |     SPI FSM     |
    //  +-----------------+
    //                 |<------------------------------------- 256 bits ------------------------------------>|
    // ss    : ^^^^^^^^\_____________________/^^^^^^^^^\_____________________/^^^^^^^^^\_____________________/^^^^^^^^^^^^^^^^^^^
    // sclk  : ___________|^|_|^|_|^|_|^|_________________|^|_|^|_|^|_|^|__________________|^|_|^|_|^|_|^|_______________________
    // state : IDLE    |   SHIFT             |  PAUSE  |    SHIFT            | PAUSE   | SHIFT               | P | FINISH | IDLE;        

    localparam STATE_WIDTH = 2;

    wire [STATE_WIDTH-1:0] pstate;
    reg  [STATE_WIDTH-1:0] nstate;

    localparam [STATE_WIDTH-1:0] IDLE   = 2'b00,
                                 SHIFT  = 2'b01,
                                 PAUSE  = 2'b10,
                                 FINISH = 2'b11;

    // NSL: Next State wire
    always @(*) begin
        casez( pstate )
            IDLE    : nstate = ~spi_ss ? SHIFT : IDLE;
            SHIFT   : nstate =  spi_ss ? ( bit_16_received ? FINISH : PAUSE ) : SHIFT;
            PAUSE   : nstate = ~spi_ss ? SHIFT : PAUSE;
            FINISH  : nstate = IDLE;
            default : nstate = 'bx;
        endcase
    end

    // PSR: Present State Register
    dff # (
        .FLOP_WIDTH ( STATE_WIDTH ),
        .RESET_VALUE ( 'b0 )
    ) u_spi_psr (
        .clk        ( clk         ),
        .reset_b    ( reset_b     ),
        .en         ( 1'b1        ),
        .d          ( nstate      ),
        .q          ( pstate      )
    );

    //  +----------------------+
    //  |     SCLK Detector    |
    //  +----------------------+

    posedge_dectector u_sclk_posedge_detector (
        .clk           ( clk             ),
        .reset_b       ( reset_b         ),
        .en            ( 1'b1            ),
        .in            ( spi_sclk        ),
        .pos_edge_det  ( spi_clk_posedge )
    );

    //  +----------------------+
    //  |     Shift Register   |
    //  +----------------------+

    wire spi_shift_en;
    wire [NPU_DATA_WIDTH-1:0] spi_shift_reg_load_data;

    assign spi_shift_en                                 = pstate == SHIFT & spi_clk_posedge;
    assign spi_shift_reg_load_data[NPU_DATA_WIDTH-1:0]  = spi_load_data[NPU_DATA_WIDTH-1:0];

    serial_shift_register # (
        .FLOP_WIDTH ( 16 )
    ) u_serial_shift_register (
        .clk        ( clk                                         ),
        .reset_b    ( reset_b                                     ),
        .load       ( spi_load                                    ),
        .shift      ( spi_shift_en                                ),
        .p_data_in  ( spi_shift_reg_load_data[NPU_DATA_WIDTH-1:0] ),
        .s_data_in  ( spi_mosi                                    ),
        .p_data_out ( spi_data_out                                ),
        .s_data_out ( spi_miso                                    )
    );

    //  +-----------------------+
    //  |     Frame Counter     |
    //  +-----------------------+

    wire frame_cntr_en;
    assign frame_cntr_en = pstate == SHIFT & spi_ss;
    wire frame_cntr_clear;
    wire [1:0] spi_frame_count;

    counter # (
        .FLOP_WIDTH ( 2 )
    ) u_spi_frame_counter (
        .clk      ( clk              ),
        .reset_b  ( reset_b          ),
        .up_count ( 1'b1             ),
        .dn_count ( 1'b0             ),
        .clear    ( frame_cntr_clear ),
        .enable   ( frame_cntr_en    ),
        .count    ( spi_frame_count  )
    );

    assign bit_16_received        = spi_frame_count[0] & frame_cntr_en;
    assign frame_cntr_clear       = bit_16_received;
    assign spi_fifo_wr_en         = pstate == FINISH;
    assign spi_16_bit_transmitted = bit_16_received;

endmodule