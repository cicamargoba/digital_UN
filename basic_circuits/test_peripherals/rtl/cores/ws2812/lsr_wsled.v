module lsr_wsled (clk , in_A , shift , load , s_A);
  input             clk;
  input [23:0]      in_A;
  input             load;
  input             shift;
  output reg [23:0] s_A;

always @(posedge clk)
  if(load)
    s_A = in_A ;
  else begin
    if(shift)
      s_A = s_A << 1 ;
    else
      s_A = s_A;
  end

endmodule
