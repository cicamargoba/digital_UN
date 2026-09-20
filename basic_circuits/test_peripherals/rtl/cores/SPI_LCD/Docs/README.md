# SPI_LCD — Controlador SPI para LCD (OLED/TFT)

**Estado:** Diseño en curso (arquitectura definida, RTL pendiente)
**Fecha:** 2026-09-20
**Diagrama de bloques:** `spiLCD.pdf` (original de Carlos, en `~/Downloads`)
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
| CRTL (FSM) | Máquina de estados maestra |
| SPI_TX | Transmisor serial, entrada DATA[9:0], salida DONE_TX |
| D_COUNT | Contador de delay (para comandos que requieren espera) |
| A_COUNT | Contador de direcciones de INIT_MEM |
| INIT_MEM | ROM de comandos de inicialización, 10 bits por entrada |
| Mux 3→1 | SEL_DATA: 0=INIT_MEM, 1={1,0xDC}, 2=converter |
| converter 32→8 | Convierte palabras de 32 bits del DMA a bytes |
| LiteDRAMDMAReader | DMA externo, CSR: base, length, enable, loop, done, offset; stream SRC_VALID/SRC_LAST/SRC.RDY |

### Salidas al display: RST, CS, DC, SCK, SDI

## Codificación INIT_MEM (10 bits)

| Bit | Significado |
|---|---|
| [9] | 0 = comando SPI, 1 = delay |
| [8] | DC (solo si bit[9]=0) |
| [7:0] | Dato: comando SPI o unidades de delay |

El FSM examina bit[9] para decidir si la entrada se envía por SPI o si carga
D_COUNT y espera DONE_DELAY.

## Comportamiento CS y DC

- **CS puede subir entre bytes** — ST7789, ILI9341 e ILI9340 usan DC para distinguir
  comando de parámetro; no dependen de CS para el contexto. En ST7789, alternar CS
  re-sincroniza el alineamiento de bytes.
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

- `flowchart_spilcd.svg` — diagrama de flujo del FSM
- Referencia original: `spiLCD.pdf` (block diagram, 1 página)
