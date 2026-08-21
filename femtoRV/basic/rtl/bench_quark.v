`timescale 1ns/1ps
module bench();
// Testbench uses a 25 MHz clock
// UART configured for 12 MHz / 57600 baud
// divisor = 12000000/57600/16 = 13
// Bit period at 25 MHz = 16 * 13 * 40ns = 8320ns
parameter tck              = 40;
parameter c_BIT_PERIOD     = 8320;

   reg CLK;
   reg RESET;
   wire LEDS;
   reg  RXD = 1'b1;
   wire TXD;

   // UART input buffer (max 256 bytes)
   reg [7:0] uart_input_mem [0:255];
   integer uart_idx;

   SOC uut(
     .clk(CLK),
     .resetn(RESET),
     .LEDS(LEDS),
     .RXD(RXD),
     .TXD(TXD)
   );

   initial CLK <= 0;
   always #(tck/2) CLK <= ~CLK;

   // LED monitor
   reg [4:0] prev_LEDS = 0;
   always @(posedge CLK) begin
      if(LEDS != prev_LEDS) begin
         $display("LEDS = %b", LEDS);
      end
      prev_LEDS <= LEDS;
   end

   // UART write task (send byte to CPU via RXD)
   task UART_WRITE_BYTE;
     input [7:0] i_Data;
     integer ii;
     begin
       RXD <= 1'b0;              // Start bit
       #(c_BIT_PERIOD);
       for(ii=0; ii<8; ii=ii+1) begin
         RXD <= i_Data[ii];
         #(c_BIT_PERIOD);
       end
       RXD <= 1'b1;              // Stop bit
       #(c_BIT_PERIOD);
     end
   endtask

   integer idx;
   initial begin

    $dumpfile("bench.vcd");
    $dumpvars(0,bench);
  `ifndef SYNTH
    for(idx = 0; idx < 32; idx = idx +1)  $dumpvars(0, bench.uut.CPU.registerFile[idx]);
    for(idx = 1020; idx < 1025; idx = idx +1)  $dumpvars(0, bench.uut.RAM.MEM[idx]);
  `endif

    // Load UART input data from file (hex bytes, one per line)
    $readmemh("uart_input.txt", uart_input_mem);

    #0   RXD   = 1;
    #0   RESET = 0;
    #80  RESET = 0;
    #160 RESET = 1;

    // Wait for program to finish printf output and reach getchar
    @(posedge CLK);
    #(tck*800000)

    // Send input bytes from file
    for(uart_idx = 0; uart_idx < 256; uart_idx = uart_idx + 1) begin
       if(uart_input_mem[uart_idx] === 8'hxx) begin
          uart_idx = 256;              // end of input
       end else begin
          $display("UART TX: 0x%02h", uart_input_mem[uart_idx]);
          UART_WRITE_BYTE(uart_input_mem[uart_idx]);
          #(tck*5000);                 // wait for program to process
       end
    end

    // Let the simulation run a bit more
    #(tck*100000)
    $finish;
 end

endmodule
