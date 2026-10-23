module font_rom #(
    parameter INIT_FILE = "font8x8.mem"
)(
    input  [9:0] addr,
    output [7:0] data
);
reg [7:0] MEM [0:1023];
initial begin
    $readmemh(INIT_FILE, MEM);
end
assign data = MEM[addr];
endmodule
