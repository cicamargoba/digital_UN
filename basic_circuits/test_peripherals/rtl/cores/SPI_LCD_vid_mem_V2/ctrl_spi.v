module ctrl_spi #(
    parameter CLK_DIV = 4
)(
    input      clk,
    input      rst,
    input      init_tx,
    input      done_div,
    input      end_byte,
    output reg sh,
    output reg rst_all,
    output reg inc_cbyte,
    output reg st_div,
    output reg clk_out,
    output reg done_tx
);
localparam S_IDLE  = 7'b0000001;
localparam S_LOAD  = 7'b0000010;
localparam S_LOW   = 7'b0000100;
localparam S_HIGH  = 7'b0001000;
localparam S_SHIFT = 7'b0010000;
localparam S_COUNT = 7'b0100000;
localparam S_DONE  = 7'b1000000;
reg [6:0] state = S_IDLE;
reg [6:0] next_state;
always @(negedge clk) begin
    if (rst) begin
        state <= S_IDLE;
    end else begin
        state <= next_state;
    end
end
always @(*) begin
    case (state)
        S_IDLE: begin
            if (init_tx) begin
                next_state = S_LOAD;
            end else begin
                next_state = S_IDLE;
            end
        end
        S_LOAD: begin
            next_state = S_LOW;
        end
        S_LOW: begin
            if (done_div) begin
                next_state = S_COUNT;
            end else begin
                next_state = S_LOW;
            end
        end
        S_HIGH: begin
            if (done_div) begin
                next_state = S_SHIFT;
            end else begin
                next_state = S_HIGH;
            end
        end

        S_SHIFT: begin
                next_state = S_LOW;
        end

        S_COUNT: begin
            if (end_byte) begin
                next_state = S_DONE;
            end else begin
                next_state = S_HIGH;
            end
        end

        S_DONE: begin
            next_state = S_IDLE;
        end
        default: begin
            next_state = S_IDLE;
        end
    endcase
end
always @(*) begin
    if (rst) begin
        sh        = 1'b0;
        rst_all   = 1'b0;
        inc_cbyte = 1'b0;
        st_div    = 1'b0;
        clk_out   = 1'b1;
        done_tx   = 1'b0;
    end else begin
        case (state)
            S_IDLE: begin
                sh        = 1'b0;
                rst_all   = 1'b0;
                inc_cbyte = 1'b0;
                st_div    = 1'b0;
                clk_out   = 1'b1;
                done_tx   = 1'b0;
            end
            S_LOAD: begin
                sh        = 1'b0;
                rst_all   = 1'b1;
                inc_cbyte = 1'b0;
                st_div    = 1'b0;
                clk_out   = 1'b1;
                done_tx   = 1'b0;
            end
            S_LOW: begin
                sh        = 1'b0;
                rst_all   = 1'b0;
                inc_cbyte = 1'b0;
                st_div    = 1'b1;
                clk_out   = 1'b0;
                done_tx   = 1'b0;
            end
            S_HIGH: begin
                sh        = 1'b0;
                rst_all   = 1'b0;
                inc_cbyte = 1'b0;
                st_div    = 1'b1;
                clk_out   = 1'b1;
                done_tx   = 1'b0;
            end
            S_SHIFT: begin
                sh        = 1'b1;
                rst_all   = 1'b0;
                inc_cbyte = 1'b0;
                st_div    = 1'b1;
                clk_out   = 1'b0;
                done_tx   = 1'b0;
            end
            S_COUNT: begin
                sh        = 1'b0;
                rst_all   = 1'b0;
                inc_cbyte = 1'b1;
                st_div    = 1'b1;
                clk_out   = 1'b1;
                done_tx   = 1'b0;
            end
            S_DONE: begin
                sh        = 1'b0;
                rst_all   = 1'b0;
                inc_cbyte = 1'b0;
                st_div    = 1'b0;
                clk_out   = 1'b1;
                done_tx   = 1'b1;
            end
            default: begin
                sh        = 1'b0;
                rst_all   = 1'b0;
                inc_cbyte = 1'b0;
                st_div    = 1'b0;
                clk_out   = 1'b1;
                done_tx   = 1'b0;
            end
        endcase
    end
end
endmodule
