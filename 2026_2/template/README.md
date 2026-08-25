# Plantilla del proyecto Digital 2

Cada grupo debe conservar esta organización y reemplazar el contenido de ejemplo por los módulos asignados.

```text
template/
├── .github/
│   └── ISSUE_TEMPLATE/  # Formulario para crear tareas
├── planificacion/       # Configuración y uso de GitHub Projects
├── docs/
│   ├── diagramas/       # Diagramas de bloques, flujo y estados
│   └── instrucciones/   # Análisis de instrucciones de femtoRV32
├── soc/
│   ├── cores/           # Periféricos Migen/LiteX o RTL integrado
│   ├── network/         # Integración y uso de la interfaz de red
│   ├── dma/             # Transferencias por acceso directo a memoria
│   └── litescope/       # Configuración y capturas de LiteScope
├── firmware/            # Firmware y drivers del sistema
└── sim/                 # Pruebas reproducibles
```

## Requisitos mínimos

1. Documentar las instrucciones estudiadas y relacionarlas con señales internas de femtoRV32.
2. Construir el SoC con LiteX.
3. Integrar una interfaz de red con una función verificable.
4. Implementar al menos una transferencia mediante DMA.
5. Utilizar LiteScope para capturar señales internas relevantes.
6. Entregar simulaciones reproducibles y evidencia de funcionamiento en FPGA.

El periférico [`soc/cores/blink/`](./soc/cores/blink/) es únicamente una guía de estructura e integración con CSR.
