`timescale 1ns/1ps //  time_unit/time_precision 

module tb_fm_seq_fa_mnist;

    //  ############################################### Nets and Variables ######################################################
    
    //  +-------------+
    //  |  Constants  |
    //  +-------------+
    //
    localparam                      INPUT_NUM_L1  = 784,
                                    INPUT_NUM_L2  = 256,
                                    INPUT_NUM_L3  = 128,
                                    NEURON_NUM_L1 = 256,
                                    NEURON_NUM_L2 = 128,
                                    NEURON_NUM_L3 = 10,
                                    WEIGHT_NUM_L1 = 784,
                                    WEIGHT_NUM_L2 = 256,
                                    WEIGHT_NUM_L3 = 128,
                                    DATA_LENGTH   = 16;
    //
    //  ---------------

    //  +----------------------+
    //  |  Multiplier signals  |
    //  +----------------------+
    //  
    logic                           clk          ;
    logic                           reset_b      ;
    logic                           start        ;
    logic                           clear        ;
    logic                           valid        ;
    //
    logic     [DATA_LENGTH-1:0]     input_in     ;
    logic     [DATA_LENGTH-1:0]     input_weight ;
    logic     [DATA_LENGTH-1:0]     multi_out    ;
    //
    //  ------------------------

    //  +------------------------------+
    //  |  Variables for loading task  |
    //  +------------------------------+
    //
    //int                             input_file; 
    int                             weight_and_bias_file;
    int                             result_file;
    int                             scan_ret_res;
    //int                             scan_ret_in;
    int                             scan_ret_wb;
    int                             start_dump;
    int                             stop_dump;
    //
    //  --------------------------------

    //  +---------------------------------------------------+
    //  |  Variables for storing neuron values and buffers  |
    //  +---------------------------------------------------+
    //
    shortreal                       neuron_l1                 [NEURON_NUM_L1-1:0];
    shortreal                       neuron_l2                 [NEURON_NUM_L2-1:0];
    shortreal                       neuron_l3                 [NEURON_NUM_L3-1:0];
    //
    integer                         start_im;
    integer                         stop_im;
    integer                         image_c;
    logic                           calc_end;
    integer                         pass_count;
    logic                           l1_done;
    logic                           l2_done;
    logic                           l3_done;
    //
    //  -----------------------------------------------------
    
    //  +----------------------------------------------------+
    //  |  Variables for loading inputs, weights and biases  |
    //  +----------------------------------------------------+
    //
    shortreal                       inputs                    [0:(INPUT_NUM_L1)];
    shortreal                       inputs_d                  [];
    //
    shortreal                       weightsnbiases            [];
    shortreal                       weights_l1                [0:((INPUT_NUM_L1*NEURON_NUM_L1)-1)];
    shortreal                       weights_l1_d              [];
    shortreal                       weights_l2                [0:((INPUT_NUM_L2*NEURON_NUM_L2)-1)];
    shortreal                       weights_l2_d              [];
    shortreal                       weights_l3                [0:((INPUT_NUM_L3*NEURON_NUM_L3)-1)];
    shortreal                       weights_l3_d              [];
    //
    shortreal                       biases_l1                 [0:(NEURON_NUM_L1-1)];
    shortreal                       biases_l1_d               [];
    shortreal                       biases_l2                 [0:(NEURON_NUM_L2-1)];
    shortreal                       biases_l2_d               [];
    shortreal                       biases_l3                 [0:(NEURON_NUM_L3-1)];
    shortreal                       biases_l3_d               [];
    //
    integer                         results                   [];
    //
    //  ------------------------------------------------------

    //  #########################################################################################################################


    //  ################################################### Main Segment ########################################################

    //  +-------------------------------+
    //  |   Multiplier instantiations   |
    //  +-------------------------------+
    //
    fp16_multiplier u_dut_0 
    (
        .clk     ( clk          ),
        .reset_b ( reset_b      ),
        .input_a ( input_in     ),
        .input_b ( input_weight ),
        .clear   ( clear        ),
        .start   ( start        ),
        .valid   ( valid        ),
        .result  ( multi_out    )
    );
    //
    //  ---------------------------------

    //  +----------------------+
    //  |   Clock generation   |
    //  +----------------------+
    //
    initial begin
        clk <= 0;
        forever #0.5 clk <= ~clk;
    end
    //
    //  -------------------------    
        
    //  +-----------------+
    //  |   Main Thread   |
    //  +-----------------+
    //
    initial begin
        $write("%c[1;34m",27);
    
        reset();

        pass_count = 0;

        start_dump = $value$plusargs("START=%0d", start_im); 
        stop_dump = $value$plusargs("STOP=%0d", stop_im); 

        load_weight_and_bias();
        load_expected_results();

        for (image_c = start_im; image_c <= stop_im; image_c = image_c + 1) begin
            nn(image_c);
        end

        $display("\n[%10t] :: From image %0d to image %0d :: TOTAL PASSED = %0d :: TOTAL FAILED = %0d", $time, start_im-1, stop_im-1, pass_count, ((stop_im - start_im + 1) - pass_count));

        $write("%c[0m",27);
    
        #20 $stop;
    end
    //
    //  -------------------------
    
    //  #########################################################################################################################


    //  ################################################## Task Declaration #####################################################

    //  +----------------------------+
    //  |   Reset task declaration   |
    //  +----------------------------+
    //  
    task automatic reset();
        $display("[%10t] :: Perfroming initial hardware reset...", $time);
        reset_b                   <= 1'b0;
        start                     <= 1'b0;
        clear                     <= 1'b0;
        
        neuron_l1                 <= '{default:0};
        neuron_l2                 <= '{default:0};
        neuron_l3                 <= '{default:0};

        inputs_d.delete();
        
        @(posedge clk) reset_b    <= 1'b1;
    endtask
    //
    //  ------------------------------
    
    //  +===========================+
    //  |   Main task declaration   |
    //  +===========================+
    //
    task automatic nn(integer test_num);
        integer i;
        shortreal max, max_in, act;
        
        $display("\n==================================================================\n");

        reset();
        load_image_data(test_num);

        layer_1();
        wait(l1_done);
        layer_2();
        wait(l2_done);
        layer_3();
        wait(l3_done);
        layer_3_softmax();
       
        max    = 0;
        max_in = 0;
        act    = 0;

        for (i = 0; i < NEURON_NUM_L3; i = i + 1) begin
            act = neuron_l3[i];
            if(max < act) begin
                max = act;
                max_in = i+1;
            end
            #1;
        end

        if (results[(test_num-1)] == max_in) begin
            pass_count = pass_count + 1;
            $display("[%10t] :: Expected image is %0d :: Detected image is %0d", $time, results[(test_num-1)], max_in);
            $display("[%10t] :: ########### PASSED ###########", $time);
        end else begin
            pass_count = pass_count;
            $display("[%10t] :: Expected image is %0d :: Detected image is %0d", $time, results[(test_num-1)], max_in);
            $display("[%10t] :: ########### FAILED ###########", $time);
        end

        $display("\n==================================================================\n");

        repeat(20) @(posedge clk);
      
    endtask
    //
    //  =============================

    //  +-------------+
    //  |   Layer 1   |
    //  +-------------+
    //
    task automatic layer_1();
        integer l1_nc;
        integer l1_mc;
        
        $display("[%10t] :: Calculating layer 1", $time);
        
        for (l1_nc = 0; l1_nc < NEURON_NUM_L1; l1_nc = l1_nc + 1) begin
            `ifdef DEBUG_MODE
                $display("[%10t] :: --> :: Layer 1 :: Neuron %0d", $time, l1_nc+1);
            `endif
                neuron_l1 [l1_nc] = 0;
            for (l1_mc = 0; l1_mc < INPUT_NUM_L1; l1_mc = l1_mc + 1) begin
                multiplier_handler ( 
                    .in ( inputs     [l1_mc]                      ),
                    .we ( weights_l1 [l1_nc*INPUT_NUM_L1 + l1_mc] )
                );
                neuron_l1 [l1_nc] = neuron_l1 [l1_nc] + bin2float( multi_out );  
            end
            neuron_l1 [l1_nc] = neuron_l1 [l1_nc] + biases_l1 [l1_nc];
            neuron_l1 [l1_nc] = (1 / ($exp(((-1)*neuron_l1 [l1_nc])) + 1));
        end
        #1 l1_done <= 1'b1;
    endtask
    //
    //  ---------------

    //  +-------------+
    //  |   Layer 2   |
    //  +-------------+
    //
    task automatic layer_2();
        integer l2_nc;
        integer l2_mc;
        
        $display("[%10t] :: Calculating layer 2", $time);

        for (l2_nc = 0; l2_nc < NEURON_NUM_L2; l2_nc = l2_nc + 1) begin
            `ifdef DEBUG_MODE
                $display("[%10t] :: --> :: Layer 2 :: Neuron %0d", $time, l2_nc+1);
            `endif
            neuron_l2 [l2_nc] = 0;
            for (l2_mc = 0; l2_mc < INPUT_NUM_L2; l2_mc = l2_mc + 1) begin
                multiplier_handler ( 
                    .in ( neuron_l1  [l2_mc]                      ),
                    .we ( weights_l2 [l2_nc*INPUT_NUM_L2 + l2_mc] )  
                );
                neuron_l2 [l2_nc] = neuron_l2 [l2_nc] + bin2float( multi_out );  
            end
            neuron_l2 [l2_nc] = neuron_l2 [l2_nc] + biases_l2 [l2_nc];
            neuron_l2 [l2_nc] = (1 / ($exp(((-1)*neuron_l2 [l2_nc])) + 1));
        end
        #1 l2_done <= 1'b1;
    endtask
    //
    //  ---------------

    //  +-------------+
    //  |   Layer 3   |
    //  +-------------+
    //
    task automatic layer_3();
        integer l3_nc;
        integer l3_mc;
        
        $display("[%10t] :: Calculating layer 3", $time);

        for (l3_nc = 0; l3_nc < NEURON_NUM_L3; l3_nc = l3_nc + 1) begin
            `ifdef DEBUG_MODE
                $display("[%10t] :: --> :: Layer 3 :: Neuron %0d", $time, l3_nc+1);
            `endif
            neuron_l3 [l3_nc] = 0;
            for (l3_mc = 0; l3_mc < INPUT_NUM_L3; l3_mc = l3_mc + 1) begin
                multiplier_handler ( 
                    .in ( neuron_l2  [l3_mc]                      ),
                    .we ( weights_l3 [l3_nc*INPUT_NUM_L3 + l3_mc] )  
                );
                neuron_l3 [l3_nc] = neuron_l3 [l3_nc] + bin2float( multi_out );  
            end
            neuron_l3 [l3_nc] = neuron_l3 [l3_nc] + biases_l3 [l3_nc];
        end
        #1 l3_done <= 1'b1;
    endtask
    //
    //  ---------------

    //  +------------------------+
    //  |   Multiplier handler   |
    //  +------------------------+
    //
    task automatic multiplier_handler (
        shortreal in,
        shortreal we   
    );
        input_in              <= float2bin(in);
        input_weight          <= float2bin(we);
        @ (posedge clk) start <= 1'b1;
        @ (posedge clk) start <= 1'b0;
        wait(valid);
        @ (posedge clk) clear <= 1'b1;
        @ (posedge clk) clear <= 1'b0;
    endtask
    //
    //  -------------------------

    //  +------------------+
    //  |   Softmax task   |
    //  +------------------+
    //
    task automatic layer_3_softmax();
        shortreal presoft_exp[9:0];
        shortreal exp_tot;
        begin
            presoft_exp[0] = $exp( neuron_l3[0] );
            presoft_exp[1] = $exp( neuron_l3[1] );
            presoft_exp[2] = $exp( neuron_l3[2] );
            presoft_exp[3] = $exp( neuron_l3[3] );
            presoft_exp[4] = $exp( neuron_l3[4] );
            presoft_exp[5] = $exp( neuron_l3[5] );
            presoft_exp[6] = $exp( neuron_l3[6] );
            presoft_exp[7] = $exp( neuron_l3[7] );
            presoft_exp[8] = $exp( neuron_l3[8] );
            presoft_exp[9] = $exp( neuron_l3[9] );
            
            exp_tot = presoft_exp[0] + presoft_exp[1] + presoft_exp[2] + presoft_exp[3] + presoft_exp[4] + presoft_exp[5] + presoft_exp[6] + presoft_exp[7] + presoft_exp[8] + presoft_exp[9];

            neuron_l3[0] = ( presoft_exp[0]/exp_tot );
            neuron_l3[1] = ( presoft_exp[1]/exp_tot );
            neuron_l3[2] = ( presoft_exp[2]/exp_tot );
            neuron_l3[3] = ( presoft_exp[3]/exp_tot );
            neuron_l3[4] = ( presoft_exp[4]/exp_tot );
            neuron_l3[5] = ( presoft_exp[5]/exp_tot );
            neuron_l3[6] = ( presoft_exp[6]/exp_tot );
            neuron_l3[7] = ( presoft_exp[7]/exp_tot );
            neuron_l3[8] = ( presoft_exp[8]/exp_tot );
            neuron_l3[9] = ( presoft_exp[9]/exp_tot );
        end
    endtask
    //
    //  --------------------

    //  +------------------------------+
    //  |   Input value loading task   |
    //  +------------------------------+
    //
    task automatic load_image_data(integer image_num);
        int    input_file;
        int    scan_ret_in;
        string file_name;
        begin 
            $sformat(file_name, "%0d", image_num);
            file_name = {"test_samples_fa_mnist/Image_", file_name, ".txt"}; 
            $display("[%10t] :: Reading sample image %0d", $time, image_num);
            input_file = $fopen(file_name, "r");
    
            if (input_file == 0) begin
                $display("[%10t] :: --> :: Cannot find the input file", $time);
                $finish();
            end else begin
                while (!$feof(input_file)) begin
                    `ifdef DEBUG_MODE
                        $display("[%10t] :: --> :: Reading pixel number %0d", $time, $size(inputs_d));
                    `endif
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
            $display("[%10t] :: Reading weights and biases", $time);
            weight_and_bias_file = $fopen("weights_biases_fa_mnist/weights_and_biases.txt", "r");
    
            if (weight_and_bias_file == 0) begin
                $display("[%10t] :: --> :: Cannot find the input file", $time);
                $finish();
            end else begin
                while (!$feof(weight_and_bias_file)) begin
                    `ifdef DEBUG_MODE
                        $display("[%10t] :: --> :: Reading weight and bias element number %0d", $time, $size(weightsnbiases));
                    `endif
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
            $display("[%10t] :: Extracting weights and biases", $time);
            for (p = 0; p < $size(weightsnbiases); p = p + 1) begin
                if (p < 785*256) begin
                    if (((p + 1) % 785) == 0) begin
                        biases_l1_d  = new [$size(biases_l1_d) + 1]  ( biases_l1_d );
                        biases_l1_d  [$size(biases_l1_d) - 1]  = weightsnbiases[p];
                    end else begin
                        weights_l1_d = new [$size(weights_l1_d) + 1] ( weights_l1_d );
                        weights_l1_d [$size(weights_l1_d) - 1] = weightsnbiases[p];
                    end
                end else if (p >= 785*256 && p < (785*256 + 257*128)) begin
                    if (((p + 1 - 785*256) % 257) == 0) begin
                        biases_l2_d  = new [$size(biases_l2_d) + 1]  ( biases_l2_d );
                        biases_l2_d  [$size(biases_l2_d) - 1]  = weightsnbiases[p];
                    end else begin
                        weights_l2_d = new [$size(weights_l2_d) + 1] ( weights_l2_d );
                        weights_l2_d [$size(weights_l2_d) - 1] = weightsnbiases[p];
                    end
                end else if (p >= 785*256 + 257*128 && p < (785*256 + 257*128 + 129*10)) begin
                    if (((p + 1 - (785*256 + 257*128)) % 129) == 0) begin
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
            $display("[%10t] :: Reading results", $time);
            result_file = $fopen("results_fa_mnist/results.txt", "r");
    
            if (result_file == 0) begin
                $display("[%10t] :: --> :: Cannot find the result file", $time);
                $finish();
            end else begin
                while (!$feof(result_file)) begin
                    `ifdef DEBUG_MODE
                        $display("[%10t] :: --> :: Reading result of image number %0d", $time, $size(results));
                    `endif
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
    function automatic [15:0] float2bin (shortreal float_a);
        logic [31:0] fp32;
        logic [7:0]  exp_temp;
        logic [22:0] man_temp;
        fp32     [31:0] = $shortrealtobits(float_a);
        exp_temp [7:0]  = ((fp32[30:23] - 8'd127) <= (-15)) ? 0                    : (fp32[30:23] - 8'd127 + 8'd15);
        man_temp [22:0] = ((fp32[30:23] - 8'd127) == (-15)) ? {1'b1,fp32[22:1]}    : 
                          ((fp32[30:23] - 8'd127) == (-16)) ? {2'b01, fp32[22:2]}  : 
                          ((fp32[30:23] - 8'd127) == (-17)) ? {3'b001, fp32[22:3]} : fp32[22:0];
        return ((float_a == 0) ? 16'd0 : {fp32[31], exp_temp[4:0], man_temp[22:13]});
    endfunction
    //
    //  ----------------------------------------

    //  +--------------------------------------+
    //  |   Binary to float task declaration   |
    //  +--------------------------------------+
    //  
    function automatic shortreal bin2float (logic [15:0] fp16);
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
  
    //  #########################################################################################################################

endmodule