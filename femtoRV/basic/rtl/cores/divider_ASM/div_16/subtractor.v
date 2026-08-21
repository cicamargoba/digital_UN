module subtractor (in_A , in_B , MSB , Result);
  input [15:0] in_A;
  input [15:0] in_B;  
  output reg MSB;
  output reg [15:0] Result;

always @(*) begin
  Result = in_A + (~in_B)+1;
  MSB    = Result[15];
end

endmodule
