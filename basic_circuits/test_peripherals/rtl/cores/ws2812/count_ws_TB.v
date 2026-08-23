`timescale 1ns / 1ps
`define SIMULATION

module count_ws_TB;

 reg clk;
 reg rst;
 reg inc;

    count_ws uut( .clk(clk), .rst(rst), .inc(inc) );


    parameter PERIOD          = 40;
    parameter real DUTY_CYCLE = 0.5;
    parameter OFFSET          = 0;

    initial  begin  // Process for clk
        #OFFSET;
        forever begin
            clk = 1'b0;
            #(PERIOD-(PERIOD*DUTY_CYCLE)) clk = 1'b1;
            #(PERIOD*DUTY_CYCLE);
        end
    end


    initial  begin
        #0 rst = 0; inc = 0;
        @ (posedge clk);
        rst = 1;
        @ (posedge clk);
        rst = 0;
        @ (posedge clk);
        inc = 1;
        # 40000
        @ (posedge clk);
        inc = 0;

    end

    initial begin: TEST_CASE
        $dumpfile("count_ws_TB.vcd");
        $dumpvars(-1, uut);
        #(100000) $finish;
    end

endmodule
