// Display/scan sequencer for the DP3365S / DP32xx-33xx family.
// Replaces show_data.v + ctrl_show.v: those counted GCLK=NOE pulses to pace
// BCM brightness externally. DP3365S does its own PWM internally (see
// reg_wr_dp3365.v), so this module only has to:
//   1. advance the panel's physical row address ROW[4:0] (unchanged role,
//      drives the panel's external row decoder, NOT the DP3365S chips), and
//   2. drive DRV_ROW toward the DP3365S chips via row_pulse_gen (W12 on
//      row 0, W4 otherwise - "General Frame Synchronization Mode", 11.7.1).
//
// ROW_PERIOD is a placeholder: how long (in clk cycles) each row is held
// before advancing. TODO - tune against the actual reg0x04/reg0x05/reg0x06
// row-display-time formula (11.8.6) once real hardware timing is measured;
// it must be long enough for load_data_dp3365.v to finish shifting the next
// row's pixel data.
module show_data_dp3365 #(
    parameter NUM_ROWS   = 32,   // physical scan rows (panel geometry, same
                                  // assumption as today's 1:32-scan design)
    parameter ROW_PERIOD = 400   // clk cycles per row - TODO tune
)(
    input        clk,
    input        rst,
    input        init,
    input        vs_done,        // pulse: new frame of pixel data is ready
    output [4:0] outc,           // physical row address (unchanged role)
    output       drv_row         // to DP3365S chips' ROW pin
);

reg        vs_pend;
reg  [4:0] row_cnt;
reg [15:0] period_cnt;
reg        row_tick;
wire       first_of_group = (row_cnt == 0);

localparam W_IDLE = 2'b00;
localparam W_SCAN = 2'b01;
reg [1:0] state;

assign outc = row_cnt;

always @(posedge clk) begin
  if (rst) begin
    state      <= W_IDLE;
    vs_pend    <= 0;
    row_cnt    <= 0;
    period_cnt <= 0;
    row_tick   <= 0;
  end
  else begin
    row_tick <= 0;
    if (vs_done)
      vs_pend <= 1;

    case (state)
      W_IDLE: begin
        row_cnt    <= 0;
        period_cnt <= 0;
        if (init && vs_pend) begin
          vs_pend  <= 0;
          row_tick <= 1;      // kick off row 0 (W12)
          state    <= W_SCAN;
        end
      end

      W_SCAN: begin
        if (period_cnt == ROW_PERIOD-1) begin
          period_cnt <= 0;
          if (row_cnt == NUM_ROWS-1) begin
            row_cnt <= 0;
            state   <= W_IDLE;   // full scan done; wait for next VSYNC
          end
          else begin
            row_cnt  <= row_cnt + 1;
            row_tick <= 1;
          end
        end
        else
          period_cnt <= period_cnt + 1;
      end

      default: state <= W_IDLE;
    endcase
  end
end

row_pulse_gen rowpulse0 (
  .clk            (clk),
  .rst            (rst),
  .row_tick       (row_tick),
  .first_of_group (first_of_group),
  .drv_row        (drv_row),
  .done           ()
);

endmodule
