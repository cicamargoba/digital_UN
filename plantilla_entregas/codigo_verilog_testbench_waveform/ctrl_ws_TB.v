`timescale 1ns / 1ps
`define SIMULATION

module ctrl_ws_TB;
    reg       clk;
    reg       reset;
    reg       init_t;
    reg [1:0] sel;
    reg       z;

    ctrl_ws uut( .clk(clk), .reset(reset), .init_t(init_t), .sel(sel), .z(z) );

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
        #0 reset = 1; z = 0; sel = 0; init_t = 0;
        @ (negedge clk);
        reset = 0;
        @ (negedge clk);
//      SEND ZERO
        sel    = 0;
        init_t = 1;
        @ (negedge clk);
        init_t = 0;
        repeat (10) @ (negedge clk);
        z = 1;
        @ (negedge clk);
        z= 0;
        repeat (20) @ (negedge clk);
        z = 1;
        @ (negedge clk);
        z = 0;
//      SEND ONE
        @ (negedge clk);
        sel    = 1;
        init_t = 1;
        @ (negedge clk);
        init_t = 0;
        repeat (20) @ (negedge clk);
        z = 1;
        @ (negedge clk);
        z= 0;
        repeat (10) @ (negedge clk);
        z = 1;
        @ (negedge clk);
        z = 0;
//      SEND RESET
        @ (negedge clk);
        sel    = 2;
        init_t = 1;
        @ (negedge clk);
        init_t = 0;
        repeat (200) @ (negedge clk);
        z = 1;
        @ (negedge clk);
        z= 0;
   end

   initial begin: TEST_CASE
     $dumpfile("ctrl_ws_TB.vcd");
     $dumpvars(-1, uut);
     #(20000) $finish;
   end

endmodule
