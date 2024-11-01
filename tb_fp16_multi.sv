`timescale 1ns/1ps

module fp16_multi_tb;
  
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

    logic                                        clk;
    logic                                        reset_b;

    logic                                        start_l1;
    logic                                        clear_l1;
    logic                                        valid_l1_tot;
    logic                                        start_l2;
    logic                                        clear_l2;
    logic                                        valid_l2_tot;
    logic                                        start_l3;
    logic                                        clear_l3;
    logic                                        valid_l3_tot;
    
    int                                          input_file;
    int                                          weight_and_bias_file;
    int                                          result_file;
    int                                          scan_ret_res;
    int                                          scan_ret_in;
    int                                          scan_ret_wb;
    
    logic     [(INPUT_NUM_L1*NEURON_NUM_L1)-1:0] valid_l1;
    logic     [(INPUT_NUM_L2*NEURON_NUM_L2)-1:0] valid_l2;
    logic     [(INPUT_NUM_L3*NEURON_NUM_L3)-1:0] valid_l3;

    shortreal                                    neuron_val_l1_presig_sr   [NEURON_NUM_L1-1:0];
    shortreal                                    neuron_val_l1_postsig_sr  [NEURON_NUM_L1-1:0];
    logic     [DATA_LENGTH-1:0]                  neuron_val_l1             [NEURON_NUM_L1-1:0];
    logic     [DATA_LENGTH-1:0]                  multi_out_l1              [(INPUT_NUM_L1*NEURON_NUM_L1)-1:0];

    shortreal                                    neuron_val_l2_presig_sr   [NEURON_NUM_L2-1:0];
    shortreal                                    neuron_val_l2_postsig_sr  [NEURON_NUM_L2-1:0];
    logic     [DATA_LENGTH-1:0]                  neuron_val_l2             [NEURON_NUM_L2-1:0];
    logic     [DATA_LENGTH-1:0]                  multi_out_l2              [(INPUT_NUM_L2*NEURON_NUM_L2)-1:0];

    shortreal                                    neuron_val_l3_presoft_sr  [NEURON_NUM_L3-1:0];
    shortreal                                    neuron_val_l3_postsoft_sr [NEURON_NUM_L3-1:0];
    logic     [DATA_LENGTH-1:0]                  neuron_val_l3             [NEURON_NUM_L3-1:0];
    logic     [DATA_LENGTH-1:0]                  multi_out_l3              [(INPUT_NUM_L3*NEURON_NUM_L3)-1:0];
    
    logic                                        calc_end;
    integer                                      pass_count;

    shortreal                                    inputs         [INPUT_NUM_L1-1:0];
    shortreal                                    inputs_d       [];

    shortreal                                    weightsnbiases [];
    shortreal                                    weights_l1     [((INPUT_NUM_L1*NEURON_NUM_L1)-1):0];
    shortreal                                    weights_l1_d   [];
    shortreal                                    weights_l2     [((INPUT_NUM_L2*NEURON_NUM_L2)-1):0];
    shortreal                                    weights_l2_d   [];
    shortreal                                    weights_l3     [((INPUT_NUM_L3*NEURON_NUM_L3)-1):0];
    shortreal                                    weights_l3_d   [];

    shortreal                                    biases_l1      [NEURON_NUM_L1-1:0];
    shortreal                                    biases_l1_d    [];
    shortreal                                    biases_l2      [NEURON_NUM_L2-1:0];
    shortreal                                    biases_l2_d    [];
    shortreal                                    biases_l3      [NEURON_NUM_L3-1:0];
    shortreal                                    biases_l3_d    [];
    
    integer                                      results        [];
    
    //  +-----------------------------------------+
    //  |   Multiplier instantiations (Layer 1)   |
    //  +-----------------------------------------+
    //
    genvar l1_ic;
    genvar l1_nc;
    //
    generate
        // For loop for selecting neurons of layer 1
        for (l1_nc = 0; l1_nc < NEURON_NUM_L1; l1_nc = l1_nc + 1) begin
            // For loop for selecting inputs and weights of layer 1 
            for (l1_ic = 0; l1_ic < INPUT_NUM_L1; l1_ic = l1_ic + 1) begin
                fp16_multiplier dut (
                    .clk     ( clk                                                      ),
                    .reset_b ( reset_b                                                  ),
                    .input_a ( float2bin ( inputs        [l1_ic] )                      ),
                    .input_b ( float2bin ( weights_l1    [l1_nc*INPUT_NUM_L1 + l1_ic] ) ),
                    .clear   ( clear_l1                                                 ),
                    .start   ( start_l1                                                 ),
                    .valid   ( valid_l1                  [l1_nc*INPUT_NUM_L1 + l1_ic]   ),
                    .result  ( multi_out_l1              [l1_nc*INPUT_NUM_L1 + l1_ic]   )
                );
            end
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
    integer l1_anc;
    //
    initial begin
        wait(valid_l1_tot);
        for (l1_anc = 0; l1_anc < NEURON_NUM_L1; l1_anc = l1_anc + 1) begin
            for (l1_ac = 0; l1_ac < INPUT_NUM_L1; l1_ac = l1_ac + 1) begin
                neuron_val_l1_presig_sr [l1_anc] = neuron_val_l1_presig_sr [l1_anc] + bin2float( multi_out_l1 [l1_anc*INPUT_NUM_L1 + l1_ac] ); 
                //#1;
            end
            neuron_val_l1_postsig_sr [l1_anc] = (1 / ($exp(neuron_val_l1_presig_sr [l1_anc]) + 1));
            neuron_val_l1 [l1_anc]            = float2bin( neuron_val_l1_postsig_sr [l1_anc] );
            //#1;
        end
        @(posedge clk) start_l2 <= 1'b1;
        @(posedge clk) start_l2 <= 1'b0;
    end
    //
    //  ---------------------------------


    //  +----------------------------------------+
    //  |   Multiplier instantiations (Layer 2)  |
    //  +----------------------------------------+
    //
    genvar l2_ic;
    genvar l2_nc;
    //
    generate
        // For loop for selecting neurons of layer 2
        for (l2_nc = 0; l2_nc < NEURON_NUM_L2; l2_nc = l2_nc + 1) begin
            // For loop for selecting inputs and weights of layer 2
            for (l2_ic = 0; l2_ic < INPUT_NUM_L2; l2_ic = l2_ic + 1) begin
                fp16_multiplier dut (
                    .clk     ( clk                                                      ),
                    .reset_b ( reset_b                                                  ),
                    .input_a ( float2bin ( neuron_val_l1 [l2_ic] )                      ),
                    .input_b ( float2bin ( weights_l2    [l2_nc*INPUT_NUM_L2 + l2_ic] ) ),
                    .clear   ( clear_l2                                                 ),
                    .start   ( start_l2                                                 ),
                    .valid   ( valid_l2                  [l2_nc*INPUT_NUM_L2 + l2_ic]   ),
                    .result  ( multi_out_l2              [l2_nc*INPUT_NUM_L2 + l2_ic]   )
                );
            end
        end
    endgenerate
    //
    //  ---------------------------------


    assign valid_l2_tot = &valid_l2; // All multiplier valid of layer 2
    

    //  +------------------------------------------+
    //  |   Neuron Value Determination (Layer 2)   |
    //  +------------------------------------------+
    //
    integer l2_ac;
    integer l2_anc;
    //
    initial begin
        wait(valid_l2_tot);
        for (l2_anc = 0; l2_anc < NEURON_NUM_L2; l2_anc = l2_anc + 1) begin
            for (l2_ac = 0; l2_ac < INPUT_NUM_L2; l2_ac = l2_ac + 1) begin
                neuron_val_l2_presig_sr [l2_anc] = neuron_val_l2_presig_sr [l2_anc] + bin2float( multi_out_l2 [l2_anc*INPUT_NUM_L2 + l2_ac] ); 
                //#1;
            end
            neuron_val_l2_postsig_sr [l2_anc] = (1 / ($exp(neuron_val_l2_presig_sr [l2_anc]) + 1));
            neuron_val_l2 [l2_anc]            = float2bin( neuron_val_l2_presig_sr [l2_anc] );
            //#1;
        end
        @(posedge clk) start_l3 <= 1'b1;
        @(posedge clk) start_l3 <= 1'b0;
    end
    //
    //  ---------------------------------


    //  +----------------------------------------+
    //  |   Multiplier instantiations (Layer 3)  |
    //  +----------------------------------------+
    //
    genvar l3_ic;
    genvar l3_nc;
    //
    generate
        // For loop for selecting neurons of layer 1
        for (l3_nc = 0; l3_nc < NEURON_NUM_L3; l3_nc = l3_nc + 1) begin
            // For loop for selecting inputs and weights of layer 1 
            for (l3_ic = 0; l3_ic < INPUT_NUM_L3; l3_ic = l3_ic + 1) begin
                fp16_multiplier dut (
                    .clk     ( clk                                                      ),
                    .reset_b ( reset_b                                                  ),
                    .input_a ( float2bin ( neuron_val_l2 [l3_ic] )                      ),
                    .input_b ( float2bin ( weights_l3    [l3_nc*INPUT_NUM_L3 + l3_ic] ) ),
                    .clear   ( clear_l3                                                 ),
                    .start   ( start_l3                                                 ),
                    .valid   ( valid_l3                  [l3_nc*INPUT_NUM_L3 + l3_ic]   ),
                    .result  ( multi_out_l3              [l3_nc*INPUT_NUM_L3 + l3_ic]   )
                );
            end
        end
    endgenerate
    //
    //  ---------------------------------


    assign valid_l3_tot = &valid_l3; // All multiplier valid of layer 3
    

    //  +------------------------------------------+
    //  |   Neuron Value Determination (Layer 3)   |
    //  +------------------------------------------+
    //
    integer l3_ac;
    integer l3_anc;
    //
    initial begin
        wait(valid_l3_tot);
        for (l3_anc = 0; l3_anc < NEURON_NUM_L3; l3_anc = l3_anc + 1) begin
            for (l3_ac = 0; l3_ac < INPUT_NUM_L3; l3_ac = l3_ac + 1) begin
                neuron_val_l3_presoft_sr [l3_anc] = neuron_val_l3_presoft_sr [l3_anc] + bin2float( multi_out_l3 [l3_anc*INPUT_NUM_L3 + l3_ac] );
                //#1;
            end
            //#1;
        end
        @(posedge clk) calc_end <= 1'b1;
        @(posedge clk) calc_end <= 1'b0;
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
        start_l2                  <= 1'b0;
        clear_l2                  <= 1'b0;
        start_l3                  <= 1'b0;
        clear_l3                  <= 1'b0;
        
        neuron_val_l1_presig_sr   <= '{default:0};
        neuron_val_l1_postsig_sr  <= '{default:0};
        neuron_val_l2_presig_sr   <= '{default:0};
        neuron_val_l2_postsig_sr  <= '{default:0};
        neuron_val_l3_presoft_sr  <= '{default:0};
        neuron_val_l3_postsoft_sr <= '{default:0};
        pass_count                <= 0;

        @(posedge clk) reset_b <= 1'b1;
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

        load_image_data();
        load_weight_and_bias();
        load_expected_results();

        $display("[%0t] :: Neural network forward propogation test started for sample number %0d", $time, test_num);
        reset();        // Reset task invoked
        $display("[%0t] :: Reset task called", $time);
        @(posedge clk) start_l1 <= 1'b1;
        @(posedge clk) start_l1 <= 1'b0;
        $display("[%0t] :: Layer 1 Calculation started", $time);
        wait(start_l2);
        $display("[%0t] :: Layer 2 calculation started", $time);
        wait(start_l3);
        $display("[%0t] :: Output Layer calculation started", $time);
        wait(calc_end);
        softmax();

        max    = 0;
        max_in = 0;
        act    = 0;

        for (i = 0; i < NEURON_NUM_L3; i = i + 1) begin
            act = bin2float(neuron_val_l3[i]);
            if(max < act) begin
                max = act;
                max_in = i+1;
            end
            #1;
        end

        $display("[%0t] :: Expected image is %0d :: Detected image is %0d", $time, results[test_num], max_in);

        if(max_in == results[test_num]) begin
            pass_count = pass_count + 1;
        end else begin
            pass_count = pass_count;
        end

        repeat(20) @(posedge clk);
      
    endtask
    //
    //  =============================


    //  +------------------+
    //  |   Softmax task   |
    //  +------------------+
    //
    task softmax();
        shortreal presoft_exp[9:0];
        shortreal exp_tot;
        begin
            presoft_exp[0] = $exp( neuron_val_l3_presoft_sr[0] );
            presoft_exp[1] = $exp( neuron_val_l3_presoft_sr[1] );
            presoft_exp[2] = $exp( neuron_val_l3_presoft_sr[2] );
            presoft_exp[3] = $exp( neuron_val_l3_presoft_sr[3] );
            presoft_exp[4] = $exp( neuron_val_l3_presoft_sr[4] );
            presoft_exp[5] = $exp( neuron_val_l3_presoft_sr[5] );
            presoft_exp[6] = $exp( neuron_val_l3_presoft_sr[6] );
            presoft_exp[7] = $exp( neuron_val_l3_presoft_sr[7] );
            presoft_exp[8] = $exp( neuron_val_l3_presoft_sr[8] );
            presoft_exp[9] = $exp( neuron_val_l3_presoft_sr[9] );
            
            exp_tot = presoft_exp[0] + presoft_exp[1] + presoft_exp[2] + presoft_exp[3] + presoft_exp[4] + presoft_exp[5] + presoft_exp[6] + presoft_exp[7] + presoft_exp[8] + presoft_exp[9];

            neuron_val_l3[0] = float2bin( presoft_exp[0]/exp_tot );
            neuron_val_l3[1] = float2bin( presoft_exp[1]/exp_tot );
            neuron_val_l3[2] = float2bin( presoft_exp[2]/exp_tot );
            neuron_val_l3[3] = float2bin( presoft_exp[3]/exp_tot );
            neuron_val_l3[4] = float2bin( presoft_exp[4]/exp_tot );
            neuron_val_l3[5] = float2bin( presoft_exp[5]/exp_tot );
            neuron_val_l3[6] = float2bin( presoft_exp[6]/exp_tot );
            neuron_val_l3[7] = float2bin( presoft_exp[7]/exp_tot );
            neuron_val_l3[8] = float2bin( presoft_exp[8]/exp_tot );
            neuron_val_l3[9] = float2bin( presoft_exp[9]/exp_tot );
        end
    endtask
    //
    //  --------------------
    

    //  +------------------------------+
    //  |   Input value loading task   |
    //  +------------------------------+
    //
    task load_image_data(/*integer image_num*/);
        //reg [8*11:0] file_name;
        begin
            //file_name  = {"image_", $str2int(image_num), ".txt"); 
            input_file = $fopen("image_4.txt", "r");
    
            if (input_file == 0) begin
                $display("Cannot find the input file");
                $finish();
            end else begin
                while (!$feof(input_file)) begin
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
            weight_and_bias_file = $fopen("weights_and_biases.txt", "r");
    
            if (weight_and_bias_file == 0) begin
                $display("Cannot find the input file");
                $finish();
            end else begin
                while (!$feof(weight_and_bias_file)) begin
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
            biases_l2 = biases_l1_d;
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
            result_file = $fopen("results.txt", "r");
    
            if (result_file == 0) begin
                $display("Cannot find the result file");
                $finish();
            end else begin
                while (!$feof(result_file)) begin
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
        exp_temp [7:0]  = fp32[30:23] - 8'd127 + 8'd15;
        man_temp [22:0] = fp32[22:0];
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
