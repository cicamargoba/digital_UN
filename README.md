# Digital UN

Este repositorio reúne material práctico para estudiar diseño digital, descripción de hardware en Verilog, procesadores RISC-V, sistemas en FPGA, Migen, LiteX y Linux embebido.

No corresponde a un único proyecto. Los directorios presentan ejemplos con distintos niveles de complejidad. Se recomienda estudiarlos en el orden indicado a continuación, porque cada sección introduce conceptos utilizados en las siguientes.

## Ruta de estudio

1. [`basic_circuits/Digital/`](#1-basic_circuitsdigital)
2. [`basic_circuits/Verilog/`](#2-basic_circuitsverilog)
3. [`basic_circuits/Blink/`](#3-basic_circuitsblink)
4. [`basic_circuits/test_peripherals/`](#4-basic_circuitstest_peripherals)
5. [Flujo hardware-software de un softcore SoC](#5-flujo-hardware-software-de-un-softcore-soc)
6. [`migen_tutorial/`](#6-migen_tutorial)
7. [`Litex/`](#7-litex)
8. [`Embedded/`](#8-embedded)

---

## 1. `basic_circuits/Digital/`

Esta sección contiene circuitos creados con el simulador gráfico **[Digital](https://github.com/hneemann/digital)**, almacenados en archivos `.dig`.

Se encontrarán ejemplos de:

- latches RS y D;
- flip-flops;
- registros;
- registros de desplazamiento;
- acumuladores;
- circuitos de simulación asociados.

El objetivo de esta sección es estudiar el comportamiento de circuitos combinatorios y secuenciales a nivel de compuertas lógicas.

---

## 2. `basic_circuits/Verilog/`

En esta sección, los circuitos estudiados e implementados gráficamente en `basic_circuits/Digital/` se describen mediante el lenguaje de descripción de hardware **Verilog**.

Se encontrarán:

- módulos Verilog en archivos `.v`;
- testbenches identificados normalmente con el sufijo `_TB.v`;
- configuraciones de señales para GTKWave en archivos `.gtkw`;
- ejemplos combinacionales, como comparadores y sumadores;
- ejemplos secuenciales, como acumuladores, registros de desplazamiento y controles;
- resultados y archivos auxiliares de simulación y síntesis;
- un `Makefile` para ejecutar las tareas disponibles en el directorio.

Para desarrollar y verificar los circuitos se utilizan las herramientas abiertas:

- **Yosys** para síntesis y generación de representaciones del circuito;
- **Icarus Verilog** (`iverilog`) para compilar y simular el código Verilog;
- **GTKWave** para revisar las formas de onda generadas por los testbenches.

Esta sección permite relacionar el circuito construido a nivel de compuertas en la sección anterior con su descripción RTL en Verilog, construir un testbench, ejecutar la simulación y revisar sus formas de onda.

---

## 3. `basic_circuits/Blink/`

Esta sección muestra cómo configurar diferentes FPGA utilizando un ejemplo sencillo de parpadeo de LED (`blink`). Los diferentes flujos de construcción y programación están definidos en [`basic_circuits/Blink/Makefile`](basic_circuits/Blink/Makefile).

Se encontrarán:

- el módulo `blink.v`;
- su testbench `blink_TB.v`;
- archivos de restricciones de pines para diferentes tarjetas;
- scripts y archivos de proyecto para distintas herramientas de FPGA;
- reportes y resultados generados durante síntesis, ubicación y enrutamiento;
- archivos de configuración de FPGA generados por los diferentes flujos.

El `Makefile` incluye flujos para tarjetas basadas en FPGA Lattice ECP5 e iCE40, Efinix Trion y Titanium, y Gowin. El ejemplo permite distinguir entre la simulación de un módulo y su implementación física, y muestra que cada familia de FPGA necesita restricciones, herramientas y archivos de salida específicos.

---

## 4. `basic_circuits/test_peripherals/`

Esta sección contiene una **suite de pruebas de periféricos** basada en el procesador RISC-V femtoRV32. Su propósito es que el estudiante pueda integrar un periférico diseñado en Verilog, crear su soporte en C y comprobar el funcionamiento conjunto del hardware y el software.

Se encontrarán dos partes principales:

- `rtl/`: SoC de prueba, núcleo femtoRV32, periféricos, testbenches y archivos para FPGA;
- `firmware/`: programas en ensamblador y C que prueban los periféricos desde software.

Dentro de `rtl/cores/` se encuentran periféricos y diseños de referencia, entre ellos UART, memorias, conversores BCD, multiplicación, división, raíz cuadrada, controladores de paneles LED, PS/2, SPI Flash y WS2812.

El directorio [`firmware/c/libfemtorv/`](basic_circuits/test_peripherals/firmware/c/libfemtorv/) permite generar la biblioteca en C utilizada por los programas de prueba. Allí el estudiante agrega el controlador de software correspondiente a su periférico, lo incorpora a `libfemtorv.a` y crea un programa que utilice esa función.

El procedimiento está documentado en:

- [`firmware/c/README.md`](basic_circuits/test_peripherals/firmware/c/README.md): estructura, compilación del firmware y generación de `libfemtorv.a`;
- [`firmware/c/AGREGAR_PERIFERICO_A_LIBFEMTORV.md`](basic_circuits/test_peripherals/firmware/c/AGREGAR_PERIFERICO_A_LIBFEMTORV.md): procedimiento para incluir en la biblioteca una función que controle un periférico nuevo.

El flujo de prueba consiste en:

1. agregar el periférico Verilog al SoC;
2. asignar y verificar su interfaz de memoria mapeada;
3. implementar su función de acceso en C;
4. agregar esa función a `libfemtorv.a`;
5. escribir y compilar el programa de prueba;
6. cargar el firmware generado en la memoria del SoC;
7. simular y observar en GTKWave la interacción entre el firmware y el periférico.

---

## 5. Flujo hardware-software de un softcore SoC

Los directorios [`femtoRV/basic/firmware/asm/`](femtoRV/basic/firmware/asm/), [`femtoRV/basic/firmware/c/`](femtoRV/basic/firmware/c/) y [`femtoRV/basic/rtl/`](femtoRV/basic/rtl/) forman una sola sección. Su objetivo es mostrar progresivamente el flujo de hardware y software de un **softcore SoC** basado en el procesador RISC-V femtoRV32.

### Primera etapa: programación en ensamblador

El estudio comienza en `femtoRV/basic/firmware/asm/` para que el estudiante comprenda qué sucede dentro del procesador a nivel de registros y cómo opera cada instrucción RISC-V RV32I.

Se encontrarán programas básicos para estudiar:

- uso de los registros del procesador;
- operaciones aritméticas y lógicas;
- saltos, ciclos y estructuras repetitivas;
- llamadas a subrutinas;
- acceso a memoria y manejo de la pila;
- entrada y salida de caracteres y cadenas;
- multiplicación, división y raíz cuadrada;
- conversión entre números binarios y BCD;
- proceso de ensamblado y enlazado del firmware.

Esta etapa permite comprender cómo las instrucciones ejecutadas por femtoRV32 producen el comportamiento de un programa antes de introducir las abstracciones del lenguaje C.

### Segunda etapa: adaptación del lenguaje C a femtoRV32

En `femtoRV/basic/firmware/c/` se muestra cómo adaptar un entorno C bare-metal al procesador femtoRV32.

El estudiante encontrará:

- programas de ejemplo y pruebas escritos en C;
- el código de arranque `crt0_baremetal.S` y su objeto compilado `crt0_baremetal.o`;
- la biblioteca estática `libfemtorv.a`;
- implementación de funciones de UART, `printf`, impresión, retardos y conteo de ciclos;
- funciones para operaciones matemáticas y acceso a periféricos matemáticos;
- script de enlazado `linker.ld`;
- `Makefile` para generar archivos `.elf`, `.hex`, `.map` y `.lst`;
- diagramas del proceso de compilación y de la relación entre hardware y software.

`crt0_baremetal.o` prepara el entorno mínimo antes de ejecutar `main()`: inicializa los registros necesarios, configura el puntero de pila y transfiere el control al programa en C. De esta manera, el estudiante puede relacionar el arranque escrito en ensamblador con la ejecución de una aplicación escrita en C.

La implementación de funciones como `printf` y de las operaciones matemáticas permite observar cómo una función disponible en C termina convirtiéndose en instrucciones ejecutadas por el procesador o en accesos a periféricos implementados en hardware.

### Tercera etapa: hardware del softcore SoC

`femtoRV/basic/rtl/` contiene la implementación RTL del sistema:

- núcleo RISC-V femtoRV32;
- módulos superiores del SoC;
- memorias, UART y periféricos;
- archivos de inicialización que incorporan el firmware compilado;
- testbenches, archivos VCD y configuraciones de GTKWave;
- Makefiles, scripts, restricciones y archivos para implementar el sistema en diferentes FPGA.

El firmware en ensamblador o C se compila para generar un archivo `.hex`, que inicializa la memoria del SoC descrito en Verilog. Después se simula el procesador ejecutando el programa y se observa la interacción entre la CPU, la memoria y los periféricos. Finalmente, el sistema puede sintetizarse e implementarse sobre una FPGA.

---

## 6. `migen_tutorial/`

Esta sección contiene ejemplos de generación de hardware con **Migen** y de construcción de sistemas con componentes de **LiteX** desde Python.

Se encontrarán proyectos de complejidad creciente relacionados con:

- parpadeo de LED;
- integración de CPU;
- UART y PWM;
- multiplicadores y otros periféricos;
- memorias y registros de control y estado;
- transferencia de datos mediante DMA;
- cruces entre dominios de reloj;
- Ethernet y UDP;
- captura interna de señales con LiteScope;
- simulaciones y testbenches del Verilog generado;
- definición y carga de diseños para diferentes plataformas FPGA.

Los archivos Python describen el hardware y generan el RTL y los archivos necesarios para cada plataforma. Esta sección debe estudiarse después de comprender Verilog y la integración básica de un SoC.

---

## 7. `Litex/`

Esta sección reúne diseños más avanzados de sistemas construidos con **LiteX**.

Se encontrarán:

- definiciones de plataformas y tarjetas FPGA;
- sistemas con y sin BIOS;
- integración de femtoRV32 dentro de un SoC LiteX;
- memorias ROM y SRAM;
- firmware en C y scripts de enlazado;
- registros CSR;
- interfaces Ethernet y transmisión UDP;
- transferencias DMA;
- controladores y flujos de datos para WS2812;
- testbenches, formas de onda y configuraciones de GTKWave;
- archivos generados de síntesis y construcción para FPGA;
- documentación y diagramas de algunos sistemas.

Esta sección permite estudiar sistemas donde Python se utiliza para integrar buses, memorias, procesadores, periféricos y flujos de datos. Los ejemplos no constituyen una única secuencia lineal; cada archivo o subdirectorio puede corresponder a una plataforma o experimento diferente.

---

## 8. `Embedded/`

Esta sección contiene material relacionado con **Linux embebido**, principalmente Buildroot y U-Boot.

Se encontrarán:

- un árbol de Buildroot orientado a la tarjeta YuzukiSBC;
- configuraciones y scripts de construcción;
- un árbol de código de U-Boot;
- configuraciones de arranque;
- archivos de Device Tree;
- parches para adaptar U-Boot al flujo de Buildroot y al hardware utilizado;
- imágenes, binarios y otros resultados de compilación.

Esta sección permite estudiar una etapa posterior al diseño RTL: la construcción del software de arranque y del sistema Linux para una plataforma embebida. Debido a su tamaño y complejidad, se recomienda abordarla después de comprender firmware bare-metal, procesadores y sistemas digitales integrados.

---

## Herramientas utilizadas

Dependiendo de la sección, se utilizan algunas de las siguientes herramientas:

- **Digital** para circuitos esquemáticos `.dig`;
- **Icarus Verilog** para simulación Verilog;
- **GTKWave** para observar formas de onda;
- **Yosys** y herramientas específicas de cada FPGA para síntesis e implementación;
- herramientas cruzadas de **RISC-V** para compilar firmware;
- **Python**, **Migen** y **LiteX** para generar e integrar hardware;
- **Buildroot** y **U-Boot** para Linux embebido.

Cada proyecto puede tener dependencias y comandos diferentes. Antes de ejecutarlo, revise su `README`, su `Makefile`, los scripts Python y los archivos de restricciones presentes en el directorio correspondiente.

## Entregas de proyectos

La estructura, los archivos obligatorios, los comandos de verificación y los criterios de evaluación de las entregas se encuentran en:

[`plantilla_entregas/README.md`](plantilla_entregas/README.md)

Revise ese documento antes de preparar una entrega.
