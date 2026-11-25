from pathlib import Path
import argparse
import csv
import io

ROOT = Path(__file__).resolve().parent
BYTE = 0
WAIT = 1
END = 2
PAUSES_MS = [9, 9, 9, 9, 65, 9, 9, 9, 9, 65, 9, 9, 9, 9, 9, 9, 9, 7]
ECC_GROUPS = [
    [0, 1, 2, 4, 5, 7, 10, 11, 13, 16, 20, 21, 22, 23],
    [0, 1, 3, 4, 6, 8, 10, 12, 14, 17, 20, 21, 22, 23],
    [0, 2, 3, 5, 6, 9, 11, 12, 15, 18, 20, 21, 22],
    [1, 2, 3, 7, 8, 9, 13, 14, 15, 19, 20, 21, 23],
    [4, 5, 6, 7, 8, 9, 16, 17, 18, 19, 20, 22, 23],
    [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23],
]


def validate_packet(packet):
    assert len(packet) >= 4
    header = int.from_bytes(packet[:3], 'little')
    ecc = sum((sum((header >> bit) & 1 for bit in group) % 2) << k
              for k, group in enumerate(ECC_GROUPS))
    assert packet[3] == ecc, 'ECC incorrecto en la captura de entrada'
    if packet[0] in (0x09, 0x29):
        length = int.from_bytes(packet[1:3], 'little')
        assert len(packet) == 4 + length + 2
        crc = 0xffff
        for byte in packet[4:-2]:
            for bit in range(8):
                feedback = (crc ^ (byte >> bit)) & 1
                crc >>= 1
                if feedback:
                    crc ^= 0x8408
        assert crc == int.from_bytes(packet[-2:], 'little'), 'CRC incorrecto'
    else:
        assert packet[0] == 0x05 and len(packet) == 4


def encode(op, last, arg):
    assert op in (BYTE, WAIT, END) and last in (0, 1) and 0 <= arg < 256
    assert last == int(op == WAIT)
    return (op << 9) | (last << 8) | arg


def build(input_path, output_path, docs):
    rows = list(csv.DictReader(input_path.open()))
    assert len(rows) == len(PAUSES_MS)
    records = []
    expected = []
    for index, (row, pause) in enumerate(zip(rows, PAUSES_MS), 1):
        wire = bytes.fromhex(row['wire_bytes_including_87'])
        assert wire[0] == 0x87
        packet = wire[1:]
        validate_packet(packet)
        expected.append(packet)
        for byte in packet:
            records.append((encode(BYTE, 0, byte), index, 'BYTE', 0, byte))
        records.append((encode(WAIT, 1, pause), index, 'WAIT_MS', 1, pause))
    records.append((encode(END, 0, 0), '', 'END', 0, 0))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(''.join(f'{word:03X}\n' for word, *_ in records))
    stored = [int(v, 16) for v in output_path.read_text().split()]
    recovered = []
    current = bytearray()
    waits = []
    for word in stored:
        assert word < 1 << 11
        op, last, arg = word >> 9, (word >> 8) & 1, word & 0xff
        if op == BYTE:
            assert not last
            current.append(arg)
        elif op == WAIT:
            assert current and last
            recovered.append(bytes(current))
            current.clear()
            waits.append(arg)
        else:
            assert not current and not last
            assert op == END and word == stored[-1] == encode(END, 0, 0)
    assert recovered == expected and waits == PAUSES_MS
    docs.mkdir(parents=True, exist_ok=True)
    table = io.StringIO()
    writer = csv.writer(table)
    writer.writerow(['address', 'rom_word_11b', 'packet', 'operation', 'last', 'argument'])
    for address, (word, packet, operation, last, arg) in enumerate(records):
        writer.writerow([address, f'{word:03X}', packet, operation, last,
                         f'{arg:02X}' if operation == 'BYTE' else arg])
    (docs / 'init_mem_map.csv').write_text(table.getvalue())
    example = ['| Dirección | Palabra ROM | Operación | ARG | LAST |',
               '|---:|---|---|---|---:|']
    for address, (word, _, operation, last, arg) in enumerate(records[:11]):
        value = f'{arg:02X}' if operation == 'BYTE' else f'{arg} ms'
        example.append(f'| {address} | `{word:03X}` | {operation} | `{value}` | {last} |')
    text = f'''# INIT_MEM: paquetes completos de inicialización

## Formato adoptado

Cada posición de `init_mem.hex` tiene **11 bits**: `{{OP[1:0], LAST, ARG[7:0]}}`.
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

{chr(10).join(example)}

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

Resultado: **{len(records)} palabras**, **18 paquetes**, **18 esperas** y un END.
Se verificó por lectura de `init_mem.hex` que los paquetes reconstruidos coinciden
byte por byte con los originales, sin el escape PHY inicial.

Los bloques ECC y CRC de MIPI_TX permanecen para video. Los bytes de INIT_MEM
deben pasar directamente al selector previo a LP_TX, sin atravesarlos.

Se ha creado el contenido de ROM y su mapa; todavía no existe RTL que lo ejecute.
'''
    (docs / 'INIT_MEM_ROM.md').write_text(text)
    print(f'ROM: {len(records)} palabras de 11 bits; LAST=1 en las 18 esperas, nunca en los bytes.')
    print('Validado: 18 ECC, 16 CRC y lectura inversa de todos los paquetes.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, default=ROOT / 'Docs' / 'init_packets.csv')
    parser.add_argument('--output', type=Path, default=ROOT / 'init_mem.hex')
    parser.add_argument('--docs', type=Path, default=ROOT / 'Docs')
    args = parser.parse_args()
    build(args.input, args.output, args.docs)
