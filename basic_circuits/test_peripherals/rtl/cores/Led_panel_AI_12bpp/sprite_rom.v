module sprite_rom #(
    parameter INIT_FILE = "sprites.mem"
)(
    input clk,
    input [7:0] addr0,
    input [7:0] addr1,
    output reg [7:0] line0,
    output reg [7:0] line1
);
(* ram_style = "block" *) reg [7:0] MEM [0:255];
initial begin
    $readmemh(INIT_FILE, MEM);
end
always @(negedge clk) begin
    line0 <= MEM[addr0];
    line1 <= MEM[addr1];
end
endmodule
