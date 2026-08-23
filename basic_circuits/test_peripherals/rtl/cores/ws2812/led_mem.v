module led_mem#(
    parameter addr_lenght = 8
) (
   input             clk,
   input      [addr_lenght -1 :0]  address,
   output reg [23:0] data_r
);
    reg [23:0] MEM [0: (2**(addr_lenght) - 1)];
    initial begin
        $readmemh("./display.hex",MEM);
    end

    always @(negedge clk) begin
        data_r <= MEM[address];
    end

endmodule
