// Bloque: Mux prioridad
// si hit: pixel=sprite_color; sino: pixel=bg_color
module mux_prioridad (
    input  wire [3:0] sprite_color,
    input  wire        hit,
    input  wire [3:0] bg_color,
    output wire [3:0] pixel
);
    assign pixel = hit ? sprite_color : bg_color;
endmodule
