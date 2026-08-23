`timescale 1ns / 1ps
`define SIMULATION

module ctrl_ws_arr_TB;
    reg       clk;
    reg       reset;
    reg       init_m;
    reg       done_led;
    reg       z;

    ctrl_ws_arr uut( .clk(clk), .reset(reset), .init_m(init_m), .done_led(done_led), .z(z) );

    parameter PERIOD          = 20;
    parameter real DUTY_CYCLE = 0.5;
    parameter OFFSET          = 0;

    initial  begin  // Process for clk
        #OFFSET;
        forever
        begin
            clk = 1'b0;
            #(PERIOD-(PERIOD*DUTY_CYCLE)) clk = 1'b1;
            #(PERIOD*DUTY_CYCLE);
        end
    end

   initial begin // Reset the system, Start the image capture process
        #0 reset = 1; z = 0; done_led = 0; init_m = 0;
        @ (negedge clk);
        reset = 0;
        @ (negedge clk);
        repeat (10) begin
            //SEND LED
            init_m = 1;
            @ (negedge clk);
            init_m = 0;
            repeat (10) @ (negedge clk);
            done_led = 1;
            @ (negedge clk);
            done_led= 0;
        end
        @ (negedge clk);
        z = 1;
        @ (negedge clk);
        z = 0;

   end

   initial begin: TEST_CASE
     $dumpfile("ctrl_ws_arr_TB.vcd");
     $dumpvars(-1, uut);
     #(20000) $finish;
   end

endmodule
