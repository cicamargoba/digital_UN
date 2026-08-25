# Estudio de instrucciones de femtoRV32

Crear una sección por cada instrucción o grupo de instrucciones asignado.

| Campo | Contenido requerido |
|---|---|
| Instrucción | Nombre y formato RISC-V |
| Codificación | `opcode`, `funct3`, `funct7` y campos aplicables |
| Registros | Fuentes y destino |
| Datapath | Ruta seguida por los operandos y el resultado |
| Control | Señales que habilitan la operación |
| Memoria | Lectura o escritura, si corresponde |
| PC | Forma en que cambia el contador de programa |
| Firmware | Programa mínimo que ejecuta la instrucción |
| Simulación | Señales y resultado esperado |
| LiteScope | Evidencia capturada en FPGA |

El análisis debe basarse en el RTL y en señales observables. No debe limitarse a copiar la descripción del manual RISC-V.
