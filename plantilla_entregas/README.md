# Requerimientos para la entrega de proyectos en Verilog

Cada entrega debe contener el código Verilog, sus bancos de prueba, la configuración utilizada para revisar las formas de onda y la documentación gráfica del diseño.

La entrega debe conservar la siguiente estructura:

```text
entrega/
├── README.md
├── codigo_verilog_testbench_waveform/
└── diagramas_flujo_bloques_estados/
```

## 1. Código Verilog, testbench y formas de onda

En `codigo_verilog_testbench_waveform/` se deben incluir:

- todos los módulos Verilog que forman el diseño;
- el módulo superior del proyecto;
- un testbench para cada módulo desarrollado;
- un testbench para el diseño completo;
- los archivos `.gtkw` utilizados para visualizar las señales en GTKWave;
- un `Makefile` que permita ejecutar los procesos de simulación, comprobación de síntesis y generación de diagramas RTL;
- todos los archivos `.svg` generados mediante `make svg`.

La nomenclatura debe relacionar claramente cada módulo con sus archivos de prueba y visualización:

```text
nombre_modulo.v
nombre_modulo_TB.v
nombre_modulo_sim.gtkw
```

Ejemplo:

```text
comp_ws.v
comp_ws_TB.v
comp_ws_sim.gtkw
```

Los nombres de los módulos, archivos y testbenches deben coincidir. El módulo instanciado en `nombre_modulo_TB.v` debe ser el definido en `nombre_modulo.v`.

## 2. Configuración del `Makefile`

Antes de ejecutar las pruebas, se debe configurar la variable `TARGET` con el nombre del módulo superior, sin la extensión `.v`:

```make
TARGET = nombre_modulo
```

La variable `OBJS` debe contener todos los archivos Verilog requeridos para compilar el diseño:

```make
OBJS = modulo_1.v modulo_2.v nombre_modulo.v
```

No deben quedar dependencias hacia módulos que no estén incluidos en la entrega.

## 3. Simulación RTL

Desde `codigo_verilog_testbench_waveform/`, se debe ejecutar:

```bash
make sim
```

Este comando compila el testbench y los módulos RTL con Icarus Verilog, ejecuta la simulación y abre el archivo VCD en GTKWave.

Antes de entregar, se debe verificar que:

- la compilación termina sin errores;
- la simulación llega hasta `$finish`;
- las entradas aplicadas por el testbench corresponden a los casos que se quieren comprobar;
- las salidas presentan el comportamiento esperado;
- el archivo `.gtkw` contiene las señales necesarias para revisar el funcionamiento del módulo.

## 4. Verificación de que el diseño es sintetizable

Es obligatorio ejecutar:

```bash
make sim_post_syn
```

Este objetivo sintetiza el diseño con Yosys y simula la netlist resultante. Su ejecución permite comprobar que el código implementado es sintetizable y que el comportamiento posterior a síntesis corresponde con el comportamiento observado en la simulación RTL.

> <span style="color: #0B2E59;"><strong>IMPORTANTE: La entrega no se considera completa si <code>make sim_post_syn</code> presenta errores de síntesis, módulos faltantes o errores durante la simulación de la netlist.</strong></span>

El estudiante debe revisar el archivo `synth.log` y corregir los errores relevantes antes de entregar.

## 5. Generación de los diagramas RTL en SVG

Es obligatorio ejecutar:

```bash
make svg
```

Este objetivo utiliza Yosys y `netlistsvg` para generar una representación estructural del diseño.

> <span style="color: #0B2E59;"><strong>IMPORTANTE: Todos los archivos <code>.svg</code> producidos por este comando deben incluirse en <code>codigo_verilog_testbench_waveform/</code> como parte de la entrega. Los diagramas deben corresponder a la misma versión del código Verilog entregado.</strong></span>

Antes de ejecutar `make svg`, se debe comprobar que `TARGET` identifica el módulo superior y que `OBJS` contiene todos los módulos requeridos.

## 6. Diagramas de flujo, bloques y estados

En `diagramas_flujo_bloques_estados/` se debe incluir la documentación gráfica del diseño en los siguientes formatos:

- `.png`, para visualización directa;
- `.pdf`, para conservar la calidad del documento.

Los diagramas deben incluir, cuando correspondan al diseño, el diagrama de flujo, el diagrama de bloques y el diagrama de estados.

> <span style="color: #0B2E59;"><strong>IMPORTANTE: Los diagramas deben ser similares a los presentados en esta plantilla. No se aceptarán dibujos realizados a mano alzada ni diagramas generados por inteligencia artificial.</strong></span>

### 6.1. Diagrama de flujo

Debe representar:

- inicio de la operación;
- decisiones y condiciones;
- operaciones realizadas;
- ciclos o repeticiones;
- condición de finalización;
- generación de las señales de terminación.

### 6.2. Diagrama de bloques

Debe mostrar:

- módulo superior;
- submódulos utilizados;
- entradas y salidas;
- señales de conexión entre los bloques;
- ancho de los buses;
- señales de control;
- parámetros y constantes relevantes.

### 6.3. Diagrama de estados

Debe mostrar:

- nombre de cada estado;
- estado inicial;
- condiciones de transición;
- secuencia de operación;
- valores de las salidas en cada estado;
- condición de finalización.

## 7. Correspondencia entre documentación y código

Los nombres de módulos, señales, estados y parámetros utilizados en los diagramas deben coincidir con los nombres empleados en los archivos Verilog.

Cada bloque presentado en el diagrama de bloques debe corresponder a un módulo o proceso identificable en el código. Cada estado documentado debe existir en la máquina de estados implementada.

Los diagramas `.png`, `.pdf` y `.svg` deben corresponder a la versión final entregada, no a versiones anteriores del diseño.

> <span style="color: #0B2E59;"><strong>IMPORTANTE: Si no existe correspondencia entre los diagramas y el código Verilog, el código no se tendrá en cuenta durante la evaluación y únicamente se revisarán los diagramas.</strong></span>

## 8. Porcentajes de evaluación

La calificación de la entrega se distribuirá de la siguiente manera:

| Elemento | Porcentaje |
|---|---:|
| **Diagramas** | **60 %** |
| **Código en Verilog** | **20 %** |
| **Testbenches** | **5 %** |
| **Formas de onda y archivos `.gtkw`** | **2.5 %** |
| **Archivos `.svg`** | **2.5 %** |
| **Análisis** | **10 %** |
| **Total** | **100 %** |

## 9. Fecha de entrega y versión evaluada

**ÚNICAMENTE SE REVISARÁ LA VERSIÓN DISPONIBLE EN EL REPOSITORIO EN LA FECHA Y HORA INDICADAS PARA LA ENTREGA. CUALQUIER COMMIT POSTERIOR NO SERÁ TENIDO EN CUENTA DURANTE LA EVALUACIÓN.**

## 10. Comprobación final de la entrega

Antes de entregar, se deben ejecutar, en este orden:

```bash
make sim
make sim_post_syn
make svg
```

La entrega debe contener:

- [ ] todos los archivos fuente `.v`;
- [ ] todos los testbenches `_TB.v`;
- [ ] los archivos de configuración `.gtkw`;
- [ ] el `Makefile` correctamente configurado;
- [ ] los archivos `.svg` generados por `make svg`;
- [ ] los diagramas en formato `.png`;
- [ ] los diagramas en formato `.pdf`;
- [ ] correspondencia entre el código, las pruebas y los diagramas;
- [ ] simulación RTL ejecutada correctamente con `make sim`;
- [ ] síntesis y simulación posterior a síntesis ejecutadas correctamente con `make sim_post_syn`.

> <span style="color: #0B2E59;"><strong>IMPORTANTE: Una entrega con archivos fuente faltantes, módulos no encontrados, errores de síntesis o diagramas que no correspondan al código se considera incompleta.</strong></span>
