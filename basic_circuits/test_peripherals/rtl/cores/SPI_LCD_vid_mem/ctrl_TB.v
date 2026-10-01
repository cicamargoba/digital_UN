`timescale 1ns / 1ps
`define SIMULATION
module ctrl_TB;
 reg clk;
 reg restart;
 reg [7:0] addr_cur;
 reg done_delay;
 wire st_delay;
 wire last_addr;
 reg src_last;
 reg src_valid;
 reg done_tx;
 wire rst;
 wire init_tx;
 wire [1:0] sel_data;
 wire inc_addr;
 wire rst_all;
 wire s_delay;
 wire src_rdy;
    ctrl #(.RESET_TICKS(8)) uut(
        .clk(clk), .restart(restart), .last_addr(last_addr),
        .done_delay(done_delay), .st_delay(st_delay),
        .src_last(src_last), .src_valid(src_valid), .done_tx(done_tx),
        .rst(rst), .init_tx(init_tx), .sel_data(sel_data),
        .inc_addr(inc_addr), .rst_all(rst_all), .s_delay(s_delay),
        .src_rdy(src_rdy)
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
    always @(posedge clk) begin
        if (rst_all)
            addr_cur <= 8'd0;
        else if (inc_addr)
            addr_cur <= addr_cur + 1;
    end
    assign st_delay = (addr_cur == 8'd1);
    assign last_addr = (addr_cur == 8'd2);
    reg [2:0] tx_cnt;
    reg [2:0] dl_cnt;
    always @(posedge clk) begin
        if (init_tx)
            tx_cnt <= 3'd3;
        else if (tx_cnt != 3'd0)
            tx_cnt <= tx_cnt - 3'd1;
    end
    always @(posedge clk) begin
        done_tx <= (tx_cnt == 3'd1);
    end
    always @(posedge clk) begin
        if (s_delay)
            dl_cnt <= 3'd4;
        else if (dl_cnt != 3'd0)
            dl_cnt <= dl_cnt - 3'd1;
    end
    always @(posedge clk) begin
        done_delay <= (dl_cnt == 3'd1);
    end
    always @(posedge init_tx)
        $display("ctrl: init_tx sel=%0d addr=%0d at %0t", sel_data, addr_cur, $time);
    always @(posedge s_delay)
        $display("ctrl: s_delay addr=%0d at %0t", addr_cur, $time);
    always @(posedge src_rdy)
        $display("ctrl: src_rdy (stream byte) at %0t", $time);
    integer bytes;
    initial begin
        #0 restart = 0; src_last = 0; src_valid = 0;
        @ (posedge clk);
        restart = 1;
        @ (posedge clk);
        restart = 0;
        @ (posedge init_tx); begin end
        @ (posedge init_tx); begin end
        @ (posedge init_tx); begin end
        $display("ctrl: init + memwr done at %0t, entering stream", $time);
        src_valid = 1;
        src_last  = 0;
        for (bytes = 0; bytes < 4; bytes = bytes + 1) begin
            @ (posedge src_rdy);
        end
        $display("ctrl: 4 stream bytes sent, loop keeps running at %0t", $time);
        #400;
        $display("ctrl: TB done");
    end
    initial begin: TEST_CASE
        $dumpfile("ctrl_TB.vcd");
        $dumpvars(-1, uut);
        #(20000) $finish;
    end
endmodule
