module text_color #(
    parameter PALETTE_FILE = "pal16.mem"
)(
    input  [7:0]  line,
    input  [2:0]  gx,
    input  [3:0]  fg,
    input  [3:0]  bg,
    output [11:0] rgb,
    output        txt_on
);
wire glyph_bit;
wire [3:0] palette_index;
assign glyph_bit = line[gx];
assign palette_index = glyph_bit ? fg : bg;
assign txt_on = glyph_bit | (bg != 4'd0);
text_palette #(
    .INIT_FILE (PALETTE_FILE)
) PALETTE (
    .index (palette_index),
    .rgb   (rgb)
);
endmodule
