// Bloque: ROM de Tiles (memoria real: 1 direccion -> 1 pixel de color)
// addr[7:0] = {tile_id[1:0], dy[2:0], dx[2:0]}
// Color 4'hF = transparente (centinela, no es un color real)
module tile_rom (
    input  wire       clk,
    input  wire [7:0] addr,
    output reg  [3:0] color
);
    localparam TRANSP = 4'hF;

    function automatic [3:0] tile_pixel;
        input [1:0] tile_id;
        input [2:0] ty;
        input [2:0] tx;
        reg [7:0] row_on; // que columnas estan encendidas en esta fila
        begin
            row_on = 8'b0;
            case (tile_id)
                2'd0: case (ty) // puntero de mouse (flecha)
                    3'd0: row_on = 8'b10000000;
                    3'd1: row_on = 8'b11000000;
                    3'd2: row_on = 8'b11100000;
                    3'd3: row_on = 8'b11110000;
                    3'd4: row_on = 8'b11111000;
                    3'd5: row_on = 8'b11001000;
                    3'd6: row_on = 8'b10000100;
                    3'd7: row_on = 8'b00000100;
                    default: row_on = 8'b0;
                endcase
                default: row_on = 8'b0; // tiles 1-3 reservados, todo transparente
            endcase
            tile_pixel = row_on[3'd7 - tx] ? 4'h1 : TRANSP; // 4'h1 = blanco
        end
    endfunction

    always @(posedge clk)
        color <= tile_pixel(addr[7:6], addr[5:3], addr[2:0]);
endmodule
