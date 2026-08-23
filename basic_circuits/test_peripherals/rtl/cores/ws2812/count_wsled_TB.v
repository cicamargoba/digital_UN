`timescale 1ns / 1ps
`define SIMULATION

module count_wsled_TB;

    reg      clk;
    reg      ld;
    reg      dec;

    count_wsled uut( .clk(clk), .ld(ld), .dec(dec) );

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
        #0 ld = 0; dec = 0;
        @ (negedge clk);
        ld  = 1;
        @ (negedge clk);
        ld  = 0;

        repeat(23) begin
            @(negedge clk);
            dec= 1;
        end
    end

    initial begin: TEST_CASE
        $dumpfile("count_wsled_TB.vcd");
        $dumpvars(-1, uut);
        #(100000) $finish;
    end


endmodule