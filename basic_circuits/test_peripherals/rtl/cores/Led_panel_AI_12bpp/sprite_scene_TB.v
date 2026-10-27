`timescale 1ns/1ps
module sprite_scene_TB;
reg clk = 0;
reg rst = 1;
reg [10:0] pix_addr = 0;
reg we = 0;
reg [2:0] waddr = 0;
reg [25:0] wdata = 0;
reg sample_valid = 0;
reg [10:0] sample_addr = 0;
wire [23:0] spr;
wire spr_on0;
wire spr_on1;
wire [7:0] col;
reg [25:0] descriptors [0:7];
integer i;
always #5 clk = ~clk;
sprite_engine #(
    .PATTERN_FILE("space_invaders_patterns.mem"),
    .PALETTE_FILE("space_invaders_palette.mem")
) DUT (
    .clk(clk), .rst(rst), .pix_addr(pix_addr),
    .we(we), .waddr(waddr), .wdata(wdata), .col_clear(1'b0),
    .spr(spr), .spr_on0(spr_on0), .spr_on1(spr_on1), .col(col)
);
initial begin
    $dumpfile("space_invaders.vcd");
    $dumpvars(1,sprite_scene_TB);
    $readmemh("space_invaders_descriptors.mem",descriptors);
    @(negedge clk);
    #1;
    rst = 0;
    for (i = 0; i < 8; i = i + 1) begin
        @(posedge clk);
        we = 1;
        waddr = i;
        wdata = descriptors[i];
        @(negedge clk);
        #1;
        we = 0;
    end
    for (i = 0; i < 2048; i = i + 1) begin
        @(posedge clk);
        sample_valid = 0;
        pix_addr = i;
        @(negedge clk);
        #1;
        sample_addr = i;
        sample_valid = 1;
        if ((^{spr,spr_on0,spr_on1,col}) === 1'bx)
            $fatal(1,"Unknown output at pixel pair %0d",i);
    end
    #1;
    $display("CAPTURE: 2048 pixel pairs, 4096 pixels, collision=%h",col);
    $finish;
end
initial begin
    #100000;
    $fatal(1,"Scene capture timeout");
end
endmodule
