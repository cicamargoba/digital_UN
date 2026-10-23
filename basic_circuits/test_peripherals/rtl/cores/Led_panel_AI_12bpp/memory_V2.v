module memory#(
    parameter size = 2047,
    parameter width = 11
)(
  input             clk,
  input  [width:0]     address,
  input             rd,
  output reg [23:0]  rdata
);

reg [11:0] MEM0 [0:size];
reg [11:0] MEM1 [0:size];

initial begin
    $readmemh("./image0.hex",MEM0);
    $readmemh("./image1.hex",MEM1);
end

  always @(negedge clk) begin
    if(rd) begin
        rdata[23:12] <= MEM0[address];     //{RGB0,RGB1}
    end
  end
  always @(negedge clk) begin
    if(rd) begin
        rdata[11:0] <= MEM1[address];     //{RGB0,RGB1}
    end
  end
endmodule
