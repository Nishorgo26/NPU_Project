module fp32_multiplier (
    input  wire        clk,
    input  wire        reset_b,
    input  wire [31:0] input_a,
    input  wire [31:0] input_b,
    input  wire        clear,
    input  wire        start,
    
    output wire        valid,
    output wire [31:0] result
);

wire          dff_in;

wire          sign_bit;
wire  [23:0]  mantisa;
wire  [23:0]  mantisa_temp;
wire  [7:0]   exponent;
wire          zcheck;
wire          ovcheck;
wire          elcheck;
wire  [22:0]  mantisa_pre_el;
wire  [22:0]  mantisa_final;
wire  [7:0]   exponent_final;

assign sign_bit       =  input_a[31] ^ input_b[31]; 
assign mantisa        =  input_a[22:0] + input_b[22:0] + 23'b000_00000_00000_00001_11101;
//assign mantisa_temp   =  input_a[22:0] + input_b[22:0];
assign exponent       =  mantisa[23] ? (input_a[30:23] + input_b[30:23] - 8'b0111_1110) : (input_a[30:23] + input_b[30:23] - 8'b0111_1111);
   
assign zcheck         =  (input_a == 32'b0) | (input_b == 32'b0); 
//assign ovcheck        =  ((&mantisa_temp[10:6]) & (~(|mantisa[10:6])));

//assign mantisa_pre_el =  ovcheck ? (mantisa[9:0] - 10'b00001_11101) : mantisa[9:0];

//assign mantisa_final  =  mantisa_pre_el >> (5'd15-(input_a[14:10] + input_b[14:10]));
//assign exponent_final =  ovcheck ? (exponent[4:0] + 5'b00001)       : exponent[4:0];

assign result         =  zcheck  ? 32'd0 : {sign_bit, exponent[7:0], mantisa[22:0]};

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

