module text_memory #(
    parameter FONT_FILE = "font8x8.mem",
    parameter PALETTE_FILE = "pal16.mem",
    parameter TOP_INIT_FILE = "",
    parameter BOT_INIT_FILE = ""
)(
    input         clk,
    input  [10:0] pix_addr,
    input         we,
    input  [5:0]  waddr,
    input  [14:0] wdata,
    output [23:0] txt,
    output        txt_on0,
    output        txt_on1
);
wire [4:0] cell_addr;
wire [14:0] cell_top;
wire [14:0] cell_bot;
wire [7:0] line_top;
wire [7:0] line_bot;
reg [2:0] gx;
reg [2:0] gy;
assign cell_addr = {pix_addr[10:9], pix_addr[5:3]};
always @(negedge clk) begin
    gx <= pix_addr[2:0];
    gy <= pix_addr[8:6];
end
text_ram #(
    .INIT_FILE (TOP_INIT_FILE)
) txt_top (
    .clk   (clk),
    .raddr (cell_addr),
    .rdata (cell_top),
    .we    (we & ~waddr[5]),
    .waddr (waddr[4:0]),
    .wdata (wdata)
);
text_ram #(
    .INIT_FILE (BOT_INIT_FILE)
) txt_bot (
    .clk   (clk),
    .raddr (cell_addr),
    .rdata (cell_bot),
    .we    (we & waddr[5]),
    .waddr (waddr[4:0]),
    .wdata (wdata)
);
font_rom #(
    .INIT_FILE (FONT_FILE)
) font_top (
    .addr ({cell_top[6:0], gy}),
    .data (line_top)
);
font_rom #(
    .INIT_FILE (FONT_FILE)
) font_bot (
    .addr ({cell_bot[6:0], gy}),
    .data (line_bot)
);
text_color #(
    .PALETTE_FILE (PALETTE_FILE)
) color_top (
    .line   (line_top),
    .gx     (gx),
    .fg     (cell_top[10:7]),
    .bg     (cell_top[14:11]),
    .rgb    (txt[23:12]),
    .txt_on (txt_on0)
);
text_color #(
    .PALETTE_FILE (PALETTE_FILE)
) color_bot (
    .line   (line_bot),
    .gx     (gx),
    .fg     (cell_bot[10:7]),
    .bg     (cell_bot[14:11]),
    .rgb    (txt[11:0]),
    .txt_on (txt_on1)
);
endmodule
