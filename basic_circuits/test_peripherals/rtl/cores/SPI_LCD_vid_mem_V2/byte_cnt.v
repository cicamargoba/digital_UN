module byte_cnt (
    input clk,
    input rst,
    input inc,
    output z
);
reg [3:0] count;
always @(posedge clk) begin
    if (rst) begin
        count <= 4'd0;
    end else if (inc) begin
        count <= count + 1'b1;
    end
end
assign z = (count == 4'd8);
endmodule
