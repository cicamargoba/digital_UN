module peripheral_led_panel #(
    parameter DELAY = 20,
    parameter TEXT_FONT_FILE = "font8x8.mem",
    parameter TEXT_PALETTE_FILE = "pal16.mem",
    parameter TEXT_TOP_INIT_FILE = "text_demo_top.mem",
    parameter TEXT_BOT_INIT_FILE = "",
    parameter SPRITE_PATTERN_FILE = "sprite_demo_patterns.mem",
    parameter SPRITE_PALETTE_FILE = "sprite_demo_palette.mem"
)(
    input clk,
    input reset,
    input [31:0] d_in,
    input cs,
    input [4:0] addr,
    input rd,
    input wr,
    output reg [31:0] d_out,
    output LP_CLK,
    output LATCH,
    output NOE,
    output [4:0] ROW,
    output [2:0] RGB0,
    output [2:0] RGB1
);
reg [5:0] s;
reg [5:0] text_addr;
reg [14:0] text_data;
reg [2:0] sprite_addr;
reg [25:0] sprite_data;
reg text_we;
reg sprite_we;

always @(*) begin
    s = 6'b000000;
    if (cs) begin
        case (addr)
            5'h04: s = 6'b000001;
            5'h08: s = 6'b000010;
            5'h0C: s = 6'b000100;
            5'h10: s = 6'b001000;
            5'h14: s = 6'b010000;
            5'h18: s = 6'b100000;
            default: s = 6'b000000;
        endcase
    end
end

always @(posedge clk) begin
    if (reset) begin
        text_addr <= 6'd0;
        text_data <= 15'd0;
        sprite_addr <= 3'd0;
        sprite_data <= 26'd0;
        text_we <= 1'b0;
        sprite_we <= 1'b0;
    end else if (cs && wr) begin
        if (s[0]) text_addr <= d_in[5:0];
        if (s[1]) text_data <= d_in[14:0];
        if (s[2]) sprite_addr <= d_in[2:0];
        if (s[3]) sprite_data <= d_in[25:0];
        if (s[4]) text_we <= d_in[0];
        if (s[5]) sprite_we <= d_in[0];
    end
end

always @(*) begin
    d_out = 32'd0;
    if (cs && rd && !reset) begin
        case (addr)
            5'h04: d_out = {26'd0, text_addr};
            5'h08: d_out = {17'd0, text_data};
            5'h0C: d_out = {29'd0, sprite_addr};
            5'h10: d_out = {6'd0, sprite_data};
            5'h14: d_out = {31'd0, text_we};
            5'h18: d_out = {31'd0, sprite_we};
            default: d_out = 32'd0;
        endcase
    end
end

led_panel_4k #(
    .CPU_CONTROL(1),
    .DELAY(DELAY),
    .TEXT_FONT_FILE(TEXT_FONT_FILE),
    .TEXT_PALETTE_FILE(TEXT_PALETTE_FILE),
    .TEXT_TOP_INIT_FILE(TEXT_TOP_INIT_FILE),
    .TEXT_BOT_INIT_FILE(TEXT_BOT_INIT_FILE),
    .SPRITE_PATTERN_FILE(SPRITE_PATTERN_FILE),
    .SPRITE_PALETTE_FILE(SPRITE_PALETTE_FILE)
) PANEL (
    .clk(clk),
    .rst(reset),
    .init(1'b1),
    .LP_CLK(LP_CLK),
    .LATCH(LATCH),
    .NOE(NOE),
    .ROW(ROW),
    .RGB0(RGB0),
    .RGB1(RGB1),
    .cpu_text_we(text_we),
    .cpu_text_addr(text_addr),
    .cpu_text_data(text_data),
    .cpu_sprite_we(sprite_we),
    .cpu_sprite_addr(sprite_addr),
    .cpu_sprite_data(sprite_data)
);
endmodule
