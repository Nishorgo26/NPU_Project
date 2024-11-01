module tb_controller_fsm;
 
bit clk              ;
bit reset_b          ;
bit write_en_frm_spi ;
bit [255:0] data_in_from_spi;
bit neuron_ready     ;
bit soft_reset       ;
bit calulcator_valid ;
bit  neuron_result_in;
bit transmitted      ;
bit start            ;
bit layer_type       ;
bit add_activation   ;
bit  neuron_data     ;
bit load_to_spi      ;
bit  input_of_r1c1   ;
bit  input_of_r1c2   ;
bit  input_of_r1c3   ;
bit  input_of_r1c4   ;
bit  input_of_r2c1   ;
bit  input_of_r2c2   ;
bit  input_of_r2c3   ;
bit  input_of_r2c4   ;
bit  input_of_r3c1   ;
bit  input_of_r3c2   ;
bit  input_of_r3c3   ;
bit  input_of_r3c4   ;
bit  input_of_r4c1   ;
bit  input_of_r4c2   ;
bit  input_of_r4c3   ;
bit  input_of_r4c4   ;
bit  weight_of_r1c1  ;
bit  weight_of_r1c2  ;
bit  weight_of_r1c3  ;
bit  weight_of_r1c4  ;
bit  weight_of_r2c1  ;
bit  weight_of_r2c2  ;
bit  weight_of_r2c3  ;
bit  weight_of_r2c4  ;
bit  weight_of_r3c1  ;
bit  weight_of_r3c2  ;
bit  weight_of_r3c3  ;
bit  weight_of_r3c4  ;
bit  weight_of_r4c1  ;
bit  weight_of_r4c2  ;
bit  weight_of_r4c3  ;
bit  weight_of_r4c4  ;             


controller u_controller(
    .clk               ( clk               ),
    .reset_b           ( reset_b           ),
    .write_en_frm_spi  ( write_en_frm_spi  ),
    . data_in_from_spi (  data_in_from_spi ),
    .neuron_ready      ( neuron_ready      ),
    .soft_reset        ( soft_reset        ),
    .calulcator_valid  ( calulcator_valid  ),
    . neuron_result_in (  neuron_result_in ),
    .transmitted       ( transmitted       ),
    .start             ( start             ),
    .layer_type        ( layer_type        ),
    .add_activation    ( add_activation    ),
    .neuron_data       ( neuron_data       ),
    .load_to_spi       ( load_to_spi       ),
    .input_of_r1c1     (  input_of_r1c1    ),
    .input_of_r1c2     (  input_of_r1c2    ),
    .input_of_r1c3     (  input_of_r1c3    ),
    .input_of_r1c4     (  input_of_r1c4    ),
    .input_of_r2c1     (  input_of_r2c1    ),
    .input_of_r2c2     (  input_of_r2c2    ),
    .input_of_r2c3     (  input_of_r2c3    ),
    .input_of_r2c4     (  input_of_r2c4    ),
    .input_of_r3c1     (  input_of_r3c1    ),
    .input_of_r3c2     (  input_of_r3c2    ),
    .input_of_r3c3     (  input_of_r3c3    ),
    .input_of_r3c4     (  input_of_r3c4    ),
    .input_of_r4c1     (  input_of_r4c1    ),
    .input_of_r4c2     (  input_of_r4c2    ),
    .input_of_r4c3     (  input_of_r4c3    ),
    .input_of_r4c4     (  input_of_r4c4    ),
    .weight_of_r1c1    (  weight_of_r1c1   ),
    .weight_of_r1c2    (  weight_of_r1c2   ),
    .weight_of_r1c3    (  weight_of_r1c3   ),
    .weight_of_r1c4    (  weight_of_r1c4   ),
    .weight_of_r2c1    (  weight_of_r2c1   ),
    .weight_of_r2c2    (  weight_of_r2c2   ),
    .weight_of_r2c3    (  weight_of_r2c3   ),
    .weight_of_r2c4    (  weight_of_r2c4   ),
    .weight_of_r3c1    (  weight_of_r3c1   ),
    .weight_of_r3c2    (  weight_of_r3c2   ),
    .weight_of_r3c3    (  weight_of_r3c3   ),
    .weight_of_r3c4    (  weight_of_r3c4   ),
    .weight_of_r4c1    (  weight_of_r4c1   ),
    .weight_of_r4c2    (  weight_of_r4c2   ),
    .weight_of_r4c3    (  weight_of_r4c3   ),
    .weight_of_r4c4    (  weight_of_r4c4   )
);



initial begin
    forever begin
        #31 clk = ~clk;
    end
end

initial begin
    repeat (2) @(posedge clk);
    reset_b = 1;
    repeat (2) @(posedge clk);

    for (int i=0; i<549; i++) begin
        @(posedge clk);
        data_in_from_spi = i;
        write_en_frm_spi = 1;
        @(posedge clk);
        write_en_frm_spi = 0;
    end

    
    repeat (200000) @(posedge clk);
    $finish();
end

initial begin
    while (!start) begin
        @(posedge clk); 
    end
        repeat (15)  @(posedge clk);
        calulcator_valid =1;
        @(posedge clk);
        calulcator_valid =0;

    
        forever begin
            @(posedge clk);
            if(tb_controller_fsm.u_controller.next_cycle) begin
                repeat (15) @(posedge clk);
                calulcator_valid =1;
                @(posedge clk);
                calulcator_valid =0;
            end
        end

end

initial begin
    forever begin
        @(posedge clk);
        while (!add_activation) begin
        @(posedge clk); 
        end
        repeat (5)  @(posedge clk);
        neuron_ready =1;
        @(posedge clk);
        neuron_ready =0;

         while (!start) begin
            @(posedge clk); 
        end
        repeat (15)  @(posedge clk);
        calulcator_valid =1;
        @(posedge clk);
        calulcator_valid =0;

    end
end


endmodule