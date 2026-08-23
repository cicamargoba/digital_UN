module count_addr (
    input            clk,
    input            rst,
    input            inc,
    output reg [7:0] address

);
    always @(negedge clk ) begin
        if (rst)
            address <= 0;
        else begin
            if (inc)
                address <= address +1;
            else
                address <= address;
        end
    end
endmodule
