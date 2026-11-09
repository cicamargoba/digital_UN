# Periférico HUB75 para femtoRV e iCEBreaker

## Integración

`perip_led_panel.v` implementa `peripheral_led_panel`, siguiendo la interfaz del multiplicador: `clk`, `reset`, `d_in[31:0]`, `cs`, `addr[4:0]`, `rd`, `wr` y `d_out[31:0]`. El periférico comprende los registros y el controlador completo: imagen, texto, sprites, mezcla, barrido y salidas HUB75.

En [`SOC.v`](../../../SOC.v), la instancia `led_panel0` ocupa **`0x00470000`**, consecutiva a `0x00460000`, mediante `cs[8]`. El chip-select tiene nueve bits y el mux devuelve `led_panel_dout` al leer este rango. Las instancias de multiplicador, binario→BCD y BCD→binario están comentadas para esta prueba del panel; sus direcciones siguen en el decodificador y no deben utilizarse. Sus salidas, junto con otras direcciones reservadas sin instancia, pueden producir advertencias de señales sin driver.

| Dirección | Registro | Bits |
|---|---|---:|
| `0x00470004` | `TEXT_ADDR` | 6 |
| `0x00470008` | `TEXT_DATA` | 15 |
| `0x0047000C` | `SPRITE_ADDR` | 3 |
| `0x00470010` | `SPRITE_DATA` | 26 |
| `0x00470014` | `TEXT_WE` | 1 |
| `0x00470018` | `SPRITE_WE` | 1 |

```text
TEXT_DATA[14:0] = {fondo[3:0], frente[3:0], carácter[6:0]}
SPRITE_DATA[25:0] = {enable, color[3:0], patrón[4:0], Y[7:0], X[7:0]}
```

El reset activo alto pone los seis registros en cero. `cs && wr` habilita las escrituras; `cs && rd` devuelve el registro seleccionado, extendido con ceros. No se implementa lectura de las memorias por este bus.

Los registros de dirección, dato y WE conservan su valor, como los CSRStorage del ejemplo LiteX. Para escribir: desactivar el WE correspondiente, cargar dirección y dato, activar WE durante al menos un flanco descendente de `clk1` y desactivarlo antes de cambiar dirección o dato. La duración debe cubrir el flanco con margen; no existe reconocimiento automático. Con WE activo la memoria puede repetir la misma escritura. WE no controla transparencia.

`led_panel_4k.v` mantiene `CPU_CONTROL=0` por defecto para conservar la demostración. El wrapper selecciona `CPU_CONTROL=1`, conecta los puertos CPU y sustituye al cargador de descriptores `sprite_demo`. La imagen continúa inicializada mediante `memory_V2.v` desde `image0.hex` e `image1.hex`; las fuentes, patrones y paletas permanecen inicializados desde archivos. La prioridad sigue siendo sprite > texto > imagen.

Diagramas de arquitectura: [general](femtorv_led_panel_peripheral.svg) y [registros](femtorv_led_panel_registers.svg). Sus rótulos de propuesta no acreditan validación física.

## Memoria de programa y CPU

[`cores/bram/bram.v`](../../bram/bram.v) se redujo de 2048 a **1024 palabras de 32 bits: 4 KiB**. El firmware previsto solo comprobará texto y sprites. El firmware y el linker todavía deben adaptarse a ese límite: el `firmware.hex` utilizado durante estas pruebas excede 1024 palabras y genera una advertencia. Que la simulación termine no demuestra que ese firmware sea válido para 4 KiB.

El banco de registros de [`femtorv32_quark_un_irq.v`](../../cpu/femtorv32_quark_un_irq.v) se modificó para permitir RAM de bloque:

- Un solo puerto de escritura; se elimina la escritura permanente de `x0`.
- Dos lecturas síncronas directas hacia `rs1_ram` y `rs2_ram`, habilitadas al capturar la instrucción, sin reset del dato de RAM.
- Dos indicadores registrados seleccionan cero después de la lectura cuando el operando es `x0`; esos indicadores sí se inicializan con reset.
- No se añade un estado ni un ciclo de ejecución.

La primera variante, con selección de cero antes del registro de lectura, **no** infirió RAM. La variante final sí: Yosys informa `mapping memory SOC.CPU.registerFile via $__ICE40_RAM4K_`.

| CPU aislada, mismo flujo `synth_ice40 -dsp` | Variante intermedia sin RAM | Variante final |
|---|---:|---:|
| LUT4 | 2880 | 1104 |
| Flip-flops | 1272 | 216 |
| RAM4K | 0 | 4 |

La copia exacta original, anterior a ambas modificaciones, se conserva junto a la CPU: [`femtorv32_quark_un_irq_before_regfile_ram.v.bak`](../../cpu/femtorv32_quark_un_irq_before_regfile_ram.v.bak). No se incluye en las fuentes de compilación. Para revertir, restaurar su contenido sobre el `.v` activo, previa autorización; no añadir ambos archivos a la compilación.

## Restricciones por placa

[`SOC_icebreaker.pcf`](../../../SOC_icebreaker.pcf) conserva reloj, reset, LED y UART existentes y añade:

| Señal | Pin |
|---|---:|
| `interrupt_request` | 39 |
| `LP_CLK`, `LATCH`, `NOE` | 32, 36, 42 |
| `ROW[0]`…`ROW[4]` | 43, 38, 34, 31, 28 |
| `RGB0[0]`…`RGB0[2]` | 4, 2, 47 |
| `RGB1[0]`…`RGB1[2]` | 3, 48, 46 |

El reset permanece en el pin 10. El pin 39 de interrupción fue elegido explícitamente por Carlos; no se ha verificado aquí su conexión física a un pulsador. No se ha añadido sincronización ni antirrebote a esa entrada.

[`SOC.lpf`](../../../SOC.lpf) incorpora las 14 señales HUB75 de `led_panel_4k.lpf` para el flujo ECP5; no es el archivo de restricciones de iCEBreaker. Las asignaciones PCF se aceptaron en nextpnr sin permitir pines sin restricción.

## Makefile y simulación

El [`Makefile` del SoC](../../../Makefile) incorpora las fuentes del panel y prepara sus siete archivos de inicialización en el directorio RTL. Las copias son archivos de trabajo; sus fuentes se mantienen en este core.

`sim_quark` selecciona explícitamente el top `bench` con Icarus (`-g2012 -DBENCH -s bench`). Guarda ejecutable y VCD bajo `build/sim_quark/`, sin borrar `a.out` ni capturas anteriores. GTKWave abre **`build/sim_quark/bench.vcd`**, no el `bench.vcd` antiguo de la raíz. `SIM_QUARK_BUILD_DIR` y `GTKWAVE` son configurables.

[`bench_quark.v`](../../../bench_quark.v) deja la interrupción externa en cero, admite `+VCD=...` y limita el volcado de las últimas palabras de BRAM a los índices 1020…1023. El acceso previo a `MEM[1024]`, fuera de rango tras reducir la memoria, reproducía un aborto interno de `vvp` y dejaba un VCD truncado sin `$enddefinitions`.

La prueba específica del wrapper sigue en `perip_led_panel_TB.v` y `Makefile.peripheral`; `perip_led_panel.gtkw` muestra bus, registros, puertos de escritura y las 64 celdas de texto y ocho descriptores. Sus resultados quedan en `build/peripheral/`.

## Verificación y límites

Pruebas realizadas el 29 de octubre de 2026:

- Wrapper: **4290 comprobaciones** aprobadas, incluyendo escritura de texto y sprites, readback e imagen intacta. Las 108 señales del `.gtkw` se contrastaron con el VCD.
- Integración inicial por inyección de transacciones en el bus del SoC: **2203 comprobaciones** aprobadas. No equivale a ejecutar firmware del panel.
- CPU final frente a la variante intermedia: comparación ciclo a ciclo durante **2653 ciclos**, con **97 escrituras**, esperas de memoria, `x0`, ALU, cargas/almacenamientos, saltos y CSR; sin diferencias en esa prueba. Interrupciones no ejercitadas en esta comparación. Prueba aislada temporal, no incorporada como regresión del repositorio.
- `make sim_quark GTKWAVE=true`: finaliza por `$finish` sin aborto. GTKWave abre la captura nueva. El firmware actual no queda validado por ello.
- SoC actual tras síntesis y **empaquetado únicamente**: **3584/5280 LC**, **28/30 RAM4K**, **20 IO** y **8/8 recursos globales**. No es una comprobación de colocación, ruteo ni timing.

No se ha validado físicamente esta integración ni programado la placa en este trabajo. Siguen pendientes el firmware de prueba para 4 KiB, la colocación/ruteo y la validación del panel en hardware.

## Firmware de prueba del panel — 2026-11-09

`firmware/asm/panel_test.S`, relativo a `test_peripherals/`, inicializa la pila en `0x1000`, borra las 64 celdas de texto y los ocho descriptores y escribe **HOLA** en las celdas 10…13, con frente blanco y fondo transparente. El sprite 0 usa el patrón 0, color 14, Y=40 y recorre X=0…56 de ida y vuelta. El resto de sprites queda deshabilitado. La imagen, fuentes, patrones, paletas y RTL no se modifican.

El target `panel_firmware` del Makefile de ensamblador genera su propio linker y ELF en `build/panel/`, limita la memoria a 4 KiB y copia el resultado a `rtl/firmware.hex`. No modifica la fuente ni los targets de la calculadora. El firmware ocupa **276 bytes (69 palabras)**, sin datos ni pila dinámica en esta prueba. No utiliza UART ni habilita interrupciones. Con la toolchain disponible se compiló usando `CROSS=riscv64-unknown-elf`, con ISA RV32I y ABI ILP32.

`PANEL_FRAME_DELAY=100000` es el retardo de movimiento de la versión para la placa. Se utilizó `PANEL_FRAME_DELAY=16` para simular el recorrido completo mediante `panel_firmware_TB.v`, compilado como top con las fuentes del SoC y ejecutado desde el directorio RTL. La prueba comprueba HOLA, los pasos de una columna, los cambios de dirección, la deshabilitación del resto de sprites, la conservación de la imagen y la ausencia de accesos fuera de la BRAM. La simulación acelerada aprobó **29183 comprobaciones y 115 posiciones del sprite**. Después se regeneró e instaló la imagen con retardo normal. El argumento `+UPDATES=1` permite comprobar el arranque de esa imagen sin esperar el recorrido completo.

El `firmware.hex` actual corresponde a esta prueba; la advertencia histórica de exceso de memoria de la calculadora no describe esta imagen. El bitstream todavía debe reconstruirse para incorporar el firmware nuevo. No se programó la placa ni se validó físicamente el resultado en este paso.

### Ampliación a tres sprites

El firmware mantiene el sprite 0 móvil en Y=40 y añade dos descriptores fijos: un invasor en el slot 1, patrón 4, color 10, posición (28,24), y un cañón en el slot 2, patrón 1 existente, color 6, posición (28,56). El patrón 4 de `sprite_demo_patterns.mem` utiliza las ocho filas `18 3C 7E DB FF 24 5A A5`, tomadas del invasor de `sprites.mem`. No se modifica el patrón de la nave ni la paleta. Los slots 3…7 siguen deshabilitados. Las tres cajas de 8×8 están separadas verticalmente durante todo el recorrido de la nave; el testbench comprueba los descriptores adicionales, el patrón del invasor y la ausencia de colisiones.

### Port a C

La misma prueba está en `firmware/c/panel_test.c`, con arranque `panel_start.S`, linker `panel_linker.ld` de 4 KiB y target `panel_firmware` del Makefile C. El ASM se conserva como referencia. El flujo C copia su resultado a `rtl/firmware.hex` y no necesita los periféricos matemáticos ni la librería de impresión. Véase [la documentación del flujo C](../../../../firmware/c/README.md). Tras generar esa imagen, hay que reconstruir el bitstream; compilar C no actualiza por sí solo la flash de la placa.

La variante C fue modificada posteriormente por Carlos para mostrar **HOLA TU** y mover también el cañón en X=2*x; el retardo de escritura de sprites es de 10 iteraciones. Se conserva sin cambiar esos valores. `panel_firmware_TB.v` sigue comprobando la escena anterior de HOLA y cañón fijo y no acredita la variante modificada. `peripheral_registers.h` centraliza ahora el mapa de UART, periféricos matemáticos, BCD y panel, con explicación de campos y ejemplos; centralizarlo no cambió los objetos compilados de la variante C actual ni de `hwmath.c`.

### Disparo y puntaje simulado — versión C posterior

Actualización del proyectil: el patrón 2 pasa a `03 03 03 00 00 00 00 00` (2×3 píxeles), y el descriptor selecciona color 12. La paleta existente asigna `00F` lógico a ese índice para compensar el intercambio físico rojo/azul registrado en esta prueba y obtener rojo en el panel. Esta actualización sustituye al proyectil blanco inicial descrito abajo; no modifica otros patrones ni colores. El testbench comprueba las ocho filas del patrón y el valor de la paleta.

Por solicitud de Carlos, `panel_test.c` sustituye la escena HOLA TU por un marcador de ocho caracteres **PTS 0000** en la primera fila. La nave queda fija en (12,12), el marciano recorre X=0…56 en Y=24 y el cañón permanece en (28,56). Un proyectil blanco (slot 3, patrón 2 existente) asciende por X=31 desde Y=53 hasta Y=9, con pasos de dos píxeles, y se deshabilita antes de entrar en la fila del texto. Se relanza tras cuatro cuadros de recarga. El puntaje aumenta 10 por recorrido, no por colisión, y vuelve a cero después de 9990. Se conserva el retardo de escritura de sprites de 10 iteraciones. `panel_shooting_TB.v` es la prueba de esta escena; la prueba anterior se conserva sin reutilizar sus resultados para validar este programa.
