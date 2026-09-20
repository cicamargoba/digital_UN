module lsr_config #(
    parameter width   = 95,
    parameter config0 = 16'h0008,
    parameter config1 = 16'h1f70,
    parameter config2 = 16'h6707,
    parameter config3 = 16'h40f7,
    parameter config4 = 16'h0040
) (clk , shift , load , s_A);
  input  clk;
  input  load;
  input  shift;
  output  [15:0] s_A;

reg [width:0] config_reg;


assign s_A = config_reg[15:0];

always @(negedge clk)
  if(load)
     config_reg <= {16'h0000, config4, config3, config2, config1, config0};
  else
   begin
    if(shift)
      config_reg[width:0] <= {config_reg[15:0],config_reg[width:16]}; // Circular register
   end

endmodule
