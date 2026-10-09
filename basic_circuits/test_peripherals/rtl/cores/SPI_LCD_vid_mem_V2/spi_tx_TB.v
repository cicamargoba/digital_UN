`timescale 1ns/1ps
module spi_tx_check #(
    parameter DIV = 4
)(
    output reg finished = 1'b0
);
reg clk = 1'b0;
reg rst = 1'b1;
reg init_tx = 1'b0;
reg [8:0] data = 9'd0;
wire dc;
wire sck;
wire sdi;
wire done_tx;
reg active = 1'b0;
reg [8:0] expected;
reg [7:0] received;
integer rising_edges;
integer falling_edges;
integer shift_steps;
integer count_steps;
integer i;
time last_edge;
time done_start;
spi_tx #(.CLK_DIV(DIV)) uut (
    .clk(clk),
    .rst(rst),
    .init_tx(init_tx),
    .data(data),
    .dc(dc),
    .sck(sck),
    .sdi(sdi),
    .done_tx(done_tx)
);
always #5 clk = ~clk;
always @(posedge clk) begin
    if (active && !rst) begin
        if (uut.sh) begin
            shift_steps = shift_steps + 1;
            if (uut.CRTL_SPI.state !== uut.CRTL_SPI.S_SHIFT) begin
                $fatal(1, "DIV=%0d SH outside S_SHIFT", DIV);
            end
        end
        if (uut.inc_cbyte) begin
            count_steps = count_steps + 1;
            if (uut.CRTL_SPI.state !== uut.CRTL_SPI.S_COUNT) begin
                $fatal(1, "DIV=%0d INC_CBYTE outside S_COUNT", DIV);
            end
        end
    end
end
always @(negedge sck) begin
    if (active && !rst) begin
        if (falling_edges != 0 && $time-last_edge != ((DIV == 1) ? 20 : DIV*10)) begin
            $fatal(1, "DIV=%0d high duration=%0t", DIV, $time-last_edge);
        end
        falling_edges = falling_edges + 1;
        last_edge = $time;
    end
end
always @(posedge sck) begin
    if (active && !rst) begin
        if ($time-last_edge != ((DIV == 1 && falling_edges > 1) ? 20 : DIV*10)) begin
            $fatal(1, "DIV=%0d low duration=%0t", DIV, $time-last_edge);
        end
        received = {received[6:0], sdi};
        rising_edges = rising_edges + 1;
        last_edge = $time;
        if (dc !== expected[8]) begin
            $fatal(1, "DIV=%0d DC mismatch", DIV);
        end
        if (rising_edges > 8 || falling_edges > 8) begin
            $fatal(1, "DIV=%0d extra SPI edge", DIV);
        end
    end
end
task send_byte;
    input [8:0] value;
    begin
        @(posedge clk);
        #1;
        expected = value;
        received = 8'd0;
        rising_edges = 0;
        falling_edges = 0;
        shift_steps = 0;
        count_steps = 0;
        active = 1'b1;
        data = value;
        init_tx = 1'b1;
        @(posedge clk);
        #1;
        init_tx = 1'b0;
        data = {value[8], ~value[7:0]};
        @(negedge sck);
        @(posedge clk);
        #1;
        init_tx = 1'b1;
        @(posedge clk);
        #1;
        init_tx = 1'b0;
        @(posedge done_tx);
        done_start = $time;
        #1;
        if (received !== value[7:0] || rising_edges != 8 || falling_edges != 8) begin
            $fatal(1, "DIV=%0d expected=%h received=%h edges=%0d/%0d",
                   DIV, value, received, falling_edges, rising_edges);
        end
        if (shift_steps != 7 || count_steps != 8) begin
            $fatal(1, "DIV=%0d shift/count steps=%0d/%0d", DIV, shift_steps, count_steps);
        end
        if (sck !== 1'b1) begin
            $fatal(1, "DIV=%0d SCK not idle at completion", DIV);
        end
        active = 1'b0;
        @(negedge done_tx);
        if ($time-done_start != 10) begin
            $fatal(1, "DIV=%0d DONE_TX width=%0t", DIV, $time-done_start);
        end
        repeat (3) @(posedge clk);
        #1;
        if (sck !== 1'b1 || done_tx !== 1'b0) begin
            $fatal(1, "DIV=%0d idle mismatch", DIV);
        end
    end
endtask
task abort_byte;
    input high_phase;
    begin
        @(posedge clk);
        #1;
        data = 9'h1a5;
        init_tx = 1'b1;
        @(posedge clk);
        #1;
        init_tx = 1'b0;
        @(negedge sck);
        if (high_phase) begin
            @(posedge sck);
        end
        #1;
        rst = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        if (sck !== 1'b1 || done_tx !== 1'b0 || dc !== data[8] || sdi !== 1'b0) begin
            $fatal(1, "DIV=%0d reset failed", DIV);
        end
        rst = 1'b0;
        repeat (20*DIV) begin
            @(posedge clk);
            #1;
            if (done_tx !== 1'b0 || sck !== 1'b1) begin
                $fatal(1, "DIV=%0d aborted transfer continued", DIV);
            end
        end
    end
endtask
initial begin
    repeat (3) @(posedge clk);
    #1;
    rst = 1'b0;
    for (i = 0; i < 256; i = i+1) begin
        send_byte({i[0], i[7:0]});
    end
    abort_byte(1'b0);
    send_byte(9'h15a);
    abort_byte(1'b1);
    send_byte(9'h0a5);
    $display("PASS spi_tx CLK_DIV=%0d: 256 bytes, DC, busy, timing, reset", DIV);
    finished = 1'b1;
end
endmodule

module spi_tx_TB;
wire [3:0] finished;
spi_tx_check #(.DIV(1)) CHECK_1(finished[0]);
spi_tx_check #(.DIV(2)) CHECK_2(finished[1]);
spi_tx_check #(.DIV(4)) CHECK_4(finished[2]);
spi_tx_check #(.DIV(7)) CHECK_7(finished[3]);
initial begin
    $dumpfile("build/spi_tx_TB.vcd");
    $dumpvars(0, spi_tx_TB);
    wait (&finished);
    $display("PASS spi_tx_TB");
    $finish;
end
initial begin
    #1000000;
    $fatal(1, "SPI test timeout");
end
endmodule
