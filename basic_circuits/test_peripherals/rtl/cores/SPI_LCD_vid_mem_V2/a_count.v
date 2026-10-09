module a_count #(
    parameter AW = 8
)(
    input             clk,
    input             rst,
    input             inc,
    output reg [AW-1:0] addr
);
always @(posedge clk) begin
    if (rst)
        addr <= 0;
    else if (inc)
        addr <= addr + 1;
end
endmodule
