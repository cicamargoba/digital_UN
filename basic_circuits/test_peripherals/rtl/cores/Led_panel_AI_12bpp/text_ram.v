module text_ram #(
    parameter INIT_FILE = ""
)(
    input             clk,
    input      [4:0]  raddr,
    output reg [14:0] rdata,
    input             we,
    input      [4:0]  waddr,
    input      [14:0] wdata
);
reg [14:0] MEM [0:31];
integer i;
initial begin
    for (i = 0; i < 32; i = i + 1)
        MEM[i] = 15'h0020;
    if (INIT_FILE != "")
        $readmemh(INIT_FILE, MEM);
end
always @(negedge clk) begin
    rdata <= MEM[raddr];
    if (we)
        MEM[waddr] <= wdata;
end
endmodule
