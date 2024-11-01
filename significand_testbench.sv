module significand_tb;

    `include "../rtl/verilog/npu_params.v";

    logic                      clk = 0;
    logic                      reset_b;
    logic                      start;
    logic [NPU_DATA_WIDTH-1:0] input_a;
    logic [NPU_DATA_WIDTH-1:0] input_b;
    logic                      hidden_bit_a;
    logic                      hidden_bit_b;
    logic                      sign_bit;

    logic [NPU_DATA_WIDTH-1:0] result;
    logic                      valid;
    logic                      significand_msb;

    initial forever begin
        #5 clk = ~clk;
    end

    task reset();
        reset_b <= 0;
        start   <= 0;
        input_a <= 0;
        input_b <= 0;

        @(posedge clk);
        
        reset_b <= 1;

        @(posedge clk);

        start <= 1;

        @(posedge clk);
        start <= 0;

        @(posedge valid);
        #1;

        $display("Input a: %b | Input b: %b | Result: %b (%h)", input_a, input_b, result, result);
    endtask

endmodule