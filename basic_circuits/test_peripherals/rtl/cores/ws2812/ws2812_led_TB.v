`timescale 1ns / 1ps
`define SIMULATION

module ws2812_led_TB;
    reg       clk;
    reg       reset;
    reg       init;
    reg [23:0] rgb;
    reg       rst_cmd;

    ws2812_led uut( .clk(clk), .reset(reset), .rgb(rgb), .init(init), .rst_cmd(rst_cmd) );

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
        #0 reset = 1; rgb = 24'h112233; init = 0; rst_cmd = 0;
        @ (posedge clk);
        reset = 0;
        @ (posedge clk);
//      SEND DATA
        init = 1;
        @ (posedge clk);
        init = 0;
        wait(ws2812_led_TB.uut.done == 1);
//      SEND DATA
        repeat (4) @ (posedge clk);
        rgb = 24'hAA5588;
        @ (posedge clk);
        init = 1;
        @ (posedge clk);
        init = 0;
        wait(ws2812_led_TB.uut.done == 1);
//      SEND DATA
        repeat (4) @ (posedge clk);
        rgb = 24'hFF00FF;
        rst_cmd = 1;
        @ (posedge clk);
        init = 1;
        @ (posedge clk);
        init = 0;
        wait(ws2812_led_TB.uut.done == 1);
   end

   initial begin: TEST_CASE
     $dumpfile("ws2812_led_TB.vcd");
     $dumpvars(-1, uut);
     #(60000) $finish;
   end

endmodule
