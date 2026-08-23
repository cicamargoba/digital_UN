module ws2812 (
    input        clk,
    input        reset,
    input        init_t,
    input [1:0]  sel,
    output       dout,
    output       done_t
);

parameter fcia = 25000000;
parameter T0H = 11'd10;
parameter T1H = 11'd20;
parameter PER = 11'd31;
parameter RES = 11'd1250;

wire rst;
wire inc;
wire  [1:0] sel_tim;
wire z;
wire [10:0] count_out;
wire [10:0] mux_out;


count_ws  count0 ( .clk(clk), .rst(rst), .inc(inc), .cnt_out(count_out) );
comp_ws   comp0  ( .in1(mux_out), .in2(count_out), .z(z) );
mux_ws    mux0   ( .in1(T0H), .in2(T1H), .in3(RES), .in4(PER), .sel(sel_tim), .y(mux_out) );
ctrl_ws   ctrl0  ( .clk(clk), .reset(reset), .init_t(init_t), .sel(sel), .z(z), 
                   .dout(dout), .done(done_t), .rst(rst), .inc(inc), .sel_tim(sel_tim) );

endmodule
