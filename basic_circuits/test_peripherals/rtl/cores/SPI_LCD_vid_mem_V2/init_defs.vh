`ifdef LCD_ST7789
`define LCD_INIT_MAX 82
`elsif LCD_ILI9341
`define LCD_INIT_MAX 87
`elsif LCD_GC9A01
`define LCD_INIT_MAX 186
`elsif LCD_ILI9488
`define LCD_INIT_MAX 68
`else
`define LCD_INIT_MAX 82
`endif
