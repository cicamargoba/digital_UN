module count_wsled #(
    parameter value = 24
) (
    input      clk,
    input      ld,
    input      dec,
    output reg z
);

reg [4:0] counter;

always @(posedge clk) begin
   if(ld)
        counter <= value;
    else begin
        if (dec)
            counter <= counter - 1;
    end
end

always @(*) begin
    if (counter == 0)
        z <= 1;
    else
        z <= 0;
end

endmodule
