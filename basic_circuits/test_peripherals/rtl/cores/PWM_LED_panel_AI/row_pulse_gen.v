// ROW pulse generator for the DP3365S / DP32xx-33xx family.
//
// DP3365S integrates its own GCLK generation (PLL) and does the PWM/BCM
// internally, so the FPGA no longer pulses NOE/GCLK with a brightness-coded
// pulse count (as FM6363 needed). Instead it drives a single ROW pin on the
// chips: its rising edge marks the start of a row, held high for
//   - W12 (12 DCLK) on row 0 of every display group
//   - W4  (4 DCLK)  on every other row
// (DP3365S_Rev1.0_EN.pdf, section 11.6 "ROW Signal Sending Way").
//
// This is unrelated to the panel's own physical ROW[4:0] scan address
// (generated elsewhere, unchanged) - same name in the vendor datasheet,
// different signal; wired here as drv_row to avoid confusion.
//
// Reuses count_l.v internally for the pulse-width timing (same
// load-N/count-down/done mechanism already used for PRE_ACT/VSYNC/WR_CFG).
module row_pulse_gen (
    input        clk,
    input        rst,
    input        row_tick,       // pulse: begin a new row's ROW signal
    input        first_of_group, // this row is row 0 of the current group
    output       drv_row,
    output       done            // one-cycle pulse when the ROW pulse ends
);

localparam W12 = 4'd12;
localparam W4  = 4'd4;

reg [3:0] start_width;
always @(*) start_width = first_of_group ? W12 : W4;

wire start_latch;
reg  start_d;
always @(posedge clk) begin
  if (rst) start_d <= 0;
  else     start_d <= row_tick;
end
assign start_latch = row_tick & ~start_d; // rising edge of row_tick

// count_l.v has no reset input (same as its existing uses for
// PRE_ACT/VSYNC/WR_CFG bursts elsewhere) - it initializes on the first
// start_latch pulse.
count_l #(.width(4)) row_pulse (
  .clk   (clk),
  .start (start_latch),
  .load  (start_width),
  .zero  (drv_row),
  .done  (done)
);

endmodule
