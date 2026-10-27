module sprite_select (
    input [207:0] descriptors,
    input [23:0] dx,
    input [23:0] dy,
    input [7:0] hits,
    output reg [14:0] attributes,
    output hit
);
integer i;
always @* begin
    attributes = 15'd0;
    for (i = 0; i < 8; i = i + 1)
        attributes = attributes | ({15{hits[i]}} &
            {descriptors[i*26+16 +: 5], dy[i*3 +: 3],
             dx[i*3 +: 3], descriptors[i*26+21 +: 4]});
end
assign hit = |hits;
endmodule
