# SPI LCD con memoria interna

LCD: Waveshare 1.28inch LCD Module, controlador **GC9A01**, resolución **240×240**, pantalla circular.

Referencia: https://www.waveshare.com/wiki/1.28inch_LCD_Module

## Pinout para iCEBreaker

Se utilizan los pines del conector del panel LED definidos en `../Led_panel_12bpp/led_panel_icebreaker.pcf`.

Los números de la tabla corresponden a los pines del encapsulado de la FPGA, no a posiciones del conector.

| Pin del LCD | Señal RTL | Pin FPGA | Señal del panel LED |
|---|---|---:|---|
| CLK | `lcd_sck` | 32 | `LP_CLK` |
| DIN | `lcd_sdi` | 4 | `RGB0[0]` |
| DC | `lcd_dc` | 36 | `LATCH` |
| CS | `lcd_cs` | 42 | `NOE` |
| RST | `lcd_rst` | 43 | `ROW[0]` |

Restricciones: `spi_lcd_icebreaker.pcf`.

### Alimentación y retroiluminación

- VCC del módulo: conectar a 3.3 V.
- GND del módulo: conectar a GND de iCEBreaker.
- BL: entrada de control de retroiluminación; no tiene señal asignada en el RTL ni en el PCF. Para retroiluminación permanente, conectar a 3.3 V.
- Las señales de la FPGA utilizan niveles de 3.3 V.

### Reloj y reset de la FPGA

| Señal RTL | Pin FPGA | Función |
|---|---:|---|
| `clk` | 35 | Reloj de iCEBreaker, 12 MHz |
| `rst` | 10 | Reset del controlador |

`rst` es la entrada de reset del controlador; `lcd_rst` es la salida de reset hacia el LCD. No son la misma señal.

## Estado de verificación

- Síntesis, ruteo y generación de bitstream para iCEBreaker verificados con la imagen de prueba de 16 bytes (`VID_AW=4`, `video_mem_init_TB.hex`).
- El pinout no ha sido validado físicamente con el LCD.
- El framebuffer completo de 240×240 no ha sido verificado. En RGB565 requiere 115 200 bytes.
