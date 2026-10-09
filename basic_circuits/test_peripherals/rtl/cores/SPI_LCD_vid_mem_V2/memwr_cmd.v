module memwr_cmd (
    output [8:0] cmd
);
assign cmd = {1'b0, 8'h2C};
endmodule
