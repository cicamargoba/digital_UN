module spi_tx #(
    parameter CLK_DIV = 4
)(
    input            clk,
    input            rst,
    input            init_tx,
    input      [8:0] data,
    output           dc,
    output           sck,
    output           sdi,
    output           done_tx
);
wire sh;
wire rst_all;
wire inc_cbyte;
wire st_div;
wire done_div;
wire end_byte;
ctrl_spi #(
    .CLK_DIV (CLK_DIV)
) CRTL_SPI (
    .clk       (clk),
    .rst       (rst),
    .init_tx   (init_tx),
    .done_div  (done_div),
    .end_byte  (end_byte),
    .sh        (sh),
    .rst_all   (rst_all),
    .inc_cbyte (inc_cbyte),
    .st_div    (st_div),
    .clk_out   (sck),
    .done_tx   (done_tx)
);
lsr LSR (
    .clk     (clk),
    .rst     (rst),
    .ld      (rst_all),
    .sh      (sh),
    .data_tx (data[7:0]),
    .sdi     (sdi)
);
byte_cnt BYTE_CNT (
    .clk (clk),
    .rst (rst | rst_all),
    .inc (inc_cbyte),
    .z   (end_byte)
);
f_div #(
    .CLK_DIV (CLK_DIV)
) F_DIV (
    .clk      (clk),
    .rst      (rst),
    .start    (st_div),
    .done_div (done_div)
);
assign dc = data[8];
endmodule
