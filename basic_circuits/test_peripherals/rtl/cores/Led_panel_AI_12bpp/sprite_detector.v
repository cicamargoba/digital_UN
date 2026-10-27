module sprite_detector (
    input [5:0] x,
    input [5:0] y,
    input [7:0] sprite_x,
    input [7:0] sprite_y,
    input en,
    output [2:0] dx,
    output [2:0] dy,
    output hit
);
wire [7:0] delta_x;
wire [7:0] delta_y;
assign delta_x = {2'b00, x} - sprite_x;
assign delta_y = {2'b00, y} - sprite_y;
assign dx = delta_x[2:0];
assign dy = delta_y[2:0];
assign hit = en & (~|delta_x[7:3]) & (~|delta_y[7:3]);
endmodule
