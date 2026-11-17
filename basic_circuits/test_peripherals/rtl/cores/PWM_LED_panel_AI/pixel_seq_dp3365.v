// Pixel data sequencer for the DP3365S / DP32xx-33xx family.
// Replaces load_data.v's P_LOAD/P_SHIFT bit-plane FSM: instead of 4 passes
// of a single replicated bit per chip (manual BCM), DP3365S takes one
// grayscale word per (line, channel) via DATA_LATCH and does the PWM/BCM
// internally (reg_wr_dp3365.v configured the grayscale depth/timing).
//
// Data order (DP3365S_Rev1.0_EN.pdf, 11.2): for each line, channels 15..0,
// and for each (line,channel) one 16-bit word is shifted into EVERY chained
// chip's position before a single DATA_LATCH (LE=1) commits all of them at
// once - exactly the same per-chip shifting pattern reg_wr_dp3365.v uses for
// WR_CFG, just with per-chip DIFFERENT data instead of a broadcast word.
//
// SIMPLIFICATION (matches the current FM6363 code's own fidelity): one
// memory word already gives one brightness value per chip (not per
// individual LED - see load_data.v's `{16{pix_bit[x]}}` channel replication
// pattern). This module keeps that same per-chip granularity: it reads one
// word from memory per (row,chip), expands each 4-bit nibble to a
// GRAY_WIDTH-bit value, and resends that same per-chip value for all 16
// channel slots of that row (the protocol still needs 16 separate
// DATA_LATCH pulses per row - only the VALUE repeats). Replacing this with
// true per-LED addressing is a follow-up, not part of this skeleton.
//
// Control outputs (st_lat/ld_pix/sh_pix) are combinational functions of
// `pstate` - same convention as ctrl_cfg.v / reg_wr_dp3365.v - so they drop
// the instant a WAIT state is entered, avoiding a stale-pulse race against
// count_l.v / out_lsr.v returning to idle.
module pixel_seq_dp3365 #(
    parameter NUM_ROWS    = 32,   // reuses memory.v's existing row addressing
    parameter NUM_DRVS    = 7,    // chips in the chain - 1
    parameter GRAY_WIDTH  = 16    // bits per channel sent on DATA_LATCH
)(
    input              clk,
    input              rst,
    input              send_data,
    output  reg        done_data,

    // memory port (shared with the rest of the design)
    output  reg [10:0] mem_addr,
    output  reg        mem_rd,
    input       [23:0] mem_rdata,

    // LE-width burst generator (external count_l.v, width=4) - DATA_LATCH=1
    output             st_lat,
    output       [3:0] latches,
    input              done_latch,

    // shared shift-control for the 6 out_lsr.v lanes (R0 G0 B0 R1 G1 B1)
    output             ld_pix,
    output             sh_pix,
    input              done_out,
    output  [GRAY_WIDTH-1:0] word_R0, word_G0, word_B0,
    output  [GRAY_WIDTH-1:0] word_R1, word_G1, word_B1
);

// Expand a 4-bit source nibble to GRAY_WIDTH bits by replication, e.g. for
// GRAY_WIDTH=16: {4{nibble}} spreads 16 levels evenly across the full range
// (0, 0x1111, 0x2222, ... 0xFFFF) instead of wasting the low end with zeros.
function [GRAY_WIDTH-1:0] expand4;
  input [3:0] nibble;
  integer i;
  begin
    for (i = 0; i < GRAY_WIDTH; i = i + 4)
      expand4[i +: 4] = nibble;
  end
endfunction

reg [3:0] chip_cnt;    // 0..NUM_DRVS, current chip position in the chain
reg [3:0] chan_cnt;    // 0..15, current channel slot (protocol bookkeeping)
reg [5:0] row_cnt;     // 0..NUM_ROWS-1

reg [23:0] row_word [0:15];   // small per-row cache: one 24-bit word/chip
                               // (supports up to 16 chained chips)

wire [23:0] cur_cached = row_word[chip_cnt];
wire [GRAY_WIDTH-1:0] cur_R0 = expand4(cur_cached[23:20]);
wire [GRAY_WIDTH-1:0] cur_G0 = expand4(cur_cached[19:16]);
wire [GRAY_WIDTH-1:0] cur_B0 = expand4(cur_cached[15:12]);
wire [GRAY_WIDTH-1:0] cur_R1 = expand4(cur_cached[11:8]);
wire [GRAY_WIDTH-1:0] cur_G1 = expand4(cur_cached[7:4]);
wire [GRAY_WIDTH-1:0] cur_B1 = expand4(cur_cached[3:0]);
assign word_R0 = cur_R0; assign word_G0 = cur_G0; assign word_B0 = cur_B0;
assign word_R1 = cur_R1; assign word_G1 = cur_G1; assign word_B1 = cur_B1;

localparam P_START    = 3'b000;
localparam P_FETCH    = 3'b001;   // cache this row's NUM_DRVS+1 mem words
localparam P_LOAD     = 3'b010;
localparam P_SHIFT    = 3'b011;
localparam P_LATCH    = 3'b100;
localparam P_NEXT     = 3'b101;
localparam P_DONE     = 3'b110;

reg [2:0] pstate;
reg [3:0] fetch_cnt;

always @(posedge clk) begin
  if (rst) begin
    pstate    <= P_START;
    row_cnt   <= 0;
    chip_cnt  <= 0;
    chan_cnt  <= 0;
    fetch_cnt <= 0;
    done_data <= 0;
    mem_rd    <= 0;
    mem_addr  <= 0;
  end
  else begin
    mem_rd <= 0;   // default

    case (pstate)
      P_START: begin
        done_data <= 0;
        row_cnt   <= 0;
        chan_cnt  <= 0;
        fetch_cnt <= 0;
        if (send_data) begin
          mem_addr <= 0;
          mem_rd   <= 1;
          pstate   <= P_FETCH;
        end
      end

      // cache NUM_DRVS+1 words for this row, one memory read per chip
      P_FETCH: begin
        if (fetch_cnt != 0)                       // rdata valid one cycle late
          row_word[fetch_cnt-1] <= mem_rdata;
        if (fetch_cnt == NUM_DRVS+1) begin
          fetch_cnt <= 0;
          chip_cnt  <= 0;
          pstate    <= P_LOAD;
        end
        else begin
          mem_addr  <= mem_addr + 1;
          mem_rd    <= 1;
          fetch_cnt <= fetch_cnt + 1;
        end
      end

      P_LOAD: pstate <= P_SHIFT;   // cur_R0..cur_B1 combinational from cache

      P_SHIFT: begin
        if (done_out) begin
          if (chip_cnt == NUM_DRVS) begin
            chip_cnt <= 0;
            pstate   <= P_LATCH;
          end
          else begin
            chip_cnt <= chip_cnt + 1;
            pstate   <= P_LOAD;
          end
        end
      end

      P_LATCH: begin                 // DATA_LATCH: LE=1 for one word-set
        if (done_latch) begin
          if (chan_cnt == 15) begin
            chan_cnt <= 0;
            pstate   <= P_NEXT;
          end
          else begin
            chan_cnt <= chan_cnt + 1;
            pstate   <= P_LOAD;       // same cached row_word[], next channel
          end
        end
      end

      P_NEXT: begin
        if (row_cnt == NUM_ROWS-1) begin
          row_cnt <= 0;
          pstate  <= P_DONE;
        end
        else begin
          row_cnt   <= row_cnt + 1;
          mem_addr  <= mem_addr + 1;
          mem_rd    <= 1;
          fetch_cnt <= 1;             // mem_addr already points at word 0
          pstate    <= P_FETCH;
        end
      end

      P_DONE: begin
        done_data <= 1;
        pstate    <= P_START;
      end

      default: pstate <= P_START;
    endcase
  end
end

assign ld_pix  = (pstate == P_LOAD);
assign sh_pix  = (pstate == P_SHIFT);
assign st_lat  = (pstate == P_LATCH);
assign latches = 4'd1;   // DATA_LATCH is always LE=1

endmodule
