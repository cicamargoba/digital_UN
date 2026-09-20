module count#(
    parameter width = 5
)(
    input   clk,
    input   reset,
    input   inc,
    output  reg [width:0] outc,
    output  zero
);

always @(negedge clk) begin
  if(~reset)
    outc <= 0;
  else if(inc)
    outc <= outc + 1;
end
assign zero = (outc == 0) ? 1 : 0;
endmodule
