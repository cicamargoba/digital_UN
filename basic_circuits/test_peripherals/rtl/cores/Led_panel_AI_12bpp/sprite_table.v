module sprite_table (
    input clk,
    input rst,
    input we,
    input [2:0] waddr,
    input [25:0] wdata,
    output [207:0] descriptors
);
reg [25:0] MEM [0:7];
integer i;
genvar g;
generate
    for (g = 0; g < 8; g = g + 1) begin: PACK
        assign descriptors[g*26 +: 26] = MEM[g];
    end
endgenerate
always @(negedge clk) begin
    if (rst) begin
        for (i = 0; i < 8; i = i + 1)
            MEM[i] <= 26'd0;
    end else if (we)
        MEM[waddr] <= wdata;
end
endmodule
