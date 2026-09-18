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
- `platform_ch32v203.c`: GPIO, bit-bang SSPI y USB CDC para el CH32V203.
- `Makefile`: construye la imagen ejecutable completa para el CH32V203.

Salida esperada por USB CDC:

```text
FPGBC flash probe
FLASH JEDEC ID: EF 40 15
```

Para una W25Q16JV, `EF` identifica Winbond y `15` corresponde a 16 Mbit.

## Base DAPLink utilizada

El firmware reutiliza el soporte para CH32V203 disponible en:

```text
https://github.com/XIVN1987/DAPLink
```

DAPLink se descarga al directorio hermano `../DAPLink` ejecutando:

```bash
make daplink
```

El `Makefile` comprueba si ya existe:

```text
../DAPLink/CH32V203/link.ld
```

Si no existe `../DAPLink`, ejecuta el equivalente a:

```bash
git clone https://github.com/XIVN1987/DAPLink.git ../DAPLink
```

De `DAPLink/CH32V203` se utilizan:

- `link.ld`: mapa de memoria del CH32V203.
- `src/Startup/`: startup, vectores, inicialización del reloj y soporte RISC-V.
- `src/Peripheral/`: biblioteca de periféricos de WCH.
- `src/USBLib/`: pila USB device.
- `src/USBUsr/`: descriptores y control USB usados por la interfaz CDC.

No se está construyendo la aplicación CMSIS-DAP original. DAPLink se usa como
**SDK/base de hardware del CH32V203**; `main.c`, la lectura SSPI y la salida USB
CDC pertenecen a esta aplicación.

La ubicación y el repositorio pueden cambiarse sin editar el `Makefile`:

```bash
make DAPLINK_DIR=/ruta/DAPLink
make daplink DAPLINK_REPO=https://github.com/XIVN1987/DAPLink.git
```

## Construcción de `firmware.bin`

Requiere un toolchain RISC-V bare-metal. Por defecto usa
`riscv64-unknown-elf-gcc`, generando código RV32:

```bash
make daplink
make
```

El proceso ejecutado por `make` es:

```text
Fuentes locales C
  + startup/periféricos/USB de DAPLink/CH32V203
  + DAPLink/CH32V203/link.ld
                    │
                    ▼
        riscv64-unknown-elf-gcc
                    │
                    ▼
          build/firmware.elf
                    │
                    ▼
 riscv64-unknown-elf-objcopy -O binary
                    │
                    ▼
          build/firmware.bin
```

El archivo ELF conserva símbolos e información de depuración. `objcopy`
extrae únicamente la imagen binaria que se graba en la flash del CH32V203.

Para el toolchain de WCH:

```bash
make CROSS_COMPILE=riscv-none-elf-
```

El resultado es:

```text
build/firmware.elf
build/firmware.bin
build/firmware.map
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

La imagen ya incluye las funciones de plataforma del CH32V203 declaradas en
`gowin_sspi_platform.h`:

```c
void gowin_gpio_write(uint32_t pin, bool value);
bool gowin_gpio_read(uint32_t pin);
void gowin_delay_us(uint32_t us);
void gowin_delay_ms(uint32_t ms);
uint8_t gowin_spi_xfer(uint8_t tx);
```

La lectura SSPI queda bloqueada hasta completar la asignación de GPIO en
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
