module d_count #(
    parameter UNIT_TICKS = 25000
)(
    input            clk,
    input            rst,
    input            s_delay,
    input      [7:0] delay_val,
    output reg       done_delay
);
reg [7:0]  val_cnt;
reg [31:0] unit_cnt;
reg        delay;
always @(posedge clk) begin
    if (rst) begin
        val_cnt    <= 0;
        unit_cnt   <= 0;
        done_delay <= 0;
    end else begin
        done_delay <= 0;
        if (s_delay) begin
            if (delay_val == 0) begin
                done_delay <= 1;
            end else begin
                val_cnt  <= delay_val;
                unit_cnt <= 0;
                delay    <= 1;
            end
        end else if (delay) begin
            if (unit_cnt == UNIT_TICKS-1) begin
                unit_cnt <= 0;
                if (val_cnt == 1) begin
                    delay      <= 0;
                    done_delay <= 1;
                end else begin
                    val_cnt <= val_cnt - 1;
                end
            end else begin
                unit_cnt <= unit_cnt + 1;
            end
        end
    end
end
endmodule
