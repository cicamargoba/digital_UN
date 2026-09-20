module pwm_led_panel(clk , rst , init, LP_CLK, LATCH, NOE, ROW, RGB0, RGB1);

    input         rst;
    input         clk;
    input         init;
    output        LP_CLK;
    output        LATCH;
    output        NOE; // GCLK
    output  [4:0] ROW;
    output  [2:0] RGB0;
    output  [2:0] RGB1;

    reg clk1;


// ======== Caracteristicas de la matriz ========
parameter NUM_COLS        = 128;
parameter NUM_ROWS        = 64;
parameter NUM_PIXELS      = NUM_COLS*NUM_ROWS*16;   // 20000h 1FFFF
parameter HALF_SCREEN     = NUM_PIXELS/2;
parameter BIT_DEPTH       = 4;
parameter TOTAL_BIT_DEPTH = 3*BIT_DEPTH;
parameter DELAY           = 20;
parameter NUM_DRVS        = NUM_COLS/16 - 1;   // 128 cols -> 8 chips -> 7
// ---- Seleccion de chip: 1 = FM6363, 0 = FM6353 ----
parameter IS_FM6363       = 1;
parameter [15:0] CFG0 = IS_FM6363 ? 16'h7e08 : 16'h0008;
parameter [15:0] CFG1 = IS_FM6363 ? 16'h0fb0 : 16'h1f70;
parameter [15:0] CFG2 = IS_FM6363 ? 16'he79d : 16'h6707;
parameter [15:0] CFG3 = IS_FM6363 ? 16'h60b6 : 16'h40f7;
parameter [15:0] CFG4 = IS_FM6363 ? 16'h5a70 : 16'h0040;
// GCLK por fila: FM6363 = 74, FM6353 = 138 (pulses_on+1)
parameter GCLK_ROW        = IS_FM6363 ? 73 : 137;
// ----------------------------------------------

wire [11:0] PIX_ADDR;
wire [23:0] mem_data;

initial begin
  clk1 = 0;
  clk_counter = 0;
end

///////////////////////
//       TEST
//////////////////////

wire [5:0] PIXEL_DATA;
wire [5:0] CFG_DATA;


reg send_config;
reg send_data;
wire done_data;
reg init_show;

assign {RGB0,RGB1}  = CFG_DATA;

//////////////////////
//////////////////////


wire [2:0] tmp_rgb;
wire tmp_noe;
wire tmp_latch;


wire done_configure;
wire vs_done;

assign LATCH = tmp_latch;
assign NOE = tmp_noe;

reg [4:0] clk_counter;
   always @(posedge clk) begin
      //if (~rst) begin
      //  clk_counter <= 0;
      //  clk1        <= 0;
      //end else 
      //begin
         if(clk_counter == 2) begin
            clk1    <= ~clk1;
            clk_counter <= 0;
         end
         else
            clk_counter <= clk_counter + 1;
      //end
   end


//0001 1111 0111 0000  0EF8

   show_data   #(.pulses_off (27), .pulses_on(GCLK_ROW), .hdr_pulses(3))
               display0 (.clk(clk1), .rst(~rst), .init(init_show), .vs_done(vs_done), .outc(ROW), .gclk(NOE));
   load_data   #(.width(128), .config0(CFG0), .config1(CFG1), .config2(CFG2), .config3(CFG3), .config4(CFG4),
                  .num_drivers(NUM_DRVS), .bit_depth(BIT_DEPTH))
               load0   (.clk(~clk1), .rst(~rst), .out_data({CFG_DATA}), .latch_out(tmp_latch), .dclk(LP_CLK),
               .send_config(send_config), .done_configure(done_configure), .vs_done(vs_done),
               .send_data(send_data), .done_data(done_data));

parameter START         = 4'b0000;
parameter SEND_CONFIG   = 4'b0001;
parameter SEND_DATA     = 4'b0010;
parameter LOOP          = 4'b0011;
parameter LOOP_SEND     = 4'b0100;
parameter SHOW_DATA     = 4'b0101;

reg [3:0] state;

always @(posedge clk1) begin
  if(~rst) begin
    state        = START;
    send_config  <= 0;
  end
  else begin
    case(state)
      START:begin
         send_config <= 1;
         send_data   <= 0;
         init_show   <= 0;
         state        = SEND_CONFIG;
      end

      SEND_CONFIG:begin
         send_config <= 0;
         send_data   <= 0;
         init_show   <= 0;
         state        = LOOP;
      end

      LOOP:begin
         send_config <= 0;
         send_data   <= 0;
         init_show   <= 0;
         if(done_configure)
            state = SEND_DATA;
         else
            state = LOOP;
      end

      SEND_DATA:begin
         send_config <= 0;
         send_data   <= 1;
         init_show   <= 0;
         state       = LOOP_SEND;
      end

      LOOP_SEND:begin
         send_config <= 0;
         send_data   <= 0;
         if(done_data) begin
            init_show <= 1;
            state = SHOW_DATA;
         end
         else begin
            init_show <= 0;
            state = LOOP_SEND;
         end
      end

      SHOW_DATA:begin
         send_config <= 0;
         send_data   <= 1;      // keep reloading the frame buffer
         init_show   <= 0;
         if(done_data)
            state = LOOP_SEND;  // frame sent; next pass reloads it
         else
            state = SHOW_DATA;
      end

//init_show

    endcase
  end
end


endmodule


/*
DATA_LATCH   1  Latch 16-bit data to SRAM
WR_DBG       2  Write debug register (register 5)
VSYNC        3  Update display data
WR_CFG1      4  Write configuration register 1
WR_CFG2      6  Write configuration register 2
WR_CFG3      8  Write configuration register 3
WR_CFG4     10  Write configuration register 4
EN_OP       12  Enable all output channels
DIS_OP      13  Disable all output channels
PRE_ACT     14  Write enable
MBIST       15  Enable SRAM checksum read status
               CFG0   CFG1     CFG2     CFG3
conf_6353 = { 0x0008, 0x1f70 , 0x6707 , 0x40f7 , 0x0040 }; 0 0 01ffff 01 11 0 00 0 || 0 11001 1 10000011 1 ||  0 100 00 00 1111 0 1 11 || 0000 0000 0100 0000
conf_6363 = { 0x7e08, 0x0fb0 , 0xe79d , 0x60b6 , 0x5a70 }; 0 0 001111 10 11 0 00 0 || 1 11001 1 11001110 1 ||  0 110 00 00 1011 0 1 10 || 0101 1010 0111 0000
CFG1     Open_det = 0 [15], GCLK = 0[14] (4 GCLKs for header and 74 GCLKs for each line), 1F [13:8] 32 lines | OPT = 01 [Level2] TEST = 3 [5:4] 
CFG2     TEST = 0 [15] line 33-64, ADJ = 25 [14:10], I_DIV4N = 1 [9] (high current), IGAIN = 131 (IOUT=19*IGAIN/(Rext*256) @ I_DIV4N=1),, Blanking mode = 1 Pulse blanking
CFG3     TEST = 4 [14:12], TEST = 0 [11:10] PWM delay = 0, TEST = 00  [9:8] chain, PWM_ALL = 16 [7:4], TEST = 0 [3] off, UP_SEL = 1 [2] void switch on, VLDO [1:0]
===============================================================================================


CFG1       4 GCLKs for frame and 74 GCLKs for each line, SCAN_LINES = 16, 

GCLK pulse packets  = 74


Panel init
send_latches(14);								// pre-active command  Hold LAT line HIGH for given number of CLK pulses Write enable
send_latches(12);								// enable all output
send_latches(3);								// vsync
for (uint8_t r = 0; r < 5; r++) {
   delayMicroseconds(1);
   this->send_latches(14);							// pre-active command
   this->send_to_allRGB(conf_6363[r], r * 2 + 2);	// send config registers 2, 4, 6, 8, 10 DCLK pulses 
}

1101 1111 1000 0000
D780

111 1100 0010 0000
4 clk LE =1  |  7 clk LE = 0  |  14 clk LE = 1
6 clk LE =1  |  7 clk LE = 0  |  14 clk LE = 1
8 clk LE =1  |  7 clk LE = 0  |  14 clk LE = 1
10 clk LE =1  |  7 clk LE = 0  |  14 clk LE = 1

2 clk LE =1
*/ 