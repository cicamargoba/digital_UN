// Load-data orchestrator for the DP3365S / DP32xx-33xx family.
// Replaces load_data.v: wires together the register-write sequencer, the
// pixel sequencer, the framebuffer, and six out_lsr.v lanes (R0 G0 B0 R1 G1
// B1 - same HUB75 wiring convention as the rest of this core: one
// independent SDI chain per color/half, not the single combined chain shown
// as an example in the vendor's typical-application schematic).
//
// Config and pixel data share the same six physical SDI lines but need
// different word content and different LE timing, so this module muxes
// between reg_wr_dp3365.v (config phase) and pixel_seq_dp3365.v (pixel
// phase); DCLK/LE gating follows the same negedge-registered-enable
// technique load_data.v already uses, to keep edges clean.
module load_data_dp3365 #(
    parameter num_drivers = 7,     // NUM_DRVS = NUM_COLS/16 - 1
    parameter num_rows    = 32,    // rows per half (matches memory.v today)
    parameter gray_width  = 16
)(
    input        clk,
    input        rst,
    output [5:0] out_data,
    output       dclk,
    output       latch_out,

    input        send_config,
    output       done_configure,

    input        send_data,
    output  reg  done_data
);

localparam CHIPS = num_drivers + 1;

// ------------------------------------------------------------------
// Framebuffer (unchanged module/format; only the chip-facing protocol
// around it changes - see Docs/dp3365s_arquitectura_blocks.svg)
// ------------------------------------------------------------------
wire [23:0] mem_rdata;
wire [10:0] mem_addr;   // driven by pixseq0 only - reg_wr_dp3365 never touches memory
wire        mem_rd;

memory #(.size(2047), .width(10)) mem0 (
  .clk(clk), .address(mem_addr), .rd(mem_rd), .rdata(mem_rdata)
);

// ------------------------------------------------------------------
// Register configuration sequencer
// ------------------------------------------------------------------
wire       cfg_st_lat;
wire [3:0] cfg_latches;
wire       cfg_done_latch;
wire       cfg_ld, cfg_sh;
wire       cfg_done_out;
wire [15:0] cfg_word;

reg cfg_phase, pix_phase;   // one-hot: which stage drives the bus

reg_wr_dp3365 #(.NUM_DRVS(num_drivers), .NUM_ROWS(num_rows*2)) regwr0 (
  .clk(clk), .rst(rst), .send_config(send_config),
  .st_lat(cfg_st_lat), .latches(cfg_latches), .done_latch(cfg_done_latch),
  .ld_out(cfg_ld), .sh_out(cfg_sh), .done_out(cfg_done_out),
  .cfg_word(cfg_word), .done_configure(done_configure)
);

count_l #(.width(4)) count_l_cfg (
  .clk(clk), .start(cfg_st_lat), .load(cfg_latches),
  .zero(cfg_clk_en), .done(cfg_done_latch)
);
wire cfg_clk_en;

// ------------------------------------------------------------------
// Pixel data sequencer
// ------------------------------------------------------------------
wire       pix_st_lat;
wire [3:0] pix_latches;
wire       pix_done_latch;
wire       pix_ld, pix_sh;
wire       pix_done_out;
wire [gray_width-1:0] pw_R0, pw_G0, pw_B0, pw_R1, pw_G1, pw_B1;
wire pix_done_data;

pixel_seq_dp3365 #(.NUM_ROWS(num_rows), .NUM_DRVS(num_drivers), .GRAY_WIDTH(gray_width)) pixseq0 (
  .clk(clk), .rst(rst), .send_data(send_data), .done_data(pix_done_data),
  .mem_addr(mem_addr), .mem_rd(mem_rd), .mem_rdata(mem_rdata),
  .st_lat(pix_st_lat), .latches(pix_latches), .done_latch(pix_done_latch),
  .ld_pix(pix_ld), .sh_pix(pix_sh), .done_out(pix_done_out),
  .word_R0(pw_R0), .word_G0(pw_G0), .word_B0(pw_B0),
  .word_R1(pw_R1), .word_G1(pw_G1), .word_B1(pw_B1)
);

count_l #(.width(4)) count_l_pix (
  .clk(clk), .start(pix_st_lat), .load(pix_latches),
  .zero(pix_clk_en), .done(pix_done_latch)
);
wire pix_clk_en;

// ------------------------------------------------------------------
// Lightweight VSYNC-only pulse: commits/display-swaps a just-loaded frame.
// Auto-triggered right after pixseq0 finishes shifting; done_data (exposed
// to the top module) only fires once this VSYNC has actually been sent.
// ------------------------------------------------------------------
reg        vs_start;
wire       vs_done_latch;
wire       vs_clk_en;
localparam VS_IDLE = 1'b0, VS_WAIT = 1'b1;
reg        vs_state;

always @(posedge clk) begin
  if (rst) begin
    vs_state  <= VS_IDLE;
    vs_start  <= 0;
    done_data <= 0;
  end
  else begin
    vs_start  <= 0;
    done_data <= 0;
    case (vs_state)
      VS_IDLE: if (pix_done_data) begin
        vs_start <= 1;
        vs_state <= VS_WAIT;
      end
      VS_WAIT: if (vs_done_latch) begin
        done_data <= 1;
        vs_state  <= VS_IDLE;
      end
    endcase
  end
end

count_l #(.width(4)) count_l_vsync (
  .clk(clk), .start(vs_start), .load(4'd3),
  .zero(vs_clk_en), .done(vs_done_latch)
);

// ------------------------------------------------------------------
// Bus mux: 6 lanes share ld/sh/word source depending on phase
// ------------------------------------------------------------------
wire ld_lane = cfg_phase ? cfg_ld : pix_phase ? pix_ld : 1'b0;
wire sh_lane = cfg_phase ? cfg_sh : pix_phase ? pix_sh : 1'b0;

wire [gray_width-1:0] in_R0 = cfg_phase ? {{(gray_width-16){1'b0}}, cfg_word} : pw_R0;
wire [gray_width-1:0] in_G0 = cfg_phase ? {{(gray_width-16){1'b0}}, cfg_word} : pw_G0;
wire [gray_width-1:0] in_B0 = cfg_phase ? {{(gray_width-16){1'b0}}, cfg_word} : pw_B0;
wire [gray_width-1:0] in_R1 = cfg_phase ? {{(gray_width-16){1'b0}}, cfg_word} : pw_R1;
wire [gray_width-1:0] in_G1 = cfg_phase ? {{(gray_width-16){1'b0}}, cfg_word} : pw_G1;
wire [gray_width-1:0] in_B1 = cfg_phase ? {{(gray_width-16){1'b0}}, cfg_word} : pw_B1;

wire shared_done_out;
assign cfg_done_out = shared_done_out;
assign pix_done_out = shared_done_out;

// phase select: whichever submodule currently owns send_config/send_data
// (vs_start/vs_state are NOT handled here - see the dedicated VSYNC block
// above; driving the same reg from two always blocks was a real bug this
// fixes: it silently cancelled every VSYNC pulse and hung done_data.)
always @(posedge clk) begin
  if (rst) begin
    cfg_phase <= 0; pix_phase <= 0;
  end
  else begin
    if (send_config)      cfg_phase <= 1;
    else if (done_configure) cfg_phase <= 0;

    if (send_data)          pix_phase <= 1;
    else if (pix_done_data) pix_phase <= 0;
  end
end

// ------------------------------------------------------------------
// 6 parallel 16-bit (gray_width here, out_lsr.v is natively 16-bit - see
// note below) shifters, one per HUB75 line (R0 G0 B0 R1 G1 B1)
// ------------------------------------------------------------------
// out_lsr.v is a fixed 16-bit shifter; for gray_width>16 this skeleton
// still only shifts the low 16 bits (TODO: widen out_lsr.v, or chain two
// per lane, once a GRAY_WIDTH>16 bring-up is actually needed).
out_lsr lsr_r0 (.clk(clk), .in_val(in_R0[15:0]), .load(ld_lane), .shift(sh_lane),
                .s_out(out_data[5]), .done(shared_done_out), .clk_en(out_clk_en), .bit_cnt());
out_lsr lsr_g0 (.clk(clk), .in_val(in_G0[15:0]), .load(ld_lane), .shift(sh_lane),
                .s_out(out_data[4]), .done(), .clk_en(), .bit_cnt());
out_lsr lsr_b0 (.clk(clk), .in_val(in_B0[15:0]), .load(ld_lane), .shift(sh_lane),
                .s_out(out_data[3]), .done(), .clk_en(), .bit_cnt());
out_lsr lsr_r1 (.clk(clk), .in_val(in_R1[15:0]), .load(ld_lane), .shift(sh_lane),
                .s_out(out_data[2]), .done(), .clk_en(), .bit_cnt());
out_lsr lsr_g1 (.clk(clk), .in_val(in_G1[15:0]), .load(ld_lane), .shift(sh_lane),
                .s_out(out_data[1]), .done(), .clk_en(), .bit_cnt());
out_lsr lsr_b1 (.clk(clk), .in_val(in_B1[15:0]), .load(ld_lane), .shift(sh_lane),
                .s_out(out_data[0]), .done(), .clk_en(), .bit_cnt());
wire out_clk_en;

// ------------------------------------------------------------------
// DCLK / LE generation - negedge-registered enables for clean edges
// (same technique as load_data.v)
// ------------------------------------------------------------------
reg en_latch_n, en_shift_n;
always @(negedge clk) begin
  en_latch_n <= cfg_clk_en | pix_clk_en | vs_clk_en;
  en_shift_n <= out_clk_en;
end
assign dclk      = clk & (en_latch_n | en_shift_n);
assign latch_out = cfg_clk_en | pix_clk_en | vs_clk_en;

endmodule
