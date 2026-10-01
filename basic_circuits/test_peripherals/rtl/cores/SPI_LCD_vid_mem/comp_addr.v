module comp_addr #(
    parameter W = 8
)(
    input  [W-1:0] in1,
    input  [W-1:0] in2,
    output         z
);
assign z = (in1 == in2);
endmodule
