module multiplier_tb;
    logic        clk = 0;
    logic        reset_b;
    logic [15:0] input_a;
    logic [15:0] input_b;
    logic        start;

    logic        valid;
    logic [15:0] result;

    fp16_multiplier DUT (
        .clk     ( clk     ),
        .reset_b ( reset_b ),
        .input_a ( input_a ),
        .input_b ( input_b ),
        .start   ( start   ),
        .valid   ( valid   ),
        .result  ( result  )
    );

    initial forever begin
        #5 clk = ~clk;
    end

    int weight_file;
    int output_file;
    int input_file;
    int scanRet;
    int i;

    logic [15:0] weights [];
    logic [15:0] outputs [];
    logic [15:0] inputs  [];

    int error_count = 0;

    initial begin
        load_inputs();
        load_weights();
        load_outputs();
        
        reset();

        for (i = 0; i<784; i++) begin
            input_a <= inputs[i];
            input_b <= weights[i];

            @(posedge clk);

            start <= 1;

            @(posedge valid);
            #1;
            
            if (outputs[i] != result) begin
                $display("[%d] Output: %b \t Result: %b \t  - FAILED", i, outputs[i], result);

                $display("significand_a      : %b", DUT.significand_a       );  
                $display("significand_b      : %b", DUT.significand_b       );  
                $display("sign_bit_a         : %b", DUT.sign_bit_a          );  
                $display("sign_bit_b         : %b", DUT.sign_bit_b          );  
                $display("exponent_a         : %b", DUT.exponent_a          );  
                $display("exponent_b         : %b", DUT.exponent_b          );
                $display("result_sign_bit    : %b", DUT.result_sign_bit     );
                $display("a_or_b_zero        : %b", DUT.a_or_b_zero         );
                $display("hidden_bit_a       : %b", DUT.hidden_bit_a        );
                $display("hidden_bit_b       : %b", DUT.hidden_bit_b        );
                $display("result_significand : %b", DUT.result_significand  );
                $display("significand_msb    : %b", DUT.significand_msb     );
                $display("a_absolute_zero    : %b", DUT.a_absolute_zero     );
                $display("b_absolute_zero    : %b", DUT.b_absolute_zero     );
                $display("result_exponent    : %b", DUT.result_exponent     );
                $display("guard_bit          : %b", DUT.u_significand_handler.guard_bit           );
                $display("round_bit          : %b", DUT.u_significand_handler.round_bit           );
                $display("sticky_bit         : %b", DUT.u_significand_handler.sticky_bit          );
                $display("quotiont q         : %b", DUT.u_significand_handler.quotiont_q     );
                $display("result_int         : %b", DUT.u_significand_handler.result_int     );
                $display("halfway_case       : %b", DUT.u_significand_handler.halfway_case     );
                $display();
                error_count++;
            end

            // if (error_count == 4) begin
            //     $display("Maximum error limit reached");
            //     break;
            // end
            start <= 0;

            @(posedge clk);
        end

        repeat(10) @(posedge clk);
        $display("Total errors: %d", error_count);
        $finish();
    end

    task reset();
        reset_b <= 'b0;
        input_a <= 'b0;
        input_b <= 'b0;
        start   <= 'b0;

        @(posedge clk);

        reset_b <= 'b1;
    endtask

    task load_weights();
        i = 1;

        weight_file = $fopen("weights_h1.txt", "r");

        if (weight_file == 0) begin
            $display("Cannot find the weight file");
            $finish();
        end
        else begin
            while (!$feof(weight_file) & i<=784) begin
                weights = new [$size(weights)+1] ( weights );
                scanRet = $fscanf(weight_file, "%b", weights[$size(weights)-1]);
                // $display("Weight [%d]: %b", i, weights[$size(weights)-1]);
                i++;
            end
        end
        
        $fclose(weight_file);
    endtask

    task load_outputs();
        i = 1;
        output_file = $fopen("fp16_multiplication_result.txt", "r");

        if (output_file == 0) begin
            $display("Cannot find the output file");
            $finish();
        end
        else begin
            while (!$feof(output_file) & i<=784) begin
                outputs = new [$size(outputs)+1] ( outputs );
                scanRet = $fscanf(output_file, "%b", outputs[$size(outputs)-1]);
                // $display("Output [%d]: %b", i, outputs[$size(outputs)-1]);
                i++;
            end
        end
        
        $fclose(output_file);
    endtask

    task load_inputs();
        i = 1;
        input_file = $fopen("binary_fp16_image.txt", "r");

        if (input_file == 0) begin
            $display("Cannot find the input file");
            $finish();
        end
        else begin
            while (!$feof(input_file) & i<=784) begin
                inputs = new [$size(inputs)+1] ( inputs );
                scanRet = $fscanf(input_file, "%b", inputs[$size(inputs)-1]);
                // $display("Input [%d]: %b", i, inputs[$size(inputs)-1]);
                i++;
            end
        end
        
        $fclose(input_file);
    endtask

endmodule