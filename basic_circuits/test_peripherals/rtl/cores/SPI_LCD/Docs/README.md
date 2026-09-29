# SPI_LCD — Controlador SPI para LCD (OLED/TFT)

**Estado:** Diseño en curso (arquitectura definida, RTL pendiente)
**Fecha:** 2026-09-20
**Diagrama de bloques:** `spiLCD.pdf` (este directorio, versión con bits DC/DELAY de INIT_MEM)
**Flowchart:** `flowchart_spilcd.svg` (este directorio)

## Objetivo

Controlador FPGA para displays SPI (ST7789, ILI9341/ILI9340). Envía la secuencia de
inicialización desde una ROM interna y luego transmite el framebuffer en loop continuo
vía DMA.

## Arquitectura

```
RESET
  │
  ▼
INIT_MEM[A_COUNT] ──► SPI_TX     fase 1: init (una pasada)
  │
  ▼ (INIT_MEM terminado)
{1, 0xDC} ──► SPI_TX             fase 2: comando Memory Write (una vez)
  │
  ▼
┌─────────────────────────────┐
│ loop continuo:              │
│ DMA ──► converter ──► SPI_TX │  fase 3: framebuffer
│ (SRC_VALID/SRC_LAST/SRC_RDY) │
└─────────────────────────────┘
```

### Bloques

| Bloque | Función |
|---|---|
| CRTL (FSM) | Máquina de estados maestra: in RESTART, DONE_DELAY, ST_DELAY, SRC_LAST, SRC_VALID, DONE_TX; out RST, INIT_TX, SEL_DATA, INC_ADDR, RST_ALL, S_DELAY, SRC.RDY |
| SPI_TX | Transmisor serial, entrada DATA[8:0] (DC + byte), salida DONE_TX |
| D_COUNT | Contador de delay; carga el valor directamente desde INIT_MEM[7:0] |
| A_COUNT | Contador de direcciones de INIT_MEM |
| INIT_MEM | ROM de comandos de inicialización, 10 bits por entrada; selector por define LCD_ST7789 / LCD_ILI9341 / LCD_GC9A01 / LCD_ILI9488 |
| Mux 3→1 | SEL_DATA: 0=INIT_MEM, 1={1,0xDC}, 2=converter |
| converter 32→8 | Convierte palabras de 32 bits del DMA a bytes |
| LiteDRAMDMAReader | DMA externo, CSR: base, length, enable, loop, done, offset; stream SRC_VALID/SRC_LAST/SRC.RDY |

### Salidas al display: RST, CS (fijo 0), DC, SCK, SDI

## Codificación INIT_MEM (10 bits)

| Bit | Significado |
|---|---|
| [9] | 0 = comando SPI, 1 = delay |
| [8] | DC (solo si bit[9]=0) |
| [7:0] | Dato: comando SPI o unidades de delay |

El FSM examina bit[9] para decidir si la entrada se envía por SPI o si carga
D_COUNT y espera DONE_DELAY.

## Variantes de controlador (defines)

`init_mem.v` es un selector: con `-DLCD_<VARIANTE>` en iverilog incluye la ROM
correspondiente. Sin define, usa ST7789. `init_defs.vh` define `LCD_INIT_MAX`
(conteo de entradas) para el parámetro INIT_MAX del top; el TB ya no lo fija.

| Define | Display | Entradas | Fuente de la secuencia |
|---|---|---|---|
| `LCD_ST7789` (default) | ST7789 240x320 | 82 | TFT_eSPI ST7789_Init.h (JLX240) |
| `LCD_ILI9341` | ILI9341/ILI9340 | 87 | TFT_eSPI ILI9341_Init.h |
| `LCD_GC9A01` | GC9A01 redondo 240x240 | 188 | Secuencia del panel (coincide con TFT_eSPI GC9A01_Init.h; B6=00 00, MADCTL=0x08) |
| `LCD_ILI9488` | ILI9488 | 68 | TFT_eSPI ILI9488_Init.h (0x3A=0x66 SPI) |

Archivos: `init_mem_<variante>.vh` (ROMs), `init_defs.vh` (LCD_INIT_MAX),
`init_mem.v` (selector con ifdef/include), `gen_init_mem.py` (generador +
verificador `--check <VARIANTE> sim.log`).

Simulación: `make sim LCD=GC9A01` (compila, corre, deja `sim.log` y VCD).
Verificación: `python3 gen_init_mem.py --check GC9A01 sim.log` compara byte a
byte init + 0xDC + stream contra la secuencia fuente. Las 4 variantes verificadas.

## Comportamiento CS y DC

- **CS fijo en 0 (decisión 2026-09-21).** El controlador mantiene CS=0 durante toda la
  operación — inicialización, delays y stream de video. Con CS atado a bajo, el panel
  no necesita flancos de CS para ejecutar comandos; el contexto comando/parámetro lo
  lleva DC. Por tanto CS no es una señal de control del FSM: el top la fija a 0
  (`assign lcd_cs = 1'b0;`) y el pin físico del panel va a GND.
- **ST7789:** con CS atado a GND requiere SPI Mode 3 (CPOL=1, CPHA=1) y SCK alto en idle.
- **ILI9340 ≈ ILI9341** en protocolo SPI; diferencias son de features, no de interface.
- **0xDC (Memory Write):** se envía una sola vez. El controlador auto-incrementa el
  puntero de memoria con cada byte DC=1. No se re-envía por frame.
- **DC = DATA[9]** en el bus hacia SPI_TX (bit 8 de INIT_MEM tras el flag de delay).

## Delays de inicialización

Cada comando tiene tiempo de ejecución interno (datasheet). Ejemplos ST7789:
SWRESET (0x01) → 120 ms, SLPOUT (0x11) → 120 ms, resto → 0 ms. La codificación
bit[9]=1 permite insertar entradas de delay entre comandos que lo requieren.

## Loop de video

Después de 0xDC, el FSM entra en loop infinito:
espera SRC_VALID → transmite byte (DC=1) → DONE_TX → siguiente.
Al SRC_LAST termina la pasada y el DMA (modo loop) reinicia el framebuffer.
Cambios en video_mem se reflejan automáticamente en la siguiente pasada —
no se re-envía 0xDC ni la inicialización.

## Archivos

- `spiLCD.pdf` — diagrama de bloques (incluye codificación DC=DATA[8], DELAY=DATA[9])
- `flowchart_spilcd.svg` — diagrama de flujo del FSM

## Pendiente antes del RTL

- Unificar nombre del handshake del converter: `SRC.RDY` (diagrama de bloques) vs `SRC_RDY` (flowchart/DMA). Usar un solo nombre.
