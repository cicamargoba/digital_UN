# Ejemplo Migen/LiteX: `blink`

El módulo [`blink.py`](./blink.py) muestra:

- lógica síncrona descrita con Migen;
- separación entre el núcleo funcional y su interfaz LiteX;
- registros CSR `enable` y `period`;
- una señal de salida que puede conectarse a un LED de la plataforma;
- simulación independiente del núcleo funcional.

## Registros

| CSR | Acceso | Descripción |
|---|---|---|
| `enable` | R/W | Habilita el parpadeo |
| `period` | R/W | Ciclos de reloj entre cambios de estado |

Este ejemplo no reemplaza la integración del SoC. El estudiante debe instanciar el módulo, agregar sus CSR y conectar `led` a un recurso de la plataforma.
