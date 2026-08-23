module ctrl_ws (
    input             clk,
    input             reset,
    input             init_t,
    input [1:0]       sel,
    input             z,
    output reg        dout,
    output reg        done,
    output reg        rst,
    output reg        inc,
    output reg [1:0]  sel_tim
);

 parameter START     = 4'b0000;
 parameter CHK_SEL   = 4'b0001;
 parameter SEND_RES  = 4'b0010;
 parameter SEND_0    = 4'b0011;
 parameter SEND_1    = 4'b0100;
 parameter WAIT_TRST = 4'b0101;
 parameter WAIT_TH   = 4'b0110;
 parameter SEND_PER  = 4'b0111;
 parameter WAIT_T    = 4'b1000;
 parameter END_SEND  = 4'b1001;

reg [3:0] state;

always @(posedge clk ) begin
    if (reset) begin
        state = START;
    end else begin
        case (state)
            START:
                if(init_t)
                    state = CHK_SEL;
                else
                    state = START;
            CHK_SEL:
                case (sel)
                    2'b00: state = SEND_0;
                    2'b01: state = SEND_1;
                    2'b10: state = SEND_RES;
                    2'b11: state = SEND_RES;
                    default: state = SEND_0;
                endcase
            SEND_RES:
                state = WAIT_TRST;
            SEND_0:
                state = WAIT_TH;
            SEND_1:
                state = WAIT_TH;
            WAIT_TH:
                if(z)
                    state = SEND_PER;
                else
                    state = WAIT_TH;
            SEND_PER:
                state = WAIT_T;
            WAIT_T:
                if(z)
                    state = END_SEND;
                else
                    state = WAIT_T;
            WAIT_TRST:
                if(z)
                    state = END_SEND;
                else
                    state = WAIT_TRST;
            END_SEND:
                state = START;
            default:
                state = START;
        endcase
    end
end

always @(* ) begin
    case (state)
        START: begin
            dout    <= 0;
            done    <= 0;
            rst     <= 1;
            inc     <= 0;
            sel_tim <= 1;
        end
        CHK_SEL: begin
            dout    <= 0;
            done    <= 0;
            rst     <= 0;
            inc     <= 0;
            sel_tim <= 0;
        end
        SEND_RES: begin
            dout    <= 0;
            done    <= 0;
            rst     <= 0;
            inc     <= 1;
            sel_tim <= 2;
        end
        SEND_0: begin
            dout    <= 1;
            done    <= 0;
            rst     <= 0;
            inc     <= 1;
            sel_tim <= 0;
        end
        SEND_1: begin
            dout    <= 1;
            done    <= 0;
            rst     <= 0;
            inc     <= 1;
            sel_tim <= 1;
        end
        WAIT_TH: begin
            dout    <= 1;
            done    <= 0;
            rst     <= 0;
            inc     <= 1;
            sel_tim <= (sel==0) ? 1'b0 : 1'b1;
        end
        SEND_PER: begin
            dout    <= 0;
            done    <= 0;
            rst     <= 0;
            inc     <= 1;
            sel_tim <= 3;
        end
        WAIT_T: begin
            dout    <= 0;
            done    <= 0;
            rst     <= 0;
            inc     <= 1;
            sel_tim <= 3;
        end
        WAIT_TRST: begin
            dout    <= 0;
            done    <= 0;
            rst     <= 0;
            inc     <= 1;
            sel_tim <= 2;
        end
        END_SEND: begin
            dout    <= 0;
            done    <= 1;
            rst     <= 0;
            inc     <= 0;
            sel_tim <= 0;
        end
        default: begin
            dout    <= 0;
            done    <= 0;
            rst     <= 0;
            inc     <= 0;
            sel_tim <= 0;
        end
    endcase
end


`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    START     : state_name = "START";
    CHK_SEL   : state_name = "CHK_SEL";
    SEND_RES  : state_name = "SEND_RES";
    SEND_0    : state_name = "SEND_0";
    SEND_1    : state_name = "SEND_1";
    WAIT_TRST : state_name = "WAIT_TRST";
    WAIT_TH   : state_name = "WAIT_TH";
    SEND_PER  : state_name = "SEND_PER";
    WAIT_T    : state_name = "WAIT_T";
    END_SEND  : state_name = "END_SEND";
  endcase
end
`endif


endmodule
