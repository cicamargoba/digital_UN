module text_overlay #(
    parameter FONT_FILE = "font8x8.mem",
    parameter PALETTE_FILE = "pal16.mem",
    parameter TOP_INIT_FILE = "",
    parameter BOT_INIT_FILE = ""
)(
    input         clk,
    input  [10:0] pix_addr,
    input  [23:0] img,
    input         we,
    input  [5:0]  waddr,
    input  [14:0] wdata,
    output [23:0] data
);
wire [23:0] txt;
wire txt_on0;
wire txt_on1;
text_memory #(
    .FONT_FILE     (FONT_FILE),
    .PALETTE_FILE  (PALETTE_FILE),
    .TOP_INIT_FILE (TOP_INIT_FILE),
    .BOT_INIT_FILE (BOT_INIT_FILE)
) TEXT_MEMORY (
    .clk      (clk),
    .pix_addr (pix_addr),
    .we       (we),
    .waddr    (waddr),
    .wdata    (wdata),
    .txt      (txt),
    .txt_on0  (txt_on0),
    .txt_on1  (txt_on1)
);
text_mix MIX (
    .img     (img),
    .txt     (txt),
    .txt_on0 (txt_on0),
    .txt_on1 (txt_on1),
    .data    (data)
);
endmodule
    