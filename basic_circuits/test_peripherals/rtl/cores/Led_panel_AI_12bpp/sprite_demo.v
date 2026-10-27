module sprite_demo #(
    parameter INIT_FILE = "sprite_demo.mem"
)(
    input clk,
    input rst,
    output we,
    output [2:0] waddr,
    output [25:0] wdata,
    output ready
);
reg [25:0] MEM [0:7];
reg [3:0] index;
initial begin
    $readmemh(INIT_FILE, MEM);
end
always @(negedge clk or posedge rst) begin
    if (rst)
        index <= 4'd0;
    else if (index < 8)
        index <= index + 1'b1;
end
assign we = !rst && index < 8;
assign waddr = index[2:0];
assign wdata = MEM[index[2:0]];
assign ready = index == 8;
endmodule
