module lsr_div (clk , rst, DV_in, IN_A, INIT, SH, LDA, A, DV0, OUT_R);  
  input clk;
  input rst;
  input [15:0] DV_in;
  input [15:0] IN_A;
  input INIT;
  input SH;
  input LDA;
  input DV0;
  output reg [15:0] A;
  output reg [15:0] OUT_R;


reg [15:0] DV;

always @(negedge clk)
  if(INIT ) begin
	  A     = 0;
	  DV    = DV_in;
    OUT_R = 0;
  end
  else begin
	  if(SH) begin
		  {A,DV} = ({A,DV}<<1);
      OUT_R  = DV; 
	  end
	  else begin
	  	if(LDA) begin
			  A     = IN_A;
        DV[0] = 1;
      end 
 	 	  else begin
			  A  = A;
        DV = DV;
      end
	  end
  end
endmodule
