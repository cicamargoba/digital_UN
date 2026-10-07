`timescale 1ns/1ps    // ← primera línea del archivo
module bench();
// Testbench uses a 10 MHz clock
// Want to interface to 115200 baud UART
// 25000000 / 57600 = 434 Clocks Per Bit.
parameter tck              = 40;
parameter c_BIT_PERIOD     = 17361;

   reg CLK;
   reg i;
   reg RESET;
   wire LEDS;
   reg  RXD = 1'b0;
   wire TXD;
   reg  interrupt_request = 1'b0;



  // Takes in input byte and serializes it 
  task UART_WRITE_BYTE;
    input [7:0] i_Data;
    integer     ii;
    begin
       
      // Send Start Bit
      RXD <= 1'b0;
      #(c_BIT_PERIOD);
      #1000;
       
       
      // Send Data Byte
      for (ii=0; ii<8; ii=ii+1)
        begin
          RXD <= i_Data[ii];
          #(c_BIT_PERIOD);
        end
       
      // Send Stop Bit
      RXD <= 1'b1;
      #(c_BIT_PERIOD);
     end
  endtask // UART_WRITE_BYTE
  
  
   SOC uut(
     .clk(CLK),
     .resetn(RESET),
     .LEDS(LEDS),
     .RXD(RXD),
     .TXD(TXD),
     .interrupt_request(interrupt_request)
   );


initial         CLK <= 0;
always #(tck/2) CLK <= ~CLK;


   reg[4:0] prev_LEDS = 0;
   initial begin
	 if(LEDS != prev_LEDS) begin
	    $display("LEDS = %b",LEDS);
	 end
	 prev_LEDS <= LEDS;
	
   end
   
   
       integer idx; 
   initial begin

    $dumpfile("bench.vcd");
    $dumpvars(0,bench);
  `ifndef SYNTH
    for(idx = 0; idx < 32; idx = idx +1)  $dumpvars(0, bench.uut.CPU.registerFile[idx]);
    for(idx = 1020; idx < 1025; idx = idx +1)  $dumpvars(0, bench.uut.RAM.MEM[idx]);
  `endif  

    //$dumpvars(0, bench.uut.CPU.registerFile[10],bench);

   // for(idx = 0; idx < 50; idx = idx +1)  $dumpvars(0, bench.uut.dpram_p0.dpram0.ram[idx]);
    //$dumpvars(0, bench.uut.CPU.registerFile[10],bench);

    #0   RXD   = 1;
    #0   RESET = 0;
    #80  RESET = 0;
    #160 RESET = 1;
    // Send a command to the UART (exercise Rx)



    for (idx=0; idx<20; idx=idx+1) begin
      @(posedge CLK);
      interrupt_request = 1;
      @(posedge CLK);
      interrupt_request = 0;
      repeat (10)  @(posedge CLK);
    end


    @(posedge CLK);
    #(tck*60000)
    UART_WRITE_BYTE(8'h30);
    #(tck*1500)
    UART_WRITE_BYTE(8'h30);
    #(tck*1500)
    UART_WRITE_BYTE(8'h36);    
    #(tck*1500)  
    UART_WRITE_BYTE(8'h37);
    #(tck*1500)
    UART_WRITE_BYTE(8'h0A);



    #(tck*50000)
    UART_WRITE_BYTE(8'h2A);    // Operator *

    for (idx=0; idx<20; idx=idx+1) begin
      @(posedge CLK);
      interrupt_request = 1;
      @(posedge CLK);
      interrupt_request = 0;
      repeat (10)  @(posedge CLK);
    end


    
    #(tck*90000)
    UART_WRITE_BYTE(8'h39);
    #(tck*1500)
    UART_WRITE_BYTE(8'h0A);
    #(tck*2500)

    #(tck*90000)
    UART_WRITE_BYTE(8'h30);
    #(tck*1500)
    UART_WRITE_BYTE(8'h30);
    #(tck*1500)
    UART_WRITE_BYTE(8'h36);    // Operator *
    #(tck*1500)  
    UART_WRITE_BYTE(8'h37);
    #(tck*1500)
    UART_WRITE_BYTE(8'h0A);


    #(tck*50000)
    UART_WRITE_BYTE(8'h2F);

    #(tck*90000)
    UART_WRITE_BYTE(8'h39);
    #(tck*1500)
    UART_WRITE_BYTE(8'h0A);
    #(tck*2500)



    
    @(posedge CLK);
    #(tck*900000) $finish;
 end
 
 
endmodule   
 
