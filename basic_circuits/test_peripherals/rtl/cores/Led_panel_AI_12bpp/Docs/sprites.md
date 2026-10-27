# Motor de sprites HUB75 RGB444

Implementado el 2026-10-27 siguiendo [los diagramas de referencia](sprites_hub75_diagramas.html): ocho sprites de 8×8, detectores paralelos, selección AND-OR, ROM de dos lecturas registradas, paletas y registro común de colisiones.

## Alcance e integración

`sprite_engine` produce dos píxeles RGB444 y sus máscaras para la misma dirección `pix_addr` que utilizan imagen y texto. El testbench conecta el motor a `text_mix`, cuya prioridad ahora es **sprite > texto > imagen**, de forma independiente en cada mitad.

El motor está **instanciado en `led_panel_4k`**, junto con el cargador estático `sprite_demo`. Comparte `clk1` y `PIX_ADDR` con imagen y texto; `text_overlay` recibe `sprite_data`, `sprite_on0` y `sprite_on1` y los conecta al mezclador existente, sin añadir latencia. No se modificaron la FSM, los contadores ni el mux BCM.

No se implementaron CPU, MMIO, movimiento automático ni sincronización entre dominios de reloj. No se programó la placa con este motor.

## Archivos

| Archivo | Función |
|---|---|
| `sprite_table.v` | Ocho registros de descriptor, legibles simultáneamente |
| `sprite_detector.v` | Restas de ocho bits y detección de rango 0…7 |
| `sprite_select.v` | Enmascaramiento por hit y OR de los ocho buses de atributos |
| `sprite_half.v` | Ocho detectores, selección y registro de dx, color y hit |
| `sprite_rom.v` | ROM 256×8 con dos direcciones y lecturas en flanco descendente |
| `sprite_collision.v` | Detección de múltiples hits y acumulación de bits por sprite |
| `sprite_engine.v` | Tabla compartida, dos mitades, ROM compartida y dos paletas |
| `sprite_demo.v` | Cargador estático de ocho descriptores al salir de reset |
| `sprites.mem` | 256 bytes: 32 patrones de ocho líneas |
| `sprite_engine_TB.v` | Prueba autochecking del motor y la mezcla |
| `Makefile.sprite` | Simulación RTL, síntesis y simulación postsíntesis |

Se reutiliza `text_palette.v` con `pal16.mem`. `text_mix.v` incorpora las entradas `spr[23:0]`, `spr_on0` y `spr_on1`.

## Descriptor e interfaz de escritura

La tabla utiliza **26 bits por sprite**, no los 24 indicados en el dibujo, para conservar todos los campos con sus anchos especificados:

| Bits de `wdata` | Campo |
|---|---|
| `[7:0]` | X, complemento a dos de ocho bits |
| `[15:8]` | Y, complemento a dos de ocho bits |
| `[20:16]` | Patrón, 0…31 |
| `[24:21]` | Índice de color, 0…15 |
| `[25]` | Habilitación |

`we=1` escribe `wdata` en el sprite seleccionado por `waddr[2:0]`, en el flanco descendente de `clk`. La tabla se lee combinacionalmente. El píxel muestreado en el mismo flanco de una escritura usa el descriptor anterior; el siguiente muestreo utiliza el nuevo.

`rst` es síncrono, activo alto, en flanco descendente: borra los ocho descriptores, el registro de colisiones y las máscaras registradas. Debe aplicarse antes de usar el motor. No borra la ROM de patrones ni la paleta.

Las posiciones de uso previstas son −8…63. Una posición negativa recorta el sprite por arriba o izquierda; las posiciones próximas a 63 lo recortan por abajo o derecha, sin envolverlo al borde opuesto. Las actualizaciones de tabla durante el barrido no son atómicas por cuadro; el control externo debe gestionar cuándo escribir si necesita evitar tearing.

## Camino de píxel

- `x = pix_addr[5:0]`.
- Mitad superior: `y = {1'b0, pix_addr[10:6]}`.
- Mitad inferior: `y = {1'b1, pix_addr[10:6]}`.
- Cada detector calcula `dx=x−X`, `dy=y−Y`; hay hit si el sprite está habilitado y los bits `[7:3]` de ambas diferencias son cero.
- La selección combina `{pat[4:0], dy[2:0], dx[2:0], color[3:0]}` mediante AND-OR. Este es el orden implementado; el texto inferior del diagrama intercambiaba dx/dy respecto a sus etiquetas de salida.
- La ROM se direcciona con `{pat,dy}`. Cada patrón contiene ocho bytes, con el bit 0 a la izquierda.
- La ROM registra la línea en el mismo flanco descendente que los registros de dx, color y hit. La salida es válida después de ese flanco y permanece estable hasta el siguiente, alineada con las lecturas de imagen y texto existentes.
- `spr_on = hit & line[dx]`. Un bit de patrón cero es transparente; un bit uno utiliza el color de la paleta, incluso si el índice es cero y el color resultante es negro.
- `spr[23:12]` corresponde a la mitad superior y `spr[11:0]` a la inferior.

Los patrones incluidos son: 0, cruz diagonal; 1, figura tipo invasor; 2, figura tipo nave; 3, barra vertical; 4, bloque lleno; 5 y 6, diagonales opuestas; 7, triángulo. Los patrones 8…31 están vacíos y disponibles para sustituirlos. Cambiar patrones o paleta requiere reconstruir el diseño.

## Colisiones y traslapes

`col[7:0]` acumula colisiones de **cajas de 8×8**, no de píxeles visibles. Cuando hay dos o más hits simultáneos en una mitad, se marcan todos los sprites implicados. Los eventos de ambas mitades se combinan en el mismo registro.

`col_clear=1` borra los eventos anteriores en flanco descendente. Si se detectan nuevas colisiones en ese mismo flanco, se conservan: el evento nuevo tiene prioridad sobre el borrado. No hay borrado automático por cuadro; corresponde al control externo leer y borrar el registro.

La selección no incorpora prioridad entre sprites: si se superponen, combina patrón, coordenadas locales y color por OR. El resultado en esa zona no es un sprite válido garantizado. Se conserva esta limitación del diagrama; el registro de colisión no elimina automáticamente ningún sprite. No detecta colisiones con texto o imagen.

## Verificación ejecutada

| Prueba | Resultado del 2026-10-27 |
|---|---|
| Motor y mezcla RTL | 30 852 comprobaciones aprobadas |
| Misma prueba sobre netlist iCE40 | 30 852 comprobaciones aprobadas |
| Síntesis iCE40, `check -assert` | Sin problemas reportados |
| Regresión del texto existente | 49 172 comparaciones BCM aprobadas |
| Captura del top existente | Finaliza con 129 latches; no acredita alineación exacta de píxeles |
| Panel físico con sprites | No probado |

Se comprueban reset, ocho entradas de tabla, 32 patrones, 16 colores, ambos puertos, cruce entre mitades, recorte en bordes, lectura registrada, escritura con dato anterior, transparencia, negro opaco, prioridad de capas, combinación AND-OR y acumulación/borrado de colisiones en ambas mitades. El testbench falla si algún byte de la ROM está sin inicializar.

La síntesis aislada iCE40 produjo **513 LUT4, 236 FF, 164 celdas de acarreo y dos bloques `SB_RAM40_4KNR`**. La ROM lógica es compartida y tiene dos puertos de lectura; en iCE40 se replica para obtenerlos. `ram_style="block"` solicita memoria de bloque. La estimación de un BSRAM del documento corresponde a Gowin y no se ha verificado con su herramienta. No se ejecutaron place-and-route ni comprobaciones de timing del motor.

Los targets de `Makefile.sprite` son `test_sprite`, `synth_sprite` y `test_sprite_post_synth`. Los ejecutables, netlists, logs y VCD quedan en `build/sprites`; `SPRITE_BUILD_DIR` permite cambiar ese destino. La simulación postsíntesis utiliza los modelos iCE40 de la instalación de Yosys. Ningún target programa hardware.

## Captura visual de Space Invaders — 2026-10-27

`sprite_scene_TB.v` y `simulate_space_invaders.py` prueban los cinco sprites de la escena de `juegos_hub75_descarga.html` facilitada por Carlos. El target `test_space_invaders` recibe ese archivo mediante `SPACE_INVADERS_HTML`; no ejecuta su JavaScript, sino que extrae los patrones, la paleta y las llamadas de posicionamiento de Space Invaders.

| Sprite | X | Y | Índice de color del HTML |
|---|---:|---:|---:|
| Platillo (`ufo`) | 8 | 9 | 12 |
| Cañón (`cannon`) | 28 | 56 | 10 |
| Disparo propio (`shot`) | 31 | 42 | 15 |
| Disparo enemigo (`zig`) | 20 | 40 | 14 |
| Disparo enemigo (`zig`) | 46 | 34 | 14 |

El HTML representa el bit 7 a la izquierda y usa una paleta distinta de `pal16.mem` en algunos índices. El preparador invierte los bits de cada byte para la ROM LSB-first del motor y genera una paleta de prueba con los valores RGB444 exactos del HTML. Estos archivos quedan exclusivamente en `build/sprites/space_invaders`; no sustituyen `sprites.mem` ni `pal16.mem`.

El testbench escribe los descriptores por la interfaz pública y recorre las 2048 direcciones de pares de píxeles. El script reconstruye los 4096 píxeles a partir de `spr`, `spr_on0` y `spr_on1` del VCD, muestreados después del flanco descendente. No consulta detectores, ROM ni registros internos del motor. Verifica muestras completas, sin duplicados ni valores desconocidos.

La referencia se calcula por separado con los patrones **originales MSB-first del HTML**, posiciones absolutas y colores originales; no se dibuja a partir de la ROM convertida ni de la netlist. Se comparan máscaras en toda la pantalla y RGB444 donde el sprite es visible. Se descartan escenas con cajas superpuestas, porque el selector del motor es AND-OR, no prioridad entre sprites.

**Resultado:** 4096 píxeles comparados, **0 diferencias**, 60 píxeles opacos tanto en simulación como en referencia y `col=00`. Captura RTL estática; no acredita movimiento, ejecución del juego, barrido HUB75 ni validación física. Los invasores de la formación pertenecen a la capa de texto del HTML y no se incluyen en esta prueba del motor de sprites.

Productos de la prueba en `build/sprites/space_invaders`:

- `comparison.png`: salida reconstruida y referencia lado a lado, con ampliaciones de los patrones en el pie.
- `simulated.png`, `expected.png`, `difference.png`: imágenes separadas, ampliadas sin interpolación.
- `space_invaders.vcd`, `simulation.log`: evidencia de simulación.
- `source_scene.json`: patrones, posiciones, paleta y SHA-256 del HTML de entrada.
- `comparison.json`: resultado cuantitativo y coordenadas de diferencias si las hubiera.

El fondo cuadriculado de las imágenes indica transparencia; no es una salida RGB generada por el motor. Se requiere Pillow para dibujarlas. El script devuelve código distinto de cero ante diferencias, colisiones inesperadas, datos desconocidos o captura incompleta.

## Prueba integrada sobre HOLA / MUNDO — 2026-10-27

El top carga `sprite_demo.mem` mediante la interfaz de escritura del motor, sin escrituras jerárquicas del testbench. `sprite_demo` avanza el índice en flanco descendente: el motor recibe el descriptor anterior al avance. Tras ocho escrituras, `ready=1` y `we=0`. Un reset reinicia la carga. El índice del cargador tiene reset asíncrono para inicializarlo aunque el divisor mantenga `clk1` detenido durante reset.

Parámetros del top: `SPRITE_INIT_FILE`, `SPRITE_PATTERN_FILE` y `SPRITE_PALETTE_FILE`. Los valores por defecto son `sprite_demo.mem`, `sprite_demo_patterns.mem` y `sprite_demo_palette.mem`. Patrones y paleta proceden de Space Invaders del HTML, convertidos al orden de bits del motor; no se cambian los archivos del texto.

| Sprite | X | Y | Propósito |
|---|---:|---:|---|
| Platillo | 8 | 0 | Encima de la O de HOLA |
| Cañón | 16 | 8 | Encima de la N de MUNDO |
| Disparo propio | 31 | 2 | Cruza las dos filas de texto |
| Disparo enemigo | 44 | 0 | Sobre una celda de texto transparente |
| Disparo enemigo | 46 | 34 | Sobre la imagen de la mitad inferior |

`Makefile` y `Makefile.text` incluyen las dependencias del motor y del cargador en el top. `text_overlay_TB` mantiene las entradas de sprites a cero para conservar la regresión aislada de texto.

`reconstruct_sprite_display.py` comprueba la mezcla RGB444 del top y reconstruye el primer cuadro desde los puertos HUB75 mediante el lector VCD de `reconstruct_text_display.py`. Para comprobar datos registrados utiliza la dirección **anterior** al flanco descendente: los contadores también cambian en ese flanco. La referencia renderiza por separado imagen, texto y sprites desde sus archivos, y verifica que existan sprites cubriendo píxeles de glifo, no solamente fondos de celdas.

Resultados ejecutados:

- **18 331 pares de píxeles comprobados, cero errores de composición**, cubriendo las 2048 direcciones.
- 60 píxeles opacos de sprites, de los cuales **29 cubren trazos de caracteres**; colisiones `00`.
- Regresión de texto: 49 172 comparaciones aprobadas; regresión del motor: 30 852 comprobaciones aprobadas.
- Síntesis del top iCE40 con `check -assert`: cero problemas; sin place-and-route ni prueba física en esta entrega.
- Reconstrucción externa: 8192 muestras de seis bits, 4096 píxeles. **1593 diferencias frente a las coordenadas ideales**, pero **cero diferencias frente al modelo de desplazamiento de una columna a la derecha** ya documentado. No se modificó el barrido para corregirlo.

La comparación se guarda en `build/sprites/display/comparison.png`, junto con `simulated.png`, `expected.png` y `comparison.json`. El VCD del top se encuentra en `build/text/text_display_TB.vcd`. El target `test_sprite_display` de `Makefile.text` ejecuta captura y comparación; **devuelve fallo mientras no coincidan exactamente las salidas HUB75**, aunque la mezcla interna pase. El script antiguo de reconstrucción de texto no incluye la capa de sprites en su referencia: para este demo debe usarse `reconstruct_sprite_display.py`.

### Configuración posterior: dos sprites rojos en la mitad inferior

Por indicación de Carlos, el demo actual reemplaza las posiciones de la prueba anterior: solo quedan habilitados el platillo en **(12,40)** y el cañón en **(40,48)**. Las otras seis entradas están deshabilitadas. No se superponen entre sí ni con HOLA/MUNDO. Los resultados numéricos de la prueba anterior corresponden a la configuración de cinco sprites, no a esta nueva distribución. Se conserva la paleta del texto sin cambios.

Carlos observó ambos sprites azules al transmitir `F00`. Para compensar el intercambio rojo/azul observado en el recorrido físico de esta prueba, el platillo utiliza el índice 12 con **`00F`**, destinado a verse rojo, y el cañón el índice 6 con **`08F`**, destinado a verse anaranjado (rojo F, verde 8, azul 0 en el panel). La compensación se limita a `sprite_demo_palette.mem`; no cambia el mux ni las restricciones de pines. Las imágenes de simulación interpretan RGB444 lógico y, por tanto, muestran esos valores como azul y azul verdoso, no como los colores físicos compensados. La nueva pareja de colores requiere reconstrucción, carga y confirmación visual.
