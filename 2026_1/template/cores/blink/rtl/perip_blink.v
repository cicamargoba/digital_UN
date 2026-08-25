`timescale 1ns/1ps

module perip_blink (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] d_in,
    input  wire        cs,
    input  wire [3:0]  addr,
    input  wire        rd,
    input  wire        wr,
    output reg  [31:0] d_out,
    output reg         led
);

    localparam ADDR_CONTROL = 4'h0;
    localparam ADDR_PERIOD  = 4'h4;

    reg        enable;
    reg [31:0] period;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            enable  <= 1'b0;
            period  <= 32'd1;
            counter <= 32'd0;
            led     <= 1'b0;
        end else begin
            if (cs && wr) begin
                case (addr)
                    ADDR_CONTROL: enable <= d_in[0];
                    ADDR_PERIOD:  period <= d_in;
                    default: ;
                endcase
            end

            if (!enable) begin
                counter <= 32'd0;
                led     <= 1'b0;
            end else if ((period <= 32'd1) || (counter >= period - 1'b1)) begin
                counter <= 32'd0;
                led     <= ~led;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

    always @(*) begin
        d_out = 32'd0;
        if (cs && rd) begin
            case (addr)
                ADDR_CONTROL: d_out = {31'd0, enable};
                ADDR_PERIOD:  d_out = period;
                default:      d_out = 32'd0;
            endcase
        end
    end

endmodule
