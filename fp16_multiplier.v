module fp16_multiplier (
    input  wire        clk,
    input  wire        reset_b,
    input  wire [15:0] input_a,
    input  wire [15:0] input_b,
    input  wire        start,
    
    output wire        valid,
    output wire [15:0] result
);

wire          sign_bit;
wire  [10:0]  mantisa;
wire  [4:0]   exponent;
wire          zcheck;

assign sign_bit   =  input_a[15] ^ input_b[15];
assign mantisa    =  input_a[9:0] + input_b[9:0];
assign exponent   =  mantisa[10] ? (input_a[14:10] + input_b[14:10] - 5'b01110) : (input_a[14:10] + input_b[14:10] - 5'b01111);
  
assign zcheck     =  (input_a == 16'b0) | (input_b == 16'b0); 
  
assign result     =  zcheck ? 16'b0 : {sign_bit, exponent, mantisa[9:0]};

dff #(
    .FLOP_WIDTH  ( 1    ),
    .RESET_VALUE ( 1'b0 )
) u_valid_reg (
    .clk        ( clk     ),
    .reset_b    ( reset_b ),
    .en         ( 1'b1    ),
    .d          ( start   ),
    .q          ( valid   )
);

endmodule
