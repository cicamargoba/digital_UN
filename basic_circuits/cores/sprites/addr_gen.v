// Bloque: Addr Gen
// Calcula la direccion exacta de UN pixel en la ROM: {tile,dy,dx}
// y si (col,row) cae dentro del rectangulo 8x8 del sprite.
module addr_gen (
    input  wire [18:0] sprite,
    input  wire [5:0]  row,
    input  wire [5:0]  col,
    output wire [7:0]  rom_addr,  // {tile_id[1:0], dy[2:0], dx[2:0]}
    output wire        in_range
);
    wire [7:0] x    = sprite[8:1];
    wire [7:0] y    = sprite[16:9];
    wire [1:0] tile = sprite[18:17];

    wire signed [8:0] dx_full = {1'b0, col} - {1'b0, x[5:0]};
    wire signed [8:0] dy_full = {1'b0, row} - {1'b0, y[5:0]};
    wire dx_in_range = (dx_full >= 0) && (dx_full < 9'sd8);
    wire dy_in_range = (dy_full >= 0) && (dy_full < 9'sd8);
    wire [2:0] dx = dx_full[2:0];
    wire [2:0] dy = dy_full[2:0];

    assign in_range = dx_in_range && dy_in_range;
    assign rom_addr = {tile, dy, dx};
endmodule
