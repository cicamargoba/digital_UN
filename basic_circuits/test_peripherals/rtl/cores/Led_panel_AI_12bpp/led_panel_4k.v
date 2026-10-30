module led_panel_4k(clk , rst , init, LP_CLK, LATCH, NOE, ROW, RGB0, RGB1,
                    cpu_text_we, cpu_text_addr, cpu_text_data,
                    cpu_sprite_we, cpu_sprite_addr, cpu_sprite_data);

    input         rst;
    input         clk;
    input         init;
    output        LP_CLK;
    output        LATCH;
    output        NOE;
    output  [4:0] ROW;
    output  [2:0] RGB0;
    output  [2:0] RGB1;
    input         cpu_text_we;
    input   [5:0] cpu_text_addr;
    input  [14:0] cpu_text_data;
    input         cpu_sprite_we;
    input   [2:0] cpu_sprite_addr;
    input  [25:0] cpu_sprite_data;


    wire w_ZR;
    wire w_ZC;
    wire w_ZD;
    wire w_ZI;
    wire w_LD;
    wire w_SHD;
    wire w_RST_R;
    wire w_RST_C;
    wire w_RST_D;
    wire w_RST_I;
    wire w_INC_R;
    wire w_INC_C;
    wire w_INC_D;
    wire w_INC_I;
    wire [10:0] count_delay;
    wire [10:0] delay;
    wire [1:0] index;



    reg clk1;


// ======== Caracteristicas de la matriz ========
parameter NUM_COLS = 64;
parameter NUM_ROWS = 64;
parameter NUM_PIXELS = NUM_COLS*NUM_ROWS;
parameter HALF_SCREEN = NUM_PIXELS/2;
parameter BIT_DEPTH = 4;
parameter TOTAL_BIT_DEPTH = 3*BIT_DEPTH;
parameter DELAY = 20;
parameter CPU_CONTROL = 0;
parameter TEXT_FONT_FILE = "font8x8.mem";
parameter TEXT_PALETTE_FILE = "pal16.mem";
parameter TEXT_TOP_INIT_FILE = "text_demo_top.mem";
parameter TEXT_BOT_INIT_FILE = "";
parameter SPRITE_INIT_FILE = "sprite_demo.mem";
parameter SPRITE_PATTERN_FILE = "sprite_demo_patterns.mem";
parameter SPRITE_PALETTE_FILE = "sprite_demo_palette.mem";

wire [($clog2(NUM_COLS)-1):0]		COL;
// ----------------------------------------------

wire [11:0] PIX_ADDR;
wire [23:0] mem_data;
wire [23:0] mixed_data;
wire [23:0] sprite_data;
wire sprite_on0;
wire sprite_on1;
wire sprite_we;
wire [2:0] sprite_waddr;
wire [25:0] sprite_wdata;
wire [7:0] sprite_col;
wire sprite_ready;


wire [2:0] tmp_rgb;
wire tmp_noe;
wire tmp_latch;

assign LATCH = tmp_latch;
assign NOE = tmp_noe;

reg [4:0] clk_counter;
   always @(posedge clk) begin
      if (rst) begin
        clk_counter <= 0;
        clk1        <= 0;
      end else begin
         if(clk_counter == 2) begin
            clk1    <= ~clk1;
            clk_counter <= 0;
         end
         else
            clk_counter <= clk_counter + 1;
      end
   end

    assign PIX_ADDR = {ROW, COL};

    assign LP_CLK = clk1 & PX_CLK_EN;

    count #(.width(( $clog2(HALF_SCREEN) -1) ))  count_row(  .clk(clk1), .reset(w_RST_R), .inc(w_INC_R), .outc(ROW),   .zero(w_ZR) );
    count #(.width(($clog2(NUM_COLS)     -1) ))  count_col(  .clk(clk1), .reset(w_RST_C), .inc(w_INC_C), .outc(COL),   .zero(w_ZC) );
    count #(.width (10))   cnt_delay(  .clk(clk1), .reset(w_RST_D), .inc(w_INC_D), .outc(count_delay));
    count #(.width (1))   count_index( .clk(clk1), .reset(w_RST_I), .inc(w_INC_I), .outc(index), .zero(w_ZI));
    lsr_led #(.init_value(DELAY), .width(10)) lsr_led0( .clk(clk1), .load(w_LD), .shift(w_SHD), .s_A(delay));
    comp_4k #(.width(10) ) compa(.in1(delay), .in2(count_delay), .out(w_ZD));
    memory  #(.size(NUM_PIXELS/2 -1), .width( $clog2(NUM_PIXELS)-2 ) ) mem0 (.clk(clk1), .address(PIX_ADDR), .rd(1'b1), .rdata(mem_data));
    generate
        if (CPU_CONTROL) begin: CPU_WRITES
            assign sprite_we = cpu_sprite_we & ~rst;
            assign sprite_waddr = cpu_sprite_addr;
            assign sprite_wdata = cpu_sprite_data;
            assign sprite_ready = 1'b1;
        end else begin: DEMO_WRITES
            sprite_demo #(.INIT_FILE(SPRITE_INIT_FILE)) SPRITE_DEMO (
                .clk(clk1), .rst(rst), .we(sprite_we), .waddr(sprite_waddr),
                .wdata(sprite_wdata), .ready(sprite_ready)
            );
        end
    endgenerate
    sprite_engine #(
        .PATTERN_FILE(SPRITE_PATTERN_FILE),
        .PALETTE_FILE(SPRITE_PALETTE_FILE)
    ) SPRITE_ENGINE (
        .clk(clk1), .rst(rst), .pix_addr(PIX_ADDR[10:0]),
        .we(sprite_we), .waddr(sprite_waddr), .wdata(sprite_wdata),
        .col_clear(1'b0), .spr(sprite_data),
        .spr_on0(sprite_on0), .spr_on1(sprite_on1), .col(sprite_col)
    );
    text_overlay #(
        .FONT_FILE     (TEXT_FONT_FILE),
        .PALETTE_FILE  (TEXT_PALETTE_FILE),
        .TOP_INIT_FILE (TEXT_TOP_INIT_FILE),
        .BOT_INIT_FILE (TEXT_BOT_INIT_FILE)
    ) TEXT_OVERLAY (
        .clk      (clk1),
        .pix_addr (PIX_ADDR[10:0]),
        .img      (mem_data),
        .we       (CPU_CONTROL ? (cpu_text_we & ~rst) : 1'b0),
        .waddr    (CPU_CONTROL ? cpu_text_addr : 6'd0),
        .wdata    (CPU_CONTROL ? cpu_text_data : 15'd0),
        .spr      (sprite_data),
        .spr_on0  (sprite_on0),
        .spr_on1  (sprite_on1),
        .data     (mixed_data)
    );
    mux_led                mux0 (.in0(mixed_data), .out0({RGB0, RGB1}), .sel(index) );
    ctrl_lp4k ctrl0 (.clk(clk1), .rst(rst), .init(1'b1), 
                    .ZR(w_ZR), .ZC(w_ZC), .ZD(w_ZD), .ZI(w_ZI),
                    .RST_R(w_RST_R), .RST_C(w_RST_C), .RST_D(w_RST_D), .RST_I(w_RST_I),
                    .INC_R(w_INC_R), .INC_C(w_INC_C), .INC_D(w_INC_D), .INC_I(w_INC_I),
                    .LD(w_LD), .SHD(w_SHD),
                    .LATCH(tmp_latch), .NOE(tmp_noe), .PX_CLK_EN(PX_CLK_EN)) ;

endmodule
