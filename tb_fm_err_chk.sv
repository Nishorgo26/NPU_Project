`timescale 1ns/1ps // time_unit/time_precision

module tb_fm_err_chk;
  
    reg                clk;
    reg                reset_b;
    reg         [15:0] a;
    reg         [15:0] b;
    reg                start;
    reg                clear;
    wire               valid;
    wire        [15:0] out; 
      
    shortreal i, j;
    shortreal max_err = 0;
    shortreal min_err = 0;

    int f_handle;
    int info_f_handle;
    int count;

    fp16_multiplier dut
    (
        .clk     ( clk     ),
        .reset_b ( reset_b ),
        .input_a ( a       ),
        .input_b ( b       ),
        .start   ( start   ),
        .clear   ( clear   ),
        .valid   ( valid   ),
        .result  ( out     )
    );


    initial begin
        clk <= 0;
        forever #0.5 clk <= ~clk;
    end
    

    initial begin
        $write("%c[1;34m",27);
    
        reset();
        
        f_handle = $fopen("raw_multiplication_test_vectors/three_dim/small_num.csv", "w");

        for(i = -1; i <= 1; i = i + 0.0015) begin
            for(j = -1; j <= 1; j = j + 0.0015) begin
                multi_op(i, j);
                #0.5;
            end
        end
    
        $fclose(f_handle);

        info_f_handle = $fopen("raw_multiplication_test_vectors/three_dim/small_num_info.txt", "w");
        
        $fdisplay(info_f_handle, "Max error: %0f", max_err);
        $fdisplay(info_f_handle, "Min error: %0f", min_err);
        
        $fclose(info_f_handle);

        $write("%c[0m",27);
    
        #20 $stop;
    end
    

    task reset();
        reset_b   <=  1'b0;
        a         <=  16'd0;
        b         <=  16'd0;
        start     <=  1'b0;
        clear     <=  1'b0;
        count     <=  0;
        @(posedge clk) reset_b <= 1'b1;
    endtask
    

    task multi_op(shortreal float_a, shortreal float_b);
        shortreal exp, act, err, err_per;

        exp        = 0;
        act        = 0;
        err        = 0;
        err_per    = 0;

        a         <=  float2bin(float_a);
        b         <=  float2bin(float_b);
        @(posedge clk) start <= 1'b1;
        @(posedge clk) start <= 1'b0;
        wait(valid);
        @(posedge clk) clear <= 1'b1;
        @(posedge clk) clear <= 1'b0;
        
        exp     = (float_a*float_b);
        act     = bin2float(out);
        err     = (exp > act) ? (exp - act) : (act - exp);

        if(((float_a*float_b) > 0.0001) || ((float_a*float_b) < -0.0001)) begin
            err_per = (exp == 0)  ? 0 : (err/exp)*100;
        end else begin
            err_per = 0;
        end

        if(max_err < err_per) begin
            max_err = err_per;
        end

        if(min_err > err_per) begin
            min_err = err_per;
        end


        $fdisplay(f_handle, "%f, %f, %f", float_a, float_b, err_per);
        
        count = count + 1;
        $display("[%20t] :: Multiplication number: %0d", $time, count);
        
        /*$display("-------------------------------------------------------------------------------------------------------------");
        $display("input a in binary         = %16b :: input a in float         = %0f",   a,              float_a );
        $display("input b in binary         = %16b :: input b in float         = %0f",   b,              float_b );
        $display("expected output in binary = %16b :: expected output in float = %0f",   float2bin(exp), exp     );
        $display("actual output in binary   = %16b :: actual output in float   = %0f\n", out,            act     );
        $display("error absolute            = %0f",                                      err                     );    
        $display("error percentage          = %0f",                                      err_per                 );    
        $display("-------------------------------------------------------------------------------------------------------------\n\n");*/

    endtask
      

    function [15:0] float2bin (shortreal float_a);
        logic [31:0] fp32;
        logic [7:0]  exp_temp;
        logic [22:0] man_temp;
        fp32     [31:0] = $shortrealtobits(float_a);
        exp_temp [7:0]  = ((fp32[30:23] - 8'd127) <= (-15)) && (float_a < 1) && (float_a > -1) ? 0                    : (fp32[30:23] - 8'd127 + 8'd15);
        man_temp [22:0] = ((fp32[30:23] - 8'd127) == (-15))                  ? {1'b1,fp32[22:1]}    : 
                          ((fp32[30:23] - 8'd127) == (-16))                  ? {2'b01, fp32[22:2]}  : 
                          ((fp32[30:23] - 8'd127) == (-17))                  ? {3'b001, fp32[22:3]} : fp32[22:0];
        return ((float_a == 0) ? 16'd0 : {fp32[31], exp_temp[4:0], man_temp[22:13]});
    endfunction
    

    function shortreal bin2float (logic [15:0] fp16);
        logic [31:0] fp32;
        logic [7:0]  exp_temp;
        logic [22:0] man_temp;
    
        exp_temp [7:0]  = {3'd0, fp16[14:10]} - 8'd15 + 8'd127;
        man_temp [22:0] = {fp16[9:0],13'd0};
        fp32     [31:0] = {fp16[15], exp_temp[7:0], man_temp[22:0]};
    
        return (~(|fp16[15:0]) ? 0 : $bitstoshortreal(fp32[31:0]));
    endfunction
  

endmodule
