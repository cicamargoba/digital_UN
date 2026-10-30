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
