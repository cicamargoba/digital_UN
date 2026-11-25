# MIPI_TX simplificado: nueva base

Referencia actual aportada por Carlos: `MIPI_TX_componentes.pdf`, una página,
con los componentes internos de los cuatro bloques simplificados. El archivo
conserva el PDF original sin modificaciones.

`MIPI_TX_bloques.pdf` conserva la vista general anterior aportada como
`MIPI_TX_simplificado-1.pdf`, de dos páginas. Se mantiene como complemento,
no como sustituto del nuevo diagrama de componentes.

- `MIPI_TX_bloques.svg` / PNG: primera página, arquitectura de cuatro bloques.
- `MIPI_TX_secuencia.svg` / PNG: segunda página, secuencia y distribución de palabras.

Bloques adoptados: LINK_FSM + TIMER, LP_TX, HS_PACKER y PHY_IF.
El camino HS es de 16 bits: un byte por lane y ciclo de CLK_BYTE.

## Cambios de interfaz respecto al TOP anterior

- `VID_BYTE[7:0]` pasa a `VID_WORD[15:0]`.
- Se añade `VID_LINE_RDY` para garantizar que se puede entregar toda la línea sin pausas.
- `VID_RD` solicita la siguiente palabra de píxeles.
- Desaparece `VID_HDR[23:0]`: el header se genera como constante en HS_PACKER.
- Se conserva el cálculo CRC16 sobre los píxeles, procesando dos bytes por ciclo.
- El dibujo distingue `INIT_NEXT`, `INIT_READY` e `INIT_DONE_TX`.

## Punto pendiente antes de adaptar CTRL y el TOP

Confirmar si `INIT_NEXT` es el pulso por byte para avanzar A_COUNT y si
`INIT_READY` indica disponibilidad para empezar un nuevo paquete. El flujo
anterior utilizaba INIT_READY para avanzar por cada byte; no deben intercambiarse
esas funciones por una suposición.

El TOP, su fuente de video y el PDF conjunto de arquitectura todavía corresponden
a la interfaz anterior mientras se aclara este punto. No se han modificado RTL
ni el flujo de CTRL por la adopción de este PDF.

El formato 720 píxeles/RGB888, el header fijo y sus palabras son parámetros de
esta propuesta, no valores obtenidos de una decodificación HS validada. El PDF
también deja pendientes los tiempos físicos y el reloj real.

No regenerar el PDF de dos páginas desde únicamente el SVG de la primera.
El generador de los otros diagramas debe conservar esta nueva base de MIPI_TX.
