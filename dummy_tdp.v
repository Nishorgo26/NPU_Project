module dummy_tdp (
    input   wire           clka,
    
    input   wire           wea,
    input   wire   [15:0]  addra,
    input   wire   [15:0]  dina,
    output  wire   [15:0]  douta,

    input   wire           clkb,
    input   wire           web,
    input   wire   [15:0]  addrb,
    input   wire   [15:0]  dinb,
    output  wire   [15:0]  doutb
);

reg [15:0] mem [20479:0];

always @(posedge clka) begin
    if (wea) begin
        mem [addra] <= dina[15:0]; 
    end 
end

always @(posedge clkb) begin
    if (web) begin
        mem [addrb] <= dinb[15:0];
    end
end

assign douta = mem [addra];
assign doutb = mem [addrb];

endmodule                                   
