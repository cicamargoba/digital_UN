module count_ws (
    input             clk,
    input             rst,
    input             inc,
    output reg [10:0] cnt_out
);

always @(negedge clk ) begin
    if(rst)
      cnt_out <= 0;
    else if (inc)
      cnt_out <= cnt_out + 1;
    else
      cnt_out <= cnt_out;
end

endmodule
