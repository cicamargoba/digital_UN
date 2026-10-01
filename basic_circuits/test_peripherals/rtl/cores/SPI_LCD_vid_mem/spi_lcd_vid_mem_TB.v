`timescale 1ns / 1ps
`define SIMULATION
module spi_lcd_vid_mem_TB;
    reg clk;
    reg rst;
    wire lcd_rst;
    wire lcd_cs;
    wire lcd_dc;
    wire lcd_sck;
    wire lcd_sdi;
    localparam AW = 4;
    localparam NBYTES = (1 << AW);
    spi_lcd_vid_mem #(
        .CLK_DIV     (2),
        .UNIT_TICKS  (4),
        .RESET_TICKS (8),
        .VID_AW      (AW),
        .VID_INIT_FILE ("video_mem_init_TB.hex")
    ) uut(
        .clk(clk), .rst(rst),
        .lcd_rst(lcd_rst), .lcd_cs(lcd_cs), .lcd_dc(lcd_dc),
        .lcd_sck(lcd_sck), .lcd_sdi(lcd_sdi)
    );
    parameter PERIOD          = 40;
    parameter real DUTY_CYCLE = 0.5;
    parameter OFFSET          = 0;
    initial  begin
        #OFFSET;
        forever begin
            clk = 1'b0;
            #(PERIOD-(PERIOD*DUTY_CYCLE)) clk = 1'b1;
            #(PERIOD*DUTY_CYCLE);
        end
    end
    reg [7:0] rx;
    integer n;
    always @(posedge lcd_sck) begin
        if (lcd_rst == 1'b1) begin
            rx = {rx[6:0], lcd_sdi};
            n = n + 1;
            if (n == 8) begin
                $display("spi_lcd: byte 0x%02h dc=%b cs=%b at %0t",
                         rx, lcd_dc, lcd_cs, $time);
                n = 0;
            end
        end
    end
    initial begin
        #0 rst = 0;
        rx = 8'h00; n = 0;
        @ (posedge clk);
        rst = 1;
        @ (posedge clk);
        rst = 0;
        $display("spi_lcd: reset released at %0t", $time);
    end
    initial begin: TEST_CASE
        $dumpfile("spi_lcd_vid_mem_TB.vcd");
        $dumpvars(-1, uut);
        #(4000000) $finish;
    end
endmodule
