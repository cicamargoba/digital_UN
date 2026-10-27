module sprite_engine #(
    parameter PATTERN_FILE = "sprites.mem",
    parameter PALETTE_FILE = "pal16.mem"
)(
    input clk,
    input rst,
    input [10:0] pix_addr,
    input we,
    input [2:0] waddr,
    input [25:0] wdata,
    input col_clear,
    output [23:0] spr,
    output spr_on0,
    output spr_on1,
    output [7:0] col
);
wire [207:0] descriptors;
wire [7:0] addr0;
wire [7:0] addr1;
wire [7:0] line0;
wire [7:0] line1;
wire [3:0] color0;
wire [3:0] color1;
wire [7:0] hits0;
wire [7:0] hits1;
sprite_table TABLE (
    .clk(clk), .rst(rst), .we(we), .waddr(waddr), .wdata(wdata),
    .descriptors(descriptors)
);
sprite_half TOP_HALF (
    .clk(clk), .rst(rst), .x(pix_addr[5:0]), .y({1'b0, pix_addr[10:6]}),
    .descriptors(descriptors), .rom_addr(addr0), .line(line0),
    .color(color0), .hits(hits0), .spr_on(spr_on0)
);
sprite_half BOT_HALF (
    .clk(clk), .rst(rst), .x(pix_addr[5:0]), .y({1'b1, pix_addr[10:6]}),
    .descriptors(descriptors), .rom_addr(addr1), .line(line1),
    .color(color1), .hits(hits1), .spr_on(spr_on1)
);
sprite_rom #(.INIT_FILE(PATTERN_FILE)) ROM (
    .clk(clk), .addr0(addr0), .addr1(addr1), .line0(line0), .line1(line1)
);
text_palette #(.INIT_FILE(PALETTE_FILE)) PALETTE0 (
    .index(color0), .rgb(spr[23:12])
);
text_palette #(.INIT_FILE(PALETTE_FILE)) PALETTE1 (
    .index(color1), .rgb(spr[11:0])
);
sprite_collision COLLISION (
    .clk(clk), .rst(rst), .clear(col_clear), .hits0(hits0), .hits1(hits1), .col(col)
);
endmodule
