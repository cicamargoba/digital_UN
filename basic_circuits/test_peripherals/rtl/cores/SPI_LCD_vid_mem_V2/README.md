# SPI LCD con memoria interna

Configuración validada en hardware: **ST7789**, pantalla **240×320**, con iCEBreaker. El diseño también incluye secuencias de inicialización para GC9A01, ILI9341 e ILI9488.

Referencia del módulo circular GC9A01 compatible: https://www.waveshare.com/wiki/1.28inch_LCD_Module

## Pinout para iCEBreaker

Se utilizan los pines del conector del panel LED definidos en `../Led_panel_12bpp/led_panel_icebreaker.pcf`.

Los números de la tabla corresponden a los pines del encapsulado de la FPGA, no a posiciones del conector.

| Pin del LCD | Señal RTL | Pin FPGA | Señal del panel LED |
|---|---|---:|---|
| CLK | `lcd_sck` | 32 | `LP_CLK` |
| DIN | `lcd_sdi` | 4  | `RGB0[0]` |
| DC  | `lcd_dc`  | 36 | `LATCH` |
| CS  | —         | —  | Conectar directamente a GND |
| RST | `lcd_rst` | 43 | `ROW[0]` |

Restricciones: `spi_lcd_icebreaker.pcf`.

El pin CS del LCD se conecta directamente a GND para mantenerlo seleccionado. No conectar CS al pin 42 de la FPGA; la salida `lcd_cs` permanece sin conexión al módulo.

### Alimentación y retroiluminación

- VCC del módulo: conectar a 3.3 V.
- GND del módulo: conectar a GND de iCEBreaker.
- BL: entrada de control de retroiluminación; no tiene señal asignada en el RTL ni en el PCF. Para retroiluminación permanente, conectar a 3.3 V.
- Las señales de la FPGA utilizan niveles de 3.3 V.

### Reloj y reset de la FPGA

| Señal RTL | Pin FPGA | Función |
|---|---:|---|
| `clk` | 35 | Reloj de iCEBreaker, 12 MHz |
| `rst` | 10 | Botón activo en bajo: oprimido = reset, suelto = funcionamiento |

`rst` es la entrada de reset del controlador; `lcd_rst` es la salida de reset hacia el LCD. No son la misma señal.

El objetivo `build_icebreaker` configura `RESET_ACTIVE_LOW=1` para invertir el botón antes de alimentar el reset interno. El valor predeterminado del módulo es `RESET_ACTIVE_LOW=0`, por lo que los testbenches conservan el reset activo en alto.

## Implementación V2: control y camino de datos separados

La versión anterior está en `../SPI_LCD_vid_mem/`. Esta carpeta conserva la segunda implementación y su correspondencia con los bloques de `spiLCD_vid_mem.pdf`:

| Bloque de la figura | Archivo | Función |
|---|---|---|
| CRTL_SPI | `ctrl_spi.v` | FSM de control: carga, desplazamiento, conteo, habilitación del divisor, SCK y fin de transmisión |
| LSR | `lsr.v` | Registro de ocho bits con carga paralela y desplazamiento hacia SDI, MSB primero |
| BYTE_CNT | `byte_cnt.v` | Contador de bits transmitidos; genera END_BYTE al llegar a ocho |
| F_DIV | `f_div.v` | Contador de temporización; genera DONE_DIV cada CLK_DIV ciclos mientras está habilitado |

`spi_tx.v` conecta estos bloques. La FSM actualiza su estado en el flanco negativo de `clk`; los registros y contadores del camino de datos trabajan en el flanco positivo. Los contadores y el desplazamiento ya no se actualizan dentro del proceso de la FSM.

El desplazamiento tiene un estado explícito `S_SHIFT`, de un ciclo, con `sh=1`; en los demás estados `sh=0`. El conteo tiene un estado explícito `S_COUNT`, de un ciclo, con `inc_cbyte=1`; en los demás estados `inc_cbyte=0`. Ninguna de estas salidas depende combinacionalmente de DONE_DIV.

En el archivo corregido por Carlos, el primer bit usa `S_LOAD → S_LOW → S_COUNT → S_HIGH`; los siguientes usan `S_HIGH → S_SHIFT → S_COUNT → S_HIGH`. S_LOW sólo se utiliza al comenzar el byte. En S_SHIFT, SCK baja y el registro desplaza el dato en el siguiente flanco positivo de clk. Al entrar en S_COUNT, SCK sube y el LCD muestrea el bit; el contador incrementa en el siguiente flanco positivo de clk. En S_COUNT se comprueba END_BYTE para pasar a S_DONE después del octavo bit, sin otro desplazamiento.

Esta corrección modifica la temporización respecto a la propuesta anterior de la IA: S_SHIFT dura un ciclo, sin volver a S_LOW entre bits. Con CLK_DIV=4, durante los bits siguientes al primero hay un ciclo bajo y tres altos; con clk de 12 MHz, el período entre flancos de muestreo consecutivos es aproximadamente 333 ns, equivalente a 3 MHz dentro del byte. El primer bit y los intervalos entre bytes tienen temporización diferente. No debe aplicarse al archivo corregido la fórmula anterior de 1,5 MHz ni suponerse un ciclo de trabajo del 50 %. Este resultado es una lectura del RTL, no una medición con osciloscopio.

### DC directo al LCD

La salida utiliza `assign dc = data[8]`, sin un registro adicional. El controlador principal mantiene la selección del multiplexor y la dirección de la fuente estables durante la transmisión; sólo avanza después de DONE_TX. Por ello, DC permanece estable durante los ocho bits.

Esta es una condición de la interfaz: si se reutiliza SPI_TX con otra fuente, esa fuente debe mantener `data[8]` estable durante toda la transferencia. El byte `data[7:0]` sí se captura en LSR al cargar. El reset no fuerza DC a cero: DC siempre refleja `data[8]`.

## Comparación de utilización de recursos

Medición del **8 de octubre de 2026**, con Yosys **0.59+62 (9aa2dde7e)** y nextpnr-ice40 **0.8-29-gfd3b4d36**. Ambas versiones se procesaron con los mismos parámetros, imagen, restricciones y semilla de implementación:

- FPGA: **iCE40UP5K**, encapsulado SG48, placa iCEBreaker.
- LCD: **ST7789**; reloj de entrada: **12 MHz**; `CLK_DIV=4`, SCK de **1,5 MHz**.
- Memoria: `VID_AW=9`, `VID_BYTES=480`, una fila de 240 píxeles BGR565. Ambas mediciones utilizan la imagen actual de V2.
- `RESET_ACTIVE_LOW=1`, `RECOVERY_TICKS=2880000`; semilla de nextpnr: **1**.
- La columna V2 es una **medición histórica de la propuesta de la IA con S_SHIFT y S_COUNT, anterior a la corrección humana final**. No corresponde al ctrl_spi.v actual. Los recursos y la temporización del archivo corregido todavía no se han vuelto a medir.

### Controlador completo

| Recurso | Versión anterior | V2 antes de la corrección humana |
|---|---:|---:|
| Celdas lógicas ocupadas / 5280 | 288 (5,45 %) | 274 (5,19 %) |
| LUT4 de síntesis | 261 | 250 |
| Flip-flops de síntesis | 128 | 117 |
| Elementos de acarreo de síntesis | 94 | 81 |
| BRAM de 4 Kib / 30 | 2 (6,67 %) | 2 (6,67 %) |
| DSP / 8 | 0 | 0 |
| Celdas de E/S reportadas por nextpnr | 7 | 7 |
| Buffers globales / 8 | 7 | 6 |
| Frecuencia máxima estimada después del enrutamiento | 22,98 MHz | 20,76 MHz |

En esa medición histórica, V2 ocupó **14 celdas lógicas menos (4,86 %)** y utilizó **11 flip-flops menos**. Ambas implementaciones cumplen la restricción de 12 MHz. Las LUT y los flip-flops pueden compartir una celda lógica; sus cantidades no se suman para obtener las celdas ocupadas. Los buffers globales incluyen señales de control promovidas por nextpnr, no sólo relojes.

La frecuencia máxima es una estimación de temporización para esta implementación y semilla, no una medición física ni una ventaja de velocidad garantizada de V2.

### SPI_TX sintetizado por separado

| Recurso | Versión anterior | V2 antes de la corrección humana | Reducción |
|---|---:|---:|---:|
| LUT4 | 48 | 48 | 0 % |
| Flip-flops | 33 | 22 | 33,33 % |
| Elementos de acarreo | 15 | 2 | 86,67 % |

Estas cifras corresponden sólo al transmisor con `CLK_DIV=4`. La síntesis del controlador completo puede optimizar lógica entre módulos; por ello, sus diferencias no coinciden necesariamente con las de SPI_TX aislado.

### Por qué V2 utiliza menos recursos

1. **Divisor dimensionado al parámetro.** Antes, `div_cnt` tenía 16 bits independientemente de CLK_DIV. En V2 su ancho es `max(1, $clog2(CLK_DIV))`: para CLK_DIV=4 sólo necesita dos bits. Se reduce tanto el almacenamiento como la lógica de incremento y comparación. Es la principal fuente del ahorro; separar módulos, por sí solo, no garantiza menor utilización.
2. **Salidas sin registros redundantes.** SDI sale del bit más significativo de LSR; SCK y DONE_TX se obtienen del control. DC se conecta directamente a `data[8]`, aprovechando la estabilidad garantizada por el controlador principal.
3. **El costo del control sigue contabilizado.** En la propuesta de la IA medida antes de la corrección humana, la FSM one-hot tenía siete bits y el contador cuatro bits para representar el valor ocho. Aunque estos bloques eran mayores que sus equivalentes anteriores, el transmisor sintetizado pasó de 33 a 22 flip-flops. SPI_TX aislado utilizó las mismas 48 LUT4 que la versión anterior; el ahorro medido fue en flip-flops y elementos de acarreo. El archivo corregido conserva siete estados, pero sus recursos finales deben medirse de nuevo, no deducirse de esta tabla.

La medición anterior de V2, con DC registrado, daba 270 celdas lógicas, 246 LUT4 y 116 flip-flops en el controlador completo. Al conectar DC directamente, se elimina un flip-flop, pero cambia la optimización de la lógica combinacional: la utilización física no disminuye necesariamente al retirar un registro. Las tablas principales conservan la medición posterior al cambio a DC directo y a la incorporación de S_SHIFT y S_COUNT por la IA, pero anterior a la corrección humana final.

### Ventajas de la segunda implementación

- **Trazabilidad didáctica:** cada bloque del diagrama tiene un módulo RTL identificable.
- **Separación de responsabilidades:** la FSM decide qué operación realizar; los registros y contadores ejecutan las operaciones.
- **Verificación localizada:** se pueden observar LSR, BYTE_CNT, F_DIV y las señales de control por separado en la simulación.
- **Parametrización:** el ancho del divisor se adapta a CLK_DIV sin reservar siempre 16 bits.
- **Menor ocupación en esta configuración**, manteniendo SPI modo 3 y transmisión de ocho bits MSB primero.

## Estado de verificación

- **Hardware, fuente humana:** Carlos confirmó el funcionamiento de la primera V2, conservó una referencia funcional en `ctrl_spi_ok.v`, informó que la propuesta de la IA con S_COUNT no mostraba las franjas y posteriormente comunicó que había solucionado el problema en `ctrl_spi.v`. Estas confirmaciones y el reporte de falla pertenecen al 8 de octubre de 2026.
- **Simulación y síntesis históricas:** la propuesta de la IA pasó pruebas del transmisor para 256 valores de byte y CLK_DIV=1, 2, 4 y 7; integración de cuatro secuencias LCD; y síntesis/place-and-route con memoria de 480 bytes. Eso no evitó el fallo informado en hardware.
- **Archivo corregido por Carlos:** revisado por lectura del RTL. Después de esa corrección no se han repetido las simulaciones ni las mediciones de recursos de esta sesión. Las cifras históricas no deben presentarse como resultados del archivo actual.
- El testbench del transmisor anterior exige semiperíodos iguales de CLK_DIV ciclos. La corrección humana cambia esa temporización; antes de reutilizar la prueba hay que contrastar sus expectativas con el protocolo y con el RTL actual. No se debe alterar el RTL confirmado en hardware sólo para satisfacer una expectativa antigua del testbench.
- El framebuffer completo no se ha validado en hardware. En formato de 16 bits, 240×240 requiere 115 200 bytes; 240×320 requiere 153 600 bytes. La comparación de recursos usa una fila repetida, no un framebuffer completo.

Los objetivos `check_spi_tx` y `check_lcd` ejecutan las pruebas sin abrir GTKWave; `check_synth` comprueba la síntesis con memoria de una fila. Los Makefiles de ambas versiones se corrigieron para que `build_icebreaker` genere el bitstream y programe la placa; `configure_icebreaker` queda como alias. No son objetivos de sólo compilación.

## Caso de estudio: interacción humano–IA

**Fecha y fuente:** conversación de trabajo entre Carlos Camargo y Claudia, 8 de octubre de 2026; archivos `spiLCD_vid_mem.pdf`, `ctrl_spi_ok.v` y `ctrl_spi.v`. Lo siguiente resume las intervenciones; no es una transcripción literal. Las intervenciones humanas se resaltan en rojo sobre fondo blanco cuando el visor admite HTML.

### Objetivo y resultado

Carlos quería que sus estudiantes pudieran relacionar un diagrama de bloques con su implementación RTL. El transmisor anterior mezclaba control, desplazamiento y contadores dentro de una máquina algorítmica. La IA debía implementar los bloques por separado en V2, conservando la carpeta anterior para trazabilidad.

La IA produjo código, pruebas y estadísticas útiles, pero una de sus modificaciones posteriores **pasó las pruebas ejecutadas y no funcionó en la placa según la comprobación de Carlos**. La IA no identificó una causa física confirmada. Carlos conservó una referencia funcional, dirigió la revisión hacia las señales modificadas, comprobó el flanco de muestreo del LCD y corrigió la secuencia de estados. Este caso muestra por qué la generación y simulación de RTL no sustituyen la intervención del ingeniero ni la validación del sistema real.

### Secuencia de interacciones

| Paso | Humano: solicitud, observación o decisión | Máquina: respuesta y resultado |
|---|---|---|
| 1. Arquitectura | <span style="color:#a00000;background-color:#ffffff">Separar control y camino de datos de SPI_TX siguiendo el diagrama, en una carpeta V2.</span> | La IA revisó el PDF y creó CRTL_SPI, LSR, BYTE_CNT y F_DIV. Integró las fuentes sin modificar la versión anterior. |
| 2. Primera validación | <span style="color:#a00000;background-color:#ffffff">¿La simulación es igual a la anterior? Cambiar las tres primeras franjas a amarillo, azul y rojo.</span> | La IA distinguió equivalencia funcional de coincidencia ciclo a ciclo y regeneró las memorias de imagen. Carlos confirmó después que la nueva versión funcionaba. |
| 3. Recursos | <span style="color:#a00000;background-color:#ffffff">Comparar la utilización de FPGA de las dos versiones.</span> | La IA ejecutó síntesis y place-and-route con parámetros comunes. Identificó el contador de divisor de 16 bits de la versión anterior como la principal oportunidad de ahorro; separar módulos no era, por sí mismo, la causa de la reducción. |
| 4. DC | <span style="color:#a00000;background-color:#ffffff">¿Por qué registrar DC si puede conectarse directamente al LCD? Hacer el cambio y documentar los recursos.</span> | La IA eliminó el registro de DC. Documentó que el controlador principal debe mantener data[8] estable durante la transferencia y ajustó la prueba a esa condición. |
| 5. Desplazamiento explícito | <span style="color:#a00000;background-color:#ffffff">No usar sh=done_div; introducir un estado que haga el desplazamiento.</span> | La IA añadió S_SHIFT, con sh=1 durante un ciclo. Carlos confirmó más adelante que la versión con S_SHIFT e inc_cbyte=done_div funcionaba y la preservó como referencia. |
| 6. Conteo explícito | <span style="color:#a00000;background-color:#ffffff">Aplicar el mismo criterio a inc_cbyte=done_div.</span> | La IA añadió S_COUNT. Las pruebas comprobaron siete desplazamientos y ocho incrementos por byte. También añadió un if(rst) al bloque de salidas: un cambio adicional que no había sido solicitado. |
| 7. Falla observada | <span style="color:#a00000;background-color:#ffffff">Con el último cambio no se ven las franjas. Revisar únicamente la señal modificada.</span> | La IA inicialmente amplió la revisión a SCK y propuso pulsos espurios por decodificación combinacional. No midió esos pulsos ni demostró que explicaran la falla. Carlos corrigió el alcance de la investigación. |
| 8. Compilar y programar | <span style="color:#a00000;background-color:#ffffff">build_icebreaker no configura la FPGA; corregir el Makefile.</span> | La IA primero explicó la diferencia entre build y configure, en lugar de efectuar la corrección solicitada. Después movió la programación al objetivo build en ambas carpetas y revisó la secuencia en seco. Esta incidencia se distingue del problema de secuenciación: no demuestra por sí sola la causa de la pantalla en blanco. |
| 9. Comparación controlada | <span style="color:#a00000;background-color:#ffffff">La versión anterior muestra las franjas y V2 no. Comparar las salidas de las máquinas.</span> | La IA comprobó que ctrl.v era idéntico; las diferencias estaban en SPI_TX. Informó diferencias de registro, conteo y temporización, pero no estableció la causa física del fallo. |
| 10. Referencia funcional | <span style="color:#a00000;background-color:#ffffff">Este código con S_SHIFT funciona. Ya restauré el archivo y tengo ctrl_spi.v y ctrl_spi_ok.v para comparar.</span> | La IA tuvo que abandonar la explicación general de que SCK combinacional era el diagnóstico: la referencia funcional también lo utilizaba. La comparación RTL encontró coincidencia en los puntos de muestreo de las transferencias y una diferencia adicional en el manejo de reset. Coincidir en esas pruebas no explicó la falla en la placa. |
| 11. Hipótesis de reset | <span style="color:#a00000;background-color:#ffffff">Verificar qué está mal en ctrl_spi.v.</span> | La IA recomendó retirar el if(rst) añadido para aislar el cambio. No probó que fuese la causa. La versión finalmente corregida por Carlos conserva ese bloque, por lo que retirarlo no quedó establecido como solución necesaria. |
| 12. Pregunta del protocolo | <span style="color:#a00000;background-color:#ffffff">¿El LCD lee el dato en el flanco de subida o de bajada de SPI_CLK?</span> | La IA respondió que, en SPI modo 3 usado aquí, el LCD muestrea en el flanco de subida. El dato debe estar preparado antes de ese flanco. |
| 13. Corrección humana | <span style="color:#a00000;background-color:#ffffff">Ya lo solucioné; revisar ctrl_spi.v.</span> | Carlos cambió las transiciones: S_HIGH espera DONE_DIV y pasa a S_SHIFT; S_SHIFT pasa directamente a S_COUNT; S_COUNT comprueba END_BYTE y pasa a S_DONE o S_HIGH. La IA revisó el archivo y señaló que también había cambiado la temporización de SCK. No realizó una nueva validación independiente en hardware. |

### Qué cambió Carlos en la secuencia

La propuesta de la IA, para CLK_DIV>1, repetía entre bits:

```text
S_HIGH → S_SHIFT → S_LOW → S_COUNT → S_HIGH
```

La corrección humana repite:

```text
S_HIGH → S_SHIFT → S_COUNT → S_HIGH
```

Además, Carlos trasladó la decisión de fin de byte a S_COUNT. En el archivo corregido, las operaciones quedan explícitas:

1. **Preparar:** S_SHIFT pone SCK en cero y activa SH. LSR cambia el dato en el siguiente flanco positivo de clk.
2. **Muestrear:** al entrar en S_COUNT, SCK sube y el LCD lee SDI.
3. **Contar:** durante S_COUNT, INC_CBYTE activa el incremento en el siguiente flanco positivo de clk.
4. **Decidir:** con el contador actualizado, END_BYTE determina si se termina o se mantiene S_HIGH antes de preparar el siguiente bit.

Esta descripción explica el comportamiento del archivo corregido. **No prueba que la propuesta anterior contara mal, ni identifica un pulso espurio medido.** La evidencia de esta conversación es que Carlos informó la falla de aquella propuesta y comunicó la solución después de cambiar la secuencia. Como también cambió la forma de onda, no sería correcto atribuir el resultado a una sola causa física no medida.

### Dónde debe intervenir el ser humano

- **Definir la arquitectura y la claridad requerida.** Carlos no aceptó una solución sólo porque transmitiera datos: pidió correspondencia con los bloques y operaciones explícitas para enseñar.
- **Controlar el alcance de los cambios.** Cambiar una salida no autoriza a modificar el reset ni a rediseñar otras partes verificadas. Hay que revisar el diff, no sólo el texto explicativo de la IA.
- **Contrastar las afirmaciones con el hardware.** La aparición o ausencia de las franjas fue evidencia del sistema real. Un reporte de pruebas aprobadas no invalida esa observación.
- **Conservar una referencia que funciona.** ctrl_spi_ok.v permitió comparar cambios concretos sin perder la solución anterior.
- **Volver al protocolo y a los flancos.** La pregunta sobre el flanco de lectura hizo explícita la relación entre preparar SDI, subir SCK y contar el bit.
- **Exigir evidencia para las explicaciones.** Una hipótesis sobre glitches o reset no debe convertirse en diagnóstico por repetición. La IA debe retirar o limitar una explicación cuando la referencia funcional no la sostiene como causa.

### Lecciones para trabajar con IA en diseño digital

**La IA puede acelerar la escritura de RTL, la organización del diseño y las pruebas; no debe decidir que el circuito funciona únicamente a partir de sus propias pruebas.** En este caso, sus testbenches validaban las expectativas que había codificado. No identificaron el problema informado en hardware. Después de la corrección humana, algunas de esas expectativas de temporización dejaron de describir el diseño.

Para utilizar este caso en clase:

1. Comparar las operaciones de la versión algorítmica con los bloques de V2.
2. Seguir en papel o en una simulación el orden de SH, SDI, SCK, INC_CBYTE y END_BYTE, distinguiendo clk de SCK.
3. Leer la referencia funcional y la secuencia corregida; separar diferencias observadas de explicaciones todavía no demostradas.
4. Revisar qué comprueba realmente cada testbench: datos, flancos, setup/hold, reset, duración de pulsos y terminación no son la misma propiedad.
5. Antes de declarar una modificación validada, registrar por separado: revisión RTL, simulación, síntesis, temporización y funcionamiento físico. Si una etapa falla, no reemplazarla con el resultado de otra.

**Resultado del caso:** la intervención humana definió el objetivo pedagógico, rechazó dependencias poco claras, delimitó la investigación, aportó la comprobación física y corrigió la secuencia. La responsabilidad de la IA es reconocer los límites de sus pruebas y sus errores, no inventar una explicación retrospectiva para presentarse como autora de la solución.
