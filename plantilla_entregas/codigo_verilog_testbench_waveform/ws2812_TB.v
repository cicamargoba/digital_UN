`timescale 1ns / 1ps
`define SIMULATION

module ws2812_TB;

    reg        clk;
    reg        reset;
    reg        init_t;
    reg [1:0]  sel;

    ws2812 uut( .clk(clk), .reset(reset), .init_t(init_t), .sel(sel) );

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

    initial begin
        #0 reset = 1; init_t = 0; sel = 0;
        @ (negedge clk);
        reset  = 0;
        @ (negedge clk);
        // SEND ZERO
        sel    = 0;
        init_t = 1;
        @ (negedge clk);
        init_t = 0;
        wait(ws2812_TB.uut.done_t == 1);
        @ (negedge clk);
        // SEND UNO
        @ (negedge clk);
        sel    = 1;
        init_t = 1;
        @ (negedge clk);
        init_t = 0;
        wait(ws2812_TB.uut.done_t == 1);
        @ (negedge clk);
        // SEND UNO
        @ (negedge clk);
        sel    = 1;
        init_t = 1;
        @ (negedge clk);
        init_t = 0;
        wait(ws2812_TB.uut.done_t == 1);
        @ (negedge clk);
        // SEND RESET
        @ (negedge clk);
        sel    = 2;
        init_t = 1;
        @ (negedge clk);
        init_t = 0;
        wait(ws2812_TB.uut.done_t == 1);
        @ (negedge clk);
    end


    initial begin: TEST_CASE
        $dumpfile("ws2812_TB.vcd");
        $dumpvars(-1, uut);
        #(100000) $finish;
    end

endmodule
