`timescale 1ns / 1ps
`define SIMULATION
module video_mem_TB;
    localparam AW = 4;
    reg clk = 1'b0;
    reg  [AW-1:0] addr;
    wire [7:0] data;
    video_mem #(
        .AW        (AW),
        .INIT_FILE ("video_mem_init_TB.hex")
    ) uut(
        .clk(clk), .addr(addr), .data(data)
    );
    always #5 clk = ~clk;
    integer i;
    integer errors;
    initial begin
        #0 errors = 0;
        for (i = 0; i < (1 << AW); i = i + 1) begin
            @(negedge clk);
            addr = i[AW-1:0];
            #1;
            if (i > 0 && data !== ((8'h10 + i - 1) & 8'hFF)) begin
                $fatal(1, "video_mem changed before the rising clock edge");
            end
            @(posedge clk);
            #1;
            if (data !== ((8'h10 + i) & 8'hFF)) begin
                $display("FAIL video_mem: addr %0d data=0x%02h expected 0x%02h",
                         i, data, (8'h10 + i) & 8'hFF);
                errors = errors + 1;
            end
        end
        if (errors == 0)
            $display("PASS video_mem: %0d entries read back from init file", (1 << AW));
        else
            $fatal(1, "FAIL video_mem: %0d errors", errors);
        $finish;
    end
endmodule
