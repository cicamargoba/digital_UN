# LCD MIPI: temporización y trama para el controlador

Fecha: 2026-11-23. Fuentes: `MIPI_VIDEO_025_D0.kvdat` y `MIPI_VIDEO_025_D1.kvdat`.

[Diagrama de formas de onda](mipi_controlador_trama.svg) · [PDF](mipi_controlador_trama.pdf)

## Alcance y estado

Se identificó el logo mediante actividad de D0 y repetición de líneas, no mediante decodificación RGB. La imagen exportada a 640×640 no establece la resolución nativa. Se decodificó la inicialización LP con ECC/CRC válidos. No se han validado los paquetes de píxeles HS. Este documento es una base de ingeniería inversa, **no una especificación completa lista para programar el panel**.

## Esquema eléctrico adoptado: D-PHY TX con TLVDS

![Figura 4-3 de Gowin: salidas TLVDS directas al LCD y ramas LVCMOS12 de 100 Ω por conductor](mipi_dphy_tx_tlvds_fig4_3.png)

Fuente: [Gowin IPUG112-2.02E, §4.2, figura 4-3, pág. 11 impresa](https://www.gowinsemi.com/upload/database_doc/277/document/5d36810e104f6.pdf#page=18). Se adopta la misma red para **D0, D1 y CLK**. El par `TLVDS_TBUF` se conecta directamente a P/N del LCD. Cada conductor tiene una rama de **100 Ω hacia su GPIO `LVCMOS12`**; no es una resistencia entre P y N. Gowin da 100 Ω como referencia y **Carlos confirmó 100 Ω medidos en el FPGBC (2026-11-24)**. En LP, el driver HS queda en alta impedancia. En HS, los GPIO LP se llevan a `0` para polarizar la red.

| Carril | HS directo al LCD, banco 1 (P/N) | LP por resistencia, banco 0 (P/N) |
|---|---:|---:|
| D0 | 117 / 116 | 122 / 123 |
| D1 | 115 / 114 | 124 / 125 |
| CLK | 113 / 112 | 126 / 128 |

La tabla es la **asignación propuesta** al aplicar la figura al trazado reportado; `UG115E` identifica los tres pares del banco 1 como True LVDS. La medición de 100 Ω no confirma por sí sola el trazado ni los roles de los pines. Queda por verificar la continuidad de cada rama y `VCCIO0`/`VCCIO1` antes de implementar la asignación. La figura no es un levantamiento del PCB.

## Generación de NRZ diferencial en HS

![Compuertas y formas de onda: OSER8, buffer diferencial triestado y ramas LP](mipi_dphy_nrz_compuertas.svg)

1. **Serialización:** cada carril de datos captura un byte en `PCLK`. `OSER8` emite `byte_i[0]` primero y un bit en cada flanco de `FCLK`: `FCLK = 4 × PCLK` y `Rlane = 2 × FCLK`. La salida `Q0` es un solo flujo NRZ, sin transición forzada entre bits iguales.
2. **Par diferencial:** `TLVDS_TBUF` aplica `O/OB` con polaridad opuesta al mismo bit. En HS, `1` significa `V(P) − V(N) > 0` y `0` significa `V(P) − V(N) < 0`. El inversor del diagrama está **dentro del modelo lógico del buffer**; no se implementa N con otra salida CMOS ni otro serializador. Las formas de onda son lógicas e ilustrativas, no amplitudes medidas.
3. **Paso LP/HS:** `OEN=0` habilita el buffer; `OEN=1` lo deja en `Z`. Antes de habilitar HS, el secuenciador lleva las ramas LP a `00` y cumple la temporización D-PHY. Al salir, deshabilita HS y mantiene el clamp el tiempo de transición correspondiente antes de devolver P/N al secuenciador LP. No se conmuta automáticamente al cambiar un bit ni se implementa BTA en este ejemplo.
4. **Reloj del enlace:** usar el mismo bloque para CLK con `byte_i=8'hAA` (alternancia `0,1,…`, salida de frecuencia `FCLK`) y relojes de serialización derivados de la misma PLL, con la fase ajustada para centrar ambos flancos de CLK en los UI de datos. La referencia de Gowin usa 90° de `FCLK` entre datos y reloj. `hs_enable` de CLK se secuencia aparte: arranca antes de los datos y se apaga después. No se presupone una frecuencia medida.

### Verilog — un carril, salida HS y ramas LP

```verilog
module dphy_tx_lane_tlvds (
    input  wire       pclk, fclk, reset,
    input  wire [7:0] byte_i,
    input  wire       hs_enable, lp_clamp,
    input  wire       lp_p_i, lp_n_i,
    output wire       hs_p_pad, hs_n_pad,
    output wire       lp_p_pad, lp_n_pad
);
    wire serial_nrz;
    wire hs_on = hs_enable & ~reset;
    wire lp_pass = ~(lp_clamp | hs_on);

    OSER8 u_ser (
        .D0(byte_i[0]), .D1(byte_i[1]), .D2(byte_i[2]), .D3(byte_i[3]),
        .D4(byte_i[4]), .D5(byte_i[5]), .D6(byte_i[6]), .D7(byte_i[7]),
        .PCLK(pclk), .FCLK(fclk), .RESET(reset),
        .TX0(1'b0), .TX1(1'b0), .TX2(1'b0), .TX3(1'b0),
        .Q0(serial_nrz), .Q1()
    );

    TLVDS_TBUF u_diff (
        .I(serial_nrz), .OEN(~hs_on), .O(hs_p_pad), .OB(hs_n_pad)
    );

    assign lp_p_pad = lp_pass & lp_p_i;
    assign lp_n_pad = lp_pass & lp_n_i;
endmodule
```

Los cuatro `*_pad` son **pines físicos distintos**. Las uniones HS/LP y los 100 Ω están en la placa, no en Verilog. `hs_enable` y `lp_clamp` deben llegar ya secuenciados; este módulo no genera los tiempos D-PHY ni configura la PLL. Antes de programar, verificar el mapeo del `OSER8` y `TLVDS_TBUF`, las restricciones de pines/tensión y la fase de CLK en Gowin para el `GW2AR-18`. Referencia de primitivas: [Gowin UG289, §§3.6.7 y 4.3.4](https://cdn.gowinsemi.com.cn/UG289E.pdf).

## Temporización medida

- Muestreo: 100 MHz, 10 ns por muestra. Cada archivo dura 5 s.
- Periodo horizontal aproximado: 2120 muestras, 21,2 µs.
- Repetición vertical: 743 periodos horizontales. Ajuste de fase entre 30 cuadros: aproximadamente 1 575 157,6 muestras, 15,751576 ms, 63,4857 Hz.
- El ajuste fraccional es una estimación para reconstrucción; no demuestra un divisor fraccional del transmisor. Los relojes del analizador y transmisor no son necesariamente síncronos.
- Una línea observada: LP11 ~220 ns → LP01 ~100 ns → primer tramo LP00 ~110 ns → actividad HS. El último valor NO identifica por sí solo T_HS-PREPARE.
- No se midió reloj útil. No asignar frecuencia DDR o bitrate a partir de la figura.
- No se separaron HSA/HBP/HFP, VSA/VBP/VFP ni altura activa. Los 743 son periodos totales, no filas visibles.

## PHY LP para reproducir la inicialización

Orden P,N: reposo 11 → 10 (~100 ns) → 00 (~100 ns) → 01 (~100 ns) → 00 (~500 ns) → escape LPDT 87 → paquete DSI → salida.
Los bytes se envían LSB primero. El escape 87 se transmite como bits `1 1 1 0 0 0 0 1`.
Cada bit normal: 1=10 y 0=01, durante ~100 ns, seguido de 00 durante ~100 ns; aproximadamente 5 Mbit/s.
Al final observado del mensaje: el último pulso se alarga a ~200 ns, luego 00 ~300 ns, 10 ~100 ns y reposo 11. No confundir ese último pulso con un bit adicional.
Los tiempos citados describen esta captura; no sustituyen los límites eléctricos/temporales de D-PHY ni del datasheet del panel.

## Inicialización LP exacta capturada

Las horas son relativas al comienzo de D0; no son retardos de alimentación. `Δ inicio` mide el tiempo entre entradas LP consecutivas, no una pausa después del paquete. `Pausa LP11` se midió desde la vuelta a 11 hasta la siguiente entrada LP; el último reposo termina al entrar en HS.
Se validaron los 18 ECC y los 16 CRC de paquetes largos. Cada fila conserva **todos los bytes de cable**, incluido el escape 87.

| # | Inicio (s) | Δ inicio (ms) | Bytes completos, hexadecimal |
|---|---:|---:|---|
| 1 | 1.45719352 | — | `87 29 02 00 00 B0 00 D6 CA` |
| 2 | 1.46620891 | 9.015390 | `87 29 06 00 23 E4 00 00 00 00 08 87 16` |
| 3 | 1.47523070 | 9.021790 | `87 29 04 00 3F D0 45 45 71 42 9E` |
| 4 | 1.48424928 | 9.018580 | `87 09 02 00 15 00 00 B8 F0` |
| 5 | 1.49326467 | 9.015390 | `87 05 11 45 04` |
| 6 | 1.55827357 | 65.008900 | `87 29 03 00 1A D0 52 4A 25 BB` |
| 7 | 1.56729056 | 9.016990 | `87 29 0D 00 00 B9 02 00 76 00 BA BB BF CC E3 46 81 31 D0 E5` |
| 8 | 1.57632354 | 9.032980 | `87 29 0C 00 1A BD FF FE FE FE FE FE FE 80 20 00 00 2A E3` |
| 9 | 1.58535493 | 9.031390 | `87 29 09 00 23 BE FF 0F 00 18 04 04 00 5D E7 C4` |
| 10 | 1.59438152 | 9.026590 | `87 29 02 00 00 B0 03 4D F8` |
| 11 | 1.65939682 | 65.015300 | `87 09 02 00 15 00 00 B8 F0` |
| 12 | 1.66841220 | 9.015380 | `87 05 29 03 1F` |
| 13 | 1.67742119 | 9.008990 | `87 29 02 00 00 B0 00 D6 CA` |
| 14 | 1.68643658 | 9.015390 | `87 29 09 00 23 BE FF 0F 00 18 04 04 00 5D E7 C4` |
| 15 | 1.69546316 | 9.026580 | `87 29 10 00 3A B7 18 00 18 18 0C 09 AC 09 5C 09 0C 09 00 10 00 44 32` |
| 16 | 1.70450095 | 9.037790 | `87 29 0E 00 06 B8 F8 DA 6D FB FF FF 4F 1F 7F 9F BF DF FF AB 18` |
| 17 | 1.71353554 | 9.034590 | `87 29 02 00 00 BB 2F 8B F7` |
| 18 | 1.72255092 | 9.015380 | `87 29 02 00 00 B0 03 4D F8` |

Pausas LP11 observadas después de filas 1–18, en ms, aproximadamente:
`8.99979, 8.99980, 8.99979, 8.99980, 64.99971, 8.99980, 8.99979, 8.99979, 8.99980, 64.99971, 8.99979, 8.99979, 8.99980, 8.99979, 8.99979, 8.99980, 8.99979, 6.99997`.

Interpretación relevante:
- DI=29: Generic Long Write. DI=09: Null Packet; no interpretar sus ceros como comandos del panel.
- Fila 5: DI=05, comando DCS 11 (*Sleep Out*). Fila 12: DI=05, comando DCS 29 (*Display On*).
- Los bytes 45 y 03 en esos headers cortos son datos transmitidos reales. Aunque el comando no usa segundo parámetro, el ECC se calcula con los tres bytes del header tal como se envían.
- El payload de un Generic Long Write se conserva sin inventar el significado de registros propietarios.
- No se capturó reset/alimentación en estos canales. No asumir que el primer paquete sea toda la secuencia de encendido.

## Generador de paquetes DSI

Header de 4 bytes: `DI D0 D1 ECC`. `DI=(VC<<6)|DT`.
Paquete corto: solo header. Paquete largo: `DI WC_L WC_H ECC payload[WC] CRC_L CRC_H`.
WC cuenta únicamente los bytes de payload. ECC son 6 bits de paridad sobre los 24 bits anteriores; bits superiores del byte ECC a cero. CRC16 sobre payload con estado inicial FFFF y polinomio reflejado 8408; enviar primero el byte bajo.
Ejemplo verificado: `87 29 02 00 00 B0 00 D6 CA`: escape 87, DT29, WC0002, ECC00, payload B000, CRC CAD6.

### ECC listo para implementar

Numerar `d[23:0] = {D1, D0, DI}`; `d[0]` es el bit menos significativo de DI. Cada fila indica los bits que se combinan con XOR:

| Bit ECC | Índices de d |
|---|---|
| p0 | 0,1,2,4,5,7,10,11,13,16,20,21,22,23 |
| p1 | 0,1,3,4,6,8,10,12,14,17,20,21,22,23 |
| p2 | 0,2,3,5,6,9,11,12,15,18,20,21,22 |
| p3 | 1,2,3,7,8,9,13,14,15,19,20,21,23 |
| p4 | 4,5,6,7,8,9,16,17,18,19,20,22,23 |
| p5 | 10,11,12,13,14,15,16,17,18,19,21,22,23 |

Transmitir `ECC={2'b00,p5,p4,p3,p2,p1,p0}`. Estas ecuaciones reprodujeron los 18 ECC capturados.

### CRC16 listo para implementar

Inicializar `crc=16'hFFFF` al comienzo de cada payload largo. Para cada byte, procesar bits de 0 a 7:

```text
feedback = crc[0] XOR byte[bit]
crc = crc >> 1
si feedback == 1: crc = crc XOR 16'h8408
```

Sin XOR final: enviar `crc[7:0]`, después `crc[15:8]`. No incluir escape, header, ECC ni SoT en este cálculo. Este algoritmo reprodujo los 16 CRC capturados.

### Formato HS estándar, condicionado a confirmar RGB888 y dos lanes

Cada lane comienza su transmisión HS con sincronización SoT (byte B8). No confundirlo con escape LPDT 87.
El paquete lógico sigue con header/payload/CRC. Con 2 lanes, repartir bytes consecutivos alternadamente: lane0=B[0],B[2]…; lane1=B[1],B[3]…; los bits dentro de cada byte son LSB primero.
En RGB888: DT=3E; payload `R0 G0 B0 R1 G1 B1 …`. Para 720 píxeles, WC=2160=0870h. Estos valores son ejemplo de la referencia, **no lectura confirmada de los paquetes HS de consola**.
Blanco ideal: FF FF FF; azul puro ideal: 00 00 FF. No se conocen los valores RGB exactos del logo ni se asegura que se use RGB888 en la consola.
Los paquetes de sincronismo/blanking, su orden y si hay paquetes adicionales aún deben confirmarse. No se dibuja una trama de video burst/no-burst supuestamente observada.
D0 y D1 no deben intercalarse directamente: las capturas tienen distinta fase temporal y no se ha establecido simultaneidad.

## Referencia local, no equivalente a la consola

Fuente: `RPI-LCD-LT031MDZ4000/panel-jdi-lt031mdz4000.c`, funciones `jdi_panel_probe`, `jdi_panel_init`, y `default_mode`.
- Configura 2 lanes y `MIPI_DSI_FMT_RGB888`.
- Flags `MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_HSE | MIPI_DSI_CLOCK_NON_CONTINUOUS`, sin BURST: referencia de video no-burst con sync pulses y clock no continuo.
- H: 720 activos +21 front porch +2 sync +24 back porch =767.
- V: 720 activos +25 front porch +5 sync +3 back porch =753.
- Pixel clock 34,653 MHz: TH≈22.133726 µs, cuadro≈16.666696 ms, refresco≈59.999896 Hz.
- La inicialización se parece en varios registros, pero no coincide completamente con la captura: no sustituir una por otra sin validación.
- Los tiempos de esta referencia NO coinciden con TH≈21,2 µs y 743 periodos/cuadro observados.

## Lo que falta para cerrar el RTL

1. Establecer lane bitrate/UI, reloj de byte y relación con el reloj DDR del PHY; obtener una captura diferencial HS adecuada.
2. Decodificar header HS DI/WC/ECC, CRC y payload de al menos una línea blanca y una que atraviese el texto.
3. Fijar resolución activa, empaquetado RGB, número/polaridad de lanes y orden exacto de paquetes de video.
4. Medir o establecer con datasheet T_HS-*, T_CLK-*, porches/sync, reset y alimentación.
5. Implementar las capas separadas: secuenciador LP, generador de header/ECC/CRC, temporizador de video, striping de lanes y PHY HS/clock. No sustituir D-PHY por niveles GPIO sin especificación eléctrica.

## Gráfica añadida: inicialización → cuadro completo → primer píxel

El SVG/PDF incluye dos ampliaciones nuevas:

- **Sección 7:** los 18 mensajes LP en orden, tiempo relativo, DI, payload/comando y pausa LP11 posterior. Muestra la transición de inicialización a video HS. La primera entrada LP está a 1,45719352 s y la entrada HS tras el último reposo queda aproximadamente a 1,729566 s. No se conoce la relación de estos instantes con reset o alimentación.
- **Sección 8:** cuadro completo con sincronización/blanking, primera línea activa, paquete de píxeles, reparto entre lanes y bits del primer píxel blanco. La estructura funcional de sync/porches no representa una secuencia de paquetes leída de HS.

### Ejemplo calculado del primer píxel, no bytes decodificados de HS

Condiciones del ejemplo: VC=0, RGB888, dos lanes y 720 píxeles por línea. No asignar estas condiciones al transmisor hasta confirmar sus paquetes.

```text
Inicialización LP (18 mensajes) → entrada HS → cuadro 0 → cuadro 1 → …

Cuadro lógico:
Vsync / VBP → línea activa y=0 → líneas y=1…Vactivo−1 → VFP → cuadro siguiente

Primera línea activa:
sync horizontal / HBP → paquete RGB (x=0…719) → HFP / cierre

Paquete RGB:
3E 70 08 13 | FF FF FF | R1 G1 B1 … R719 G719 B719 | CRC_L CRC_H
   header      R0 G0 B0             resto de línea
```

El header calculado es `DI=3E`, `WC=0870h` (2160 bytes), `ECC=13`. Si **toda la línea** es blanca, los 2160 bytes del payload son FF y el CRC calculado es 3425h: bytes de cable `25 34`. Que solo el primer píxel sea blanco no determina el CRC de toda la línea.

| Ciclo de byte desde header | Lane 0 | Lane 1 | Función |
|---:|---|---|---|
| SoT, antes del header | B8 | B8 | Sincronización PHY por lane |
| 0 | 3E | 70 | DI / WC bajo |
| 1 | 08 | 13 | WC alto / ECC |
| 2 | FF = R0 | FF = G0 | Primeros dos componentes del píxel (0,0) |
| 3 | FF = B0 | R1 | Completa el primer píxel; inicia el siguiente |
| 4 | G1 | B1 | Completa el segundo píxel |
| … | … | … | Continúa hasta x=719 |
| 1082 | CRC_L | CRC_H | CRC del payload completo |

Definir `UI=1/Rlane`, `Tbyte=8·UI` y `FCLK=Rlane/2` por transmisión DDR. No se tiene un bitrate HS validado para reemplazar UI por nanosegundos.

El primer triplete RGB queda completo al finalizar B0: 16 UI desde el comienzo de R0/G0, o 32 UI desde el comienzo del header (sin contar SoT). El ritmo sostenido es 12 UI/píxel porque dos píxeles RGB888 ocupan tres ciclos de byte entre las dos lanes.

En un byte FF, los ocho bits LSB-first son uno: la lane puede permanecer sin flancos de datos durante todo el byte. Aun así el reloj D-PHY debe funcionar durante la transferencia HS. El reloj dibujado es **ilustrativo**, no recuperado del canal CLK.

Al reunir `R0=G0=B0=FF`, el receptor tiene el blanco del píxel lógico (0,0). Esto no determina la latencia física hasta que el panel lo muestra: puede haber buffers, validación de CRC y temporización de escaneo interna. Tampoco implica un comando DCS `2C` por píxel; el ejemplo es video por paquetes RGB.

## Archivos

- [Formas de onda: PDF de dos páginas](mipi_flujo_ondas.pdf).
- [Flujo total: inicialización y video, SVG](mipi_flujo_total_ondas.svg) / [PNG](mipi_flujo_total_ondas.png).
- [Detalle: Display On, LP, entrada HS y primer píxel, SVG](mipi_detalle_ondas.svg) / [PNG](mipi_detalle_ondas.png).
- `mipi_controlador_trama.svg`: diagrama vectorial.
- `mipi_controlador_trama.pdf`: formas de onda originales, figura 4-3 de Gowin y apéndice NRZ con compuertas y Verilog.
- `mipi_controlador_init.csv`: bytes exactos y tiempos de inicio para el secuenciador LP.

## Reloj no visible: qué se puede concluir

**LP:** las transiciones independientes de P y N permiten decodificar la transmisión sin la lane de reloj. La inicialización aquí validada utiliza LPDT.

**HS D-PHY convencional:** el receptor necesita la lane de reloj diferencial durante la recepción HS. SoT permite alinear los bytes; no sustituye el reloj de muestreo. Header/WC/ECC delimitan los paquetes y los eventos de sincronismo delimitan el video.

La observación de un canal CLK sin oscilación **en el analizador** no demuestra que el reloj diferencial físico esté ausente. Podría no ser resuelto por esa medición; no se ha comprobado la causa. Los archivos analizados solo contienen P/N de datos y no aportan una medición independiente del reloj. El umbral configurado de los canales de datos figura como 0,25 V en los metadatos; no se debe convertir el eje 0/1 de los diagramas a una amplitud real.

`Display On` sí aparece: mensaje 12, entrada LP a **1,66841220 s**, bytes completos `87 05 29 03 1F`, con ECC correcto. Su comando DCS es `29`; `87` es escape LPDT, `05` es DI y `1F` es ECC. Habilita la presentación, pero no constituye una fuente de reloj para el enlace. También se observó `Sleep Out` (`11`) en el mensaje 5.

Un panel en command mode puede tener memoria y temporización de escaneo interna; esa posibilidad no demuestra que esta consola esté usando dicho modo y tampoco elimina el requisito de reloj de una transferencia HS D-PHY.

Las nuevas láminas distinguen: envolvente comprimida de actividad para ver el flujo global; muestras digitales reales de P/N en las ampliaciones; y señales de un ejemplo RGB888 calculado. El reloj ideal solo se dibuja en este último ejemplo, explícitamente como no medido.

No se modificaron capturas, RTL ni firmware. No se programó hardware.
