module ctrl #(
    parameter RESET_TICKS = 250000
)(
    input            clk,
    input            restart,
    input            last_addr,
    input            st_delay,
    input            src_valid,
    input            done_tx,
    input            done_delay,
    output reg       rst,
    output reg       init_tx,
    output reg [1:0] sel_data,
    output reg       inc_addr,
    output reg       rst_all,
    output reg       s_delay,
    output reg       src_rdy,
    output reg       inc_v_addr
);
localparam S_RESET  = 4'd0;
localparam S_READ   = 4'd1;
localparam S_DECODE = 4'd2;
localparam S_CMD    = 4'd3;
localparam S_WTX    = 4'd4;
localparam S_DL     = 4'd5;
localparam S_WDL    = 4'd6;
localparam S_INC    = 4'd7;
localparam S_MEMWR  = 4'd8;
localparam S_WTX2   = 4'd9;
localparam S_STREAM = 4'd10;
localparam S_CMD3   = 4'd11;
localparam S_WTX3   = 4'd12;
localparam S_RDY    = 4'd13;
reg [3:0]  state;
reg [31:0] rst_cnt;
`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
    case(state)
        S_RESET  : state_name = "S_RESET";
        S_READ   : state_name = "S_READ";
        S_DECODE : state_name = "S_DECODE";
        S_CMD    : state_name = "S_CMD";
        S_WTX    : state_name = "S_WTX";
        S_DL     : state_name = "S_DL";
        S_WDL    : state_name = "S_WDL";
        S_INC    : state_name = "S_INC";
        S_MEMWR  : state_name = "S_MEMWR";
        S_WTX2   : state_name = "S_WTX2";
        S_STREAM : state_name = "S_STREAM";
        S_CMD3   : state_name = "S_CMD3";
        S_WTX3   : state_name = "S_WTX3";
        S_RDY    : state_name = "S_RDY";
        default  : state_name = "?";
    endcase
end
`endif
always @(negedge clk) begin
    if (restart) begin
        state   <= S_RESET;
        rst_cnt <= 32'd0;
    end else begin
        case (state)
            S_RESET: begin
                if (rst_cnt == RESET_TICKS-1) begin
                    state <= S_READ;
                end else begin
                    rst_cnt <= rst_cnt + 1;
                end
            end
            S_READ: begin
                state <= S_DECODE;
            end
            S_DECODE: begin
                if (st_delay) begin
                    state <= S_DL;
                end else begin
                    state <= S_CMD;
                end
            end
            S_CMD: begin
                state <= S_WTX;
            end
            S_WTX: begin
                if (done_tx) begin
                    if (last_addr) begin
                        state <= S_MEMWR;
                    end else begin
                        state <= S_INC;
                    end
                end
            end
            S_DL: begin
                state <= S_WDL;
            end
            S_WDL: begin
                if (done_delay) begin
                    if (last_addr) begin
                        state <= S_MEMWR;
                    end else begin
                        state <= S_INC;
                    end
                end
            end
            S_INC: begin
                state <= S_READ;
            end
            S_MEMWR: begin
                state <= S_WTX2;
            end
            S_WTX2: begin
                if (done_tx) begin
                    state <= S_STREAM;
                end
            end
            S_STREAM: begin
                if (src_valid) begin
                    state <= S_CMD3;
                end
            end
            S_CMD3: begin
                state <= S_WTX3;
            end
            S_WTX3: begin
                if (done_tx) begin
                    state <= S_RDY;
                end
            end
            S_RDY: begin
                state <= S_STREAM;
            end
            default: begin
                state <= S_RESET;
            end
        endcase
    end
end
always @(*) begin
    case (state)
        S_RESET: begin
            rst        = 1'b0;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b1;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_READ: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_DECODE: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_CMD: begin
            rst        = 1'b1;
            init_tx    = 1'b1;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_WTX: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_DL: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b1;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_WDL: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_INC: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b1;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_MEMWR: begin
            rst        = 1'b1;
            init_tx    = 1'b1;
            sel_data   = 2'd1;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_WTX2: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd1;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_STREAM: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd2;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_CMD3: begin
            rst        = 1'b1;
            init_tx    = 1'b1;
            sel_data   = 2'd2;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_WTX3: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd2;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
        S_RDY: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd2;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b1;
            inc_v_addr = 1'b1;
        end
        default: begin
            rst        = 1'b1;
            init_tx    = 1'b0;
            sel_data   = 2'd0;
            inc_addr   = 1'b0;
            rst_all    = 1'b0;
            s_delay    = 1'b0;
            src_rdy    = 1'b0;
            inc_v_addr = 1'b0;
        end
    endcase
end
endmodule
