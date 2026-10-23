module text_palette #(
    parameter INIT_FILE = "pal16.mem"
)(
    input  [3:0]  index,
    output [11:0] rgb
);
reg [11:0] MEM [0:15];
initial begin
    $readmemh(INIT_FILE, MEM);
end
assign rgb = MEM[index];
endmodule
