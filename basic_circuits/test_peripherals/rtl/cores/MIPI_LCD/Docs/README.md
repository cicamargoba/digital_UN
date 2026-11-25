# MIPI LCD: documentación y estado

## Arquitectura

- [MIPI_TX simplificado, base actual aportada por Carlos](MIPI_TX_bloques.pdf):
  dos páginas, cuatro bloques y camino HS de 16 bits.
- [Secuencia del MIPI_TX simplificado](MIPI_TX_secuencia.svg).
- [Adopción y cambios de interfaz pendientes](MIPI_TX_adopcion.md).
- [TOP de trabajo](MIPI_LCD_vid_mem_bloques.svg).
- [PHY de trabajo y onda LPDT](MIPI_PHY_bloques.svg).
- [Flujo de CTRL](CTRL_flujo_inicio.pdf), con pasos formados únicamente por
  asignaciones de las señales de control.

**Integración pendiente:** el TOP, el flujo de CTRL y el PDF conjunto
`MIPI_LCD_arquitectura.pdf` todavía corresponden al transmisor anterior. No son
una integración terminada con el nuevo MIPI_TX. Falta confirmar el papel de
INIT_NEXT frente a INIT_READY y adaptar la fuente de video a VID_WORD[15:0],
VID_RD y VID_LINE_RDY. El nuevo HS_PACKER genera un header constante y elimina
VID_HDR externo para la configuración propuesta.

Los generadores mantenidos están en `../tools/`. El generador general conserva
el MIPI_TX aportado por Carlos en lugar de sobrescribirlo con el dibujo anterior.
No reconstruir su PDF de dos páginas a partir de solo el SVG de la primera.

## ROM de inicialización

- [Formato y secuencia](INIT_MEM_ROM.md).
- [Mapa completo de direcciones](init_mem_map.csv).
- [Bytes capturados](init_packets.csv).
- Datos: `../init_mem.hex`; generador: `../gen_init_mem.py`.

223 posiciones de 11 bits: OP[1:0], LAST y ARG[7:0]. Hay 204 bytes DSI,
18 esperas de 7/9/65 ms y un END. LAST=1 identifica WAIT, que no se transmite;
los bytes de header, ECC, payload y CRC llevan LAST=0. El escape LPDT 87 lo
genera LP_TX, no se duplica en ROM.

## Capturas y extracción

[Resultados, procedencia y revisión técnica](extraccion_025/README.md).
Las imágenes nuevas de D0 y D1 se obtienen exclusivamente de las muestras.
Son actividad gris o segmentada, **no RGB decodificado**. La carpeta conserva
matrices, parámetros y SHA-256 de las dos fuentes. Los KVdat originales, de unos
2 GB en total, no se incluyen en Git.

Herramientas: `../extract_capture_activity.py` y
`../tools/probe_mipi_equiv.py`. Reciben las rutas de captura como argumentos;
no necesitan una fotografía ni un archivo de imagen de referencia.

Los documentos anteriores en la ruta del repositorio `FPGBC/Docs/mipi_*`
se conservan como antecedentes. Sus ejemplos coloreados o formatos hipotéticos
no deben confundirse con una decodificación HS validada.

## Límites actuales

No se ha creado RTL ni validado físicamente este controlador. El formato RGB888
de 720 píxeles, el reloj real, los tiempos HS y el modo de reloj/EoTp requieren
cerrar la configuración del panel. También falta definir memoria/escalado/buffer
de línea y garantizar dos bytes por ciclo de byte HS. La ROM y sus checksums sí
se verificaron contra los paquetes LP capturados.
