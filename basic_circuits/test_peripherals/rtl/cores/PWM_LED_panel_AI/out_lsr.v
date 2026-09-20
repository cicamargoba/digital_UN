// 16-bit parallel-load serial shifter, MSB (bit 15) first.
// load: parallel load; shift: start shifting.
// clk_en: high while DCLK must be generated (exactly 16 clk edges per word).
// done: one-cycle pulse when the word has been fully shifted.
module out_lsr(clk , shift , in_val, load , s_out, done, clk_en, bit_cnt);
  input         clk;
  input [15:0]  in_val;
  input         load;
  input         shift;
  output wire   s_out;
  output reg    done;
  output reg    clk_en;
  output wire [4:0] bit_cnt;

parameter START    = 3'b000;
parameter DONE     = 3'b001;
parameter COUNT    = 3'b010;

reg [15:0] outc;
reg  [4:0] bits;
reg [2:0] state;

// MSB first
assign s_out = outc[15];
// bit index of the bit currently on s_out (15 first ... 0 last).
// During COUNT, s_out holds bit (15 - bits).
assign bit_cnt = (state == COUNT) ? (5'd15 - bits) : 5'd15;

always @(posedge clk) begin
  if(load) begin
    state <= START;
    outc  <= in_val;
    bits  <= 0;
    done  <= 0;
  end
  else begin
    case(state)
      START: begin
        done <= 0;
        if(shift) begin
          state  <= COUNT;
          clk_en <= 1;
        end
      end

      COUNT: begin
        outc <= {outc[14:0], 1'b0};
        if (bits == 15) begin
          state  <= DONE;
          bits   <= 0;
          clk_en <= 0;   // 16 edges: START->COUNT entry + 15 COUNT cycles
        end
        else begin
          bits <= bits + 1;
        end
      end

      DONE: begin
        done  <= 1;
        state <= START;
      end

      default: state <= START;
    endcase
  end
end

endmodule
