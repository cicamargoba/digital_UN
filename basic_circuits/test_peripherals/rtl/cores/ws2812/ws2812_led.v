module ws2812_led (
    input        reset,
    input        clk,
    input [23:0] rgb,
    input        init,
    input        rst_cmd,
    output       dout,
    output       done
);

wire        sh;
wire        init_t;
wire [1:0]  sel;
wire        dec;
wire        ld;
wire        z;
wire        done_t;
wire [23:0] s_A;

lsr_wsled    lsr0    ( .clk(clk), .in_A(rgb), .load(ld), .shift(sh), .s_A(s_A) );
count_wsled  count0  ( .clk(clk), .ld(ld), .dec(dec), .z(z) );
ws2812       ws28120 ( .clk(clk), .reset(reset), .init_t(init_t), .sel({rst_cmd, s_A[23]}), .dout(dout), .done_t(done_t) );
ctrl_wsled   control0( .clk(clk), .reset(reset), .init(init), .done_t(done_t), .z(z),
                        .sh(sh), .init_t(init_t), .dec(dec), .ld(ld), .done(done) );

endmodule
