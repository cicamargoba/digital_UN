`timescale 1ns / 1ps

`define SIMULATION
module count_l_TB;
   reg  clk;
   reg  start;
   reg  [7:0] load;
   wire zero;


    count_l #(.width (7)) uut (
        .clk(clk),
        .start(start),
        .load(load),
        .zero(zero)
    );



   parameter PERIOD = 20;
   // Initialize Inputs
   initial begin  
      clk = 0; start = 0; load = 14;
   end
   // clk generation
   initial         clk <= 0;
   always #(PERIOD/2) clk <= ~clk;

   initial begin 
     // Reset 
      @ (posedge clk);
      start = 1;
      @ (posedge clk);
      start = 0;
      #(360)
      load = 12;
      @ (posedge clk);
      start = 1;
      @ (posedge clk);
      start = 0;      
      #(300)
      load = 3;
      @ (posedge clk);
      start = 1;
      @ (posedge clk);
      start = 0;      


   end

   integer idx;
   initial begin: TEST_CASE
     $dumpfile("count_l_TB.vcd");
     $dumpvars(-1, count_l_TB);
    //for(idx = 0; idx < 100; idx = idx +1)  $dumpvars(0, pwm_led_panel_TB.uut.mem0.MEM[idx]);
     #(PERIOD*100000) $finish;
   end





endmodule
