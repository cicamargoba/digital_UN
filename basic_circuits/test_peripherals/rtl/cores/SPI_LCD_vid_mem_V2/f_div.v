module f_div #(
    parameter CLK_DIV = 4
)(
    input      clk,
    input      rst,
    input      start,
    output reg done_div
);
localparam CW = (CLK_DIV > 1) ? $clog2(CLK_DIV) : 1;
reg [CW-1:0] count;
always @(posedge clk) begin
    if (rst) begin
        count <= {CW{1'b0}};
        done_div <= 1'b0;
    end else if (!start) begin
        count <= {CW{1'b0}};
        done_div <= 1'b0;
    end else if (count == CLK_DIV-1) begin
        count <= {CW{1'b0}};
        done_div <= 1'b1;
    end else begin
        count <= count + 1'b1;
        done_div <= 1'b0;
    end
end
endmodule
