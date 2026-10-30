`timescale 1ns/1ps
module perip_led_panel_TB;
reg clk = 1'b0;
reg reset = 1'b1;
reg [31:0] d_in = 32'd0;
reg cs = 1'b0;
reg [4:0] addr = 5'd0;
reg rd = 1'b0;
reg wr = 1'b0;
wire [31:0] d_out;
wire LP_CLK;
wire LATCH;
wire NOE;
wire [4:0] ROW;
wire [2:0] RGB0;
wire [2:0] RGB1;
reg [23:0] image_before [0:2047];
reg [14:0] expected_text [0:63];
reg [25:0] expected_sprite [0:7];
integer i;
integer checks = 0;
integer dump_index;
reg [2:0] phase = 3'd0;
wire [14:0] text_cell_top;
wire [14:0] text_cell_bot;
wire [25:0] sprite_descriptor;

assign text_cell_top = dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[dut.text_addr[4:0]];
assign text_cell_bot = dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[dut.text_addr[4:0]];
assign sprite_descriptor = dut.PANEL.SPRITE_ENGINE.TABLE.MEM[dut.sprite_addr];

always #5 clk = ~clk;

peripheral_led_panel dut (
    .clk(clk), .reset(reset), .d_in(d_in), .cs(cs), .addr(addr),
    .rd(rd), .wr(wr), .d_out(d_out), .LP_CLK(LP_CLK),
    .LATCH(LATCH), .NOE(NOE), .ROW(ROW), .RGB0(RGB0), .RGB1(RGB1)
);

task check;
    input condition;
    input [511:0] message;
    begin
        checks = checks + 1;
        if (condition !== 1'b1)
            $fatal(1, "%0s", message);
    end
endtask

task write_reg;
    input [4:0] offset;
    input [31:0] value;
    begin
        @(negedge clk);
        cs = 1'b1;
        wr = 1'b1;
        addr = offset;
        d_in = value;
        @(negedge clk);
        cs = 1'b0;
        wr = 1'b0;
    end
endtask

task read_reg;
    input [4:0] offset;
    input [31:0] expected;
    begin
        @(negedge clk);
        cs = 1'b1;
        rd = 1'b1;
        addr = offset;
        #1;
        check(d_out === expected, "CSR readback mismatch");
        @(negedge clk);
        cs = 1'b0;
        rd = 1'b0;
        #1;
        check(d_out === 32'd0, "d_out must be zero when deselected");
    end
endtask

task hold_write;
    begin
        repeat (12) @(negedge clk);
    end
endtask

initial begin
    $dumpfile("build/peripheral/perip_led_panel_TB.vcd");
    $dumpvars(1, perip_led_panel_TB);
    $dumpvars(1, dut);
    $dumpvars(1, dut.PANEL);
    $dumpvars(1, dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top);
    $dumpvars(1, dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot);
    $dumpvars(1, dut.PANEL.SPRITE_ENGINE.TABLE);
    for (dump_index = 0; dump_index < 32; dump_index = dump_index + 1) begin
        $dumpvars(0, dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[dump_index]);
        $dumpvars(0, dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[dump_index]);
    end
    for (dump_index = 0; dump_index < 8; dump_index = dump_index + 1)
        $dumpvars(0, dut.PANEL.SPRITE_ENGINE.TABLE.MEM[dump_index]);
    repeat (4) @(negedge clk);
    check(dut.text_addr === 6'd0, "TEXT_ADDR reset");
    check(dut.text_data === 15'd0, "TEXT_DATA reset");
    check(dut.sprite_addr === 3'd0, "SPRITE_ADDR reset");
    check(dut.sprite_data === 26'd0, "SPRITE_DATA reset");
    check(dut.text_we === 1'b0, "TEXT_WE reset");
    check(dut.sprite_we === 1'b0, "SPRITE_WE reset");
    reset = 1'b0;
    hold_write;
    for (i = 0; i < 2048; i = i + 1) begin
        image_before[i] = {dut.PANEL.mem0.MEM0[i], dut.PANEL.mem0.MEM1[i]};
        check((^image_before[i]) !== 1'bx, "Uninitialized image word");
    end
    for (i = 0; i < 32; i = i + 1) begin
        expected_text[i] = dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i];
        expected_text[i+32] = dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[i];
    end
    for (i = 0; i < 8; i = i + 1)
        check(dut.PANEL.SPRITE_ENGINE.TABLE.MEM[i] === 26'd0, "Demo must be disabled in CPU mode");

    phase = 3'd1;
    write_reg(5'h04, 32'hffffffff);
    write_reg(5'h08, 32'hffffffff);
    write_reg(5'h0c, 32'hffffffff);
    write_reg(5'h10, 32'hffffffff);
    read_reg(5'h04, 32'd63);
    read_reg(5'h08, 32'h7fff);
    read_reg(5'h0c, 32'd7);
    read_reg(5'h10, 32'h3ffffff);
    read_reg(5'h14, 32'd0);
    read_reg(5'h18, 32'd0);
    hold_write;
    check(dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[31] === expected_text[63], "TEXT_WE=0 must inhibit writes");
    check(dut.PANEL.SPRITE_ENGINE.TABLE.MEM[7] === 26'd0, "SPRITE_WE=0 must inhibit writes");

    @(negedge clk);
    addr = 5'h04;
    d_in = 32'd0;
    wr = 1'b1;
    @(negedge clk);
    wr = 1'b0;
    read_reg(5'h04, 32'd63);
    @(negedge clk);
    cs = 1'b1;
    addr = 5'h04;
    d_in = 32'd0;
    @(negedge clk);
    cs = 1'b0;
    read_reg(5'h04, 32'd63);
    write_reg(5'h05, 32'd0);
    write_reg(5'h1c, 32'd0);
    read_reg(5'h04, 32'd63);
    read_reg(5'h05, 32'd0);
    read_reg(5'h1c, 32'd0);

    phase = 3'd2;
    for (i = 0; i < 64; i = i + 1) begin
        expected_text[i] = {i[3:0], ~i[3:0], 1'b1, i[5:0]};
        write_reg(5'h04, i);
        write_reg(5'h08, {17'd0, expected_text[i]});
        write_reg(5'h14, 32'd1);
        hold_write;
        check(dut.text_we === 1'b1, "TEXT_WE must remain asserted");
        write_reg(5'h14, 32'd0);
        hold_write;
    end
    for (i = 0; i < 32; i = i + 1) begin
        check(dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i] === expected_text[i], "Top text RAM mismatch");
        check(dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[i] === expected_text[i+32], "Bottom text RAM mismatch");
    end
    phase = 3'd3;
    for (i = 0; i < 8; i = i + 1) begin
        expected_sprite[i] = {1'b1, 1'b0, i[2:0], 2'b00, i[2:0], 2'b00, i[2:0], 3'b000, 2'b00, i[2:0], 3'b000};
        write_reg(5'h0c, i);
        write_reg(5'h10, {6'd0, expected_sprite[i]});
        write_reg(5'h18, 32'd1);
        hold_write;
        check(dut.sprite_we === 1'b1, "SPRITE_WE must remain asserted");
        write_reg(5'h18, 32'd0);
        hold_write;
    end
    for (i = 0; i < 8; i = i + 1)
        check(dut.PANEL.SPRITE_ENGINE.TABLE.MEM[i] === expected_sprite[i], "Sprite descriptor mismatch");
    phase = 3'd4;
    write_reg(5'h08, 32'd0);
    write_reg(5'h10, 32'd0);
    hold_write;
    check(dut.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[31] === expected_text[63], "Text changed with WE disabled");
    check(dut.PANEL.SPRITE_ENGINE.TABLE.MEM[7] === expected_sprite[7], "Sprite changed with WE disabled");
    write_reg(5'h14, 32'hfffffffe);
    write_reg(5'h18, 32'hfffffffe);
    read_reg(5'h14, 32'd0);
    read_reg(5'h18, 32'd0);
    for (i = 0; i < 2048; i = i + 1)
        check({dut.PANEL.mem0.MEM0[i], dut.PANEL.mem0.MEM1[i]} === image_before[i], "Image changed during CPU writes");
    phase = 3'd5;
    write_reg(5'h14, 32'd1);
    write_reg(5'h18, 32'd1);
    @(negedge clk);
    reset = 1'b1;
    repeat (4) @(negedge clk);
    check(dut.text_we === 1'b0, "Warm reset TEXT_WE");
    check(dut.sprite_we === 1'b0, "Warm reset SPRITE_WE");
    check(dut.text_data === 15'd0, "Warm reset TEXT_DATA");
    check(dut.sprite_data === 26'd0, "Warm reset SPRITE_DATA");
    check(dut.text_addr === 6'd0, "Warm reset TEXT_ADDR");
    check(dut.sprite_addr === 3'd0, "Warm reset SPRITE_ADDR");
    $display("PASS: %0d checks", checks);
    $finish;
end

initial begin
    #1000000;
    $fatal(1, "Timeout");
end
endmodule
