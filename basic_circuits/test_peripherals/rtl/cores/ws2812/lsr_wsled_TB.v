`timescale 1ns / 1ps
`define SIMULATION

module lsr_wsled_TB;

    reg        clk;
    reg [23:0] in_A;
    reg        load;
    reg        shift;

    lsr_wsled uut( .clk(clk), .in_A(in_A), .load(load), .shift(shift) );

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
        #0 in_A = 2567; load = 0; shift = 0;
        @ (negedge clk);
        load  = 1;
        @ (negedge clk);
        load  = 0;

        repeat(23) begin
            @(negedge clk);
            shift= 1;
            @(negedge clk);
            shift = 0;
        end
    end

    initial begin: TEST_CASE
        $dumpfile("lsr_wsled_TB.vcd");
        $dumpvars(-1, uut);
        #(100000) $finish;
    end

endmodule