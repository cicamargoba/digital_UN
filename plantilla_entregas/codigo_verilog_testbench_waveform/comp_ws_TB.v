`timescale 1ns / 1ps
`define SIMULATION

module comp_ws_TB;

 reg [10:0] in1;
 reg [10:0] in2;


    comp_ws uut( .in1(in1), .in2(in2) );

    initial  begin
        #0 in1 = 20; in2 = 30;

        # 40 in1 = 30; in2 = 30;
        # 40 in1 = 50; in2 = 30;
        # 40 in1 = 20; in2 = 20;
        # 40 in1 = 29; in2 = 30;
    end

    initial begin: TEST_CASE
        $dumpfile("comp_ws_TB.vcd");
        $dumpvars(-1, uut);
        #(100000) $finish;
    end

endmodule
