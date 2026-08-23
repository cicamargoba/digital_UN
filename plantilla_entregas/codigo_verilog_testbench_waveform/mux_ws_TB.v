`timescale 1ns / 1ps
`define SIMULATION

module mux_ws_TB;

 reg [10:0] in1;
 reg [10:0] in2;
 reg [10:0] in3;
 reg [10:0] in4;
 reg [1:0]  sel;

    mux_ws uut( .in1(in1), .in2(in2), .in3(in3), .in4(in4), .sel(sel) );

    initial  begin
        #0 in1 = 20; in2 = 30; in3 = 60; in4 =1000;
        sel = 0;
        # 40;
        sel = 1;
        # 40;
        sel = 2;
        # 40;
        sel = 3;
        # 40;
    end

    initial begin: TEST_CASE
        $dumpfile("mux_ws_TB.vcd");
        $dumpvars(-1, uut);
        #(100000) $finish;
    end

endmodule
