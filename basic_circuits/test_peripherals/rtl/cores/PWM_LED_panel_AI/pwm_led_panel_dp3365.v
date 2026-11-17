// Top level for the DP3365S / DP32xx-33xx family variant of this core.
// Mirrors pwm_led_panel.v's structure (same clk1 divider, same high-level
// FSM shape) but targets the DP3365S protocol instead of FM6363/FM6353:
//   - no NOE/OE pin: DP3365S replaces it with DRV_ROW (see row_pulse_gen.v)
//   - register writes are indexed {addr,data} (see reg_wr_dp3365.v), not a
//     fixed 5-word concatenated config register
//   - pixel data is one grayscale word per channel, not a 1-bit BCM plane
//     (see pixel_seq_dp3365.v); the chip does PWM/BCM internally
// See Docs/dp3365s_arquitectura_blocks.svg for the full block diagram and
// Docs/ for the vendor datasheets this was built against.
module pwm_led_panel_dp3365(clk, rst, init, LP_CLK, LATCH, DRV_ROW, ROW);

    input         rst;
    input         clk;
    input         init;
    output        LP_CLK;
    output        LATCH;
    output        DRV_ROW;     // to each DP3365S chip's ROW pin
    output  [4:0] ROW;         // physical panel row address (unchanged role)

    reg clk1;

// ======== Caracteristicas de la matriz ========
parameter NUM_COLS = 128;
parameter NUM_ROWS = 64;
parameter NUM_DRVS = NUM_COLS/16 - 1;   // 128 cols -> 8 chips -> 7

initial begin
  clk1        = 0;
  clk_counter = 0;
end

reg [4:0] clk_counter;
always @(posedge clk) begin
   if (~rst) begin
     clk_counter <= 0;
     clk1        <= 0;
   end
   else begin
      if(clk_counter == 2) begin
         clk1    <= ~clk1;
         clk_counter <= 0;
      end
      else
         clk_counter <= clk_counter + 1;
   end
end

wire [5:0] out_data_unused;   // DP3365S has no RGB-pin config-readback debug
wire       vs_done;
wire       done_configure;
reg        send_config;
reg        send_data;
wire       done_data;
reg        init_show;

show_data_dp3365 #(.NUM_ROWS(32))
    display0 (.clk(clk1), .rst(~rst), .init(init_show), .vs_done(vs_done),
              .outc(ROW), .drv_row(DRV_ROW));

load_data_dp3365 #(.num_drivers(NUM_DRVS), .num_rows(32))
    load0 (.clk(~clk1), .rst(~rst), .out_data(out_data_unused),
           .dclk(LP_CLK), .latch_out(LATCH),
           .send_config(send_config), .done_configure(done_configure),
           .send_data(send_data), .done_data(done_data));

assign vs_done = done_data;

parameter START         = 4'b0000;
parameter SEND_CONFIG   = 4'b0001;
parameter SEND_DATA     = 4'b0010;
parameter LOOP          = 4'b0011;
parameter LOOP_SEND     = 4'b0100;
parameter SHOW_DATA     = 4'b0101;

reg [3:0] state;

always @(posedge clk1) begin
  if(~rst) begin
    state       <= START;
    send_config <= 0;
  end
  else begin
    case(state)
      START: begin
         send_config <= 1;
         send_data   <= 0;
         init_show   <= 0;
         state       <= SEND_CONFIG;
      end

      SEND_CONFIG: begin
         send_config <= 0;
         send_data   <= 0;
         init_show   <= 0;
         state       <= LOOP;
      end

      LOOP: begin
         send_config <= 0;
         send_data   <= 0;
         init_show   <= 0;
         if(done_configure)
            state <= SEND_DATA;
         else
            state <= LOOP;
      end

      SEND_DATA: begin
         send_config <= 0;
         send_data   <= 1;
         init_show   <= 0;
         state       <= LOOP_SEND;
      end

      LOOP_SEND: begin
         send_config <= 0;
         send_data   <= 0;
         if(done_data) begin
            init_show <= 1;
            state <= SHOW_DATA;
         end
         else begin
            init_show <= 0;
            state <= LOOP_SEND;
         end
      end

      SHOW_DATA: begin
         send_config <= 0;
         send_data   <= 1;      // keep reloading the frame buffer
         init_show   <= 0;
         if(done_data)
            state <= LOOP_SEND;
         else
            state <= SHOW_DATA;
      end

      default: state <= START;
    endcase
  end
end

endmodule
