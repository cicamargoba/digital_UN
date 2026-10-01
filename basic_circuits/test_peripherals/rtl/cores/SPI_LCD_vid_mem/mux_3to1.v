module mux_3to1 (
    input      [8:0] in0,
    input      [8:0] in1,
    input      [8:0] in2,
    input      [1:0] sel,
    output reg [8:0] out
);
always @(*) begin
    case (sel)
        2'd0:    out = in0;
        2'd1:    out = in1;
        2'd2:    out = in2;
        default: out = 9'h000;
    endcase
end
endmodule
