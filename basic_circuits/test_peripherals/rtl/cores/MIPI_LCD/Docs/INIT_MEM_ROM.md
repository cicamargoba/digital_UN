# INIT_MEM: paquetes completos de inicialización

## Formato adoptado

Cada posición de `init_mem.hex` tiene **11 bits**: `{OP[1:0], LAST, ARG[7:0]}`.
OP ocupa los bits 10:9; LAST el bit 8; ARG los bits 7:0.

| OP | Operación | ARG |
|---|---|---|
| 00 | BYTE | Byte DSI; LAST=0 |
| 01 | WAIT_MS | Espera en milisegundos; LAST=1; no se transmite |
| 10 | END | Fin de inicialización |
| 11 | Reservado | No utilizado |

Salidas lógicas de la ROM: OP[1:0], LAST, INIT_BYTE=ARG[7:0] y
DELAY_MS=ARG[7:0]. INIT_BYTE se conecta al transmisor; DELAY_MS a D_COUNT.
ARG tiene ocho bits, usados como byte o como cantidad de ticks de 1 ms.

Los paquetes se almacenan consecutivamente, incluidos el header, su ECC y, en
los paquetes largos, payload y CRC. **LAST=1 identifica la entrada WAIT que
sigue al paquete; no el último byte transmitido.** Todos los bytes DSI tienen
LAST=0, incluidos CRC_H o el ECC final de un paquete corto. No se deduce el fin
por un valor especial del byte, porque cualquier valor puede aparecer en el payload.

En esta codificación LAST es una marca explícita de WAIT, redundante con OP=01,
para permitir la condición LAST=1 en el flujo acordado. END se distingue por OP=10.

El escape PHY `87` **no se almacena**: LP_TX lo genera una vez al comenzar cada
paquete. Si el payload contiene 87, ese byte sí se conserva como dato.

## Ejemplo: primer paquete y comienzo del siguiente

| Dirección | Palabra ROM | Operación | ARG | LAST |
|---:|---|---|---|---:|
| 0 | `029` | BYTE | `29` | 0 |
| 1 | `002` | BYTE | `02` | 0 |
| 2 | `000` | BYTE | `00` | 0 |
| 3 | `000` | BYTE | `00` | 0 |
| 4 | `0B0` | BYTE | `B0` | 0 |
| 5 | `000` | BYTE | `00` | 0 |
| 6 | `0D6` | BYTE | `D6` | 0 |
| 7 | `0CA` | BYTE | `CA` | 0 |
| 8 | `309` | WAIT_MS | `9 ms` | 1 |
| 9 | `029` | BYTE | `29` | 0 |
| 10 | `006` | BYTE | `06` | 0 |

La primera trama DSI almacenada es `29 02 00 00 B0 00 D6 CA`. La salida LPDT
incluye delante el escape: `87 29 02 00 00 B0 00 D6 CA`.

## Control de secuencia

En S_INIT, CTRL mantiene RST_ALL=1 (A_COUNT y D_COUNT en cero), INIT_DONE=0
(VIDEO_TIMING deshabilitado), INIT_REQ=0, INC_A=0 y START_DELAY=0. En S_READ
libera RST_ALL, conserva el video deshabilitado y da un ciclo para leer ROM[0].
El primer byte DSI es 29, con OP=BYTE y LAST=0. El flujo de comandos está
dibujado en CTRL_flujo_inicio; todavía no existe RTL que implemente estos estados.

1. BYTE: INIT_REQ=1 durante un estado; después INIT_REQ=0 y esperar INIT_READY=1.
2. Incrementar A_COUNT durante un estado; después INC_A=0 y evaluar LAST de la nueva palabra.
3. LAST=0: enviar el siguiente byte. LAST=1: es WAIT, no activar INIT_REQ ni incrementar A_COUNT.
4. Mantener la dirección del WAIT mientras INIT_LAST notifica el cierre del paquete LP;
   esperar INIT_DONE_TX antes de iniciar el temporizador.
5. START_DELAY=1 durante un estado, después START_DELAY=0 y esperar DONE_DELAY=1.
6. Con DONE_DELAY=1, incrementar A_COUNT, bajar INC_A y leer OP: BYTE continúa
   el envío; END mantiene INIT_REQ=0 e INC_A=0 y activa INIT_DONE=1.

Las esperas nominales conservadas son 9 ms, dos pausas de 65 ms y una final de
7 ms. Proceden de la captura, no de mínimos universales del panel. La captura no
define por sí sola toda la secuencia de reset o alimentación.

## Comprobación y reproducción

Origen de bytes: `Docs/init_packets.csv`, procedente de MIPI_VIDEO_025_D0.
`gen_init_mem.py` conserva los bytes capturados y valida los 18 ECC y los 16 CRC;
no los sustituye por otros valores. El cálculo del script es una verificación
fuera de línea: MIPI_TX no recalcula ECC ni CRC para inicialización.

Resultado: **223 palabras**, **18 paquetes**, **18 esperas** y un END.
Se verificó por lectura de `init_mem.hex` que los paquetes reconstruidos coinciden
byte por byte con los originales, sin el escape PHY inicial.

Los bloques ECC y CRC de MIPI_TX permanecen para video. Los bytes de INIT_MEM
deben pasar directamente al selector previo a LP_TX, sin atravesarlos.

Se ha creado el contenido de ROM y su mapa; todavía no existe RTL que lo ejecute.
