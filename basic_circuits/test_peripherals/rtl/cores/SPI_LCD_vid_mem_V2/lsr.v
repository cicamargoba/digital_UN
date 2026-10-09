module lsr (
    input       clk,
    input       rst,
    input       ld,
    input       sh,
    input [7:0] data_tx,
    output      sdi
);
reg [7:0] data_reg;
always @(posedge clk) begin
    if (rst) begin
        data_reg <= 8'h00;
    end else if (ld) begin
        data_reg <= data_tx;
    end else if (sh) begin
        data_reg <= {data_reg[6:0], 1'b0};
    end
end
assign sdi = data_reg[7];
endmodule
