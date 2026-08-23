`timescale 1ns / 1ps
`define SIMULATION

module led_mem_TB;

 reg clk;
 reg [5:0] address;

    led_mem uut( .clk(clk), .address(address) );


    parameter PERIOD          = 40;
    parameter real DUTY_CYCLE = 0.5;
    parameter OFFSET          = 0;

    integer ii;

    initial  begin  // Process for clk
        #OFFSET;
        forever
        begin
            clk = 1'b0;
            #(PERIOD-(PERIOD*DUTY_CYCLE)) clk = 1'b1;
            #(PERIOD*DUTY_CYCLE);
        end
    end

    initial  begin

      for (ii=0; ii<64; ii=ii+1)
        begin
          @(negedge clk);
          address <= ii;
        end
    end


    initial begin: TEST_CASE
        $dumpfile("led_mem_TB.vcd");
        $dumpvars(-1, uut);
        #(100000) $finish;
    end

endmodule
