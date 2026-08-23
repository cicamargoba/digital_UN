module control_div( clk , rst , init_in , MSB , z , INIT , SH , DEC , LDA , DONE, DV0  );

 input clk;
 input rst;
 input init_in;
 input MSB;
 input z;

 output reg INIT;
 output reg DV0;
 output reg SH;
 output reg DEC;
 output reg LDA;
 output reg DONE;


 parameter START      = 3'b000;
 parameter SHIFT_DEC  = 3'b001;
 parameter CHECK      = 3'b010;
 parameter ADD        = 3'b011;
 parameter END1       = 3'b100;
 
 reg [2:0] state;
 

reg [3:0] count;

always @(posedge clk) begin
    if (rst) begin
      state = START;
    end 
    else begin
      case(state)

        START: begin
          if(init_in)
            state = SHIFT_DEC;
          else
            state = START;
        end

        SHIFT_DEC:
          state = CHECK;

        CHECK: 
          if(z)
            state = END1;
          else begin 
            if (MSB==0)
              state = ADD;
            else
              state = SHIFT_DEC;
          end

        ADD: 
          if(z)
            state = END1;
          else
            state = SHIFT_DEC;

        END1:begin
          if(init_in)
            state = START;
          else
            state = END1;
        end

      default: state = START;
      
    endcase
   end
 end

always @(*) begin
  case(state)
    START:begin
      INIT = 1;
      DV0  = 0;
      SH   = 0;
      DEC  = 0;
      LDA  = 0;
      DONE = 0;
    end
    SHIFT_DEC:begin
      INIT = 0;
      DV0  = DV0;
      SH   = 1;
      DEC  = 1;
      LDA  = 0;
      DONE = 0;
    end
    CHECK:begin
      INIT = 0;
      DV0  = 0;
      SH   = 0;
      DEC  = 0;
      LDA  = 0;
      DONE = 0;
    end
    ADD:begin
      INIT = 0;
      DV0  = 1; // primero suma
      SH   = 0;
      DEC  = 0;
      LDA  = 1;
      DONE = 0;
    end
    END1:begin
      INIT = 0;
      DV0  = 0;
      SH   = 0;
      DEC  = 0;
      LDA  = 0;
      DONE = 1;
    end
    default:begin
      INIT = 1;
      DV0  = 0;
      SH   = 0;
      DEC  = 0;
      LDA  = 0;
      DONE = 0;
    end
  endcase
end


`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    START     : state_name = "START";
    CHECK     : state_name = "CHECK";
    SHIFT_DEC : state_name = "SHIFT_DEC";
    ADD       : state_name = "ADD";
    END1      : state_name = "END1";
  endcase
end
`endif




endmodule
