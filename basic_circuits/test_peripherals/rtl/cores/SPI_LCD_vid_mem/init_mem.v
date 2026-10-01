`ifdef LCD_ST7789
`include "init_mem_st7789.vh"
`elsif LCD_ILI9341
`include "init_mem_ili9341.vh"
`elsif LCD_GC9A01
`include "init_mem_gc9a01.vh"
`elsif LCD_ILI9488
`include "init_mem_ili9488.vh"
`else
`include "init_mem_st7789.vh"
`endif
