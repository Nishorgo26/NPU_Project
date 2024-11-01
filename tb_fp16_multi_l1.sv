`timescale 1ns/1ps

module fp16_multi_tb_l1;
  
    parameter                                    INPUT_NUM_L1  = 3072,
                                                 INPUT_NUM_L2  = 256,
                                                 INPUT_NUM_L3  = 128,
                                                 NEURON_NUM_L1 = 256,
                                                 NEURON_NUM_L2 = 128,
                                                 NEURON_NUM_L3 = 10,
                                                 WEIGHT_NUM_L1 = 3072,
                                                 WEIGHT_NUM_L2 = 256,
                                                 WEIGHT_NUM_L3 = 128,
                                                 DATA_LENGTH   = 16;

    parameter                                    NEURON_SELECTOR = 99;

    logic                                        clk;
    logic                                        reset_b;

    logic                                        start_l1;
    logic                                        clear_l1;
    logic                                        valid_l1_tot;
    
    int                                          input_file;
    int                                          weight_and_bias_file;
    int                                          result_file;
    int                                          scan_ret_res;
    int                                          scan_ret_in;
    int                                          scan_ret_wb;
    
    logic     [(INPUT_NUM_L1-1):0]               valid_l1;

    shortreal                                    neuron_val_l1_presig_sr;
    shortreal                                    neuron_val_l1_presig_sr_exp;
    shortreal                                    neuron_val_l1_postsig_sr;
    shortreal                                    neuron_val_l1_postsig_sr_exp;
    logic     [DATA_LENGTH-1:0]                  neuron_val_l1;
    logic     [DATA_LENGTH-1:0]                  multi_out_l1              [(INPUT_NUM_L1-1):0];

    logic                                        calc_end;
    integer                                      pass_count;

    shortreal                                    inputs                    [0:(INPUT_NUM_L1)];
    shortreal                                    inputs_d                  [];

    shortreal                                    weightsnbiases            [];
    shortreal                                    weights_l1                [0:((INPUT_NUM_L1*NEURON_NUM_L1)-1)];
    shortreal                                    weights_l1_d              [];
    shortreal                                    weights_l2                [0:((INPUT_NUM_L2*NEURON_NUM_L2)-1)];
    shortreal                                    weights_l2_d              [];
    shortreal                                    weights_l3                [0:((INPUT_NUM_L3*NEURON_NUM_L3)-1)];
    shortreal                                    weights_l3_d              [];

    shortreal                                    biases_l1                 [0:(NEURON_NUM_L1-1)];
    shortreal                                    biases_l1_d               [];
    shortreal                                    biases_l2                 [0:(NEURON_NUM_L2-1)];
    shortreal                                    biases_l2_d               [];
    shortreal                                    biases_l3                 [0:(NEURON_NUM_L3-1)];
    shortreal                                    biases_l3_d               [];
    
    integer                                      results                   [];
    
    //  +-----------------------------------------+
    //  |   Multiplier instantiations (Layer 1)   |
    //  +-----------------------------------------+
    //
    genvar l1_ic;
    genvar l1_nc;
    //
    generate
        // For loop for selecting inputs and weights of layer 1 
        for (l1_ic = 0; l1_ic < INPUT_NUM_L1; l1_ic = l1_ic + 1) begin
            fp16_multiplier dut (
                .clk     ( clk                                                                ),
                .reset_b ( reset_b                                                            ),
                .input_a ( float2bin ( inputs        [l1_ic] )                                ),
                .input_b ( float2bin ( weights_l1    [NEURON_SELECTOR*INPUT_NUM_L1 + l1_ic] ) ),
                .clear   ( clear_l1                                                           ),
                .start   ( start_l1                                                           ),
                .valid   ( valid_l1                  [l1_ic]                                  ),
                .result  ( multi_out_l1              [l1_ic]                                  )
            );
        end
    endgenerate
    //
    //  ---------------------------------


    assign valid_l1_tot = &valid_l1; // All multiplier valid of layer 1
    

    //  +------------------------------------------+
    //  |   Neuron Value Determination (Layer 1)   |
    //  +------------------------------------------+
    //
    integer l1_ac;
    shortreal expected, actual, error;
    //
    initial begin
        wait(valid_l1_tot);
            for (l1_ac = 0; l1_ac < INPUT_NUM_L1; l1_ac = l1_ac + 1) begin
                expected = (inputs[l1_ac]*weights_l1[NEURON_SELECTOR*INPUT_NUM_L1 + l1_ac]);
                /*actual   = bin2float(multi_out_l1[l1_ac]);
                error    = ((expected-actual)/expected)*100;
                if((error > 100) || (error < -100)) begin
                    $display("\n\nexpected multiplication result = %0f \nexpected multiplication result in bin = %16b \ncaptured multiplication result = %0f \ncaptured multiplication result = %16b \nerror percentage = %0f\n", expected, float2bin(expected), actual, multi_out_l1[l1_ac], error);
                    $display("error resulting input in binary = %16b \nerror resulting input in float = %0f \nerror resulting weight in binary = %16b \nerror resulting weight in float = %0f", float2bin(inputs[l1_ac]), inputs[l1_ac], float2bin(weights_l1[NEURON_SELECTOR*INPUT_NUM_L1 + l1_ac]), weights_l1[NEURON_SELECTOR*INPUT_NUM_L1 + l1_ac]);
                end*/
                neuron_val_l1_presig_sr_exp = neuron_val_l1_presig_sr_exp + expected; 
                neuron_val_l1_presig_sr     = neuron_val_l1_presig_sr + bin2float( multi_out_l1 [l1_ac] ); 
                #0.1;
            end
            neuron_val_l1_presig_sr       =  neuron_val_l1_presig_sr + biases_l1[NEURON_SELECTOR];
            neuron_val_l1_presig_sr_exp   =  neuron_val_l1_presig_sr_exp + biases_l1[NEURON_SELECTOR];
            neuron_val_l1_postsig_sr      =  (1 / ($exp(((-1)*neuron_val_l1_presig_sr)) + 1));
            neuron_val_l1_postsig_sr_exp  =  (1 / ($exp(((-1)*neuron_val_l1_presig_sr_exp)) + 1));
            neuron_val_l1                 =  float2bin( neuron_val_l1_postsig_sr );
        @(posedge clk) calc_end          <=  1'b1;
    end
    //
    //  ---------------------------------


    //  +-----------------------+
    //  |   Clock generation    |
    //  +-----------------------+
    //
    initial begin
        clk <= 0;
        forever #5 clk <= ~clk;
    end
    //
    //  -------------------------    
    
    
    //  +-----------------------+
    //  |   Test invocations    |
    //  +-----------------------+
    //
    initial begin
        $write("%c[1;34m",27);
    
        reset();
        nn(4);
                
        $write("%c[0m",27);
    
        #20 $stop;
    end
    //
    //  -------------------------
    

    //  +----------------------------+
    //  |   Reset task declaration   |
    //  +----------------------------+
    //  
    task reset();
        $display("[%0t] :: Perfroming initial hardware reset...", $time);
        reset_b                   <= 1'b0;
        start_l1                  <= 1'b0;
        clear_l1                  <= 1'b0;
               
        neuron_val_l1_presig_sr   <= 0;
        neuron_val_l1_postsig_sr  <= 0;
        pass_count                <= 0;

        @(posedge clk) reset_b    <= 1'b1;
    endtask
    //
    //  ------------------------------
    

    //  +===========================+
    //  |   Main task declaration   |
    //  +===========================+
    //
    task nn(integer test_num);
        integer i;
        shortreal act, max, max_in;

        load_image_data(test_num);
        load_weight_and_bias();
        load_expected_results();

        reset();        // Reset task invoked
        @(posedge clk) start_l1 <= 1'b1;
        @(posedge clk) start_l1 <= 1'b0;
        wait(calc_end);
       
        $display("[%0t] :: Captured value of neuron number %0d is %0f before sigmoid and %0f after applying sigmoid", $time, (NEURON_SELECTOR+1), neuron_val_l1_presig_sr, neuron_val_l1_postsig_sr);
        $display("[%0t] :: Expexted value of neuron number %0d is %0f before sigmoid and %0f after applying sigmoid", $time, (NEURON_SELECTOR+1), neuron_val_l1_presig_sr_exp, neuron_val_l1_postsig_sr_exp);

        repeat(20) @(posedge clk);
      
    endtask
    //
    //  =============================


    //  +------------------------------+
    //  |   Input value loading task   |
    //  +------------------------------+
    //
    task load_image_data(integer image_num);
        //reg [8*11:0] file_name;
        begin
            //file_name  = {"image_", $str2int(image_num), ".txt"); 
            $display("[%0t] :: Reading sample image %0d", $time, image_num);
            input_file = $fopen("image_4.txt", "r");
    
            if (input_file == 0) begin
                $display("Cannot find the input file");
                $finish();
            end else begin
                while (!$feof(input_file)) begin
                    $display("[%0t] :: --> Reading pixel number %0d", $time, $size(inputs_d));
                    inputs_d      = new [$size(inputs_d)+1] ( inputs_d );
                    scan_ret_in = $fscanf(input_file, "%f", inputs_d[$size(inputs_d)-1]);
                end
                inputs = inputs_d;
            end
            
            $fclose(input_file);
        end
    endtask
    //
    //  --------------------------------
    
    
    //  +----------------------------------------+
    //  |   Weight and Bias value loading task   |
    //  +----------------------------------------+
    //
    task load_weight_and_bias();
        begin
            $display("[%0t] :: Reading weights and biases", $time);
            weight_and_bias_file = $fopen("weights_and_biases.txt", "r");
    
            if (weight_and_bias_file == 0) begin
                $display("Cannot find the input file");
                $finish();
            end else begin
                while (!$feof(weight_and_bias_file)) begin
                    $display("[%0t] :: --> Reading weight and bias element number %0d", $time, $size(weightsnbiases));
                    weightsnbiases = new [$size(weightsnbiases)+1] ( weightsnbiases );
                    scan_ret_wb    = $fscanf(weight_and_bias_file, "%f", weightsnbiases[$size(weightsnbiases)-1]);
                end
            end
            
            extract_weight_and_bias();

            $fclose(weight_and_bias_file);
        end
    endtask
    //
    //  ------------------------------------------

    //  +--------------------------------+
    //  |   Weight and Bias extraction   |
    //  +--------------------------------+
    //
    task extract_weight_and_bias();
        integer p;
        begin
            $display("[%0t] :: --> :: --> Extracting weights and biases", $time);
            for (p = 0; p < $size(weightsnbiases); p = p + 1) begin
                if (p < 3073*256) begin
                    if (((p + 1) % 3073) == 0) begin
                        biases_l1_d  = new [$size(biases_l1_d) + 1]  ( biases_l1_d );
                        biases_l1_d  [$size(biases_l1_d) - 1]  = weightsnbiases[p];
                    end else begin
                        weights_l1_d = new [$size(weights_l1_d) + 1] ( weights_l1_d );
                        weights_l1_d [$size(weights_l1_d) - 1] = weightsnbiases[p];
                    end
                end else if (p >= 3073*256 && p < (3073*256 + 257*128)) begin
                    if (((p + 1 - 3073*256) % 257) == 0) begin
                        biases_l2_d  = new [$size(biases_l2_d) + 1]  ( biases_l2_d );
                        biases_l2_d  [$size(biases_l2_d) - 1]  = weightsnbiases[p];
                    end else begin
                        weights_l2_d = new [$size(weights_l2_d) + 1] ( weights_l2_d );
                        weights_l2_d [$size(weights_l2_d) - 1] = weightsnbiases[p];
                    end
                end else if (p >= 3073*256 + 257*128 && p < (3073*256 + 257*128 + 129*10)) begin
                    if (((p + 1 - (3073*256 + 257*128)) % 129) == 0) begin
                        biases_l3_d  = new [$size(biases_l3_d) + 1]  ( biases_l3_d );
                        biases_l3_d  [$size(biases_l3_d) - 1]  = weightsnbiases[p];
                    end else begin
                        weights_l3_d = new [$size(weights_l3_d) + 1] ( weights_l3_d );
                        weights_l3_d [$size(weights_l3_d) - 1] = weightsnbiases[p];
                    end
                end
            end
            biases_l1 = biases_l1_d;
            biases_l2 = biases_l2_d;
            biases_l3 = biases_l3_d;
            weights_l1 = weights_l1_d;
            weights_l2 = weights_l2_d;
            weights_l3 = weights_l3_d; 
        end
    endtask
    //
    //  ----------------------------------


    //  +-------------------------------+
    //  |   Result value loading task   |
    //  +-------------------------------+
    //
    task load_expected_results();
        begin
            $display("[%0t] :: Reading results", $time);
            result_file = $fopen("results.txt", "r");
    
            if (result_file == 0) begin
                $display("Cannot find the result file");
                $finish();
            end else begin
                while (!$feof(result_file)) begin
                    $display("[%0t] :: --> Reading result of image number %0d", $time, $size(results));
                    results     = new [$size(results)+1] ( results );
                    scan_ret_res = $fscanf(result_file, "%d", results[$size(results)-1]);
                end
            end
            
            $fclose(result_file);
        end
    endtask
    //
    //  ---------------------------------


    //  +--------------------------------------+
    //  |   Float to binary task declaration   |
    //  +--------------------------------------+
    //  
    function [15:0] float2bin (shortreal float_a);
        logic [31:0] fp32;
        logic [7:0]  exp_temp;
        logic [22:0] man_temp;
        fp32     [31:0] = $shortrealtobits(float_a);
        exp_temp [7:0]  = ((fp32[30:23] - 8'd127) <= (-15)) ? 0 : (fp32[30:23] - 8'd127 + 8'd15);
        man_temp [22:0] = ((fp32[30:23] - 8'd127) == (-15)) ? {1'b1,fp32[22:1]} : 
                          ((fp32[30:23] - 8'd127) == (-16)) ? {2'b01, fp32[22:2]} : 
                          ((fp32[30:23] - 8'd127) == (-17)) ? {3'b001, fp32[22:3]} : fp32[22:0];
        return ((float_a == 0) ? 16'd0 : {fp32[31], exp_temp[4:0], man_temp[22:13]});
    endfunction
    //
    //  ----------------------------------------


    //  +--------------------------------------+
    //  |   Binary to float task declaration   |
    //  +--------------------------------------+
    //  
    function shortreal bin2float (logic [15:0] fp16);
        logic [31:0] fp32;
        logic [7:0]  exp_temp;
        logic [22:0] man_temp;
    
        exp_temp [7:0]  = {3'd0, fp16[14:10]} - 8'd15 + 8'd127;
        man_temp [22:0] = {fp16[9:0],13'd0};
        fp32     [31:0] = {fp16[15], exp_temp[7:0], man_temp[22:0]};
    
        return (~(|fp16[15:0]) ? 0 : $bitstoshortreal(fp32[31:0]));
    endfunction
    //
    //  ----------------------------------------
  
endmodule



