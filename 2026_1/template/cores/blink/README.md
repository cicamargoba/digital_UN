# Ejemplo guía: periférico `blink`

Este ejemplo muestra la organización mínima esperada para cada periférico:

- `diagramas/`: comportamiento e interfaz del módulo;
- `rtl/`: módulo Verilog, testbench, Makefile y configuración de GTKWave;
- `firmware/`: driver C para acceder a sus registros.

## Registros CSR

| Desplazamiento | Nombre | Acceso | Descripción |
|---|---|---|---|
| `0x00` | `CONTROL` | R/W | Bit 0: habilita el parpadeo |
| `0x04` | `PERIOD` | R/W | Número de ciclos de reloj por cada cambio del LED |

El módulo recibe la dirección local del periférico. El decodificador del SoC debe generar `cs` y restar la dirección base antes de conectarla a `addr`.
Para este ejemplo se reserva `0x500000`, fuera de las ventanas del mapa principal. Al integrar otro periférico, el grupo debe usar la dirección que le haya sido asignada.

## Simulación

```bash
cd rtl
make sim
```

La prueba configura un período corto, habilita el módulo, verifica la lectura de los CSR y comprueba que el LED cambie de estado.
