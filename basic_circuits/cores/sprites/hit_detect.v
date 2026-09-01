// Bloque: Hit Detector
// Lee la salida de la ROM EN PARALELO al mux (no esta entre la ROM y el mux).
module hit_detect (
    input  wire       active,
    input  wire       in_range,
    input  wire [3:0] rom_color,
    output wire        hit
);
    localparam TRANSP = 4'hF;
    assign hit = active && in_range && (rom_color != TRANSP);
endmodule
