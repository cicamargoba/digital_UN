# CH32V203 → Gowin GW2AR-18 por SSPI

Este directorio contiene el módulo para que un CH32V203 programe la flash
externa W25Q16JV de la FPGA Gowin `GW2AR-LV18EQ144PC8` mediante SSPI.

El programa inicial incluido en `main.c` ejecuta únicamente una prueba de
detección: lee el JEDEC ID de la flash y lo envía por el puerto serial USB.

## Arquitectura

```text
PC → USB → CH32V203 → SSPI → GW2AR-18 → MSPI → W25Q16JV
```

Secuencia implementada:

1. `MODE[2:0] = 001` y pulso en `RECONFIG_N`.
2. Espera de `READY`.
3. Lectura de ID y estado de la FPGA.
4. Comando Gowin `0x16 0x00` para encaminar SSPI hacia la flash MSPI.
5. Lectura del JEDEC ID con `0x9F`.
6. Borrado por sectores de 4 KiB.
7. Programación por páginas de hasta 256 bytes.
8. Verificación byte a byte.
9. `MODE[2:0] = 000`, pulso en `RECONFIG_N` y espera de `DONE`.

## Archivos

- `gowin_sspi_flash.c`: secuencia Gowin y acceso JEDEC a la W25Q16JV.
- `gowin_sspi_flash.h`: API pública y callback de lectura de imagen.
- `gowin_sspi_platform.h`: interfaz que debe implementar el HAL del CH32V203.
- `board_config.h`: única tabla para asignar los GPIO del CH32V203.
- `main.c`: prueba periódica de detección y reporte del JEDEC ID.
- `Makefile`: compila el módulo como biblioteca estática RISC-V.

Salida esperada por USB CDC:

```text
FPGBC flash probe
FLASH JEDEC ID: EF 40 15
```

Para una W25Q16JV, `EF` identifica Winbond y `15` corresponde a 16 Mbit.

## Compilación del módulo

Requiere un toolchain RISC-V bare-metal. Por defecto usa
`riscv64-unknown-elf-gcc`, generando código RV32:

```bash
make
```

Para el toolchain de WCH:

```bash
make CROSS_COMPILE=riscv-none-elf-
```

El resultado es:

```text
build/libgowin_sspi_flash.a
```

También están disponibles:

```bash
make check
make clean
```

## Programación con WCH-LinkE

El `Makefile` incluye el objetivo `program` para grabar el CH32V203 mediante
un programador WCH-LinkE y la herramienta `wlink`:

```bash
make program
```

Por defecto programa:

```text
build/firmware.bin
```

en la dirección:

```text
0x08000000
```

Es posible cambiar ambos parámetros:

```bash
make program PROGRAM_FILE=ruta/firmware.bin FLASH_ADDRESS=0x08000000
```

La herramienta también puede seleccionarse explícitamente:

```bash
make program WLINK=/ruta/a/wlink
```

Versión verificada en este sistema:

```text
wlink 0.1.2
```

## Integración pendiente

Este módulo todavía no es una imagen de firmware autónoma. La aplicación del
CH32V203 debe implementar las funciones declaradas en
`gowin_sspi_platform.h`:

```c
void gowin_gpio_write(uint32_t pin, bool value);
bool gowin_gpio_read(uint32_t pin);
void gowin_delay_us(uint32_t us);
void gowin_delay_ms(uint32_t ms);
uint8_t gowin_spi_xfer(uint8_t tx);
```

La compilación genera una imagen ejecutable en `build/firmware.bin`. La lectura
SSPI queda bloqueada hasta completar la asignación de GPIO en
`board_config.h`.
La recepción progresiva del archivo `.fs` no forma parte de esta prueba.
Los valores `PIN_*` son identificadores abstractos, no pines físicos del
CH32V203.

Las señales desconocidas tienen `*_ASSIGNED` igual a `0`. Para asignarlas,
se cambia el indicador a `1` y se definen `*_PORT` y `*_PIN`. Mientras la
configuración esté incompleta, el firmware no ejecuta SSPI y reporta:

```text
ERROR: SSPI PIN CONFIG INCOMPLETE
```

## Conexiones lógicas

```text
CH32 SPI_SCK   → FPGA SCLK
CH32 SPI_MOSI  → FPGA SI
CH32 SPI_MISO  ← FPGA SO
CH32 GPIO      → FPGA SSPI_CS_N
CH32 GPIO      → FPGA RECONFIG_N
CH32 GPIO      → FPGA MODE0
CH32 GPIO      → FPGA MODE1
CH32 GPIO      → FPGA MODE2
CH32 GPIO      ← FPGA READY
CH32 GPIO      ← FPGA DONE
```

La flash observada en la FPGBC está conectada a la FPGA así:

```text
FPGA 93  MCLK  → Flash SCK
FPGA 94  MCS_N → Flash CS_N
FPGA 95  MO    → Flash SI/MOSI
FPGA 96  MI    ← Flash SO/MISO
```

## Primera prueba de hardware

La secuencia `0x16 0x00` y el puente SSPI→MSPI todavía requieren validación
física. La primera captura con analizador lógico debe comprobar:

```text
CS low
16 00
CS high

CS low
9F
leer tres bytes
CS high
```

Se debe rechazar un JEDEC ID igual a `00 00 00` o `FF FF FF`.
