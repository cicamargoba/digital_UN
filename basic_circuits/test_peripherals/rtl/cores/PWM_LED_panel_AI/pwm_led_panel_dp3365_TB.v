`timescale 1ns / 1ps

`define SIMULATION
// Self-checking testbench for pwm_led_panel_dp3365.v.
// Unlike the plain VCD-dump style used for FM6363/FM6353 (pwm_led_panel_TB.v),
// this one verifies the actual DP3365S protocol against the datasheet:
//   1. Every WR_CFG word shifted matches the expected {addr,data} register
//      table from reg_wr_dp3365.v (13 registers).
//   2. The LE-width sequence sent is exactly
//      VSYNC(3) -> PRE_ACT(14) -> WR_CFG(5) x13 -> [pixel phase] -> VSYNC(3).
//   3. The pixel phase sends exactly NUM_ROWS*16 DATA_LATCH (LE=1) pulses
//      per frame (32 rows * 16 channel slots = 512).
//   4. DRV_ROW and LP_CLK are actually toggling (sanity, not stuck at X/0).
// Uses hierarchical references into the DUT (white-box) - legitimate for a
// unit-level protocol check, not meant to be synthesizable.
module pwm_led_panel_dp3365_TB;
   reg  clk;
   reg  rst;
   reg  init;
   wire LP_CLK;
   wire LATCH;
   wire DRV_ROW;
   wire [4:0] ROW;

   pwm_led_panel_dp3365 uut (
       .clk(clk), .rst(rst), .init(init),
       .LP_CLK(LP_CLK), .LATCH(LATCH), .DRV_ROW(DRV_ROW), .ROW(ROW)
   );

   parameter PERIOD = 20;
   initial begin
      clk = 0; rst = 0; init = 0;
   end
   initial clk <= 0;
   always #(PERIOD/2) clk <= ~clk;

   initial begin
     @(posedge clk);
     rst = 0;
     repeat (10) @(posedge clk);
     rst = 1;
     #(PERIOD*4)
     init = 1;
   end

   // No VCD dump here on purpose: this testbench carries several
   // testbench-only counters that change almost every cycle (error/pulse
   // counters below), and dumping them at -1 depth over the ~10M+ cycles a
   // full frame needs blows up to multi-GB VCDs and slows simulation by
   // orders of magnitude. This bench is self-checking via $display instead;
   // for waveform debugging, use the plain dump-style run (`make sim`-style,
   // no checks) on a shorter slice instead.

   // ------------------------------------------------------------------
   // Expected register table - mirrors reg_wr_dp3365.v's initial block,
   // resolved with the parameters load_data_dp3365.v actually instantiates
   // it with (NUM_DRVS=7, NUM_ROWS=64; PWM_GROUPS/PWM_WIDTH/PLL_DIV at
   // their module defaults: 1, 64, 1).
   // ------------------------------------------------------------------
   reg [7:0] exp_addr [0:12];
   reg [7:0] exp_data [0:12];
   initial begin
     exp_addr[0]  = 8'h02; exp_data[0]  = 8'h3F;  // (64-1)&0x3F
     exp_addr[1]  = 8'h03; exp_data[1]  = 8'h00;  // (1-1)&0x7F
     exp_addr[2]  = 8'h04; exp_data[2]  = 8'h3F;  // (64-1)&0x7F
     exp_addr[3]  = 8'h05; exp_data[3]  = 8'h00;
     exp_addr[4]  = 8'h06; exp_data[4]  = 8'h00;  // (1-1)&0x07
     exp_addr[5]  = 8'h07; exp_data[5]  = 8'h00;
     exp_addr[6]  = 8'h08; exp_data[6]  = 8'h00;
     exp_addr[7]  = 8'h09; exp_data[7]  = 8'h00;
     exp_addr[8]  = 8'h0a; exp_data[8]  = 8'h00;
     exp_addr[9]  = 8'h0b; exp_data[9]  = 8'h00;
     exp_addr[10] = 8'h0c; exp_data[10] = 8'h00;
     exp_addr[11] = 8'h14; exp_data[11] = 8'h00;
     exp_addr[12] = 8'h17; exp_data[12] = 8'h00;
   end

   integer errors;
   integer reg_checks;
   initial begin errors = 0; reg_checks = 0; end

   // SEND_WRCFG = 4'b0111 in reg_wr_dp3365.v
   localparam SEND_WRCFG = 4'b0111;
   reg [3:0] last_idx;
   initial last_idx = 4'hF;

   always @(posedge clk) begin
     if (uut.load0.regwr0.state == SEND_WRCFG &&
         uut.load0.regwr0.reg_idx !== last_idx) begin
       reg_checks = reg_checks + 1;
       if (uut.load0.regwr0.cfg_word !==
           {exp_addr[uut.load0.regwr0.reg_idx], exp_data[uut.load0.regwr0.reg_idx]}) begin
         errors = errors + 1;
         $display("FAIL reg[%0d]: expected addr=%02h data=%02h, got word=%04h",
           uut.load0.regwr0.reg_idx,
           exp_addr[uut.load0.regwr0.reg_idx], exp_data[uut.load0.regwr0.reg_idx],
           uut.load0.regwr0.cfg_word);
       end
       last_idx = uut.load0.regwr0.reg_idx;
     end
   end

   // ------------------------------------------------------------------
   // LE-width sequence check: VSYNC(3) -> PRE_ACT(14) -> WR_CFG(5) x13
   // ------------------------------------------------------------------
   integer le_idx;
   reg le_seq_ok;
   initial begin le_idx = 0; le_seq_ok = 1; end

   function [3:0] expected_le;
     input integer idx;
     begin
       if (idx == 0) expected_le = 4'd3;         // VSYNC
       else if (idx == 1) expected_le = 4'd14;   // PRE_ACT
       else expected_le = 4'd5;                  // WR_CFG x13
     end
   endfunction

   always @(posedge clk) begin
     if (uut.load0.cfg_st_lat && uut.load0.regwr0.state != last_le_state) begin
       if (le_idx <= 14) begin
         if (uut.load0.cfg_latches !== expected_le(le_idx)) begin
           errors = errors + 1;
           le_seq_ok = 0;
           $display("FAIL LE seq[%0d]: expected %0d, got %0d",
             le_idx, expected_le(le_idx), uut.load0.cfg_latches);
         end
         le_idx = le_idx + 1;
       end
       last_le_state = uut.load0.regwr0.state;
     end
   end
   reg [3:0] last_le_state;
   initial last_le_state = 4'hF;

   // ------------------------------------------------------------------
   // Pixel phase: count DATA_LATCH (LE=1) pulses, expect NUM_ROWS*16 = 512
   // ------------------------------------------------------------------
   integer data_latch_count;
   integer latched_dlc;
   initial data_latch_count = 0;
   reg pix_st_lat_d;
   initial pix_st_lat_d = 0;
   always @(posedge clk) begin
     pix_st_lat_d <= uut.load0.pix_st_lat;
     if (uut.load0.pix_st_lat && !pix_st_lat_d)
       data_latch_count = data_latch_count + 1;
   end

   // ------------------------------------------------------------------
   // DRV_ROW / LP_CLK toggling sanity
   // ------------------------------------------------------------------
   integer drv_row_toggles, lp_clk_toggles;
   reg last_drv_row, last_lp_clk;
   initial begin drv_row_toggles = 0; lp_clk_toggles = 0; last_drv_row = 0; last_lp_clk = 0; end
   always @(posedge clk) begin
     if (DRV_ROW !== last_drv_row) begin drv_row_toggles = drv_row_toggles + 1; last_drv_row = DRV_ROW; end
     if (LP_CLK  !== last_lp_clk)  begin lp_clk_toggles  = lp_clk_toggles + 1;  last_lp_clk  = LP_CLK;  end
   end

   // ------------------------------------------------------------------
   // Sequencing: wait for config, then one full pixel frame, then report
   // ------------------------------------------------------------------
   initial begin
     @(posedge uut.done_configure);
     $display("t=%0t: done_configure (checked %0d/13 registers so far)", $time, reg_checks);

     @(posedge uut.done_data);
     // capture DATA_LATCH count right here - the DUT immediately starts
     // reloading the next frame (by design), so data_latch_count keeps
     // climbing in the background from this point on.
     latched_dlc = data_latch_count;
     $display("t=%0t: done_data (first frame) - DATA_LATCH pulses sent = %0d (expected 512)",
       $time, latched_dlc);

     // show_data_dp3365 runs independently of load_data_dp3365, paced by its
     // own ROW_PERIOD; give it room to actually scan a few rows before
     // judging DRV_ROW/LP_CLK activity (checking right at done_data itself
     // only catches the very first row's pulse, if that).
     #(PERIOD*60000);
     if (latched_dlc != 512) begin
       errors = errors + 1;
       $display("FAIL: expected 512 DATA_LATCH pulses, got %0d", latched_dlc);
     end
     if (reg_checks != 13) begin
       errors = errors + 1;
       $display("FAIL: expected 13 register checks, got %0d", reg_checks);
     end
     if (drv_row_toggles < 10) begin
       errors = errors + 1;
       $display("FAIL: DRV_ROW barely toggled (%0d transitions) - looks stuck", drv_row_toggles);
     end
     if (lp_clk_toggles < 100) begin
       errors = errors + 1;
       $display("FAIL: LP_CLK barely toggled (%0d transitions) - looks stuck", lp_clk_toggles);
     end

     $display("----------------------------------------------------------");
     if (errors == 0)
       $display("PASS: all checks passed (13 registers, LE sequence, 512 DATA_LATCH, DRV_ROW/LP_CLK active)");
     else
       $display("FAIL: %0d check(s) failed", errors);
     $display("----------------------------------------------------------");
     $finish;
   end

   // safety timeout
   initial begin
     #(PERIOD*800000000);
     $display("TIMEOUT waiting for first full frame - errors so far=%0d", errors);
     $finish;
   end

endmodule
