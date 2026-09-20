module ctrl_lp4k(
    input   clk,
    input   init,
    input   rst,
    input   ZR,
    input   ZC,
    input   ZD,
    input   ZI,
    output  reg RST_R,
    output  reg RST_C,
    output  reg RST_D,
    output  reg RST_I,
    output  reg INC_R,
    output  reg INC_C,
    output  reg INC_D,
    output  reg INC_I,
    output  reg LD,
    output  reg SHD,
    output  reg LATCH,
    output  reg NOE,
    output  reg PX_CLK_EN
);

 parameter START       = 4'b0000;
 parameter GET_PIXEL   = 4'b0001;
 parameter INC_COL     = 4'b0010;
 parameter ROW_READY   = 4'b0100;
 parameter SEND_ROW    = 4'b0011;
 parameter DELAY_ROW   = 4'b0101;
 parameter INC_ROW     = 4'b0110;
 parameter READY_FRAME = 4'b0111;
 parameter NEXT_BIT    = 4'b1000;
 parameter NEXT_DELAY  = 4'b1001;

 reg [3:0] state;


 always @(posedge clk) begin
  if (rst) begin
    state = START;
  end else begin
    case(state)
      START: begin
        if(init)
          state = GET_PIXEL;
        else
          state = START;
      end

      GET_PIXEL: begin
        state = INC_COL;
      end

      INC_COL: begin
        if(ZC)
          state = SEND_ROW;
        else 
          state = INC_COL;
      end


      SEND_ROW: begin
        state = DELAY_ROW;
      end

      DELAY_ROW: begin
        if(ZD)
          state = NEXT_BIT;
        else
          state = DELAY_ROW;
      end

      NEXT_BIT: begin
        state = NEXT_DELAY;
      end

      NEXT_DELAY: begin
        if(ZI)
          state = INC_ROW;
        else
          state = GET_PIXEL;
      end

      INC_ROW: begin
        state = READY_FRAME;
      end

      READY_FRAME: begin
        if(ZR)
          state = START;
        else
          state = GET_PIXEL;
      end

      default: state = START;
    endcase
  end
end

always @(*) begin
    case(state)
      START: begin
        RST_R = 0; RST_C = 0; RST_D = 0; RST_I = 0;
        INC_R = 0; INC_C = 0; INC_D = 0; INC_I = 0;
        LD    = 1; SHD   = 0;
        LATCH = 0; NOE   = 1; PX_CLK_EN = 0;
      end

      GET_PIXEL: begin
        RST_R = 1; RST_C = 1; RST_D = 1; RST_I = 1;
        INC_R = 0; INC_C = 0; INC_D = 0; INC_I = 0;
        LD    = 0; SHD   = 0;
        LATCH = 0; NOE   = 1; PX_CLK_EN = 0;
      end

      INC_COL: begin
        RST_R = 1; RST_C = 1; RST_D = 1; RST_I = 1;
        INC_R = 0; INC_C = 1; INC_D = 0; INC_I = 0;
        LD    = 0; SHD   = 0;
        LATCH = 0; NOE   = 1; PX_CLK_EN = 1;
      end

      SEND_ROW: begin
        RST_R = 1; RST_C = 1; RST_D = 1; RST_I = 1;
        INC_R = 0; INC_C = 0; INC_D = 0; INC_I = 0;
        LD    = 0; SHD   = 0;
        LATCH = 1; NOE   = 0; PX_CLK_EN = 0;
      end

      DELAY_ROW: begin
        RST_R = 1; RST_C = 1; RST_D = 1; RST_I = 1;
        INC_R = 0; INC_C = 0; INC_D = 1; INC_I = 0;
        LD    = 0; SHD   = 0;
        LATCH = 0; NOE   = 0; PX_CLK_EN = 0;
      end


      NEXT_BIT: begin
        RST_R = 1; RST_C = 1; RST_D = 0; RST_I = 1;
        INC_R = 0; INC_C = 0; INC_D = 0; INC_I = 1;
        LD    = 0; SHD   = 1;
        LATCH = 0; NOE   = 0; PX_CLK_EN = 0;
      end


      NEXT_DELAY: begin
        RST_R = 1; RST_C = 1; RST_D = 1; RST_I = 1;
        INC_R = 0; INC_C = 0; INC_D = 1; INC_I = 0;
        LD    = 0; SHD   = 0;
        LATCH = 0; NOE   = 0; PX_CLK_EN = 0;
      end


      INC_ROW: begin
        RST_R = 1; RST_C = 0; RST_D = 0; RST_I = 1;
        INC_R = 1; INC_C = 0; INC_D = 0; INC_I = 0;
        LD    = 1; SHD   = 1;
        LATCH = 0; NOE   = 1; PX_CLK_EN = 0;
      end

      READY_FRAME: begin
        RST_R = 1; RST_C = 1; RST_D = 1; RST_I = 1;
        INC_R = 0; INC_C = 0; INC_D = 0; INC_I = 0;
        LD    = 0; SHD   = 0;
        LATCH = 0; NOE   = 1; PX_CLK_EN = 0;
      end

      default: begin
        RST_R = 0; RST_C = 0; RST_D = 0; RST_I = 1;
        INC_R = 0; INC_C = 0; INC_D = 0; INC_I = 0;
        LD    = 0; SHD   = 0;
        LATCH = 0; NOE   = 1; PX_CLK_EN = 0;
      end

    endcase
end


`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    START       : state_name = "START";
    GET_PIXEL   : state_name = "GET_PIXEL";
    INC_COL     : state_name = "INC_COL";
    ROW_READY   : state_name = "ROW_READY";
    SEND_ROW    : state_name = "SEND_ROW";
    DELAY_ROW   : state_name = "DELAY_ROW";
    INC_ROW     : state_name = "INC_ROW";
    READY_FRAME : state_name = "READY_FRAME";
    NEXT_BIT    : state_name = "NEXT_BIT";
    NEXT_DELAY  : state_name = "NEXT_DELAY";
  endcase
end
`endif

endmodule
