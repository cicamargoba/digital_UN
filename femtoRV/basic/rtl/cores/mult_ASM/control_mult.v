module control_mult( clk , rst , lsb_B , init , z , done , sh , reset , add );


 input clk;
 input rst;
 input lsb_B;
 input init; 
 input z;

 output reg done;
 output reg sh;
 output reg reset;
 output reg add;


 parameter START  = 3'b000;
 parameter CHECK  = 3'b001;
 parameter SHIFT  = 3'b010;
 parameter ADD  = 3'b011;
 parameter END  = 3'b100;
 
 reg [2:0] state;
 
 initial begin
  done = 0;
  sh = 0;
  reset = 0;
  add = 0;
  state = 0;
 end

reg [4:0] count;

always @(posedge clk) begin
    if (rst) begin
      state = START;
    end else begin
    case(state)

      START:begin
        done = 0;
        sh = 0;
        reset = 1;
        add = 0;
        count=0;
        if(init)
          state = CHECK;
        else
          state = START;
      end

     CHECK: begin
      done = 0;
      sh = 0;
      reset = 0;
      add = 0;
      if(lsb_B)
        state = ADD;
      else
        state = SHIFT;
     end   
     SHIFT: begin
      done = 0;
      sh = 1;
      reset = 0;
      add = 0;
      if(z)
        state = END;
      else
        state = CHECK;
     end
     ADD: begin
        done = 0;
        sh = 0;
        reset = 0;
        add = 1;
        state = SHIFT;
     end
     END:begin
        done = 1;
        sh = 0;
        reset = 0;
        add = 0;
        count = count + 1;
        state = (count>30) ? START : END ; // hace falta de 10 ciclos de reloj, para que lea el done y luego cargue el resultado
     end

     default: state = START;
   endcase
  end
end



`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    START    : state_name = "START";
    CHECK    : state_name = "CHECK";
    SHIFT    : state_name = "SHIFT";
    ADD      : state_name = "ADD";
    END      : state_name = "END";
  endcase
end
`endif



endmodule
