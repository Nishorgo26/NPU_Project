module fifo_testbench #(
    parameter FIFO_WIDTH = 16,
    parameter FIFO_DEPTH = 8
)();
    bit                        clk;
    bit                        reset_b;
    bit                        fifo_wr_enb;
    bit                        fifo_rd_enb;
    bit                        fifo_en;
    bit                        fifo_reset;
    bit [FIFO_WIDTH-1:0] 	     fifo_wdata;
    logic [FIFO_WIDTH-1:0] 	     fifo_rdata;
    logic [$clog2(FIFO_DEPTH):0] fifo_entry;
    logic                  		 fifo_empty;
    logic                  		 fifo_full;

fifo i_fifo (
    .clk            ( clk           ),
    .reset_b        ( reset_b       ),
    .fifo_wr_enb    ( fifo_wr_enb   ),
    .fifo_rd_enb    ( fifo_rd_enb   ),
    .fifo_en        ( fifo_en       ),
    .fifo_reset     ( fifo_reset    ),
    .fifo_wdata     ( fifo_wdata    ),
    .fifo_rdata     ( fifo_rdata    ),
    .fifo_entry     ( fifo_entry    ),
    .fifo_empty     ( fifo_empty    ),
    .fifo_full      ( fifo_full     )
);

    initial begin
            forever begin
                #31 clk = ~clk;
            end
    end

    initial begin
        repeat (2) @(posedge clk);
        reset_b = 1;
        fifo_en = 1;
        repeat (2) @(posedge clk);
        fifo_write($random());
        fifo_write($random());
        fifo_write($random());
        fifo_write($random());
        repeat (10) @(posedge clk);
        $finish();
    end
    task fifo_write (reg [FIFO_WIDTH-1:0] value);
        fifo_wr_enb = 1;
        fifo_wdata = value;
        @(posedge clk);
        fifo_wr_enb = 0;
        @(posedge clk);
    endtask
    
endmodule