// Register configuration sequencer for the DP3365S / DP32xx-33xx family
// (DP3264S, DP3265S, DP3367S, DP3365S all share this exact command layer,
// confirmed against four vendor datasheets).
//
// Protocol (DP3365S_Rev1.0_EN.pdf, section 11):
//   VSYNC(3) -> PRE_ACT(14) -> WR_CFG(5) x NUM_REGS
//   Each WR_CFG is preceded by shifting the SAME 16-bit
//   {addr[7:0],data[7:0]} word once per chained chip (so every chip in the
//   SDI->SDO chain ends up with the same configuration), then LE is held
//   high for 5 DCLK to commit it.
//
// This module only sequences the *command* side: it drives an external
// count_l.v (via st_lat/latches/done_latch) for the LE-width bursts, and an
// external out_lsr.v (via ld_out/sh_out/done_out) for the 16-bit SDI word,
// exactly the same interface convention ctrl_cfg.v uses for FM6363/FM6353.
// This keeps count_l.v / out_lsr.v reused unchanged (see Docs block diagram).
//
// st_lat/ld_out/sh_out are combinational functions of `state` (not
// registered) - same convention ctrl_cfg.v uses - so they drop the instant
// a WAIT_* state is entered. Holding them registered one cycle longer would
// race with count_l.v/out_lsr.v returning to IDLE/START and re-trigger them.
//
// NOTE - open TODO: the DP3365S datasheet's register instruction/write-format
// section (11.1-11.6) is fully confirmed, but the bit-level register MAP
// (section "11.10 Registers") is missing from the public PDF (same gap as
// the DP3265S datasheet). The table below only fills in the fields whose
// meaning is given by formulas elsewhere in the datasheet (11.8.1-11.8.5);
// everything else is a 0x00 placeholder and MUST be reviewed against real
// hardware or a complete register-map datasheet before first bring-up.
module reg_wr_dp3365 #(
  parameter NUM_DRVS = 7,          // chips in the chain - 1 (8 chips -> 7)
  parameter NUM_ROWS = 64,         // physical scan rows
  // PWM_GROUPS=1 matches "General Frame Synchronization Mode" (11.7.1) with
  // refresh_rate/frame_rate=1: the chip redisplays the data it was given
  // only once per VSYNC, same timing model as the existing FM6363 design.
  // Raise it (with reg0x0c[7:6]=2) for the "high-gray independent refresh"
  // modes once row_pulse_gen/show_data_dp3365 are extended to pace ROW
  // independently of VSYNC.
  parameter PWM_GROUPS = 1,        // PWM display groups (reg0x03[6:0]+1)
  parameter PWM_WIDTH  = 64,       // row PWM width units (reg0x04[6:0]+1)
  parameter PLL_DIV    = 1         // GCLK = DCLK * PLL_DIV (reg0x06[2:0]+1 -1)
)(
    input             clk,
    input             rst,
    input             send_config,     // pulse to start the full register pass

    // LE-width burst generator (external count_l.v, width=4)
    output            st_lat,
    output      [3:0] latches,
    input             done_latch,

    // 16-bit SDI shifter (external out_lsr.v)
    output             ld_out,
    output             sh_out,
    input              done_out,
    output      [15:0] cfg_word,        // {addr[7:0],data[7:0]} to load

    output  reg       done_configure
);

localparam NUM_REGS = 13;

// ---------------------------------------------------------------
// Register table: address -> data.
// Only formula-backed fields are filled; rest are TODO placeholders.
// ---------------------------------------------------------------
reg [7:0] reg_addr [0:NUM_REGS-1];
reg [7:0] reg_data [0:NUM_REGS-1];

initial begin
  // reg0x02[5:0] = number of row scans - 1  (11.8.1)
  reg_addr[0]  = 8'h02; reg_data[0]  = (NUM_ROWS-1) & 8'h3F;
  // reg0x03[6:0] = PWM display groups - 1  (11.8.3)
  reg_addr[1]  = 8'h03; reg_data[1]  = (PWM_GROUPS-1) & 8'h7F;
  // reg0x04[6:0] = row PWM width - 1, low bits (11.8.2; reg0x14[3] holds bit7)
  reg_addr[2]  = 8'h04; reg_data[2]  = (PWM_WIDTH-1) & 8'h7F;
  // reg0x05 = row timing margins (DISSHD_TIME / precharge) - TODO
  reg_addr[3]  = 8'h05; reg_data[3]  = 8'h00;
  // reg0x06[2:0] = PLL divider for GCLK (11.8.4): FGCLK = FDCLK*(div+1)
  reg_addr[4]  = 8'h06; reg_data[4]  = (PLL_DIV-1) & 8'h07;
  // reg0x07 = gamma coarse/fine adjust - TODO
  reg_addr[5]  = 8'h07; reg_data[5]  = 8'h00;
  // reg0x08[7:0] = IGAIN (current gain) - TODO, default left at reset value
  reg_addr[6]  = 8'h08; reg_data[6]  = 8'h00;
  // reg0x09 = coupling optimization level - TODO
  reg_addr[7]  = 8'h09; reg_data[7]  = 8'h00;
  // reg0x0a = coupling optimization enhancement - TODO
  reg_addr[8]  = 8'h0a; reg_data[8]  = 8'h00;
  // reg0x0b = constant-current inflection point / shadow level - TODO
  reg_addr[9]  = 8'h0b; reg_data[9]  = 8'h00;
  // reg0x0c[7:6] = PWM display mode (00=general frame sync), [1]=remove bad
  // spots, [0]=open-circuit detect enable - leave disabled for bring-up
  reg_addr[10] = 8'h0c; reg_data[10] = 8'h00;
  // reg0x14[3] = high bit of row PWM width (paired with reg0x04) - TODO
  reg_addr[11] = 8'h14; reg_data[11] = 8'h00;
  // reg0x17[6],[4] = extra row-timing multiplier bits - TODO
  reg_addr[12] = 8'h17; reg_data[12] = 8'h00;
end

parameter START        = 4'b0000;
parameter SEND_VSYNC   = 4'b0001;
parameter WAIT_VSYNC   = 4'b0010;
parameter SEND_PREACT  = 4'b0011;
parameter WAIT_PREACT  = 4'b0100;
parameter LOAD_WORD    = 4'b0101;
parameter SHIFT_CHIPS  = 4'b0110;
parameter SEND_WRCFG   = 4'b0111;
parameter WAIT_WRCFG   = 4'b1000;
parameter NEXT_REG     = 4'b1001;
parameter END_CONFIG   = 4'b1010;

reg [3:0]  state;
reg [3:0]  reg_idx;      // 0..NUM_REGS-1
reg [3:0]  chip_cnt;     // 0..NUM_DRVS

wire [15:0] cur_word = {reg_addr[reg_idx], reg_data[reg_idx]};
assign cfg_word = cur_word;

always @(posedge clk) begin
  if (rst) begin
    state          <= START;
    reg_idx        <= 0;
    chip_cnt       <= 0;
    done_configure <= 0;
  end
  else begin
    case (state)
      START: begin
        done_configure <= 0;
        reg_idx        <= 0;
        if (send_config)
          state <= SEND_VSYNC;
      end

      SEND_VSYNC:  state <= WAIT_VSYNC;    // VSYNC: 3 DCLK with LE high
      WAIT_VSYNC:  if (done_latch) state <= SEND_PREACT;

      SEND_PREACT: state <= WAIT_PREACT;   // PRE_ACT: 14 DCLK with LE high
      WAIT_PREACT: if (done_latch) begin
                     chip_cnt <= 0;
                     state    <= LOAD_WORD;
                   end

      LOAD_WORD:   state <= SHIFT_CHIPS;   // (re)load {addr,data} for 1 chip

      SHIFT_CHIPS: begin                   // shift 16 bits for this chip
        if (done_out) begin
          if (chip_cnt == NUM_DRVS)
            state <= SEND_WRCFG;
          else begin
            chip_cnt <= chip_cnt + 1;
            state    <= LOAD_WORD;
          end
        end
      end

      SEND_WRCFG:  state <= WAIT_WRCFG;    // WR_CFG: 5 DCLK, commits the word
      WAIT_WRCFG:  if (done_latch) state <= NEXT_REG;

      NEXT_REG: begin
        if (reg_idx == NUM_REGS-1)
          state <= END_CONFIG;
        else begin
          reg_idx  <= reg_idx + 1;
          chip_cnt <= 0;
          state    <= LOAD_WORD;
        end
      end

      END_CONFIG: begin
        done_configure <= 1;
        state          <= START;
      end

      default: state <= START;
    endcase
  end
end

// Combinational outputs: drop the instant we leave the SEND_* state, so
// count_l.v / out_lsr.v never see a stale start/load/shift pulse after they
// return to idle (see module header).
assign st_lat  = (state == SEND_VSYNC) || (state == SEND_PREACT) || (state == SEND_WRCFG);
assign latches = (state == SEND_VSYNC)  ? 4'd3  :
                  (state == SEND_PREACT) ? 4'd14 :
                  (state == SEND_WRCFG)  ? 4'd5  : 4'd0;
assign ld_out  = (state == LOAD_WORD);
assign sh_out  = (state == SHIFT_CHIPS);

`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    START       : state_name = "START";
    SEND_VSYNC  : state_name = "SEND_VSYNC";
    WAIT_VSYNC  : state_name = "WAIT_VSYNC";
    SEND_PREACT : state_name = "SEND_PREACT";
    WAIT_PREACT : state_name = "WAIT_PREACT";
    LOAD_WORD   : state_name = "LOAD_WORD";
    SHIFT_CHIPS : state_name = "SHIFT_CHIPS";
    SEND_WRCFG  : state_name = "SEND_WRCFG";
    WAIT_WRCFG  : state_name = "WAIT_WRCFG";
    NEXT_REG    : state_name = "NEXT_REG";
    END_CONFIG  : state_name = "END_CONFIG";
    default     : state_name = "?";
  endcase
end
`endif

endmodule
