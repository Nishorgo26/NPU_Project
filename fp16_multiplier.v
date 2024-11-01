module fp16_multiplier (
    input  wire        clk,
    input  wire        reset_b,
    input  wire [15:0] input_a,
    input  wire [15:0] input_b,
    input  wire        clear,
    input  wire        start,
    
    output wire        valid,
    output wire [15:0] result
);

wire          dff_in;

wire          sign_bit;
wire  [10:0]  mantisa;
wire  [10:0]  mantisa_temp;
wire  [4:0]   exponent;
wire          zcheck;
wire          ovcheck;
wire          elcheck;
wire  [9:0]   mantisa_pre_el;
wire  [9:0]   mantisa_final;
wire  [4:0]   exponent_final;

assign sign_bit       =  input_a[15] ^ input_b[15]; 
assign mantisa        =  input_a[9:0] + input_b[9:0] + 10'b00001_11101;
assign mantisa_temp   =  input_a[9:0] + input_b[9:0];
assign exponent       =  elcheck ? 5'b00000 : (mantisa[10] ? (input_a[14:10] + input_b[14:10] - 5'b01110) : (input_a[14:10] + input_b[14:10] - 5'b01111));
   
assign elcheck        =  (input_a[14:10] + input_b[14:10]) < 15;
assign zcheck         =  (input_a == 16'b0) | (input_b == 16'b0);
assign ovcheck        =  ((&mantisa_temp[10:6]) & (~(|mantisa[10:6])));

assign mantisa_pre_el =  ovcheck ? (mantisa[9:0] - 10'b00001_11101) : mantisa[9:0];

assign mantisa_final  =  elcheck ? (mantisa_pre_el >> (5'd15-(input_a[14:10] + input_b[14:10]))) : mantisa_pre_el;
assign exponent_final =  ovcheck ? (exponent[4:0] + 5'b00001) : exponent[4:0];

assign result         =  zcheck  ? 16'd0 : {sign_bit, exponent_final[4:0], mantisa_final[9:0]};

assign dff_in         =  start ? 1'b1 : (clear ? 1'b0 : valid);

dff #(
    .FLOP_WIDTH  ( 1       ),
    .RESET_VALUE ( 1'b0    )
) u_valid_reg (
    .clk         ( clk     ),
    .reset_b     ( reset_b ),
    .en          ( 1'b1    ),
    .d           ( dff_in  ),
    .q           ( valid   )
);

endmodule
