module spi_tx #(
    parameter CLK_DIV = 4
)(
    input            clk,
    input            rst,
    input            init_tx,
    input      [8:0] data,
    output reg       dc,
    output reg       sck,
    output reg       sdi,
    output reg       done_tx
);
localparam S_IDLE = 2'd0;
localparam S_RUN  = 2'd1;
localparam S_DONE = 2'd2;
reg [1:0]  state;
reg [7:0]  shreg;
reg [2:0]  bit_cnt;
reg [15:0] div_cnt;
always @(posedge clk) begin
    if (rst) begin
        state   <= S_IDLE;
        sck     <= 1'b1;
        sdi     <= 1'b0;
        dc      <= 1'b0;
        done_tx <= 1'b0;
        shreg   <= 8'h00;
        bit_cnt <= 3'd0;
        div_cnt <= 16'd0;
    end else begin
        done_tx <= 1'b0;
        case (state)
            S_IDLE: begin
                sck <= 1'b1;
                if (init_tx) begin
                    dc      <= data[8];
                    shreg   <= data[7:0];
                    bit_cnt <= 3'd0;
                    div_cnt <= 16'd0;
                    state   <= S_RUN;
                end
            end
            S_RUN: begin
                if (div_cnt == CLK_DIV-1) begin
                    div_cnt <= 16'd0;
                    sck     <= ~sck;
                    if (sck) begin
                        sdi   <= shreg[7];
                        shreg <= {shreg[6:0], 1'b0};
                    end else begin
                        if (bit_cnt == 3'd7) begin
                            state <= S_DONE;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end else begin
                    div_cnt <= div_cnt + 1;
                end
            end
            S_DONE: begin
                sck     <= 1'b1;
                done_tx <= 1'b1;
                state   <= S_IDLE;
            end
            default: state <= S_IDLE;
        endcase
    end
end
endmodule
