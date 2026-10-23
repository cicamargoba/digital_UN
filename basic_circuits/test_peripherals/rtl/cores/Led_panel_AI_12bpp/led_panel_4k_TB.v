`timescale 1ns / 1ps

`define SIMULATION
module led_panel_4k_TB;
   reg  clk;
   reg  rst;
   reg  init;
   wire  LATCH;
   wire  NOE;
   wire  [4:0] ROW;
   wire  [2:0] RGB0;
   wire  [2:0] RGB1;


    led_panel_4k uut (
        .clk(clk),
        .rst(rst),
        .init(init),
        .LATCH(LATCH),
        .NOE(NOE),
        .ROW(ROW),
        .RGB0(RGB0),
        .RGB1(RGB1)
    );



   parameter PERIOD = 20;
   // Initialize Inputs
   initial begin  
      clk = 0; rst = 0; init = 0;
   end
   // clk generation
   initial         clk <= 0;
   always #(PERIOD/2) clk <= ~clk;

   initial begin 
     // Reset 
     @ (posedge clk);
      rst = 1;
      @ (posedge clk);
      rst = 0;
     #(PERIOD*4)
      init = 1;
   end

   integer idx;
   initial begin: TEST_CASE
     $dumpfile("led_panel_4k_TB.vcd");
     $dumpvars(-1, led_panel_4k_TB);
//    for(idx = 0; idx < 100; idx = idx +1)  $dumpvars(0, led_panel_4k_TB.uut.mem0.MEM[idx]);
     #(PERIOD*100000) $finish;
   end





endmodule
