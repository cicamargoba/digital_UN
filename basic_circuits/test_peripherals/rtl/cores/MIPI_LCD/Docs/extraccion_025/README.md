# Extracción de las capturas MIPI_VIDEO_025

## Resultado y límite

Se obtuvieron **dos mapas de actividad independientes**, uno desde D0 y otro
desde D1. Ambos muestran GAME BOY y la barra inferior. No se utilizó la
fotografía, ningún PNG anterior, una plantilla de letras ni un generador de
imágenes para obtener estos resultados.

**No son píxeles RGB decodificados.** La intensidad gris representa la proporción
de muestras P=1; la versión binaria es una segmentación automática de esa
actividad. No se asignaron colores ni se corrigieron letras o regiones a mano.
El aspecto horizontal no se ha ajustado a una supuesta pantalla cuadrada.

| Resultado | D0 | D1 |
|---|---|---|
| Actividad gris, contraste automático | [PNG](MIPI_VIDEO_025_D0_actividad_gris.png) | [PNG](MIPI_VIDEO_025_D1_actividad_gris.png) |
| Actividad sin normalización de contraste | [PNG](MIPI_VIDEO_025_D0_actividad_sin_normalizar.png) | [PNG](MIPI_VIDEO_025_D1_actividad_sin_normalizar.png) |
| Segmentación automática, no RGB | [PNG](MIPI_VIDEO_025_D0_segmentacion_actividad.png) | [PNG](MIPI_VIDEO_025_D1_segmentacion_actividad.png) |
| Periodo de cuadro completo, sin recorte espacial | [PNG](MIPI_VIDEO_025_D0_actividad_cuadro.png) | [PNG](MIPI_VIDEO_025_D1_actividad_cuadro.png) |
| Parámetros y huella de la fuente | [JSON](MIPI_VIDEO_025_D0_extraccion.json) | [JSON](MIPI_VIDEO_025_D1_extraccion.json) |

## Procedencia reproducible

Fuentes proporcionadas por Carlos: `MIPI_VIDEO_025_D0.kvdat` y
`MIPI_VIDEO_025_D1.kvdat`. Tamaños: 1 014 349 646 y 1 068 014 249 bytes.

SHA-256:

```text
D0 93eb96243e4d92417898a39da5d71ac823e02d27315ad1eb8559ca5f1807f804
D1 c40815f987ecba5c77db8d93a95b0f8f2f327d7c534705fe750d4c5fc377c04b
```

El programa mantenido es [extract_capture_activity.py](../../extract_capture_activity.py).
Abre el archivo KVdat indicado y escribe los derivados. No recibe una fotografía
ni otro archivo de imagen como entrada. Las únicas transformaciones de los PNG
son alineación temporal, promedio, recorte por actividad, agrupación horizontal
de cuatro muestras y, donde corresponde, contraste o umbral automático.

1. Leer los dos canales digitales P/N y sus estados iniciales del contenedor.
2. Detectar intervalos LP11 y ajustar su periodo horizontal.
3. Buscar la periodicidad vertical por autocorrelación de actividad por línea.
4. Promediar 30 repeticiones en la ventana 4,50–4,98 s.
5. Recortar el intervalo denso mediante la propia actividad de las muestras.
6. Guardar la matriz y los parámetros, además del PNG.

El umbral binario de Otsu fue 31/255 para D0 y 23/255 para D1, aplicado sobre
actividad sin normalizar. No se aplicaron operaciones morfológicas ni retoques.
Las matrices de salida son de **647 filas temporales × 493 grupos horizontales
de muestras**: esos números **no establecen la resolución nativa del panel**.
Se procesaron las capturas por separado, sin intercalarlas como si fueran
simultáneas.

## Medidas nuevas, obtenidas sin referencia visual

| Parámetro | D0 | D1 |
|---|---:|---:|
| Muestreo del contenedor | 100 MHz | 100 MHz |
| Total | 500 000 000 muestras | 500 000 000 muestras |
| Periodo H ajustado | 2119,996793 muestras | 2119,997267 muestras |
| Periodos H por repetición de cuadro | 743 | 743 |
| Periodo de cuadro | 15,751576 ms | 15,751580 ms |
| Frecuencia de repetición | 63,485710 Hz | 63,485696 Hz |

El ajuste fraccional se usa para alinear repeticiones, no para afirmar una
precisión absoluta del analizador superior a su muestreo de 10 ns. Tampoco
identifica automáticamente VSS, VSE, HSS, HSE ni un modo de video DSI.

## Intento de recuperar bits HS

Se ensayó muestreo equivalente con 2400 repeticiones de una región temprana de
líneas densas por archivo. Los PNG/NPZ `*_cabecera_equivalente.*` son un estudio
de probabilidades P/N frente a fase, no una decodificación confirmada.

En la región de 750–1500 ns desde LP11 se observó P=N=0 en aproximadamente el
59,1 % de las observaciones de D0 y el 62,2 % de D1. No se ha conseguido validar
en HS un header por ECC y un payload por CRC. Por tanto **no se declaran bitrate,
RGB888, WC=2160 ni valores RGB recuperados**. Tampoco se concluye que toda
recuperación HS sea imposible: este intento no cerró esa decodificación.

## Contraste de los comentarios de revisión

### ECC: no modificar Sleep Out como si el capturado fuera inválido

Recalculado con las ecuaciones usadas para los 18 headers:

| Tres bytes del header | ECC calculado |
|---|---|
| `05 11 45` | `04` |
| `05 11 00` | `36` |
| `05 29 03` | `1F` |
| `3E 70 08` | `13` |

Por ello `05 11 45 04` **tiene ECC válido**. `05 11 00 36` también es válido,
pero es otro header; el cálculo no demuestra un glitch en el capturado y no
justifica reemplazarlo automáticamente. No se cambió la ROM por esta sugerencia.
En D0_025, Sleep Out es LPDT #5 a 1,49326467 s; Display On es LPDT #12 a
1,66841220 s, no #15 según la numeración de esos 18 mensajes.

### Orden de bits de 87

El valor de byte es `87`. Sus bits en orden temporal b0→b7 son `11100001`.
Esa cadena parece E1 si se interpreta como una representación MSB-first: no son
dos valores intercambiables al decodificar. La entrada LPDT y los ocho bits
deben tratarse con su orden temporal correcto.

### Tiempos y esperas

Los archivos aquí examinados indican **100 Msps**, no 50. El periodo nominal
de las fases LP es de unos 100 ns, pero no todas se capturaron con ese ancho:

- Mensaje #1: 138 estados de 100 ns, cuatro de 90 y cuatro de 110 ns, además
  de los estados largos de entrada/salida.
- Mensaje #2: 104 estados de 90 ns, dos de 100 y 104 de 110 ns, además de los
  tres estados largos; 213 estados en total.

No corresponde afirmar aquí que 210/213 midieron exactamente 100 ns.

Los reposos LP11 guardados fueron 8,99979–8,99980 ms, 64,99971 ms y 6,99997 ms.
Los intervalos entre comienzos de mensajes incluyen además el tiempo de emisión
del paquete; por eso dan valores como 9,02 o 65,01 ms. Para WAIT se conservan
los valores nominales 9, 65 y 7 ms.

### Distribución y recursos: hipótesis que requieren cerrar el diseño

- Hay que representar y parametrizar entrada y salida HS por línea, no solo
  header/payload/CRC. Una ráfaga HS por línea no demuestra por sí misma el modo
  de video llamado Burst Mode. EoT físico y paquete EoTp no son lo mismo.
- Bajo el supuesto de 720 píxeles RGB888, el paquete largo tiene 2166 bytes.
  Repartido en dos lanes son 8664 bits/lane. Dividir por 21,2 µs da
  **408,679 Mbps/lane**, no 415 como resultado de esa división. SoT, transiciones,
  otros paquetes y tiempos inactivos elevan el requisito. El reloj HS DDR
  correspondiente sería mayor que 204,34 MHz; esto **no es la frecuencia de
  entrada CLK_REF de la placa**. No se ha medido ese bitrate.
- Un framebuffer supuesto de 720×648×3 ocupa **1 399 680 bytes**. No cabe en
  los 46 bloques BSRAM de 18 432 bits de GW2AR-18: **105 984 bytes**, o 103,5 KiB.
  La familia contempla memoria SiP, pero su tipo/capacidad disponible depende
  del encapsulado; no debe confundirse con BSRAM.
- Para un diseño basado en Game Boy, una fuente 160×144 RGB565 ocupa 46 080
  bytes y puede combinarse con escalado y buffer de línea. Esto sería una
  elección de arquitectura, no prueba de que la captura use escalado 4,5.
- Hay otro requisito de caudal pendiente en el dibujo: dos lanes necesitan
  **dos bytes por ciclo de byte HS**. Un camino de VIDEO_MEM/PACKET_MUX de
  ocho bits por ciclo al mismo clk_byte no los suministra sin buffering,
  aumento de reloj o ensanchamiento. LANE_SPLIT por sí solo no crea caudal.
- Un tamaño impar no obliga en general a agregar un byte de píxel artificial.
  La distribución DSI contempla validez por lane y finalización independiente.
  No se debe alterar WC ni CRC para introducir un padding no justificado.
- Falta decidir el modo de reloj continuo/no continuo y EoTp contra el panel.
  Los dos KVdat analizados no contienen una lane CLK independiente.

Referencias consultadas para los puntos de recursos y multilane:

- [Gowin, tabla GW2AR](https://www.gowinsemi.com/en/product/arora-ii-fpga/),
  BSRAM y memorias de la familia; comprobar el encapsulado antes de aplicarlo.
- [DSI 1.00a, §6.1.3, SoT/EoT multilane](https://studfile.net/preview/1645839/page:9/),
  distribución de cantidades arbitrarias de bytes y validez por lane. Es una
  referencia del protocolo, no una validación del panel ni de los headers HS
  de estas capturas.

Los diagramas siguen siendo una propuesta previa a RTL. Esta revisión no
autoriza a presentar las hipótesis como medidas ni a sustituir bytes capturados
que ya tienen ECC válido.
