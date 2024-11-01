module calculator_tb;

    localparam NPU_DATA_WIDTH = 16;

    logic                          clk = 0;
    logic                          reset_b;
    logic                          start;
    logic [NPU_DATA_WIDTH - 1 : 0] input_0;
    logic [NPU_DATA_WIDTH - 1 : 0] input_1;
    logic [NPU_DATA_WIDTH - 1 : 0] input_2;
    logic [NPU_DATA_WIDTH - 1 : 0] input_3;
    logic [NPU_DATA_WIDTH - 1 : 0] input_4;
    logic [NPU_DATA_WIDTH - 1 : 0] input_5;
    logic [NPU_DATA_WIDTH - 1 : 0] input_6;
    logic [NPU_DATA_WIDTH - 1 : 0] input_7;
    logic [NPU_DATA_WIDTH - 1 : 0] input_8;
    logic [NPU_DATA_WIDTH - 1 : 0] input_9;
    logic [NPU_DATA_WIDTH - 1 : 0] input_10;
    logic [NPU_DATA_WIDTH - 1 : 0] input_11;
    logic [NPU_DATA_WIDTH - 1 : 0] input_12;
    logic [NPU_DATA_WIDTH - 1 : 0] input_13;
    logic [NPU_DATA_WIDTH - 1 : 0] input_14;
    logic [NPU_DATA_WIDTH - 1 : 0] input_15;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_0;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_1;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_2;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_3;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_4;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_5;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_6;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_7;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_8;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_9;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_10;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_11;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_12;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_13;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_14;
    logic [NPU_DATA_WIDTH - 1 : 0] weight_15;
    logic                          valid;
    logic                          write_en_fr_neuron;
    logic [NPU_DATA_WIDTH - 1 :0]  result;
    
    initial forever begin
        #5 clk = ~clk;
    end

    calculator DUT (
        .clk                ( clk                ),
        .reset_b            ( reset_b            ),
        .start              ( start              ),
        .input_0            ( input_0            ),
        .input_1            ( input_1            ),
        .input_2            ( input_2            ),
        .input_3            ( input_3            ),
        .input_4            ( input_4            ),
        .input_5            ( input_5            ),
        .input_6            ( input_6            ),
        .input_7            ( input_7            ),
        .input_8            ( input_8            ),
        .input_9            ( input_9            ),
        .input_10           ( input_10           ),
        .input_11           ( input_11           ),
        .input_12           ( input_12           ),
        .input_13           ( input_13           ),
        .input_14           ( input_14           ),
        .input_15           ( input_15           ),
        .weight_0           ( weight_0           ),
        .weight_1           ( weight_1           ),
        .weight_2           ( weight_2           ),
        .weight_3           ( weight_3           ),
        .weight_4           ( weight_4           ),
        .weight_5           ( weight_5           ),
        .weight_6           ( weight_6           ),
        .weight_7           ( weight_7           ),
        .weight_8           ( weight_8           ),
        .weight_9           ( weight_9           ),
        .weight_10          ( weight_10          ),
        .weight_11          ( weight_11          ),
        .weight_12          ( weight_12          ),
        .weight_13          ( weight_13          ),
        .weight_14          ( weight_14          ),
        .weight_15          ( weight_15          ),
        .valid              ( valid              ),
        .result             ( result             )
    );

    int weight_file;
    int output_file;
    int input_file;
    int multiplied_file;
    int scanRet;
    int i;

    logic [15:0] weights [];
    logic [15:0] outputs [];
    logic [15:0] inputs  [];


    initial begin
        load_inputs();
        load_weights();
        load_outputs();
        
        reset();

        for (int i = 0; i<49; i++) begin
            calculate(i);
        end

        repeat(200) @(posedge clk);
        $finish();
    end

    task load_weights();
        i = 0;

        weight_file = $fopen("weights_h1.txt", "r");

        if (weight_file == 0) begin
            $display("Cannot find the weight file");
            $finish();
        end
        else begin
            while (!$feof(weight_file)) begin
                weights = new [$size(weights)+1] ( weights );
                scanRet = $fscanf(weight_file, "%h", weights[$size(weights)-1]);
                $display("Weight [%d]: %b", i, weights[$size(weights)-1]);
                i++;
            end
        end
        
        $fclose(weight_file);
    endtask

    task load_outputs();
        i = 0;
        output_file = $fopen("weights_op.txt", "r");

        if (output_file == 0) begin
            $display("Cannot find the output file");
            $finish();
        end
        else begin
            while (!$feof(output_file)) begin
                outputs = new [$size(outputs)+1] ( outputs );
                scanRet = $fscanf(output_file, "%h", outputs[$size(outputs)-1]);
                $display("Output [%d]: %b", i, outputs[$size(outputs)-1]);
                i++;
            end
        end
        
        $fclose(output_file);
    endtask

    task load_inputs();
        i = 0;
        input_file = $fopen("binary_fp16_image.txt", "r");

        if (input_file == 0) begin
            $display("Cannot find the input file");
            $finish();
        end
        else begin
            while (!$feof(input_file)) begin
                inputs = new [$size(inputs)+1] ( inputs );
                scanRet = $fscanf(input_file, "%h", inputs[$size(inputs)-1]);
                $display("Input [%d]: %b", i, inputs[$size(inputs)-1]);
                i++;
            end
        end
        
        $fclose(input_file);
    endtask

    task reset();
        reset_b <= 0;
        start            <= 0;
        input_0          <= 0;
        input_1          <= 0;
        input_2          <= 0;
        input_3          <= 0;
        input_4          <= 0;
        input_5          <= 0;
        input_6          <= 0;
        input_7          <= 0;
        input_8          <= 0;
        input_9          <= 0;
        input_10         <= 0;
        input_11         <= 0;
        input_12         <= 0;
        input_13         <= 0;
        input_14         <= 0;
        input_15         <= 0;
        weight_0         <= 0;
        weight_1         <= 0;
        weight_2         <= 0;
        weight_3         <= 0;
        weight_4         <= 0;
        weight_5         <= 0;
        weight_6         <= 0;
        weight_7         <= 0;
        weight_8         <= 0;
        weight_9         <= 0;
        weight_10        <= 0;
        weight_11        <= 0;
        weight_12        <= 0;
        weight_13        <= 0;
        weight_14        <= 0;
        weight_15        <= 0;
        @(posedge clk);

        reset_b <= 1;

        @(posedge clk);
    endtask

    task calculate(int index);
        input_0          <= inputs [index*16 + 0 ];
        input_1          <= inputs [index*16 + 1 ];
        input_2          <= inputs [index*16 + 2 ];
        input_3          <= inputs [index*16 + 3 ];
        input_4          <= inputs [index*16 + 4 ];
        input_5          <= inputs [index*16 + 5 ];
        input_6          <= inputs [index*16 + 6 ];
        input_7          <= inputs [index*16 + 7 ];
        input_8          <= inputs [index*16 + 8 ];
        input_9          <= inputs [index*16 + 9 ];
        input_10         <= inputs [index*16 + 10];
        input_11         <= inputs [index*16 + 11];
        input_12         <= inputs [index*16 + 12];
        input_13         <= inputs [index*16 + 13];
        input_14         <= inputs [index*16 + 14];
        input_15         <= inputs [index*16 + 15];

        weight_0         <= weights[index*16 + 0 ];
        weight_1         <= weights[index*16 + 1 ];
        weight_2         <= weights[index*16 + 2 ];
        weight_3         <= weights[index*16 + 3 ];
        weight_4         <= weights[index*16 + 4 ];
        weight_5         <= weights[index*16 + 5 ];
        weight_6         <= weights[index*16 + 6 ];
        weight_7         <= weights[index*16 + 7 ];
        weight_8         <= weights[index*16 + 8 ];
        weight_9         <= weights[index*16 + 9 ];
        weight_10        <= weights[index*16 + 10];
        weight_11        <= weights[index*16 + 11];
        weight_12        <= weights[index*16 + 12];
        weight_13        <= weights[index*16 + 13];
        weight_14        <= weights[index*16 + 14];
        weight_15        <= weights[index*16 + 15];

        start            <= 1;

        @(posedge clk);

        @(DUT.combined_multiplier_valid);

        multiplied_file = $fopen("multiplied.txt", "a");

        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_0  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_1  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_2  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_3  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_4  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_5  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_6  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_7  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_8  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_9  );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_10 );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_11 );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_12 );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_13 );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_14 );
        $fdisplay(multiplied_file, "%b", DUT.multiplier_result_15 );

        $fclose(multiplied_file);

        @(posedge valid);
        start            <= 0;
        #1;
        $display("Result: %b (%h)", result, result);
        @(posedge clk);

    endtask


endmodule