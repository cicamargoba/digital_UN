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

`ifdef LCD_ILI9488
`define LCD_WIDTH 320
`define LCD_HEIGHT 480
`define LCD_BYTES_PER_PIXEL 3
`elsif LCD_GC9A01
`define LCD_WIDTH 240
`define LCD_HEIGHT 240
`define LCD_BYTES_PER_PIXEL 2
`else
`define LCD_WIDTH 240
`define LCD_HEIGHT 320
`define LCD_BYTES_PER_PIXEL 2
`endif

`ifndef LCD_CLK_HZ
`define LCD_CLK_HZ 12000000
`endif

`ifndef LCD_ROW_MODE
`define LCD_ROW_MODE 1
`endif
