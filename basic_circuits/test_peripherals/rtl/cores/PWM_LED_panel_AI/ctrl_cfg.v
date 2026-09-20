// Configuration sequencer for FM6363/FM6353-style drivers.
// Sequence:
//   PRE_ACT (14) -> EN_OP (12) -> VSYNC (3)
//   then for each of 5 registers (latch widths 2,4,6,8,10):
//     PRE_ACT (14) -> shift 8 words of 16 bits (NUM_DRVS+1 chips chained)
//     with LE high during the last `num_latches` bits of the LAST word.
//   then final VSYNC (3) and vs_done pulse.
// LE during data is generated from the shifter bit position, not from
// separate latch bursts after the data (the old SEND_CFG_LATCHES bursts
// appended N extra edges with SDI=0 and are removed).
module ctrl_cfg #(
  parameter NUM_DRVS = 8,
  parameter DELAY    = 16
)(
    input             clk,
    input             rst,
    input             send_config,
    input             done_latch,
    output  reg       st_lat,
    output  reg       ld_cfg,
    output  reg       sh_cfg,
    output  reg [3:0] latches,

    output   reg      ld_out,
    output   reg      sh_out,
    input             done_out,
    input      [4:0]  bit_cnt,       // current bit index from out_lsr
    input      [3:0]  drv_cnt,       // current chained-driver index
    output   reg      le_data,       // LE override during data shift
    output   reg      done_configure,
    output   reg      vs_done
);

parameter START                 = 5'b00000;
parameter WAIT_SEND_LATCH1      = 5'b00001;
parameter SEND_CFG_LOOP         = 5'b00010;
parameter SEND_PRE_ACT          = 5'b00011;
parameter START_SEND_CFG        = 5'b00100;
parameter WAIT_SEND_CFG_DATA    = 5'b00101;
parameter SET_NEXT_CFG_DATA     = 5'b00110;
parameter NEXT_CFG_DATA_DELAY   = 5'b01010;
parameter WAIT_END_PREACT_CMD   = 5'b01011;
parameter SEND_PREACT_CMD       = 5'b01100;
parameter END_CONFIGURE         = 5'b01101;

parameter SEND_EN_CHAN          = 5'b01110;
parameter WAIT_END_SEND_CHAN    = 5'b01111;
parameter SEND_VSYNC            = 5'b10000;
parameter WAIT_END_VSYNC        = 5'b10001;
parameter SEND_VSYNC_END        = 5'b10010;
parameter WAIT_END_VSYNC_END    = 5'b10011;

reg [4:0] state;
reg [3:0] num_latches;
reg [3:0] num_drivers;
reg [4:0] count_delay;

always @(posedge clk) begin
  if(rst) begin
    state        <= START;
    latches      <= 14;
    num_latches  <= 2;
    num_drivers  <= 0;
    count_delay  <= 0;
    vs_done      <= 0;
  end
  else begin
    case(state)
      START: begin
        vs_done <= 0;
        latches <= 14;
        num_latches <= 2;
        if(send_config)
          state <= SEND_PRE_ACT;
      end

      SEND_PRE_ACT: begin   // PRE_ACT command: 14 edges, LE high
        latches <= 14;
        state   <= WAIT_SEND_LATCH1;
      end

      WAIT_SEND_LATCH1: begin
        latches <= 14;
        if (done_latch)
          state <= SEND_EN_CHAN;
      end

      SEND_EN_CHAN: begin   // EN_OP command: 12 edges, LE high
        latches <= 12;
        state   <= WAIT_END_SEND_CHAN;
      end

      WAIT_END_SEND_CHAN: begin
        latches <= 12;
        if (done_latch)
          state <= SEND_VSYNC;
      end

      SEND_VSYNC: begin     // VSYNC command: 3 edges, LE high
        latches <= 3;
        state   <= WAIT_END_VSYNC;
      end

      WAIT_END_VSYNC: begin
        latches <= 3;
        if (done_latch)
          state <= START_SEND_CFG;
      end

      START_SEND_CFG: begin // load config register shifter
        state   <= SEND_PREACT_CMD;
        latches <= 14;
      end

      SEND_PREACT_CMD: begin
        latches <= 14;
        state   <= WAIT_END_PREACT_CMD;
      end

      WAIT_END_PREACT_CMD: begin
        latches <= 14;
        if (done_latch)
          state <= SEND_CFG_LOOP;
      end

      SEND_CFG_LOOP: begin  // shift configuration data words
        state <= WAIT_SEND_CFG_DATA;
      end

      WAIT_SEND_CFG_DATA: begin
        if(done_out) begin
          if(num_drivers == NUM_DRVS) begin
            // last word shifted; LE was held high on the last num_latches
            // bits by le_data. Move to next register.
            state       <= SET_NEXT_CFG_DATA;
            num_drivers <= 0;
          end
          else begin
            num_drivers <= num_drivers + 1;
            state       <= SEND_CFG_LOOP;
          end
        end
      end

      SET_NEXT_CFG_DATA: begin
        num_latches <= num_latches + 2;
        if(num_latches == 10)
          state <= SEND_VSYNC_END;
        else
          state <= NEXT_CFG_DATA_DELAY;
      end

      NEXT_CFG_DATA_DELAY: begin
        if(count_delay == DELAY) begin
          state       <= SEND_PREACT_CMD;
          count_delay <= 0;
        end else begin
          count_delay <= count_delay + 1;
        end
      end

      SEND_VSYNC_END: begin // final VSYNC: 3 edges, LE high
        latches <= 3;
        state   <= WAIT_END_VSYNC_END;
      end

      WAIT_END_VSYNC_END: begin
        latches <= 3;
        if (done_latch)
          state <= END_CONFIGURE;
      end

      END_CONFIGURE: begin
        vs_done <= 1;      // one-cycle pulse: frame data can be shown
        state   <= START;
      end

      default: state <= START;
    endcase
  end
end

// LE override during data shift: high on the last num_latches bits of the
// LAST chained word of each register (regs 1-4 also get the 14-high
// postamble by the PRE_ACT burst that follows in the next pass).
always @(*) begin
  le_data = 1'b0;
  if(state == WAIT_SEND_CFG_DATA && num_drivers == NUM_DRVS) begin
    if(bit_cnt >= (16 - num_latches))
      le_data = 1'b1;
  end
end

always @(*) begin
  // defaults
  st_lat = 0; ld_cfg = 0; sh_cfg = 0;
  ld_out = 0; sh_out = 0; done_configure = 0;
  case(state)
    SEND_PRE_ACT, SEND_EN_CHAN, SEND_VSYNC,
    SEND_PREACT_CMD, SEND_VSYNC_END: st_lat = 1;

    START_SEND_CFG: begin ld_cfg = 1; ld_out = 1; end
    SEND_CFG_LOOP:  sh_out = 1;

    END_CONFIGURE: done_configure = 1;
    default: ;
  endcase
end

`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    START               : state_name = "START";
    WAIT_SEND_LATCH1    : state_name = "WAIT_SEND_LATCH1";
    SEND_CFG_LOOP       : state_name = "SEND_CFG_LOOP";
    SEND_PRE_ACT        : state_name = "SEND_PRE_ACT";
    START_SEND_CFG      : state_name = "START_SEND_CFG";
    WAIT_SEND_CFG_DATA  : state_name = "WAIT_SEND_CFG_DATA";
    SET_NEXT_CFG_DATA   : state_name = "SET_NEXT_CFG_DATA";
    NEXT_CFG_DATA_DELAY : state_name = "NEXT_CFG_DATA_DELAY";
    WAIT_END_PREACT_CMD : state_name = "WAIT_END_PREACT_CMD";
    SEND_PREACT_CMD     : state_name = "SEND_PREACT_CMD";
    END_CONFIGURE       : state_name = "END_CONFIGURE";
    SEND_EN_CHAN        : state_name = "SEND_EN_CHAN";
    WAIT_END_SEND_CHAN  : state_name = "WAIT_END_SEND_CHAN";
    SEND_VSYNC          : state_name = "SEND_VSYNC";
    WAIT_END_VSYNC      : state_name = "WAIT_END_VSYNC";
    SEND_VSYNC_END      : state_name = "SEND_VSYNC_END";
    WAIT_END_VSYNC_END  : state_name = "WAIT_END_VSYNC_END";
    default             : state_name = "?";
  endcase
end
`endif

endmodule
