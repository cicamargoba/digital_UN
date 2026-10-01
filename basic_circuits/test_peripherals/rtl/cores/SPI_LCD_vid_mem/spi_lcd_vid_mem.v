`include "init_defs.vh"
module spi_lcd_vid_mem #(
    parameter INIT_MAX    = `LCD_INIT_MAX,
    parameter CLK_DIV     = 4,
    parameter UNIT_TICKS  = 25000,
    parameter RESET_TICKS = 250000,
    parameter VID_AW      = 18,
    parameter VID_INIT_FILE = "video_mem_init.hex"
)(
    input         clk,
    input         rst,
    output        lcd_rst,
    output        lcd_cs,
    output        lcd_dc,
    output        lcd_sck,
    output        lcd_sdi
);
wire [7:0] a_addr;
wire [9:0] init_mem_data;
wire [8:0] memwr;
wire [8:0] spi_data;
wire       done_delay;
wire       done_tx;
wire       init_tx;
wire [1:0] sel_data;
wire       inc_addr;
wire       rst_all;
assign lcd_cs = 1'b0;
wire       s_delay;
wire       st_delay;
wire       last_addr;
wire [7:0] init_last;
wire [VID_AW-1:0] v_addr;
wire [7:0] vid_data;
wire       inc_v_addr;
wire       rst_v;
assign st_delay = init_mem_data[9];
assign init_last = INIT_MAX - 1;
comp_addr #(
    .W (8)
) COMP_ADDR (
    .in1 (a_addr),
    .in2 (init_last),
    .z   (last_addr)
);
ctrl #(
    .RESET_TICKS (RESET_TICKS)
) CRTL (
    .clk        (clk),
    .restart    (rst),
    .last_addr  (last_addr),
    .done_delay (done_delay),
    .st_delay   (st_delay),
    .src_last   (1'b1),
    .src_valid  (1'b1),
    .done_tx    (done_tx),
    .rst        (lcd_rst),
    .init_tx    (init_tx),
    .sel_data   (sel_data),
    .inc_addr   (inc_addr),
    .rst_all    (rst_all),
    .s_delay    (s_delay),
    .src_rdy    (),
    .inc_v_addr (inc_v_addr),
    .rst_v      (rst_v)
);
spi_tx #(
    .CLK_DIV (CLK_DIV)
) SPI_TX (
    .clk     (clk),
    .rst     (rst),
    .init_tx (init_tx),
    .data    (spi_data),
    .dc      (lcd_dc),
    .sck     (lcd_sck),
    .sdi     (lcd_sdi),
    .done_tx (done_tx)
);
d_count #(
    .UNIT_TICKS (UNIT_TICKS)
) D_COUNT (
    .clk        (clk),
    .rst        (rst_all),
    .s_delay    (s_delay),
    .delay_val  (init_mem_data[7:0]),
    .done_delay (done_delay)
);
a_count A_COUNT (
    .clk  (clk),
    .rst  (rst_all),
    .inc  (inc_addr),
    .addr (a_addr)
);
init_mem INIT_MEM (
    .addr (a_addr),
    .data (init_mem_data)
);
memwr_cmd MEMWR_CMD (
    .cmd (memwr)
);
v_count #(
    .AW (VID_AW)
) V_COUNT (
    .clk  (clk),
    .rst  (rst_v),
    .inc  (inc_v_addr),
    .addr (v_addr)
);
video_mem #(
    .AW        (VID_AW),
    .INIT_FILE (VID_INIT_FILE)
) VIDEO_MEM (
    .addr (v_addr),
    .data (vid_data)
);
mux_3to1 MUX (
    .in0 (init_mem_data[8:0]),
    .in1 (memwr),
    .in2 ({1'b1, vid_data}),
    .sel (sel_data),
    .out (spi_data)
);
endmodule
