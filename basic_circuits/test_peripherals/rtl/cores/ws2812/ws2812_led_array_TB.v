`timescale 1ns / 1ps
`define SIMULATION

module ws2812_led_array_TB;
    reg       clk;
    reg       reset;
    reg       init_m;
    reg       rst_cmd;

    ws2812_led_array uut( .clk(clk), .reset(reset), .init_m(init_m), .rst_cmd(rst_cmd) );

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
        #0 reset = 1; init_m = 0; rst_cmd = 0;
        @ (negedge clk);
        reset = 0;
        @ (negedge clk);
//      SEND DATA
        init_m = 1;
        @ (negedge clk);
        init_m = 0;
        wait(ws2812_led_array_TB.uut.done == 1);
   end

   initial begin: TEST_CASE
     $dumpfile("ws2812_led_array_TB.vcd");
     $dumpvars(-1, uut);
     #(6000000) $finish;
   end

endmodule
