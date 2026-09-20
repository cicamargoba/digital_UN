module lsr_led#(
    parameter init_value = 100,
    parameter width      = 10
) (clk , shift , load , s_A);
  input clk;
  input load;
  input shift;
  output reg [width:0]s_A;

always @(negedge clk)
  if(load)
     s_A <= init_value;
  else
   begin
    if(shift)
      s_A <= s_A << 1 ;
    else
      s_A <= s_A;
   end

endmodule
