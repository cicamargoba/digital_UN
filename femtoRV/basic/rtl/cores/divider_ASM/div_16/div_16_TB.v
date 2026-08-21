`timescale 1ns / 1ps

`define SIMULATION


module div_16_TB;

   reg  clk;
   reg  rst;
   reg  reset;
   reg  start;
   reg  init_in;
   reg  [15:0]A;
   reg  [15:0]B;
   wire [15:0] Result;
   wire done;

   div_16 uut (.clk(clk) , .rst(rst) , .init_in(start) , .A(A) , .B(B) , .Result(Result) , .done(done));

   parameter PERIOD          = 20;
   parameter real DUTY_CYCLE = 0.5;
   parameter OFFSET          = 0;
   reg [20:0] i;

	event reset_trigger;
	event reset_done_trigger;

	initial begin 
	  forever begin 
	   @ (reset_trigger);
		@ (negedge clk);
		rst = 1;
		repeat(2) @ (negedge clk);
		rst = 0;
		-> reset_done_trigger;
		end
	end


   initial begin  // Initialize Inputs
      clk = 0; reset = 1; start = 0; A = 16'h95EC; B = 16'h00CA;
   end

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
        #10 -> reset_trigger;
        @ (reset_done_trigger);
        @ (posedge clk);
        start = 0;
        @ (posedge clk);
        start = 1;

        repeat (2) @ (posedge clk);
        start = 0;

       for(i=0; i<17; i=i+1) begin
         @ (posedge clk);
       end

   end
	 

   initial begin: TEST_CASE
     $dumpfile("div_16_TB.vcd");
     $dumpvars(-1, uut);
     #((PERIOD*DUTY_CYCLE)*120) $finish;
   end

endmodule

