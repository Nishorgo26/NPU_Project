`timescale 1ns/1ns 
`define DEBUG

module tb #(
    `include "../rtl/verilog/npu_params.v"
)
();
    bit   clk;
    bit   reset_b;

    bit spi_ss;
    bit spi_sclk;
    bit spi_mosi;
    logic spi_miso;
    logic start_transmission;
    bit soft_reset; 
    
    bit  debug_wr_en;
    logic [NPU_DATA_WIDTH - 1 :0] debug_data;

    int weight_file;
    int output_file;
    int input_file;
    int fifo_output_file;
    int scanRet;
    int i;
    int frame;
    int index;
    int count = 0;
    int t;
    logic [NPU_DATA_WIDTH - 1 :0] tb_capture_data;

    logic [15:0] weights [];
    logic [15:0] outputs_weight [];
    logic [15:0] inputs  [];
    
    logic [255:0]  faster_read_mem;

    string input_file_name;

    initial begin
        t = $value$plusargs("INPUTFILE=%s", input_file_name);
        // $display(input_file_name);
    end

    string weight_hl_file_f = "../weights_h1.txt";
    string weight_op_file_f = "../weights_op.txt";
    string fifo_output_file_f = "../fifo_output.txt";
    // string input_file_f     = {"../test/image_5/",input_file_name};

    npu_top u_npu_top(
                    .clk                 ( clk                 ),
                    .reset_b             ( reset_b             ),
                `ifdef DEBUG
                    .debug_wr_en         ( debug_wr_en         ),
                    .debug_data          ( debug_data          ),
                `endif 
                    .spi_ss              ( spi_ss              ),
                    .spi_sclk            ( spi_sclk            ),
                    .spi_mosi            ( spi_mosi            ),
                    .spi_miso            ( spi_miso            ),   
                    .start_transmission  ( start_transmission  ),
                    .soft_reset          ( soft_reset          )
                );


    initial begin
    fifo_output_file = $fopen(fifo_output_file_f, "w");
    $fwrite(fifo_output_file);
    $fclose(fifo_output_file);
    end

    always @(posedge start_transmission) begin
        spi_data_transmit_output(8'bxxxxxxxx);
        spi_data_transmit_output(8'bxxxxxxxx);
        // $display("value of [%0d] neuron is : %b | %h ",count, tb_capture_data, tb_capture_data);
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


    initial begin
        forever begin
            #31 clk = ~clk;
        end
    end


`ifdef DEBUG
    initial begin
        spi_ss = 1 ;
        repeat (2) @(posedge clk);
        reset_b = 1;
        repeat (2) @(posedge clk);

        load_inputs();
        load_hidden_weights();
        load_output_weights();

        @(posedge clk)
        for (int fr = 0; fr < $size(weights)/16; fr++) begin
                
                for (int rr = 0; rr < 16; rr++) begin
                    faster_read_mem = {weights[rr+(fr*16)],faster_read_mem[255: 16]};
                    // $display("%h", faster_read_mem);
                    //$display("inner circle :: %d",rr);
                end
                // $display("After for loop: %h", faster_read_mem);
                debug_data   = faster_read_mem;
                debug_wr_en= 1'b1;
                @(posedge clk);
                debug_wr_en= 1'b0;
                faster_read_mem = 256'bx;
                @(posedge clk);
                // $display("Inside: %h\n", testbench.u_npu_top.u_controller.u_weights.u_weight_fifo.fifo_mem[fr]);
                // if(fr == 1) break;
                // $display("O U T T E R  circle :: %d",fr);
        end

        @(posedge clk)
        for (int frg = 0; frg < 10; frg++) begin
            for (int rrg = 0; rrg < 10; rrg++) begin
                faster_read_mem = {outputs_weight[rrg+(frg*10)],faster_read_mem[255: 16]};
                // $display("inner 1st circle :: %d",rrg);
            end
            for (int gg = 0; gg < 6; gg++) begin
                faster_read_mem = {16'bx,faster_read_mem[255: 16]};
                // $display("inner SECOUND circle :: %d",gg);
            end
            debug_data   = faster_read_mem;
            debug_wr_en= 1'b1;
            @(posedge clk);
            debug_wr_en= 1'b0;
            faster_read_mem = 256'bx;
            @(posedge clk);
            // $display("O U T T E R     L A S T    L O O P  :: %d",frg);
        end

        @(posedge clk);
        for (int frk = 0; frk < $size(inputs)/16; frk++) begin
            for (int rrk = 0; rrk < 16; rrk++) begin
                faster_read_mem = {inputs[rrk+(frk*16)],faster_read_mem[255: 16]};
                //$display("inner circle :: %d",rr);
            end
            debug_data   = faster_read_mem;
            debug_wr_en= 1'b1;
            @(posedge clk);
            debug_wr_en= 1'b0;
            faster_read_mem = 256'bx;
            @(posedge clk);
            // $display("O U T T E R  circle :: %d",fr);
        end
        repeat(100) @(posedge clk);

        // while (~u_npu_top.u_calculation.layer_type) begin
        //     @(posedge u_npu_top.u_calculation.sigmoid_valid);
        //     #1;
        //     $display("Calculated: %h | Sigmoid result: %h", u_npu_top.u_calculation.calculated_reg_q, u_npu_top.u_calculation.sigmoid_result );
        // end
        repeat (30000) @(posedge clk);
        $finish();


    end
`else
    initial begin
        load_inputs();
        load_hidden_weights();
        load_output_weights();

       $display("outputs_weight size: %d", $size(outputs_weight));
       $display("weights size: %d", $size(weights));
       $display("inputs size: %d", $size(inputs));

        spi_ss = 1 ;
        repeat (2) @(posedge clk);
        reset_b = 1;
        repeat (2) @(posedge clk);

        hidden_weight_transfer ();
        output_weight_transfer ();
        input_transfer ();
        // for (int i = 0; i<(7840+100+784+60) ;i++) begin
        //     spi_data_transmit(i[7:0]);
        //     spi_data_transmit(i[15:8]);
        // end
        repeat(100) @(posedge clk);

        // while (~u_npu_top.u_calculation.layer_type) begin
        //     @(posedge u_npu_top.u_calculation.sigmoid_valid);
        //     #1;
        //     $display("Calculated: %h | Sigmoid result: %h", u_npu_top.u_calculation.calculated_reg_q, u_npu_top.u_calculation.sigmoid_result );
        // end

        repeat (30000) @(posedge clk);
        $finish();
        
    end
`endif
//=======================================================================================================================//
//=======================================================================================================================//
//=======================================================================================================================//
//=======================================================================================================================//


    task hidden_weight_transfer;
        for (frame = 0 ; frame <$size(weights) ; frame++ ) begin
            spi_data_transmit(weights[frame][7:0]);
            spi_data_transmit(weights[frame][15:8]);
            //  $display("Transferred #%d       weight: %b",frame+1,weights[frame]);
        end
        //   $display("hidden Weight transmit complete");
        //    #1000;
    
    endtask

    
    task output_weight_transfer;
        for (int i=0; i<10; i++) begin
            index = 0;
            for (index = 0; index < 10; index++) begin
                spi_data_transmit(outputs_weight[i*10+index][7:0]);
                spi_data_transmit(outputs_weight[i*10+index][15:8]);
            // $display("Completed original weight transfer : %d : %h", index, outputs_weight[i*10+index]);
            end
            for (int k = 0 ; k < 6 ; k++ ) begin
                spi_data_transmit(8'bxxxxxxxx);
                spi_data_transmit(8'bxxxxxxxx);
                //$display("Completed fake weight transfer : %d", k);
            end
        // $display("Completed original+fake weight transfer : %d", i+1);
        end
        //  #1000;
        //  $display("output Weight transmit complete");
    endtask


    
    task input_transfer;
        for (int i = 0 ; i <$size(inputs) ; i++ ) begin
            spi_data_transmit(inputs[i][7:0]);
            spi_data_transmit(inputs[i][15:8]);
        end
    endtask

    task spi_data_transmit(logic [7:0] data);
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
         @(posedge clk); @(posedge clk);
    endtask 

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
            spi_sclk = 0 ;
            data = {1'b0,data[7:1]};
        end
        @(posedge clk);
        @(posedge clk);
        spi_ss = 1;
         @(posedge clk); @(posedge clk);
    endtask 

    task load_hidden_weights();
        i = 1;

        weight_file = $fopen( weight_hl_file_f , "r");

        if (weight_file == 0) begin
            $display("Cannot find the weight file");
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

    task load_output_weights();
        i = 1;
        output_file = $fopen(weight_op_file_f, "r");

        if (output_file == 0) begin
            $display("Cannot find the output file");
            $finish();
        end
        else begin
            while (!$feof(output_file)) begin
                outputs_weight = new [$size(outputs_weight)+1] ( outputs_weight );
                scanRet = $fscanf(output_file, "%b", outputs_weight[$size(outputs_weight)-1]);
                // $display("Output weight [%d]: %b", i, outputs_weight[$size(outputs_weight)-1]);
                i++;
            end
        end
        
        $fclose(output_file);
    endtask

    task load_inputs();
        i = 1;
        input_file = $fopen( {"../test/samples/",input_file_name} , "r");

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
endmodule
