module text_mix (
    input  [23:0] img,
    input  [23:0] txt,
    input         txt_on0,
    input         txt_on1,
    output [23:0] data
);
assign data[23:12] = txt_on0 ? txt[23:12] : img[23:12];
assign data[11:0] = txt_on1 ? txt[11:0] : img[11:0];
endmodule
