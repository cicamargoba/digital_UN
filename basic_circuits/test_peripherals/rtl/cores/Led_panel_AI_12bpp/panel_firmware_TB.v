`timescale 1ns/1ps
module panel_firmware_TB;
reg clk = 1'b0;
reg resetn = 1'b0;
wire LEDS, TXD, LP_CLK, LATCH, NOE;
wire [4:0] ROW;
wire [2:0] RGB0, RGB1;
integer cycles = 0;
integer updates = 0;
integer checks = 0;
integer i;
integer target_updates;
reg [25:0] previous_sprite = 26'd0;
reg saw_left = 1'b0;
reg [23:0] image_before [0:2047];
localparam [63:0] INVADER_ROWS = 64'hA55A24FFDB7E3C18;
always #41.666667 clk = ~clk;

SOC dut (
    .clk(clk), .resetn(resetn), .LEDS(LEDS), .RXD(1'b1), .TXD(TXD),
    .interrupt_request(1'b0), .LP_CLK(LP_CLK), .LATCH(LATCH), .NOE(NOE),
    .ROW(ROW), .RGB0(RGB0), .RGB1(RGB1)
);

task check;
    input condition;
    begin
        checks = checks + 1;
        if (condition !== 1'b1)
            $fatal(1, "Firmware check %0d failed at cycle %0d", checks, cycles);
    end
endtask

initial begin
    if (!$value$plusargs("UPDATES=%d", target_updates))
        target_updates = 115;
    #1;
    for (i = 0; i < 2048; i = i + 1)
        image_before[i] = {dut.led_panel0.PANEL.mem0.MEM0[i], dut.led_panel0.PANEL.mem0.MEM1[i]};
    repeat (8) @(negedge clk);
    resetn = 1'b1;
end

always @(negedge clk) begin
    cycles = cycles + 1;
    if (resetn) begin
        if (dut.wr || dut.rd) begin
            check((^dut.mem_addr) !== 1'bx);
            if (dut.cs[0])
                check(dut.mem_addr < 32'h1000);
        end
        if (dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0][25] &&
            dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0] !== previous_sprite) begin
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[10] === 15'h7c8);
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[11] === 15'h7cf);
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[12] === 15'h7cc);
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[13] === 15'h7c1);
            check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0][24:8] === 17'h1c028);
            check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0][7:0] <= 8'd56);
            check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[1] === 26'h344181c);
            check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[2] === 26'h2c1381c);
            if (updates > 0) begin
                if (dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0][7:0] < previous_sprite[7:0]) begin
                    saw_left = 1'b1;
                    check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0][7:0] == previous_sprite[7:0] - 1);
                end else
                    check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0][7:0] == previous_sprite[7:0] + 1);
            end
            previous_sprite = dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0];
            updates = updates + 1;
            if (updates == target_updates) begin
                if (target_updates >= 58)
                    check(saw_left);
                for (i = 0; i < 32; i = i + 1) begin
                    if (i < 10 || i > 13)
                        check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i] === 15'h20);
                    check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[i] === 15'h20);
                end
                for (i = 3; i < 8; i = i + 1)
                    check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[i] === 26'd0);
                for (i = 0; i < 8; i = i + 1)
                    check(dut.led_panel0.PANEL.SPRITE_ENGINE.ROM.MEM[32+i] === INVADER_ROWS[i*8 +: 8]);
                check(dut.led_panel0.PANEL.sprite_col === 8'd0);
                for (i = 0; i < 2048; i = i + 1)
                    check({dut.led_panel0.PANEL.mem0.MEM0[i], dut.led_panel0.PANEL.mem0.MEM1[i]} === image_before[i]);
                $display("PASS: %0d checks, HOLA, invader, cannon, %0d ship positions, left_seen=%0d, image unchanged", checks, updates, saw_left);
                $finish;
            end
        end
    end
    if (cycles > 150000)
        $fatal(1, "Timeout; use PANEL_FRAME_DELAY=16 for this simulation");
end
endmodule
