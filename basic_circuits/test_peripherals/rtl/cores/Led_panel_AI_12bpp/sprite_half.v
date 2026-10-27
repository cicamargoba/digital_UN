module sprite_half (
    input clk,
    input rst,
    input [5:0] x,
    input [5:0] y,
    input [207:0] descriptors,
    output [7:0] rom_addr,
    input [7:0] line,
    output reg [2:0] dx,
    output reg [3:0] color,
    output reg hit,
    output [7:0] hits,
    output spr_on
);
wire [23:0] delta_x;
wire [23:0] delta_y;
wire [14:0] attributes;
wire selected_hit;
genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin: DETECT
        sprite_detector D (
            .x(x),
            .y(y),
            .sprite_x(descriptors[i*26 +: 8]),
            .sprite_y(descriptors[i*26+8 +: 8]),
            .en(descriptors[i*26+25]),
            .dx(delta_x[i*3 +: 3]),
            .dy(delta_y[i*3 +: 3]),
            .hit(hits[i])
        );
    end
endgenerate
sprite_select SELECT (
    .descriptors(descriptors),
    .dx(delta_x),
    .dy(delta_y),
    .hits(hits),
    .attributes(attributes),
    .hit(selected_hit)
);
assign rom_addr = attributes[14:7];
always @(negedge clk) begin
    if (rst) begin
        dx <= 3'd0;
        color <= 4'd0;
        hit <= 1'b0;
    end else begin
        dx <= attributes[6:4];
        color <= attributes[3:0];
        hit <= selected_hit;
    end
end
assign spr_on = hit & line[dx];
endmodule
