`timescale 1ns/1ps
module text_display_TB;
reg clk = 0;
reg rst = 1;
wire LP_CLK;
wire LATCH;
wire NOE;
wire [4:0] ROW;
wire [2:0] RGB0;
wire [2:0] RGB1;
wire [23:0] img;
wire [23:0] mixed;
wire [10:0] pix_addr;
wire [1:0] index;
wire clk1;
reg [8*256-1:0] vcd_file;
integer word_index;
integer latches = 0;
integer shifts = 0;
always #10 clk = ~clk;
led_panel_4k SCANNER (
    .clk   (clk),
    .rst   (rst),
    .init  (1'b1),
    .LP_CLK(LP_CLK),
    .LATCH (LATCH),
    .NOE   (NOE),
    .ROW   (ROW),
    .RGB0  (RGB0),
    .RGB1  (RGB1)
);
assign img = SCANNER.mem_data;
assign mixed = SCANNER.mixed_data;
assign pix_addr = SCANNER.PIX_ADDR[10:0];
assign index = SCANNER.index;
assign clk1 = SCANNER.clk1;
always @(posedge LP_CLK)
    shifts = shifts + 1;
always @(posedge LATCH) begin
    latches = latches + 1;
    if (latches == 129) begin
        $display("CAPTURE: integrated top, 32 physical rows x 4 BCM planes, %0d shift events", shifts);
        $display("Message: HOLA on text row 0, MUNDO on text row 1; bottom half keeps image");
        $finish;
    end
end
initial begin
    if (!$value$plusargs("VCD=%s", vcd_file))
        vcd_file = "text_display_TB.vcd";
    $dumpfile(vcd_file);
    $dumpvars(0, text_display_TB);
    for (word_index = 0; word_index < 32; word_index = word_index + 1) begin
        $dumpvars(0, SCANNER.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[word_index]);
        $dumpvars(0, SCANNER.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[word_index]);
    end
    repeat (4) @(negedge clk);
    rst = 0;
end
initial begin
    #5000000;
    $fatal(1, "Scanner timeout: %0d latches", latches);
end
endmodule
