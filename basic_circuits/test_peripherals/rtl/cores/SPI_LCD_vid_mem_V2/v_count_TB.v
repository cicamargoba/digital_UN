`timescale 1ns / 1ps
`define SIMULATION
module v_count_TB;
    localparam AW = 4;
    reg clk;
    reg rst;
    reg inc;
    wire [AW-1:0] addr;
    v_count #(.AW(AW)) uut(
        .clk(clk), .rst(rst), .inc(inc), .addr(addr)
    );
    parameter PERIOD          = 40;
    parameter real DUTY_CYCLE = 0.5;
    initial begin
        forever begin
            clk = 1'b0;
            #(PERIOD-(PERIOD*DUTY_CYCLE)) clk = 1'b1;
            #(PERIOD*DUTY_CYCLE);
        end
    end
    integer i;
    integer errors;
    initial begin
        #0 rst = 1; inc = 0; errors = 0;
        repeat (3) @ (posedge clk);
        @ (negedge clk);
        rst = 0;
        if (addr !== {AW{1'b0}}) begin
            $display("FAIL v_count: after rst addr=%h expected 0", addr);
            errors = errors + 1;
        end
        for (i = 1; i <= 20; i = i + 1) begin
            @ (negedge clk);
            inc = 1;
            @ (negedge clk);
            inc = 0;
            if (addr !== (i % (1 << AW))) begin
                $display("FAIL v_count: step %0d addr=%0d expected %0d", i, addr, i % (1 << AW));
                errors = errors + 1;
            end
        end
        if (errors == 0)
            $display("PASS v_count: increment and natural wrap verified");
        else
            $display("FAIL v_count: %0d errors", errors);
        $finish;
    end
    initial begin: TEST_CASE
        $dumpfile("v_count_TB.vcd");
        $dumpvars(-1, uut);
        #(20000) $finish;
    end
endmodule
