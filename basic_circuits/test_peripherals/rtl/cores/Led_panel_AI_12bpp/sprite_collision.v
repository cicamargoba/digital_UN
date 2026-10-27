module sprite_collision (
    input clk,
    input rst,
    input clear,
    input [7:0] hits0,
    input [7:0] hits1,
    output reg [7:0] col
);
wire multiple0;
wire multiple1;
wire [7:0] events;
assign multiple0 = |(hits0 & (hits0 - 8'd1));
assign multiple1 = |(hits1 & (hits1 - 8'd1));
assign events = ({8{multiple0}} & hits0) | ({8{multiple1}} & hits1);
always @(negedge clk) begin
    if (rst)
        col <= 8'd0;
    else if (clear)
        col <= events;
    else
        col <= col | events;
end
endmodule
