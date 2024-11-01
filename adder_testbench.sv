module adder_tb;

    logic        clk = 0;
    logic        reset_b;
    logic        start_addition;
    logic        clear;
    logic [15:0] input_a;
    logic [15:0] input_b;
    logic [15:0] result;
    logic        valid;

    logic [15:0] expected_result;

    initial forever begin
        #5 clk = ~clk;
    end

    int error_count = 0;

    // DUT
    fp16_adder DUT (
        .clk            ( clk            ),
        .reset_b        ( reset_b        ),
        .start_addition ( start_addition ),
        .clear          ( clear          ),
        .input_a        ( input_a        ),
        .input_b        ( input_b        ),
        .result         ( result         ),
        .valid          ( valid          )
    );

    int i = 0;

    logic [15:0] input_1 [];
    logic [15:0] input_2 [];
    logic [15:0] results [];

    initial begin
        load_results();
        load_input_1();
        load_input_2();
        reset();

        @(posedge clk);

        for (i = 0; i<392; i++) begin
            add(input_1[i], input_2[i], i);
        end
        
        $display("Total Errors: %d / 392", error_count);

        $finish();
    end

    task reset();
        reset_b         <= 0;
        start_addition  <= 0;
        input_a         <= 0;
        input_b         <= 0;
        clear           <= 0;

        @(posedge clk);

        reset_b         <= 1;
    endtask

    task add(logic [15:0] a, logic [15:0] b, int i);
        input_a <= a;
        input_b <= b;

        start_addition <= 1;

        @(posedge clk);
        start_addition <= 0;

        if (~valid) @(posedge valid);
        @(posedge clk);

        if (results[i] == result) begin
            // $display("Input A: %b %b %b | Input B: %b %b %b | Result: %b | Expected: %b |   PASSED", input_a[15], input_a[14:10], input_a[9:0], input_b[15], input_b[14:10], input_b[9:0], result, results[i]);
        end
        else begin
            $display("Input A: %b %b %b | Input B: %b %b %b | Result: %b | Expected: %b (%h) | - FAILED", input_a[15], input_a[14:10], input_a[9:0], input_b[15], input_b[14:10], input_b[9:0], result, results[i], results[i]);
            error_count++;
        end

        clear <= 1;
        @(posedge clk);
        clear <= 0;

        @(posedge clk);
        @(posedge clk);
    endtask

    logic a_absolute_zero;
    logic b_absolute_zero;
    logic        hidden_bit_a;
    logic        hidden_bit_b;
    logic [10:0] significand_1;
    logic [10:0] significand_2;
    logic [11:0] operation_result;
    logic [4:0]  result_exponent;
    logic        result_sign_bit;

    logic [15:0] bfm_result;
    logic        bfm_valid;

    int result_file;
    int input_1_file;
    int scanRet;
    int input_2_file;

    task adder_bfm(
        input  logic [15:0] bfm_input_a,
        input  logic [15:0] bfm_input_b
    );

        bfm_result = 0;
        bfm_valid = 0;

        a_absolute_zero = (bfm_input_a[14:0] == 0);
        b_absolute_zero = (bfm_input_b[14:0] == 0);

        hidden_bit_a = |bfm_input_a[14:10];
        hidden_bit_b = |bfm_input_b[14:10];

        if (bfm_input_a[14:10] != bfm_input_b[14:10]) begin
            if (bfm_input_a[14:0] > bfm_input_b[14:0]) begin
                significand_1[10:0] = {hidden_bit_a, bfm_input_a[9:0]};
                significand_2[10:0] = {hidden_bit_b, bfm_input_b[9:0]} >> (bfm_input_a[14:10] - bfm_input_b[14:10]);
                result_exponent[4:0] = bfm_input_a[14:10] - 15;
                result_sign_bit = bfm_input_a[15];
            end
            else begin
                significand_1[10:0] = {hidden_bit_b, bfm_input_b[9:0]};
                significand_2[10:0] = {hidden_bit_a, bfm_input_a[9:0]} >> (bfm_input_b[14:10] - bfm_input_a[14:10]);
                result_exponent[4:0] = bfm_input_b[14:10] - 15;
                result_sign_bit = bfm_input_b[15];
            end
        end
        else begin
            significand_1[10:0] = {hidden_bit_a, bfm_input_a[9:0]};
            significand_2[10:0] = {hidden_bit_b, bfm_input_b[9:0]};
        end

        if (bfm_input_a[15] ^ bfm_input_b[15]) begin
            operation_result[11:0] = significand_1[10:0] - significand_2[10:0];
        end
        else begin
            operation_result[11:0] = significand_1[10:0] + significand_2[10:0];
        end

        while (~operation_result[11]) begin
            operation_result[11:0] = operation_result[11:0] << 1;
            result_exponent[4:0] = result_exponent[4:0] - 1;
            @(posedge clk);
        end

        bfm_result[15:0] = { result_sign_bit, result_exponent + 4'd15, operation_result[11:2] };

        bfm_valid = 1;
        $display("Input A: %h | Input B: %h", bfm_input_a, bfm_input_b);
        $display("Input A: %b | Input B: %b | Sign Bit: %b | Sig: %b | Exp: %b", bfm_input_a, bfm_input_b, bfm_result[15], bfm_result[9:0], bfm_result[14:10]);
        $display("Result: %b | %h\n", bfm_result, bfm_result);
        @(posedge clk);

        bfm_valid = 0;

    endtask

    task load_results();
        i = 1;

        result_file = $fopen("adder_results.txt", "r");

        if (result_file == 0) begin
            $display("Cannot find the result file");
            $finish();
        end
        else begin
            while (!$feof(result_file)) begin
                results = new [$size(results)+1] ( results );
                scanRet = $fscanf(result_file, "%b", results[$size(results)-1]);
                // $display("Weight [%d]: %b", i, weights[$size(weights)-1]);
                i++;
            end
        end
        
        $fclose(result_file);
    endtask

    task load_input_1();
        i = 1;
        input_1_file = $fopen("adder_input_1.txt", "r");

        if (input_1_file == 0) begin
            $display("Cannot find the input 1 file");
            $finish();
        end
        else begin
            while (!$feof(input_1_file)) begin
                input_1 = new [$size(input_1)+1] ( input_1 );
                scanRet = $fscanf(input_1_file, "%b", input_1[$size(input_1)-1]);
                // $display("Output [%d]: %b", i, outputs[$size(outputs)-1]);
                i++;
            end
        end
        
        $fclose(input_1_file);
    endtask

    task load_input_2();
        i = 1;
        input_2_file = $fopen("adder_input_2.txt", "r");

        if (input_2_file == 0) begin
            $display("Cannot find the input 2 file");
            $finish();
        end
        else begin
            while (!$feof(input_2_file)) begin
                input_2 = new [$size(input_2)+1] ( input_2 );
                scanRet = $fscanf(input_2_file, "%b", input_2[$size(input_2)-1]);
                // $display("Input [%d]: %b", i, inputs[$size(inputs)-1]);
                i++;
            end
        end
        
        $fclose(input_2_file);
    endtask

endmodule