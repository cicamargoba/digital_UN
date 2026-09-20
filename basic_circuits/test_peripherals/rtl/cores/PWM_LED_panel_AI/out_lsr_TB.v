`timescale 1ns / 1ps

`define SIMULATION
module out_lsr_TB;
   reg  clk;
   reg  load;
   reg  shift;
   reg  [15:0] in_val;
   wire zero;


    out_lsr uut (
        .clk(clk),
        .load(load),
        .shift(shift),
        .in_val(in_val)
    );


   parameter PERIOD = 20;
   // Initialize Inputs
   initial begin  
      clk = 0; load = 0; in_val = 14; shift = 0;
   end
   // clk generation
   initial         clk <= 0;
   always #(PERIOD/2) clk <= ~clk;

   initial begin 
     // Reset 
      @ (posedge clk);
      load = 1;
      @ (posedge clk);
      load = 0;
      @ (posedge clk);
      shift = 1;
      @ (posedge clk);
      shift = 0;
      #(400)
      in_val = 12;
      @ (posedge clk);
      load = 1;
      @ (posedge clk);
      load = 0;      
      @ (posedge clk);
      shift = 1;
      @ (posedge clk);
      shift = 0;
      #(400)
      in_val = 16'hCA;
      @ (posedge clk);
      load = 1;
      @ (posedge clk);
      load = 0;      
      @ (posedge clk);
      shift = 1;
      @ (posedge clk);
      shift = 0;

   end

   integer idx;
   initial begin: TEST_CASE
     $dumpfile("out_lsr_TB.vcd");
     $dumpvars(-1, out_lsr_TB);
    //for(idx = 0; idx < 100; idx = idx +1)  $dumpvars(0, pwm_led_panel_TB.uut.mem0.MEM[idx]);
     #(PERIOD*100000) $finish;
   end





endmodule
