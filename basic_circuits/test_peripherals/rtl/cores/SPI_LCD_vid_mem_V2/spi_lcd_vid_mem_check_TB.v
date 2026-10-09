`timescale 1ns/1ps
`include "init_defs.vh"
module spi_lcd_vid_mem_check_TB;
parameter TEST_BYTES = 16;
parameter TEST_INIT_FILE = "video_mem_init_TB.hex";
localparam TEST_AW = (TEST_BYTES > 1) ? $clog2(TEST_BYTES) : 1;
reg clk = 1'b0;
reg rst = 1'b1;
wire lcd_rst;
wire lcd_cs;
wire lcd_dc;
wire lcd_sck;
wire lcd_sdi;
reg [7:0] ref_addr;
wire [9:0] ref_data;
reg [8:0] expected [0:255];
reg [7:0] pixels [0:TEST_BYTES-1];
reg [7:0] received = 8'd0;
reg sampling = 1'b0;
reg [8:0] expected_byte;
integer init_bytes = 0;
integer byte_count = 0;
integer bit_count = 0;
integer i;
init_mem REFERENCE (.addr(ref_addr), .data(ref_data));
spi_lcd_vid_mem #(
    .CLK_DIV(2),
    .UNIT_TICKS(4),
    .RESET_TICKS(8),
    .RECOVERY_TICKS(8),
    .VID_AW(TEST_AW),
    .VID_BYTES(TEST_BYTES),
    .VID_INIT_FILE(TEST_INIT_FILE)
) uut (
    .clk(clk),
    .rst(rst),
    .lcd_rst(lcd_rst),
    .lcd_cs(lcd_cs),
    .lcd_dc(lcd_dc),
    .lcd_sck(lcd_sck),
    .lcd_sdi(lcd_sdi)
);
always #20 clk = ~clk;
always @(negedge lcd_sck) begin
    if (!rst && lcd_rst) begin
        sampling = 1'b1;
    end
end
always @(posedge lcd_sck) begin
    if (sampling && !rst && lcd_rst) begin
        received = {received[6:0], lcd_sdi};
        bit_count = bit_count + 1;
        if (bit_count == 8) begin
            if (byte_count < init_bytes) begin
                expected_byte = expected[byte_count];
            end else if (byte_count == init_bytes) begin
                expected_byte = 9'h02c;
            end else begin
                expected_byte = {1'b1, pixels[(byte_count-init_bytes-1)%TEST_BYTES]};
            end
            if ({lcd_dc, received} !== expected_byte || lcd_cs !== 1'b0) begin
                $fatal(1, "byte=%0d expected=%h received=%h CS=%b",
                       byte_count, expected_byte, {lcd_dc, received}, lcd_cs);
            end
            $display("spi_lcd: byte 0x%02h dc=%b cs=%b at %0t",
                     received, lcd_dc, lcd_cs, $time);
            bit_count = 0;
            byte_count = byte_count + 1;
            if (byte_count == init_bytes+1+3*TEST_BYTES) begin
                $display("PASS LCD: %0d init bytes, 0x2C, 3 passes of %0d bytes", init_bytes, TEST_BYTES);
                $finish;
            end
        end
    end
end
initial begin
    $dumpfile("build/spi_lcd_vid_mem_check_TB.vcd");
    $dumpvars(0, uut);
    $readmemh(TEST_INIT_FILE, pixels);
    for (i = 0; i < `LCD_INIT_MAX; i = i+1) begin
        ref_addr = i;
        #1;
        if (!ref_data[9]) begin
            expected[init_bytes] = ref_data[8:0];
            init_bytes = init_bytes+1;
        end
    end
    repeat (3) @(posedge clk);
    #1;
    rst = 1'b0;
end
initial begin
    #(4000000 + TEST_BYTES*10000);
    $fatal(1, "LCD integration timeout");
end
endmodule
