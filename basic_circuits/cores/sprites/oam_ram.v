// Bloque: OAM RAM (1 sprite)
// [0]=active [8:1]=X [16:9]=Y [18:17]=tile_id
// (ya NO guarda color: el color real vive en la ROM, por pixel)
module oam_ram (
    input  wire        clk,
    input  wire        cs,
    input  wire        wr,
    input  wire [18:0] d_in,
    output reg  [18:0] sprite
);
    always @(posedge clk) begin
        if (cs && wr)
            sprite <= d_in;
    end
endmodule
