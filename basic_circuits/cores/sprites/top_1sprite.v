// Top-level: la ROM de tiles conecta DIRECTO al mux (su salida rom_color
// va sin pasar por ningun bloque intermedio hacia u_mux_prioridad).
// hit_detect lee la MISMA senal rom_color en paralelo, no en el camino.
module top_1sprite (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cs_sprite,
    input  wire        wr_sprite,
    input  wire [18:0] d_in_sprite,

    input  wire        cs_bg,
    input  wire        wr_bg,
    input  wire [11:0] addr_bg,
    input  wire [3:0]  d_in_bg,

    input  wire [5:0]  row,
    input  wire [5:0]  col,

    output wire [3:0]  pixel
);

    wire [18:0] sprite;
    oam_ram u_oam_ram (
        .clk(clk), .cs(cs_sprite), .wr(wr_sprite), .d_in(d_in_sprite),
        .sprite(sprite)
    );

    wire [7:0] rom_addr;
    wire       in_range;
    addr_gen u_addr_gen (
        .sprite(sprite), .row(row), .col(col),
        .rom_addr(rom_addr), .in_range(in_range)
    );

    wire [3:0] rom_color;
    tile_rom u_tile_rom (
        .clk(clk), .addr(rom_addr), .color(rom_color)
    );

    wire hit;
    hit_detect u_hit_detect (
        .active(sprite[0]), .in_range(in_range), .rom_color(rom_color),
        .hit(hit)
    );

    wire [3:0] bg_color;
    memory_bg u_memory_bg (
        .clk(clk), .cs(cs_bg), .wr(wr_bg), .addr(addr_bg), .d_in(d_in_bg),
        .row(row), .col(col),
        .bg_color(bg_color)
    );

    // ---- MUX: sus 2 entradas de datos son DIRECTAS de las 2 memorias ----
    mux_prioridad u_mux_prioridad (
        .sprite_color(rom_color), .hit(hit), .bg_color(bg_color),
        .pixel(pixel)
    );

endmodule
