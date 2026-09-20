// Latch-burst generator.
// On 'start', loads 'load' (N). Then produces exactly N clk edges with
// clk_en high, followed by 1 clk edge with clk_en low (idle), then done.
// N edges with LE high = command value N (PRE_ACT=14, EN_OP=12, VSYNC=3,
// DATA_LATCH=1, WR_CFGx=2/4/6/8/10).
module count_l#(
    parameter width = 5
    )(
    input   clk,
    input   start,
    input   [width:0] load,
    output  reg zero,      // clk enable for the DCLK gate
    output  reg done
);

parameter IDLE     = 3'b000;
parameter COUNT    = 3'b001;
parameter IDLE_CLK = 3'b010;
parameter DONE     = 3'b011;

reg [width:0] outc;
reg [2:0] state;

always @(posedge clk) begin
  case(state)
    IDLE: begin
      done <= 0;
      zero <= 0;
      if(start) begin
        outc  <= load;
        zero  <= 1;
        state <= COUNT;
      end
    end

    COUNT: begin
      outc <= outc - 1;
      if(outc == 1) begin
        zero  <= 0;        // trailing idle clock edge
        state <= IDLE_CLK;
      end
    end

    IDLE_CLK: begin
      state <= DONE;
    end

    DONE: begin
      done  <= 1;
      state <= IDLE;
    end

    default: state <= IDLE;
  endcase
end

endmodule
