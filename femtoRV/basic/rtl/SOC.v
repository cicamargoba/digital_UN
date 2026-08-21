`timescale 1ns / 1ps
module SOC (
    input        clk,    // system clock 
    input        resetn, // reset button
    output wire  LEDS,   // system LEDs
    input        RXD,    // UART receive
    output       TXD     // UART transmit
);

   wire [31:0] mem_addr;
   reg  [31:0] mem_rdata;
   wire mem_rstrb;
   wire [31:0] mem_wdata;
   wire [3:0]  mem_wmask;

  // ============== Chip_Select (Addres decoder) ======================== 
  // se hace con los 8 bits mas significativos de mem_addr
  // Se asigna el rango de la memoria de programa 0x00000000 - 0x003FFFFF
  // ====================================================================
  reg [8:0]cs;  // CHIP-SELECT

   
   FemtoRV32 CPU(
      .clk(clk),  
      .reset(resetn),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask(mem_wmask),
      .mem_rbusy(1'b0),
      .mem_wbusy(1'b0)
   );
   wire [31:0] RAM_rdata;
   wire  wr = |mem_wmask;
   wire  rd = mem_rstrb;

   bram RAM(
      .clk(clk),
      .mem_addr(mem_addr),
      .mem_rdata(RAM_rdata),
      .mem_rstrb(cs[0] & rd),
      .mem_wdata(mem_wdata),
      .mem_wmask({4{cs[0]}}&mem_wmask)
   );
   wire [31:0] uart_dout;
   wire [31:0] mult_dout;
   wire [31:0] div_dout;
   wire [31:0] sqrt_dout;
   wire [31:0] bin2bcd_dout;
   wire [31:0] bcd2bin_dout;
   wire [31:0] ws2812_dout;

  peripheral_uart #(
//     .clk_freq(50000000),  // for primer 25k
//     .clk_freq(33333333),  // for efinix
//       .clk_freq(25000000),    //for TEST
//     .clk_freq(27000000),  // for nano_20k
     .clk_freq(12000000),  // for icebreaker
     .baud(57600)            // 57600 for gowin
   ) per_uart(
     .clk(clk),
     .rst(!resetn),
     .d_in(mem_wdata),
     .cs(cs[5]),
     .addr(mem_addr[4:0]),
     .rd(rd),
     .wr(wr),
     .d_out(uart_dout),
     .uart_tx(TXD),
     .uart_rx(RXD),
     .ledout(LEDS)
   ); 

   peripheral_mult mult1 (
      .clk(clk),
      .reset(!resetn),
      .d_in(mem_wdata[15:0]),
      .cs(cs[3]),
      .addr(mem_addr[4:0]),
      .rd(rd),
      .wr(wr),
      .d_out(mult_dout)
   );

   peripheral_div div1 (
      .clk (clk),
      .rst (!resetn),
      .d_in (mem_wdata[15:0]),
      .cs (cs[2]), 
      .addr (mem_addr[4:0]),
      .rd (rd), 
      .wr(wr), 
      .d_out (div_dout) );

   peripheral_sqrt sqrt1(
      .clk(clk) ,
      .reset (!resetn),
      .d_in (mem_wdata[15:0]),
      .cs (cs[4]),
      .addr (mem_addr[4:0]),
      .rd (rd),
      .wr (wr),
      .d_out (sqrt_dout) );

   peripheral_bin2bcd bin2bcd0 (
      .clk(clk),
      .reset(!resetn),
      .d_in(mem_wdata[15:0]),
      .cs(cs[1]),
      .addr(mem_addr[4:0]), // 4 LSB from j1_io_addr
      .rd(rd),
      .wr(wr),
      .d_out(bin2bcd_dout)
   );

   peripheral_bcd2bin bcd2bin0 (
      .clk(clk),
      .reset(!resetn),
      .d_in(mem_wdata[19:0]),
      .cs(cs[7]),
      .addr(mem_addr[4:0]), // 4 LSB from j1_io_addr
      .rd(rd),
      .wr(wr),
      .d_out(bcd2bin_dout)
   );

//   *********************************
//  Instanciar el periferico WS2812
//   *********************************



  always @*
  begin
      case (mem_addr[31:16])	// direcciones - chip_select
        16'h0040: cs= 9'b000100000; //uart
        16'h0041: cs= 9'b000010000; //sqrt
        16'h0042: cs= 9'b000001000; //mult
        16'h0043: cs= 9'b000000100; //div
        16'h0044: cs= 9'b000000010; //bin_to_bcd
        16'h0045: cs= 9'b001000000; //dpRAM
        16'h0046: cs= 9'b010000000; //bcd_to_bin
        16'h0047: cs= 9'b100000000; //ws2812
        16'h0000: cs= 9'b000000001; //RAM
        default:  cs= 9'b000000001;
      endcase
  end
  // ============== MUX ========================  // se encarga de lecturas del RV32
  always @*
  begin
      case (cs)
//        7'b1000000: mem_rdata = dpram_dout;
        9'b100000000: mem_rdata = ws2812_dout;
        9'b010000000: mem_rdata = bcd2bin_dout;
        9'b000100000: mem_rdata = uart_dout;
        9'b000010000: mem_rdata = sqrt_dout;
        9'b000001000: mem_rdata = mult_dout;
        9'b000000100: mem_rdata = div_dout;
        9'b000000010: mem_rdata = bin2bcd_dout;
        9'b000000001: mem_rdata = RAM_rdata;
        default:  mem_rdata = RAM_rdata;
      endcase
  end
 // ============== MUX ========================  // 

`ifdef BENCH
   always @(posedge clk) begin
      if(cs[5] & wr ) begin
	 $write("%c", mem_wdata[7:0] );
	 $fflush(32'h8000_0001);
      end
   end
`endif

endmodule
