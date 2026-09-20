module comp_4k#(
  parameter width = 10
)(
  input [width:0]  in1,
  input [width:0]  in2,  
  output  reg       out
);

  always @(*) begin
    if(in1 == in2)
      out = 1;
    else
      out = 0;
  end

endmodule