// Loads configuration words and pixel data into the FM6363/FM6353 chain.
//
// Config path: lsr_config feeds six out_lsr shifters; ctrl_cfg sequences
// PRE_ACT/EN_OP/VSYNC bursts and per-register data (8 words x 16 bits,
// MSB first) with LE high on the last N bits of the last word.
//
// Pixel path: 32 rows x 128 columns, 8 chips of 16 channels each, one
// 16-bit word per chip per channel-color line, MSB first. LE gets a
// single 1-CLK-high pulse on b0 of the last chip of each channel
// (DATA_LATCH command).
// DCLK is gated with enables registered on the negedge so LE/SDI change
// away from the DCLK rising edge (FM6363 needs 3 ns SDI / 7 ns LE setup).
module load_data #(
    parameter width       = 128,
    parameter config0     = 16'h0008,
    parameter config1     = 16'h1f70,
    parameter config2     = 16'h6707,
    parameter config3     = 16'h40f7,
    parameter config4     = 16'h0040,
    parameter num_drivers = 7,     // NUM_DRVS = NUM_COLS/16 - 1
    parameter bit_depth   = 4
)(
    input        clk,
    input        rst,
    output [5:0] out_data,
    output       dclk,
    output       latch_out,
    input        send_config,
    output       done_configure,
    output       vs_done,
    input        send_data,
    output  reg  done_data
);

localparam CHIPS = num_drivers + 1;   // 8 chips for 128 columns

// ------------------------------------------------------------------
// Config datapath
// ------------------------------------------------------------------
wire sh_cfg;
wire ld_cfg;
wire [15:0] ser_cfg;

wire st_lat;
wire [3:0] latches;
wire clk_en_latch;
wire done_latch;

wire ld_out;
wire sh_out;
wire done_out;
wire clk_en_out;
wire [4:0] bit_cnt;
wire le_data;

lsr_config #( .width(width), .config0(config0), .config1(config1),
              .config2(config2), .config3(config3), .config4(config4))
            lsr_cfg0 (.clk(clk) , .shift(sh_cfg) , .load(ld_cfg) , .s_A(ser_cfg));

count_l    #( .width(4))   count_l0( .clk(clk), .start(st_lat), .load(latches), .zero(clk_en_latch), .done(done_latch));

ctrl_cfg   #(.NUM_DRVS(num_drivers), .DELAY(10)) ctr_cfg0(
                    .clk(clk), .rst(rst), .send_config(send_config),
                    .latches(latches), .st_lat(st_lat), .done_latch(done_latch),
                    .ld_cfg(ld_cfg), .sh_cfg(sh_cfg), .done_configure(done_configure),
                    .ld_out(ld_out), .sh_out(sh_out), .done_out(done_out),
                    .bit_cnt(bit_cnt), .drv_cnt(4'b0), .le_data(le_data),
                    .vs_done(vs_done) );

// ------------------------------------------------------------------
// Pixel datapath: framebuffer + bit-plane mux + shared shifter words
// ------------------------------------------------------------------
wire [23:0] mem_rdata;
reg  [10:0] mem_addr;
reg         mem_rd;

memory #(.size(2047), .width(10)) mem0 (
  .clk(clk), .address(mem_addr), .rd(mem_rd), .rdata(mem_rdata)
);

reg  [1:0] plane_sel;
wire [5:0] pix_bit;
mux_led mux0 (.in0(mem_rdata), .sel(plane_sel), .out0(pix_bit));

// Config words during config phase, pixel words during data phase.
// In pixel phase each shifter serializes the 16-bit word of one chip;
// the SDO->SDI chain carries the stream through all 8 chips.
wire pix_phase;
reg  [15:0] pix_word_R0, pix_word_G0, pix_word_B0;
reg  [15:0] pix_word_R1, pix_word_G1, pix_word_B1;

wire [15:0] ld_R0 = pix_phase ? pix_word_R0 : ser_cfg;
wire [15:0] ld_G0 = pix_phase ? pix_word_G0 : ser_cfg;
wire [15:0] ld_B0 = pix_phase ? pix_word_B0 : ser_cfg;
wire [15:0] ld_R1 = pix_phase ? pix_word_R1 : ser_cfg;
wire [15:0] ld_G1 = pix_phase ? pix_word_G1 : ser_cfg;
wire [15:0] ld_B1 = pix_phase ? pix_word_B1 : ser_cfg;

wire cfg_ld = ld_out;
wire cfg_sh = sh_out;
reg  pix_ld, pix_sh;

out_lsr  lsr_r0(  .clk(clk), .in_val(ld_R0), .load(cfg_ld | pix_ld), .shift(cfg_sh | pix_sh),
                  .s_out(out_data[5]), .done(done_out), .clk_en(clk_en_out), .bit_cnt(bit_cnt) );  // R0
out_lsr  lsr_g0(  .clk(clk), .in_val(ld_G0), .load(cfg_ld | pix_ld), .shift(cfg_sh | pix_sh), .s_out(out_data[4]) );  // G0
out_lsr  lsr_b0(  .clk(clk), .in_val(ld_B0), .load(cfg_ld | pix_ld), .shift(cfg_sh | pix_sh), .s_out(out_data[3]) );  // B0
out_lsr  lsr_r1(  .clk(clk), .in_val(ld_R1), .load(cfg_ld | pix_ld), .shift(cfg_sh | pix_sh), .s_out(out_data[2]) );  // R1
out_lsr  lsr_g1(  .clk(clk), .in_val(ld_G1), .load(cfg_ld | pix_ld), .shift(cfg_sh | pix_sh), .s_out(out_data[1]) );  // G1
out_lsr  lsr_b1(  .clk(clk), .in_val(ld_B1), .load(cfg_ld | pix_ld), .shift(cfg_sh | pix_sh), .s_out(out_data[0]) );  // B1

// Enables registered on negedge for clean DCLK gating
reg en_latch_n, en_out_n;
always @(negedge clk) begin
  en_latch_n <= clk_en_latch;
  en_out_n   <= clk_en_out;
end
assign dclk = clk & (en_latch_n | en_out_n);

// LE: burst generator during commands, bit-window during config data,
// 1-clock pulse per channel during pixel data.
reg pix_le;
assign latch_out = clk_en_latch | le_data | pix_le;

// ------------------------------------------------------------------
// Pixel FSM: 32 rows x 16 channel-groups x 8 chips x 16 bits
// Memory: 2048 x 24-bit words = 64 rows x 32 col-groups of 8 px.
// Lower half rows (0-31) -> RGB0 chain, upper half -> RGB1 chain.
// Address = {row[5:0], col_group[4:0]} flattened to 11 bits.
// ------------------------------------------------------------------
reg [4:0] chan_cnt;    // 0..15 channel-group within half-row (128px/8)
reg [3:0] chip_cnt;    // 0..7 chip within group
reg [5:0] row_count;   // 0..31 logical rows
reg [1:0] plane;       // current bit-plane

assign pix_phase = (pstate != P_START) && (pstate != P_DONE);

parameter P_START = 3'b000;
parameter P_READ  = 3'b001;
parameter P_LOAD  = 3'b010;
parameter P_SHIFT = 3'b011;
parameter P_LATCH = 3'b100;
parameter P_NEXT  = 3'b101;
parameter P_DONE  = 3'b110;

reg [2:0] pstate;

always @(posedge clk) begin
  if(rst) begin
    pstate    <= P_START;
    row_count <= 0;
    chan_cnt  <= 0;
    chip_cnt  <= 0;
    plane     <= 0;
    done_data <= 0;
    pix_le    <= 0;
    pix_ld    <= 0;
    pix_sh    <= 0;
    mem_rd    <= 0;
    mem_addr  <= 0;
    plane_sel <= 0;
  end
  else begin
    case(pstate)
      P_START: begin
        done_data <= 0;
        pix_le    <= 0;
        pix_sh    <= 0;
        row_count <= 0;
        chan_cnt  <= 0;
        chip_cnt  <= 0;
        plane     <= 0;
        if(send_data) begin
          mem_addr <= 0;
          mem_rd   <= 1;
          pstate   <= P_READ;
        end
      end

      P_READ: begin
        mem_rd    <= 0;
        plane_sel <= plane;
        pstate    <= P_LOAD;
      end

      P_LOAD: begin
        // Replicate current bit-plane bits across the 16 channels of
        // the chip (one bit per constant-current channel).
        pix_word_R0 <= {16{pix_bit[5]}};
        pix_word_G0 <= {16{pix_bit[4]}};
        pix_word_B0 <= {16{pix_bit[3]}};
        pix_word_R1 <= {16{pix_bit[2]}};
        pix_word_G1 <= {16{pix_bit[1]}};
        pix_word_B1 <= {16{pix_bit[0]}};
        pix_ld      <= 1;
        pstate      <= P_SHIFT;
      end

      P_SHIFT: begin
        pix_ld <= 0;
        pix_sh <= 1;
        if(done_out) begin
          pix_sh <= 0;
          if(chip_cnt == CHIPS-1) begin
            pix_le <= 1;           // 1-CLK LE on b0 of last chip
            pstate <= P_LATCH;
          end
          else begin
            chip_cnt <= chip_cnt + 1;
            pstate   <= P_LOAD;
          end
        end
      end

      P_LATCH: begin
        pix_le   <= 0;
        chip_cnt <= 0;
        if(chan_cnt == 15) begin
          chan_cnt <= 0;
          pstate   <= P_NEXT;
        end
        else begin
          chan_cnt <= chan_cnt + 1;
          mem_addr <= mem_addr + 1;
          mem_rd   <= 1;
          pstate   <= P_READ;
        end
      end

      P_NEXT: begin
        if(row_count == 31) begin
          row_count <= 0;
          if(plane == bit_depth-1) begin
            pstate <= P_DONE;
          end
          else begin
            plane    <= plane + 1;
            mem_addr <= 0;
            mem_rd   <= 1;
            pstate   <= P_READ;
          end
        end
        else begin
          row_count <= row_count + 1;
          mem_addr  <= mem_addr + 1;
          mem_rd    <= 1;
          pstate    <= P_READ;
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

endmodule
