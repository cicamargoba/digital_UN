// Display refresh engine: generates GCLK (NOE) and the row address.
// After each VSYNC (vs_done pulse from load_data) a header of
// hdr_pulses+1 GCLKs (4) is emitted, then each row gets pulses_on+1
// (138) GCLKs with pulses_off+1 (27) idle clocks between rows.
// gclk is gated with an enable registered on the negedge of clk, so
// the output edges align cleanly with the DCLK domain.
module show_data #(
    parameter pulses_on  = 138,
    parameter pulses_off = 27,
    parameter hdr_pulses = 3
)(
    input         clk,
    input         rst,
    input         init,
    input         vs_done,
    output [4:0 ] outc,
    output        gclk
);

   wire inc_o;
   wire inc_c;
   wire inc_z;
   wire inc_h;
   wire z_o;
   wire z_c;
   wire z_z;
   wire z_h;
   wire clk_en;
   wire clr_vs;
   wire vs_pend;

   // VSYNC pending flag: set by vs_done, cleared when the header starts
   reg vs_pend_r;
   always @(posedge clk) begin
     if(rst)
       vs_pend_r <= 0;
     else if(clr_vs)
       vs_pend_r <= 0;
     else if(vs_done)
       vs_pend_r <= 1;
   end
   assign vs_pend = vs_pend_r;

   // negedge-registered enable for clean GCLK gating
   reg clk_en_n;
   always @(negedge clk) begin
     clk_en_n <= clk_en;
   end
   assign gclk = clk & clk_en_n;

   ctrl_show   ctrl0 (.clk(clk), .rst(rst), .init(init), .vs_pend(vs_pend),
                      .z_c(z_c), .z_z(z_z), .z_o(z_o), .z_h(z_h),
                      .inc_o(inc_o), .inc_z(inc_z), .inc_c(inc_c), .inc_h(inc_h),
                      .clr_vs(clr_vs), .clk_en(clk_en) );

   count #(.width (4), .limit(31))         count_col  (.clk(clk), .reset(rst), .inc(inc_c), .zero(z_c), .outc(outc));
   count #(.width (5), .limit(pulses_off)) count_zero (.clk(clk), .reset(rst), .inc(inc_z), .zero(z_z));
   count #(.width (8), .limit(pulses_on))  count_pulse(.clk(clk), .reset(rst), .inc(inc_o), .zero(z_o));
   count #(.width (2), .limit(hdr_pulses)) count_hdr  (.clk(clk), .reset(rst), .inc(inc_h), .zero(z_h));

endmodule
