module v_count #(
    parameter AW = 17,
    parameter NBYTES = (1 << AW)
)(
    input             clk,
    input             rst,
    input             inc,
    output reg [AW-1:0] addr
);
always @(posedge clk) begin
    if (rst)
        addr <= 0;
    else if (inc) begin
        if (addr == NBYTES - 1)
            addr <= 0;
        else
            addr <= addr + 1;
    end
end
endmodule
