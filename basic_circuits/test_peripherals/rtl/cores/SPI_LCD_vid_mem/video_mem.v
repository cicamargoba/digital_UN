module video_mem #(
    parameter AW = 18,
    parameter INIT_FILE = "video_mem_init.hex"
)(
    input      [AW-1:0] addr,
    output reg [7:0]   data
);
localparam LAST = (1 << AW) - 1;
reg [7:0] MEM [0:LAST];
initial begin
    $readmemh(INIT_FILE, MEM);
end
always @(*) begin
    data = MEM[addr];
end
endmodule
