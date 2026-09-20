module count#(
    parameter width = 5,
    parameter limit  = 27
)(
    input   clk,
    input   reset,
    input   inc,
    output  reg [width:0] outc,
    output  zero
);

always @(negedge clk) begin
  if(reset)
    outc <= 0;
  else begin
    if(inc) begin
      if (outc == limit)
        outc <= 0;
      else
         outc <= outc + 1;
    end
  end
end
assign zero = (outc == 0 ) ? 1 : 0;
endmodule
