`timescale 1ns/1ps
module configuration_TB;
parameter TEST_INIT_FILE = "video_mem_row.hex";
parameter EXPECT_CLK_HZ = 12000000;
parameter EXPECT_ROW_MODE = 1;
parameter EXPECT_WIDTH = 240;
parameter EXPECT_HEIGHT = 320;
parameter EXPECT_BPP = 2;
parameter EXPECT_BYTES = 480;
parameter EXPECT_AW = 9;
parameter EXPECT_UNIT = 25000;
parameter EXPECT_RESET = 250000;
parameter EXPECT_RECOVERY = 3000000;
reg clk = 1'b0;
reg rst = 1'b1;
reg inc = 1'b0;
reg delay_rst = 1'b1;
reg start_delay = 1'b0;
wire [3:0] addr;
wire done_delay;
integer i;
integer ticks;
spi_lcd_vid_mem #(.VID_INIT_FILE(TEST_INIT_FILE)) uut (
    .clk(clk), .rst(1'b1),
    .lcd_rst(), .lcd_cs(), .lcd_dc(), .lcd_sck(), .lcd_sdi()
);
v_count #(.AW(4), .NBYTES(11)) COUNT (
    .clk(clk), .rst(rst), .inc(inc), .addr(addr)
);
d_count #(.UNIT_TICKS(3)) DELAY (
    .clk(clk), .rst(delay_rst), .s_delay(start_delay),
    .delay_val(8'd4), .done_delay(done_delay)
);
always #5 clk = ~clk;
initial begin
    #1;
    if (uut.CLK_HZ != EXPECT_CLK_HZ || uut.ROW_MODE != EXPECT_ROW_MODE ||
        uut.LCD_WIDTH != EXPECT_WIDTH || uut.LCD_HEIGHT != EXPECT_HEIGHT ||
        uut.BYTES_PER_PIXEL != EXPECT_BPP || uut.VID_BYTES != EXPECT_BYTES ||
        uut.VID_AW != EXPECT_AW || uut.UNIT_TICKS != EXPECT_UNIT ||
        uut.RESET_TICKS != EXPECT_RESET || uut.RECOVERY_TICKS != EXPECT_RECOVERY) begin
        $fatal(1, "Geometry or clock-derived parameter mismatch");
    end
    repeat (2) @(negedge clk);
    if (addr !== 0) $fatal(1, "Counter reset failed");
    rst = 1'b0;
    inc = 1'b1;
    for (i = 1; i <= 44; i = i+1) begin
        @(posedge clk);
        #1;
        if (addr !== (i % 11)) $fatal(1, "Non-power-of-two wrap failed at %0d", i);
    end
    @(negedge clk);
    inc = 1'b0;
    repeat (3) begin
        @(posedge clk);
        #1;
        if (addr !== 0) $fatal(1, "Counter did not hold its address");
    end
    @(negedge clk);
    delay_rst = 1'b0;
    start_delay = 1'b1;
    @(negedge clk);
    start_delay = 1'b0;
    ticks = 0;
    while (!done_delay && ticks < 20) begin
        @(posedge clk);
        #1;
        ticks = ticks+1;
    end
    if (ticks != 12 || done_delay !== 1'b1) $fatal(1, "Delay counter duration mismatch: %0d", ticks);
    $display("PASS configuration: %0dx%0d, bpp-bytes=%0d, memory=%0d, clock=%0d, unit=%0d, reset=%0d, recovery=%0d; wrap=11 and delay=12 cycles",
             EXPECT_WIDTH, EXPECT_HEIGHT, EXPECT_BPP, EXPECT_BYTES,
             EXPECT_CLK_HZ, EXPECT_UNIT, EXPECT_RESET, EXPECT_RECOVERY);
    $finish;
end
initial begin
    #100000;
    $fatal(1, "Configuration test timeout");
end
endmodule
