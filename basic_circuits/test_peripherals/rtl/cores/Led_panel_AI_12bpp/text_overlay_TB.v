`timescale 1ns/1ps
module text_overlay_TB;
reg clk = 0;
reg [10:0] pix_addr = 0;
reg we = 0;
reg [5:0] waddr = 0;
reg [14:0] wdata = 0;
reg [1:0] index = 0;
wire [23:0] img;
wire [23:0] mixed;
wire [5:0] rgb;
reg [14:0] cells [0:63];
reg [7:0] font [0:1023];
reg [11:0] palette [0:15];
reg [11:0] image_top [0:2047];
reg [11:0] image_bot [0:2047];
reg [8*256-1:0] vcd_file;
integer i;
integer x;
integer y;
integer code;
integer checks = 0;
reg [14:0] new_cell;
always #5 clk = ~clk;
memory #(.size(2047), .width(10)) IMAGE (
    .clk(clk), .address(pix_addr), .rd(1'b1), .rdata(img)
);
text_overlay DUT (
    .clk(clk), .pix_addr(pix_addr), .img(img),
    .we(we), .waddr(waddr), .wdata(wdata), .data(mixed)
);
mux_led BCM (.in0(mixed), .sel(index), .out0(rgb));

function [11:0] render;
    input [14:0] cell_word;
    input [2:0] gx;
    input [2:0] gy;
    input [11:0] image_pixel;
    reg [7:0] glyph_line;
    reg bit_on;
    begin
        glyph_line = font[cell_word[6:0] * 8 + gy];
        bit_on = (glyph_line >> gx) & 1;
        if (bit_on)
            render = palette[cell_word[10:7]];
        else if (cell_word[14:11] != 0)
            render = palette[cell_word[14:11]];
        else
            render = image_pixel;
    end
endfunction

task verify;
    input [10:0] addr;
    integer cell_index;
    integer plane;
    integer color;
    reg [23:0] expected;
    reg [5:0] expected_bits;
    begin
        cell_index = (addr / 512) * 8 + ((addr % 64) / 8);
        expected[23:12] = render(cells[cell_index], addr % 8, (addr / 64) % 8, image_top[addr]);
        expected[11:0] = render(cells[cell_index + 32], addr % 8, (addr / 64) % 8, image_bot[addr]);
        if (img !== {image_top[addr], image_bot[addr]})
            $fatal(1, "Image alignment addr=%0d", addr);
        if (mixed !== expected)
            $fatal(1, "Pixel addr=%0d got=%h expected=%h", addr, mixed, expected);
        for (plane = 0; plane < 4; plane = plane + 1) begin
            index = plane;
            #1;
            for (color = 0; color < 6; color = color + 1)
                expected_bits[5-color] = expected[20 - color * 4 + plane];
            if (rgb !== expected_bits)
                $fatal(1, "BCM addr=%0d plane=%0d got=%b expected=%b", addr, plane, rgb, expected_bits);
            checks = checks + 1;
        end
    end
endtask

task pixel;
    input [10:0] addr;
    reg [23:0] previous;
    begin
        @(posedge clk);
        previous = mixed;
        pix_addr = addr;
        we = 0;
        #1;
        if (mixed !== previous)
            $fatal(1, "Output changed before falling read edge");
        @(negedge clk);
        #1;
        verify(addr);
    end
endtask

task write_cell;
    input [5:0] addr;
    input [14:0] value;
    begin
        @(posedge clk);
        we = 1;
        waddr = addr;
        wdata = value;
        @(negedge clk);
        #1;
        cells[addr] = value;
        we = 0;
    end
endtask

initial begin
    if ($value$plusargs("VCD=%s", vcd_file)) begin
        $dumpfile(vcd_file);
        $dumpvars(0, text_overlay_TB);
    end
    $readmemh("font8x8.mem", font);
    $readmemh("pal16.mem", palette);
    $readmemh("image0.hex", image_top);
    $readmemh("image1.hex", image_bot);
    for (i = 0; i < 64; i = i + 1)
        cells[i] = 15'h0020;
    if (font[520] !== 8'h0C || font[524] !== 8'h3F || palette[14] !== 12'hFF0 || palette[15] !== 12'hFFF)
        $fatal(1, "Font orientation or palette reference mismatch");
    @(negedge clk);
    #1;
    for (i = 0; i < 2048; i = i + 1)
        pixel(i);
    $display("PASS: empty text preserves complete image");

    for (i = 0; i < 64; i = i + 1) begin
        new_cell[6:0] = 32 + i;
        new_cell[10:7] = i % 16;
        case (i % 4)
            0: new_cell[14:11] = 0;
            1: new_cell[14:11] = 1;
            2: new_cell[14:11] = 8;
            3: new_cell[14:11] = 15;
        endcase
        write_cell(i, new_cell);
    end
    for (i = 2047; i >= 0; i = i - 1)
        pixel(i);
    $display("PASS: all 64 cells, both halves, fg/bg and opaque black");

    for (code = 0; code < 128; code = code + 1) begin
        new_cell = (15 << 7) | code;
        write_cell(0, new_cell);
        new_cell = (1 << 11) | (14 << 7) | (127-code);
        write_cell(32, new_cell);
        for (y = 0; y < 8; y = y + 1)
            for (x = 0; x < 8; x = x + 1)
                pixel(y * 64 + x);
    end
    $display("PASS: all 128 glyphs, all glyph pixels and four BCM planes");

    pixel(0);
    @(posedge clk);
    we = 1;
    waddr = 0;
    wdata = 15'h4020;
    @(negedge clk);
    #1;
    verify(0);
    cells[0] = wdata;
    we = 0;
    pixel(0);
    @(posedge clk);
    we = 1;
    waddr = 32;
    wdata = 15'h07C1;
    @(negedge clk);
    #1;
    verify(0);
    cells[32] = wdata;
    we = 0;
    pixel(0);
    $display("PASS: same-address write reads old cell, new cell on next read");
    $display("PASS: %0d BCM comparisons", checks);
    $finish;
end
initial begin
    #1000000;
    $fatal(1, "Timeout");
end
endmodule
