`timescale 1ns/1ns
// `define DEBUG

module testbench;

    `include "../rtl/verilog/npu_params.v";

/// [DUT Signals]
    bit                           clk;
    bit                           reset_b;
    bit [1:0]                     mode ;
    bit                           spi_ss;
    bit                           spi_sclk;
    bit                           spi_mosi;
    logic                         spi_miso;
    logic                         start_transmission;
    bit                           soft_reset;
    logic [NPU_DATA_WIDTH - 1 :0] tb_capture_data;

/// [Testbench Variables]
    int count = 0;
    int i;
    int total_size;

/// [Layer Arrays]
    logic [15:0] weights [];
    logic [15:0] inputs  [];

/// [Files/File variables]
    int weight_file;
    int input_file;
    int fifo_output_file;
    int scanRet;

/// [Files/Filenames]
    string input_file_f;
    string weight_file_f        = "../weights.txt";
    // string weight_file_f        = "../weights_15neuron.txt";
    string fifo_output_file_f   = "../fifo_output.txt";

/// [Arguments]
    int t;
    initial begin
        t = $value$plusargs("INPUTFILE=%s", input_file_f);
    end

/// [DUT]
    npu_top u_npu_top(
    `ifdef DEBUG                                        // Debug mode: Loads inputs faster
        .debug_wr_en          ( debug_wr_en         ),
        .debug_data           ( debug_data          ),
    `endif                                              // Normal mode: Loads inputs through SPI
        .spi_ss               ( spi_ss              ),
        .spi_sclk             ( spi_sclk            ),
        .spi_mosi             ( spi_mosi            ),
        .spi_miso             ( spi_miso            ),
        .clk                  ( clk                 ),
        .reset_b              ( reset_b             ),
        .mode                 ( mode                ),
        .start_transmission   ( start_transmission  )
        // .soft_reset           ( soft_reset          )
    );

/// [Clock generation]
    initial forever begin
        #5 clk = ~clk;
    end

/// [Main testbench]
    initial begin
        load_inputs();               //  Populate the input array from input file
        load_weights();              //  Populate the weight array from weights.txt file

        total_size= ($size(inputs)+$size(weights));
        if(total_size>20400) begin
            $display("ERROR: Memory Limit Exceeded.\nMaximun allocation is 20400 fp16 data.\nBut Provided with %d fp16 data.\n Simulation Exiting...", total_size);
            $finish();
        end
        reset();                     // Apply reset

        mode = 2'b10;

        // reg_write(16'h04, 784);      //  Number of inputs
        reg_write(16'h08, 3);        //  Number of layers

        mode = 2'b01;

        transfer(784);               // Transfer number of inputs
        transfer(10);                // Transfer number of hidden layer neurons
        transfer(10);                // Transfer number of output layer neurons
        // transfer(6);

        for (int k = 0; k < $size(inputs) - 1; k++ ) begin            //
            transfer(inputs[k]);                                      //  Transfer the inputs
        end                                                           //

        for (int k = 0; k < $size(weights); k++ ) begin               //
            transfer(weights[k]);                                     //  Transfer the output layer weights
        end                                                           //

        repeat(100)@(posedge clk);

        mode = 2'b11;

        repeat(200000)@(posedge clk);

        $finish();
    end

/// [Read data from NPU]
    initial begin
        fifo_output_file = $fopen(fifo_output_file_f, "w");
        $fwrite(fifo_output_file);
        $fclose(fifo_output_file);
    end

    always @(posedge start_transmission) begin
        mode = 2'b00;
        spi_data_transmit_output(8'bxxxxxxxx);
        spi_data_transmit_output(8'bxxxxxxxx);
        $display("value of [%0d] neuron is : %b | %h ",count, tb_capture_data, tb_capture_data);
        count = count+1;

        fifo_output_file = $fopen(fifo_output_file_f, "a");

        if (count != 10) begin
            $fwrite(fifo_output_file, "%b\n", tb_capture_data);
        end
        else begin
            $fwrite(fifo_output_file, "%b", tb_capture_data);
        end
        
        $fclose(fifo_output_file);
    end

/// [Tasks/Register write]
    task reg_write(reg [15:0] addr, reg [15:0] data );
        transfer(addr);
        transfer(data);
    endtask

/// [Tasks/Transfer 16 bit]
    task transfer(reg [15:0] inputs);
        spi_data_transmit(inputs[7:0]);
        spi_data_transmit(inputs[15:8]);
    endtask

/// [Tasks/SPI Write Transfer]
    task spi_data_transmit(reg [7:0] data);
        @(posedge clk);
        @(posedge clk);      
        spi_ss = 0;          
        for (int i = 0 ; i <=7;i++ ) begin
            spi_mosi = data[0];
            @(posedge clk);
            @(posedge clk);
            spi_sclk = 1 ;
            @(posedge clk);
            @(posedge clk);
            spi_sclk = 0 ;
            data = {1'b0,data[7:1]};
        end
        @(posedge clk);
        @(posedge clk);
        spi_ss = 1;
    endtask

/// [Tasks/SPI Read Transfer]
    task spi_data_transmit_output(logic [7:0] data);
        @(posedge clk);
        spi_ss = 0;
        for (int i = 0 ; i <=7;i++ ) begin
            spi_mosi = data[0];
            @(posedge clk);
            @(posedge clk);
            spi_sclk = 1 ;
            tb_capture_data = {spi_miso,tb_capture_data[15:1]};
            // $display("miso: %0b \t value is : %0b,",spi_miso, tb_capture_data);
            @(posedge clk);
            @(posedge clk);
            spi_sclk = 0;
            data = {1'b0,data[7:1]};
        end
        @(posedge clk);
        @(posedge clk);
        spi_ss = 1;
    endtask

/// [Tasks/Reset Task]
    task reset();
        reset_b = 0;
        spi_ss = 1;
        @(posedge clk);
        reset_b = 1;
        @(posedge clk);
    endtask

/// [Tasks/Load inputs]
    task load_inputs();
        i = 1;
        input_file = $fopen( {"../test/samples/",input_file_f} , "r");

        if (input_file == 0) begin
            $display("Cannot find the input file");
            $finish();
        end
        else begin
            while (!$feof(input_file)) begin
                inputs = new [$size(inputs)+1] ( inputs );
                scanRet = $fscanf(input_file, "%b", inputs[$size(inputs)-1]);
                // $display("Input [%d]: %b", i, inputs[$size(inputs)-1]);
                i++;
            end
        end
        $fclose(input_file);
    endtask

/// [Tasks/Load weights]
    task load_weights();
        i = 1;

        weight_file = $fopen(weight_file_f, "r");

        if (weight_file == 0) begin
            $display("Cannot find the weight.tzt file");
            $finish();
        end
        else begin
            while (!$feof(weight_file)) begin
                weights = new [$size(weights)+1] ( weights );
                scanRet = $fscanf(weight_file, "%b", weights[$size(weights)-1]);
                // $display("Weight [%d]: %b", i, weights[$size(weights)-1]);
                i++;
            end
        end
        
        $fclose(weight_file);
    endtask
endmodule
