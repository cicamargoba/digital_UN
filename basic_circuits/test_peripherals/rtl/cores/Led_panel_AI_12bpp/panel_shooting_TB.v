`timescale 1ns/1ps
module panel_shooting_TB;
reg clk = 1'b0;
reg resetn = 1'b0;
wire LEDS, TXD, LP_CLK, LATCH, NOE;
wire [4:0] ROW;
wire [2:0] RGB0, RGB1;
integer cycles = 0;
integer checks = 0;
integer frames = 0;
integer shots = 0;
integer finishes = 0;
integer last_score = 0;
integer score;
integer i;
reg saw_left = 0;
reg [25:0] previous_invader = 0;
reg [25:0] previous_projectile = 0;
reg [23:0] image_before [0:2047];
wire [25:0] invader = dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[1];
wire [25:0] projectile = dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[3];
always #41.666667 clk = ~clk;

SOC dut (.clk(clk), .resetn(resetn), .LEDS(LEDS), .RXD(1'b1), .TXD(TXD),
    .interrupt_request(1'b0), .LP_CLK(LP_CLK), .LATCH(LATCH), .NOE(NOE),
    .ROW(ROW), .RGB0(RGB0), .RGB1(RGB1));

task check;
    input condition;
    begin
        checks = checks + 1;
        if (condition !== 1'b1)
            $fatal(1, "Shooting check %0d failed, cycle=%0d frame=%0d", checks, cycles, frames);
    end
endtask

initial begin
    #1;
    for (i = 0; i < 2048; i = i + 1)
        image_before[i] = {dut.led_panel0.PANEL.mem0.MEM0[i], dut.led_panel0.PANEL.mem0.MEM1[i]};
    repeat (8) @(negedge clk);
    resetn = 1;
end

always @(negedge clk) begin
    cycles = cycles + 1;
    if (resetn) begin
        if (dut.wr || dut.rd) begin
            check((^dut.mem_addr) !== 1'bx);
            if (dut.cs[0]) check(dut.mem_addr < 32'h1000);
        end
        if (projectile !== previous_projectile) begin
            if (projectile[25]) begin
                check(projectile[7:0] === 8'd31);
                check(projectile[24:16] === {4'd12, 5'd2});
                check(projectile[15:8] >= 9 && projectile[15:8] <= 53);
                if (previous_projectile[25])
                    check(projectile[15:8] == previous_projectile[15:8] - 2);
                else begin
                    check(projectile[15:8] === 8'd53);
                    shots = shots + 1;
                end
            end else if (previous_projectile[25]) begin
                check(previous_projectile[15:8] === 8'd9);
                finishes = finishes + 1;
            end
            previous_projectile = projectile;
        end
        if (invader[25] && invader !== previous_invader) begin
            check(invader[24:8] === 17'h14418);
            check(invader[7:0] <= 56);
            if (frames > 0) begin
                if (invader[7:0] < previous_invader[7:0]) begin
                    saw_left = 1;
                    check(invader[7:0] == previous_invader[7:0] - 1);
                end else
                    check(invader[7:0] == previous_invader[7:0] + 1);
            end
            previous_invader = invader;
            frames = frames + 1;
            check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[0] === 26'h3c00c0c);
            check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[2] === 26'h2c1381c);
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[0] === 15'h7d0);
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[1] === 15'h7d4);
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[2] === 15'h7d3);
            check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[3] === 15'h7a0);
            score = 0;
            for (i = 4; i < 8; i = i + 1) begin
                check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i][14:7] === 8'h0f);
                check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i][6:0] >= 48 &&
                      dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i][6:0] <= 57);
                score = score * 10 + dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i][6:0] - 48;
            end
            check(score == last_score || score == last_score + 10);
            last_score = score;
            if (frames == 116) begin
                check(saw_left && shots >= 4 && finishes >= 4 && score == 40);
                for (i = 8; i < 32; i = i + 1)
                    check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_top.MEM[i] === 15'h20);
                for (i = 0; i < 32; i = i + 1)
                    check(dut.led_panel0.PANEL.TEXT_OVERLAY.TEXT_MEMORY.txt_bot.MEM[i] === 15'h20);
                for (i = 4; i < 8; i = i + 1)
                    check(dut.led_panel0.PANEL.SPRITE_ENGINE.TABLE.MEM[i] === 26'd0);
                for (i = 0; i < 8; i = i + 1)
                    check(dut.led_panel0.PANEL.SPRITE_ENGINE.ROM.MEM[16+i] === (i < 3 ? 8'h03 : 8'h00));
                check(dut.led_panel0.PANEL.SPRITE_ENGINE.PALETTE0.MEM[12] === 12'h00f);
                for (i = 0; i < 2048; i = i + 1)
                    check({dut.led_panel0.PANEL.mem0.MEM0[i], dut.led_panel0.PANEL.mem0.MEM1[i]} === image_before[i]);
                $display("PASS: %0d checks, 116 invader frames, %0d shots, %0d completed, PTS 0040, image unchanged", checks, shots, finishes);
                $finish;
            end
        end
    end
    if (cycles > 500000) $fatal(1, "Timeout: compile PANEL_FRAME_DELAY=16 for simulation");
end
endmodule
