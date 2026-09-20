module memory#(
    parameter size = 2047,
    parameter width = 11
)(
  input             clk,
  input  [width:0]     address,
  input             rd,
  output reg [23:0]  rdata
);

reg [23:0] MEM [0:size];
initial begin
    $readmemh("./image.hex",MEM);
end

  always @(negedge clk) begin
    if(rd) begin
        rdata <= MEM[address];     //{RGB0,RGB1}
    end
  end

endmodule
