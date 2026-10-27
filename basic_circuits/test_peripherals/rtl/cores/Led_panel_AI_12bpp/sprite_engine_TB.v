`timescale 1ns/1ps
module sprite_engine_TB;
reg clk = 0;
reg rst = 1;
reg [10:0] pix_addr = 0;
reg we = 0;
reg [2:0] waddr = 0;
reg [25:0] wdata = 0;
reg col_clear = 0;
wire [23:0] spr;
wire on0;
wire on1;
wire [7:0] col;
reg [23:0] img = 24'h123456;
reg [23:0] txt = 24'hABCDEF;
reg txt_on0 = 0;
reg txt_on1 = 0;
wire [23:0] mixed;
reg [25:0] model [0:7];
reg [7:0] patterns [0:255];
reg [11:0] palette [0:15];
reg [7:0] expected_col = 0;
reg [8*256-1:0] vcd_file;
integer checks = 0;
integer i;
integer j;
integer p;
integer a;
integer n;
integer positions [0:5];
always #5 clk = ~clk;
sprite_engine DUT (
    .clk(clk), .rst(rst), .pix_addr(pix_addr), .we(we),
    .waddr(waddr), .wdata(wdata), .col_clear(col_clear),
    .spr(spr), .spr_on0(on0), .spr_on1(on1), .col(col)
);
text_mix MIX (
    .img(img), .txt(txt), .txt_on0(txt_on0), .txt_on1(txt_on1),
    .spr(spr), .spr_on0(on0), .spr_on1(on1), .data(mixed)
);

function [25:0] descriptor;
    input integer x;
    input integer y;
    input integer pattern;
    input integer color;
    input integer enabled;
    begin
        descriptor = {enabled[0], color[3:0], pattern[4:0], y[7:0], x[7:0]};
    end
endfunction

task reference_half;
    input integer x;
    input integer y;
    output reg [7:0] hits;
    output reg active;
    output reg [11:0] rgb;
    integer k;
    integer sx;
    integer sy;
    integer dx;
    integer dy;
    integer selected_pat;
    integer selected_dx;
    integer selected_dy;
    integer selected_color;
    reg [7:0] line;
    begin
        hits = 0;
        selected_pat = 0;
        selected_dx = 0;
        selected_dy = 0;
        selected_color = 0;
        for (k = 0; k < 8; k = k + 1) begin
            sx = model[k][7:0];
            sy = model[k][15:8];
            if (sx >= 128) sx = sx - 256;
            if (sy >= 128) sy = sy - 256;
            dx = x - sx;
            dy = y - sy;
            if (model[k][25] && dx >= 0 && dx < 8 && dy >= 0 && dy < 8) begin
                hits[k] = 1;
                selected_pat = selected_pat | model[k][20:16];
                selected_dx = selected_dx | dx;
                selected_dy = selected_dy | dy;
                selected_color = selected_color | model[k][24:21];
            end
        end
        line = patterns[selected_pat*8 + selected_dy];
        active = (hits != 0) && ((line >> selected_dx) & 1);
        rgb = palette[selected_color];
    end
endtask

task tick;
    reg [7:0] h0;
    reg [7:0] h1;
    reg [7:0] events;
    reg e0;
    reg e1;
    reg [11:0] c0;
    reg [11:0] c1;
    reg [23:0] expected_mix;
    begin
        reference_half(pix_addr % 64, pix_addr / 64, h0, e0, c0);
        reference_half(pix_addr % 64, pix_addr / 64 + 32, h1, e1, c1);
        events = 0;
        if ((h0 & (h0-1)) != 0) events = events | h0;
        if ((h1 & (h1-1)) != 0) events = events | h1;
        if (rst) begin
            expected_col = 0;
            e0 = 0;
            e1 = 0;
            c0 = palette[0];
            c1 = palette[0];
        end else if (col_clear)
            expected_col = events;
        else
            expected_col = expected_col | events;
        @(negedge clk);
        #1;
        if ({on0,on1} !== {e0,e1} || spr !== {c0,c1})
            $fatal(1,"Pixel %0d got on=%b%b rgb=%h expected on=%b%b rgb=%h",pix_addr,on0,on1,spr,e0,e1,{c0,c1});
        if (col !== expected_col)
            $fatal(1,"Collision got=%h expected=%h",col,expected_col);
        expected_mix[23:12] = e0 ? c0 : txt_on0 ? txt[23:12] : img[23:12];
        expected_mix[11:0] = e1 ? c1 : txt_on1 ? txt[11:0] : img[11:0];
        if (mixed !== expected_mix)
            $fatal(1,"Layer priority got=%h expected=%h",mixed,expected_mix);
        if (rst) begin
            for (n = 0; n < 8; n = n + 1) model[n] = 0;
        end else if (we)
            model[waddr] = wdata;
        checks = checks + 1;
    end
endtask

task pixel;
    input [10:0] addr;
    reg [25:0] previous;
    begin
        @(posedge clk);
        previous = {on0,on1,spr};
        pix_addr = addr;
        #1;
        if ({on0,on1,spr} !== previous)
            $fatal(1,"Output changed before registered read edge");
        tick;
    end
endtask

task write_sprite;
    input [2:0] slot;
    input [25:0] value;
    begin
        @(posedge clk);
        we = 1;
        waddr = slot;
        wdata = value;
        tick;
        we = 0;
    end
endtask

task reset_engine;
    begin
        @(posedge clk);
        rst = 1;
        tick;
        rst = 0;
    end
endtask

initial begin
    if ($value$plusargs("VCD=%s",vcd_file)) begin
        $dumpfile(vcd_file);
        $dumpvars(0,sprite_engine_TB);
    end
    $readmemh("sprites.mem",patterns);
    $readmemh("pal16.mem",palette);
    for (i = 0; i < 256; i = i + 1)
        if ((^patterns[i]) === 1'bx)
            $fatal(1,"Uninitialized pattern byte %0d",i);
    for (i = 0; i < 8; i = i + 1) model[i] = 0;
    positions[0] = -8;
    positions[1] = -3;
    positions[2] = 0;
    positions[3] = 28;
    positions[4] = 60;
    positions[5] = 63;
    tick;
    rst = 0;
    for (a = 0; a < 2048; a = a + 1) pixel(a);
    $display("PASS: reset disables all sprites and preserves image");
    for (p = 0; p < 32; p = p + 1) begin
        write_sprite(0,descriptor(11,28,p,p%16,1));
        for (j = 0; j < 32; j = j + 1)
            for (i = 8; i < 22; i = i + 1) begin
                txt_on0 = (i%2);
                txt_on1 = ((i/2)%2);
                pixel(j*64+i);
            end
    end
    $display("PASS: 32 patterns, 16 colors, half boundary, transparency and layers");
    for (i = 0; i < 8; i = i + 1)
        write_sprite(i,descriptor(i*8,(i%4)*16,5+i%3,i+1,1));
    for (a = 0; a < 2048; a = a + 1) pixel(a);
    $display("PASS: all eight table entries and both ROM ports");
    reset_engine;
    write_sprite(0,descriptor(5,7,5,1,1));
    write_sprite(1,descriptor(5,39,7,2,1));
    pixel(7*64+5);
    if (!on0 || !on1) $fatal(1,"Both ROM ports must render simultaneously");
    for (j = 7; j < 15; j = j + 1)
        for (i = 5; i < 13; i = i + 1)
            pixel(j*64+i);
    $display("PASS: simultaneous different patterns on both halves");
    reset_engine;
    for (p = 0; p < 6; p = p + 1) begin
        write_sprite(0,descriptor(positions[p],positions[p],7,12,1));
        for (a = 0; a < 2048; a = a + 1) pixel(a);
    end
    $display("PASS: signed clipping at negative and right/bottom boundaries");
    write_sprite(0,descriptor(0,0,4,0,1));
    txt_on0 = 1;
    txt_on1 = 1;
    pixel(0);
    if (!on0 || mixed[23:12] !== 12'h000)
        $fatal(1,"Black sprite must be opaque");
    write_sprite(0,descriptor(0,0,4,15,0));
    pixel(0);
    if (on0) $fatal(1,"Disabled descriptor rendered");
    $display("PASS: color zero opaque, disable and old-data write semantics");
    reset_engine;
    write_sprite(0,descriptor(0,0,1,1,1));
    write_sprite(1,descriptor(1,1,2,2,1));
    pixel(65);
    if (col !== 8'h03) $fatal(1,"Top overlap missing");
    pixel(2047);
    if (col !== 8'h03) $fatal(1,"Collision not sticky");
    col_clear = 1;
    pixel(2047);
    if (col !== 0) $fatal(1,"Clear failed");
    pixel(65);
    if (col !== 8'h03) $fatal(1,"New collision must win over clear");
    col_clear = 0;
    write_sprite(2,descriptor(0,32,8,4,1));
    write_sprite(7,descriptor(1,33,8,8,1));
    pixel(65);
    if (col !== 8'h87) $fatal(1,"Both halves must accumulate in common register");
    if (on1) $fatal(1,"Empty pattern must be transparent despite box collision");
    $display("PASS: AND-OR overlap, bounding-box collisions, sticky/clear and both halves");
    reset_engine;
    pixel(0);
    if (col !== 0 || on0 || on1) $fatal(1,"Final reset failed");
    $display("PASS: %0d sprite/mixer checks",checks);
    $finish;
end
initial begin
    #2000000;
    $fatal(1,"Timeout");
end
endmodule
