`timescale 1ns/1ps

module tb;

logic        clk;
logic        reset_b;
logic [15:0] neuron_val;
logic        add_activation; 

logic        valid;
logic [15:0] result;

int input_file;
int result_file;
int scanRet;

integer i;

logic [15:0] inputs[];
logic [15:0] results[];

//  +----------------------------+
//  |    Sigmoid intantiation    |
//  +----------------------------+

sigmoid dut (
    .clk            ( clk           ),
    .reset_b        ( reset_b       ),
    .neuron_val     ( neuron_val    ),
    .add_activation ( add_activation),

    .valid          ( valid         ),
    .result         ( result        )      
);

//  +------------------------+
//  |    Clock generation    |
//  +------------------------+

initial begin
    clk = 0;
    forever begin
        #5 clk = ~clk;
    end
end

//  +-----------------------------+
//  |    Test task invocations    |
//  +-----------------------------+

initial begin
    load_inputs();
    load_results();
    reset();
    for (i = 0; i < $size(inputs); i = i + 1) begin
        test(inputs[i], i);
    end
    $stop;
end

//  +-----------------+
//  |    Test task    |
//  +-----------------+

task test(input [15:0] nval, input integer p);
    begin
        @ (posedge clk) neuron_val     = nval;
        @ (posedge clk) add_activation = 1'b1;
        forever begin
            if (valid) begin
                $display("Test input %d, \t\tInput: %f, \tResult: %f, \tExpected result: %f, \tError percentage: %f", p, fp16_to_real(nval[15:0]), fp16_to_real(result[15:0]), fp16_to_real(results[p]), 100*((fp16_to_real(result[15:0])-fp16_to_real(results[p])) / fp16_to_real(results[p])));
                add_activation = 1'b0;
                break;
            end
            #0.1;
        end
    end
endtask

//  +----------------------------------------+
//  |    fp16 to real convertion function    |
//  +----------------------------------------+

function shortreal fp16_to_real(input [15:0] fp16);
    return $bitstoshortreal({fp16[15], ({3'd0, fp16[14:10]} - 8'd15 + 8'd127), {fp16[9:0],13'd0}});
endfunction

//  +--------------------------------+
//  |    input value loading task    |
//  +--------------------------------+

task load_inputs();
    begin
        input_file = $fopen("demo_input_vals.txt", "r");

        if (input_file == 0) begin
            $display("Cannot find the input file");
            $finish();
        end else begin
            while (!$feof(input_file)) begin
                inputs = new [$size(inputs)+1] ( inputs );
                scanRet = $fscanf(input_file, "%b", inputs[$size(inputs)-1]);
            end
        end
        
        $fclose(input_file);
    end
endtask

//  +---------------------------------+
//  |    result value loading task    |
//  +---------------------------------+

task load_results();
    begin
        result_file = $fopen("demo_input_res.txt", "r");

        if (result_file == 0) begin
            $display("Cannot find the result file");
            $finish();
        end else begin
            while (!$feof(result_file)) begin
                results = new [$size(results)+1] ( results );
                scanRet = $fscanf(result_file, "%b", results[$size(results)-1]);
            end
        end
        
        $fclose(result_file);
    end
endtask

//  +------------------+
//  |    reset task    |
//  +------------------+

task reset();
    begin
        reset_b                 = 1'b0;
        neuron_val              = 16'd0;
        add_activation          = 1'b0;
        @ (posedge clk) reset_b = 1'b1;
    end
endtask
  
endmodule