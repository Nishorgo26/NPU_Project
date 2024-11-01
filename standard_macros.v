module counter_m # (
    parameter FLOP_WIDTH = 2,
    parameter RESET_VALUE = 0
)(
    input wire                  clk,
    input wire                  reset_b,
    input wire                  enable,
    input wire                  direction,
    input wire                  preload,
    input wire [FLOP_WIDTH-1:0] preload_value,
    input wire                  clear,
    
    output reg [FLOP_WIDTH-1:0] count
);
    
    reg [FLOP_WIDTH-1:0] counter_value;
    
    always @(*) begin
        casez ( { clear, preload, direction } )
            3'b000   : counter_value[FLOP_WIDTH-1:0] = count[FLOP_WIDTH-1:0] - enable;
            3'b001   : counter_value[FLOP_WIDTH-1:0] = count[FLOP_WIDTH-1:0] + enable;
            3'b010   : counter_value[FLOP_WIDTH-1:0] = preload_value[FLOP_WIDTH-1:0];
            3'b011   : counter_value[FLOP_WIDTH-1:0] = preload_value[FLOP_WIDTH-1:0];
            3'b100   : counter_value[FLOP_WIDTH-1:0] = 'b0;
            3'b101   : counter_value[FLOP_WIDTH-1:0] = 'b0;
            3'b110   : counter_value[FLOP_WIDTH-1:0] = 'b0;
            3'b111   : counter_value[FLOP_WIDTH-1:0] = 'b0;
            default  : counter_value[FLOP_WIDTH-1:0] = 'bx;
        endcase
    end
    
    always @(posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            count[FLOP_WIDTH-1:0] <= RESET_VALUE;
        end
        else begin
            count[FLOP_WIDTH-1:0] <= counter_value[FLOP_WIDTH-1:0];
        end
    end

endmodule



//                         +---- DFF With Reset ----+
//                         |                        |
//                         |                        |
//        clk ------------>|                        |-----------> q
//    reset_b ------------>|                        |
//         en ------------>|                        |
//          d ------------>|                        |
//                         |                        |
//                         |                        |
//                         +------------------------+

module dff # (
    parameter FLOP_WIDTH = 1,
    parameter RESET_VALUE = 1'b0
)(
    input  wire                  clk,
    input  wire                  reset_b,
    input  wire                  en,
    input  wire [FLOP_WIDTH-1:0] d,
    output reg  [FLOP_WIDTH-1:0] q
);

    always @(posedge clk or negedge reset_b) begin
        if(~reset_b) begin
            q [FLOP_WIDTH-1:0] <= RESET_VALUE;
        end
        else begin
            q [FLOP_WIDTH-1:0] <= en ? d [FLOP_WIDTH-1:0] : q [FLOP_WIDTH-1:0];
        end
    end

endmodule

//                    +---- mux_4x1 ----+
//                    |                 |
//                    |                 |
//    in0 ----------->|                 |-----------> out
//    in1 ----------->|                 |
//    in2 ----------->|                 |
//    in3 ----------->|                 |
//    sel ---[1:0]--->|                 |
//                    |                 |
//                    |                 |
//                    +-----------------+

module mux_4x1 # (
    parameter PORT_WIDTH = 1
)(
    input  wire [PORT_WIDTH-1:0] in0,
    input  wire [PORT_WIDTH-1:0] in1,
    input  wire [PORT_WIDTH-1:0] in2,
    input  wire [PORT_WIDTH-1:0] in3,
    input  wire [1:0]            sel,

    output reg [PORT_WIDTH-1:0] out
);

    always @(*) begin
        casez( sel )
            2'b00   : out [PORT_WIDTH-1:0] = in0 [PORT_WIDTH-1:0];
            2'b01   : out [PORT_WIDTH-1:0] = in1 [PORT_WIDTH-1:0];
            2'b10   : out [PORT_WIDTH-1:0] = in2 [PORT_WIDTH-1:0];
            2'b11   : out [PORT_WIDTH-1:0] = in3 [PORT_WIDTH-1:0];
            default : out [PORT_WIDTH-1:0] = 'bx;
        endcase
    end

endmodule

//                        +---- Positive Edge Detector ----+
//                        |                                |
//                        |                                |
//        clk ----------->|                                |-----------> posedge_det
//    reset_b ----------->|                                |
//         en ----------->|                                |
//         in ----------->|                                |
//                        |                                |
//                        |                                |
//                        +--------------------------------+

module posedge_dectector (
    input  wire clk,
    input  wire reset_b,
    input  wire en,
    input  wire in,
    output wire pos_edge_det
);

    //internal signals
    wire pos_out;

    assign pos_edge_det = ~pos_out & in;

    dff # (
        .FLOP_WIDTH  ( 1     ),
        .RESET_VALUE ( 32'h0 )
    ) posedge_detect_flop (
        .clk        ( clk       ),
        .reset_b    ( reset_b   ),
        .en         ( en        ),
        .d          ( in        ),
        .q          ( pos_out   )
    );

endmodule

//                        +---- Negative Edge Detector ----+
//                        |                                |
//                        |                                |
//        clk ----------->|                                |-----------> negedge_det
//    reset_b ----------->|                                |
//         en ----------->|                                |
//         in ----------->|                                |
//                        |                                |
//                        |                                |
//                        +--------------------------------+

module negedge_dectector (
    input        clk,
    input        reset_b,
    input  wire  en,
    input        in,
    output wire  neg_edge_det
);

    wire neg_out;

    assign neg_edge_det = neg_out & ~in;

    dff # (
        .FLOP_WIDTH  ( 1     ),
        .RESET_VALUE ( 32'h0 )
    ) negedge_detect_flop (
        .clk        ( clk       ),
        .reset_b    ( reset_b   ),
        .en         ( en        ),
        .d          ( in        ),
        .q          ( neg_out   )
    );

endmodule

module counter # (
    parameter FLOP_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  reset_b,

    input  wire                  up_count,
    input  wire                  dn_count,
    input  wire                  clear,
    input  wire                  enable,

    output reg [FLOP_WIDTH-1:0] count
);

    always @(posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            count [FLOP_WIDTH-1:0] <= 'b0;
        end
        else begin
            casez({ clear, up_count, dn_count })
                3'b000  : count [FLOP_WIDTH-1:0] <= count[FLOP_WIDTH-1:0];
                3'b001  : count [FLOP_WIDTH-1:0] <= count[FLOP_WIDTH-1:0] - enable;
                3'b010  : count [FLOP_WIDTH-1:0] <= count[FLOP_WIDTH-1:0] + enable;
                3'b100  : count [FLOP_WIDTH-1:0] <= 'b0;
                3'b101  : count [FLOP_WIDTH-1:0] <= 'b0;
                3'b110  : count [FLOP_WIDTH-1:0] <= 'b0;
                3'b111  : count [FLOP_WIDTH-1:0] <= 'b0;
                default : count [FLOP_WIDTH-1:0] <= 'bx;
            endcase
        end
    end

endmodule

module fifo #(
    parameter FIFO_WIDTH = 16,
    parameter FIFO_DEPTH = 8
)(
    input  wire                        clk,
    input  wire                        reset_b,
    input  wire                        fifo_wr_enb,
    input  wire                        fifo_rd_enb,
    input  wire                        fifo_en,
    input  wire                        fifo_reset,
    input  wire  [FIFO_WIDTH-1:0] 	    fifo_wdata,
    output wire [FIFO_WIDTH-1:0] 	    fifo_rdata,
    output wire [$clog2(FIFO_DEPTH):0] fifo_entry,
    output wire                  		fifo_empty,
    output wire                  		fifo_full
);

    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);

    wire [FIFO_PTR_WIDTH:0] wptr;
    wire [FIFO_PTR_WIDTH:0] rptr;
    wire                    fifo_wr_en;
    wire                    fifo_rd_en;
    wire                    fifo_rd_ptr_incr_enb;
    wire                    fifo_wr_ptr_incr_enb;

    assign fifo_wr_en  = fifo_wr_enb & !fifo_full;
    assign fifo_rd_en  = fifo_rd_enb & !fifo_empty;

    assign fifo_wr_ptr_incr_enb = fifo_wr_en & fifo_en;
    assign fifo_rd_ptr_incr_enb = fifo_rd_en  & fifo_en;

    counter # (
        .FLOP_WIDTH ( FIFO_PTR_WIDTH + 1 )
    ) u_wr_ptr_counter (
        .clk      ( clk                   ),
        .reset_b  ( reset_b               ),
        .clear    ( fifo_reset            ),
        .up_count ( 1'b1                  ),
        .dn_count ( 1'b0                  ),
        .enable   ( fifo_wr_ptr_incr_enb  ),
        .count    ( wptr                  )
    );

    counter # (
        .FLOP_WIDTH ( FIFO_PTR_WIDTH + 1 )
    ) u_rd_ptr_counter (
        .clk      ( clk                   ),
        .reset_b  ( reset_b               ),
        .clear    ( fifo_reset            ),
        .up_count ( 1'b1                  ),
        .dn_count ( 1'b0                  ),
        .enable   ( fifo_rd_ptr_incr_enb  ),
        .count    ( rptr                  )
    );

    counter # (
        .FLOP_WIDTH ( FIFO_PTR_WIDTH + 1 )
    ) u_entry_counter (
        .clk      ( clk                   ),
        .reset_b  ( reset_b               ),
        .clear    ( fifo_reset            ),
        .up_count ( fifo_wr_en            ),
        .dn_count ( fifo_rd_en            ),
        .enable   ( 1'b1                  ),
        .count    ( fifo_entry            )
    );

    //  +-------------------------+
    //  |       FIFO MEMORY       |
    //  +-------------------------+

    reg [FIFO_WIDTH-1:0] fifo_mem [FIFO_DEPTH-1:0];
    assign fifo_rdata = fifo_mem[rptr[FIFO_PTR_WIDTH-1:0]];

    always@(posedge clk)
    begin
        if(fifo_wr_en) fifo_mem[wptr[FIFO_PTR_WIDTH-1:0]] <= fifo_wdata[FIFO_WIDTH-1:0];
    end

    assign fifo_empty = fifo_en ? (wptr[FIFO_PTR_WIDTH:0] == rptr[FIFO_PTR_WIDTH:0]) : ~fifo_entry[0];
    assign fifo_full  = fifo_en ? (wptr[FIFO_PTR_WIDTH-1:0] == rptr[FIFO_PTR_WIDTH-1:0]) && (wptr[FIFO_PTR_WIDTH] != rptr[FIFO_PTR_WIDTH]) : fifo_entry[0];

endmodule

module shift_register # (
    parameter FLOP_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  reset_b,
    input  wire                  load,
    input  wire                  shift,
    input  wire [FLOP_WIDTH-1:0] data_in,
    
    output reg [FLOP_WIDTH-1:0] data_out
);

    always @(posedge clk or negedge reset_b) begin
        if(~reset_b) begin
            data_out[FLOP_WIDTH-1:0] <= 'b1010; //MOD, must change to zero. 
        end
        else begin
            casez ( { load, shift } )
                2'b00   : data_out[FLOP_WIDTH-1:0] <= data_out[FLOP_WIDTH-1:0];
                2'b01   : data_out[FLOP_WIDTH-1:0] <= { 1'b0, data_out[FLOP_WIDTH-1:1] };
                2'b10   : data_out[FLOP_WIDTH-1:0] <= data_in[FLOP_WIDTH-1:0];
                2'b11   : data_out[FLOP_WIDTH-1:0] <= data_in[FLOP_WIDTH-1:0];
                default : data_out[FLOP_WIDTH-1:0] <= 'bx;
            endcase
        end
    end

endmodule

module serial_shift_register # (
    parameter FLOP_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  reset_b,
    input  wire                  load,
    input  wire                  shift,
    input  wire [FLOP_WIDTH-1:0] p_data_in,
    input  wire                  s_data_in,
    output reg [FLOP_WIDTH-1:0] p_data_out,
    output wire                  s_data_out
);

    always @(posedge clk or negedge reset_b) begin
        if(~reset_b) begin
            p_data_out[FLOP_WIDTH-1:0] <= 'b0;
        end
        else begin
            casez ( { load, shift } )
                2'b00   : p_data_out[FLOP_WIDTH-1:0] <= p_data_out[FLOP_WIDTH-1:0];
                2'b01   : p_data_out[FLOP_WIDTH-1:0] <= { s_data_in, p_data_out[FLOP_WIDTH-1:1] };
                2'b10   : p_data_out[FLOP_WIDTH-1:0] <= p_data_in[FLOP_WIDTH-1:0];
                2'b11   : p_data_out[FLOP_WIDTH-1:0] <= p_data_in[FLOP_WIDTH-1:0];
                default : p_data_out[FLOP_WIDTH-1:0] <= 'bx;
            endcase
        end
    end

    assign s_data_out = p_data_out[0];

endmodule


module customized_fifo #(
    parameter FIFO_WIDTH = 16,
    parameter FIFO_DEPTH = 8
)(
    input  wire                        clk,
    input  wire                        reset_b,
    input  wire                        fifo_wr_enb,
    input  wire                        fifo_rd_enb,
    input  wire                        fifo_en,
    input  wire                        fifo_reset,
    input  wire [FIFO_WIDTH-1:0] 	    fifo_wdata,
    output wire [FIFO_WIDTH-1:0] 	    fifo_rdata,
    output wire [$clog2(FIFO_DEPTH):0] fifo_entry,
    output wire                  		fifo_empty,
    output wire                  		fifo_full,
    input  wire                        neuron_ready
);

    localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);

    wire [FIFO_PTR_WIDTH:0] wptr;
    wire [FIFO_PTR_WIDTH:0] rptr;
    wire                    fifo_wr_en;
    wire                    fifo_rd_en;
    wire                    fifo_rd_ptr_incr_enb;
    wire                    fifo_wr_ptr_incr_enb;

    assign fifo_wr_en  = fifo_wr_enb & !fifo_full;
    assign fifo_rd_en  = fifo_rd_enb & !fifo_empty;

    assign fifo_wr_ptr_incr_enb = fifo_wr_en & fifo_en;
    assign fifo_rd_ptr_incr_enb = fifo_rd_en  & fifo_en;

    counter # (
        .FLOP_WIDTH ( FIFO_PTR_WIDTH + 1 )
    ) u_wr_ptr_counter (
        .clk      ( clk                   ),
        .reset_b  ( reset_b               ),
        .clear    ( fifo_reset            ),
        .up_count ( 1'b1                  ),
        .dn_count ( 1'b0                  ),
        .enable   ( fifo_wr_ptr_incr_enb  ),
        .count    ( wptr                  )
    );

    counter # (
        .FLOP_WIDTH ( FIFO_PTR_WIDTH + 1 )
    ) u_rd_ptr_counter (
        .clk      ( clk                   ),
        .reset_b  ( reset_b               ),
        .clear    ( read_fifo_reset       ),
        .up_count ( 1'b1                  ),
        .dn_count ( 1'b0                  ),
        .enable   ( fifo_rd_ptr_incr_enb  ),
        .count    ( rptr                  )
    );
    

    counter # (
        .FLOP_WIDTH ( FIFO_PTR_WIDTH + 1 )
    ) u_entry_counter (
        .clk      ( clk                   ),
        .reset_b  ( reset_b               ),
        .clear    ( read_fifo_reset       ),
        .up_count ( fifo_wr_en            ),
        .dn_count ( fifo_rd_en            ),
        .enable   ( 1'b1                  ),
        .count    ( fifo_entry            )
    );

    assign read_fifo_reset = neuron_ready;
    //  +-------------------------+
    //  |       FIFO MEMORY       |
    //  +-------------------------+

    reg [FIFO_WIDTH-1:0] fifo_mem [FIFO_DEPTH-1:0];
    assign fifo_rdata = fifo_mem[rptr[FIFO_PTR_WIDTH-1:0]];

    always@(posedge clk)
    begin
        if(fifo_wr_en) fifo_mem[wptr[FIFO_PTR_WIDTH-1:0]] <= fifo_wdata[FIFO_WIDTH-1:0];
    end

    assign fifo_empty = fifo_en ? (wptr[FIFO_PTR_WIDTH:0] == rptr[FIFO_PTR_WIDTH:0]) : ~fifo_entry[0];
    assign fifo_full  = fifo_en ? (wptr[FIFO_PTR_WIDTH-1:0] == rptr[FIFO_PTR_WIDTH-1:0]) && (wptr[FIFO_PTR_WIDTH] != rptr[FIFO_PTR_WIDTH]) : fifo_entry[0];

endmodule
