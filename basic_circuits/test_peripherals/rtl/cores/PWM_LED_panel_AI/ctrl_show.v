// Sequencer for show_data.
// WAIT_VS: wait for a pending VSYNC.
// HDR: emit hdr_pulses+1 GCLKs (4) as frame header.
// ROW_ON: emit pulses_on+1 (138) GCLKs for the current row.
// GAP: wait pulses_off+1 (27) clocks (blanking between rows).
// NEXT_ROW: advance the row counter; after 32 rows go back to WAIT_VS.
module ctrl_show(
  input  clk,
  input  rst,
  input  init,
  input  vs_pend,
  input  z_c,
  input  z_o,
  input  z_z,
  input  z_h,
  output reg inc_o,
  output reg inc_z,
  output reg inc_c,
  output reg inc_h,
  output reg clr_vs,
  output reg clk_en
);

 parameter WAIT_VS  = 3'b000;
 parameter HDR      = 3'b001;
 parameter ROW_ON   = 3'b010;
 parameter GAP      = 3'b011;
 parameter NEXT_ROW = 3'b100;

reg [2:0] state;

always @(posedge clk) begin
  if(rst) begin
    state <= WAIT_VS;
  end
  else begin
    case(state)
      WAIT_VS: begin
        if(init && vs_pend)
          state <= HDR;
        else
          state <= WAIT_VS;
      end

      HDR: begin
        if(z_h)
          state <= ROW_ON;
        else
          state <= HDR;
      end

      ROW_ON: begin
        if(z_o)
          state <= GAP;
        else
          state <= ROW_ON;
      end

      GAP: begin
        if(z_z)
          state <= NEXT_ROW;
        else
          state <= GAP;
      end

      NEXT_ROW: begin
        if(z_c)
          state <= WAIT_VS;   // 32 rows done; wait for next frame
        else
          state <= ROW_ON;
      end

      default: state <= WAIT_VS;
    endcase
  end
end

always @(*) begin
  // defaults
  inc_o = 0; inc_z = 0; inc_c = 0; inc_h = 0;
  clr_vs = 0; clk_en = 0;
  case(state)
    WAIT_VS: begin
      if(init && vs_pend)
        clr_vs = 1;
    end

    HDR: begin
      inc_h  = 1;
      clk_en = 1;
    end

    ROW_ON: begin
      inc_o  = 1;
      clk_en = 1;
    end

    GAP: begin
      inc_z = 1;
    end

    NEXT_ROW: begin
      inc_c = 1;
    end

    default: ;
  endcase
end

`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    WAIT_VS  : state_name = "WAIT_VS";
    HDR      : state_name = "HDR";
    ROW_ON   : state_name = "ROW_ON";
    GAP      : state_name = "GAP";
    NEXT_ROW : state_name = "NEXT_ROW";
  endcase
end
`endif

endmodule
