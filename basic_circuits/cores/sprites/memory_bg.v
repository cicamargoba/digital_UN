// Bloque: MEMORY (framebuffer de fondo, 64x64, 4 bits/pixel)
module memory_bg (
    input  wire        clk,
    input  wire        cs,
    input  wire        wr,
    input  wire [11:0] addr,
    input  wire [3:0]  d_in,
    input  wire [5:0]  row,
    input  wire [5:0]  col,
    output reg  [3:0]  bg_color
);
    reg [3:0] fb [0:4095];
    wire [11:0] raddr = {row, col};

    always @(posedge clk) begin
        if (cs && wr) fb[addr] <= d_in;
        bg_color <= fb[raddr];
    end
endmodule
