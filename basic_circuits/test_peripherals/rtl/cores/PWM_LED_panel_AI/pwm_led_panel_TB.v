`timescale 1ns / 1ps

`define SIMULATION
module pwm_led_panel_TB;
   reg  clk;
   reg  rst;
   reg  init;
   wire  LP_CLK;
   wire  LATCH;
   wire  NOE;
   wire  [4:0] ROW;
   wire  [2:0] RGB0;
   wire  [2:0] RGB1;


    pwm_led_panel uut (
        .clk(clk),
        .rst(rst),
        .init(init),
        .LP_CLK(LP_CLK),
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
      rst = 0;
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);

      rst = 1;
     #(PERIOD*4)
      init = 1;
   end

   integer idx;
   initial begin: TEST_CASE
     $dumpfile("pwm_led_panel_TB.vcd");
     $dumpvars(-1, pwm_led_panel_TB);
    //for(idx = 0; idx < 100; idx = idx +1)  $dumpvars(0, pwm_led_panel_TB.uut.mem0.MEM[idx]);
     #(PERIOD*4500000) $finish;
   end





endmodule
