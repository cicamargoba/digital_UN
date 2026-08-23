module ctrl_wsled (
    input clk,
    input reset,
    input init,
    input done_t,
    input z,
    output reg sh,
    output reg init_t,
    output reg dec,
    output reg ld,
    output reg done
);


 parameter START     = 3'b000;
 parameter CHK_SEL   = 3'b001;
 parameter SEND_BIT  = 3'b010;
 parameter WAIT_TX   = 3'b011;
 parameter SHIFT     = 3'b100;
 parameter CHECK_END = 3'b101;
 parameter END_SEND  = 3'b110;

reg [2:0] state;

always @(negedge clk ) begin
    if (reset) begin
        state = START;
    end else begin
        case (state)
            START:
                if(init)
                    state = CHK_SEL;
                else
                    state = START;
            CHK_SEL:
                state = SEND_BIT;
            SEND_BIT:
                state = WAIT_TX;
            WAIT_TX:
                if(done_t)
                    state = SHIFT;
                else
                    state = WAIT_TX;
            SHIFT:
                state = CHECK_END;
            CHECK_END:
                if(z)
                    state = END_SEND;
                else
                    state = CHK_SEL;
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
            sh     <= 0;
            init_t <= 0;
            dec    <= 0;
            ld     <= 1;
            done   <= 0;
        end
        CHK_SEL: begin
            sh     <= 0;
            init_t <= 1;
            dec    <= 0;
            ld     <= 0;
            done   <= 0;
        end
        SEND_BIT: begin
            sh     <= 0;
            init_t <= 0;
            dec    <= 0;
            ld     <= 0;
            done   <= 0;
        end
        WAIT_TX: begin
            sh     <= 0;
            init_t <= 0;
            dec    <= 0;
            ld     <= 0;
            done   <= 0;
        end
        SHIFT: begin
            sh     <= 1;
            init_t <= 0;
            dec    <= 1;
            ld     <= 0;
            done   <= 0;
        end
        CHECK_END: begin
            sh     <= 0;
            init_t <= 0;
            dec    <= 0;
            ld     <= 0;
            done   <= 0;
        end
        END_SEND: begin
            sh     <= 0;
            init_t <= 0;
            dec    <= 0;
            ld     <= 0;
            done   <= 1;
        end
        default: begin
            sh     <= 0;
            init_t <= 0;
            dec    <= 0;
            ld     <= 0;
            done   <= 0;
        end

    endcase
end

`ifdef BENCH
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    START     : state_name = "START";
    CHK_SEL   : state_name = "CHK_SEL";
    SEND_BIT  : state_name = "SEND_BIT";
    WAIT_TX   : state_name = "WAIT_TX";
    SHIFT     : state_name = "SHUFT";
    CHECK_END : state_name = "CHECK_END";
    END_SEND  : state_name = "END_SEND";
  endcase
end
`endif
endmodule
