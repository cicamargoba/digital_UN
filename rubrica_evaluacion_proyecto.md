# Rúbrica de evaluación de proyecto

Esta rúbrica define una estructura reutilizable para evaluar proyectos de los cursos de diseño digital. Evalúa el proceso de diseño, el resultado técnico, la evidencia reproducible y la responsabilidad de cada integrante.

La rúbrica adapta la estructura de especificación, modelado, arquitectura, prototipado, pruebas y documentación de la rúbrica de heteroevaluación utilizada anteriormente. Los criterios fueron actualizados para el flujo de trabajo con hardware digital, firmware, GitHub y repositorios por equipos.

Cada curso debe complementar los criterios generales con un perfil de evidencia técnica propio. Esto permite reutilizar la rúbrica en periodos posteriores sin cambiar sus niveles, pesos ni método de calificación.

## Principios de evaluación

1. Se evalúa evidencia verificable, no solamente la explicación oral.
2. Cada tarea debe estar asociada con un equipo y una persona responsable.
3. El resultado del equipo no reemplaza la evaluación de la contribución individual.
4. Las simulaciones y pruebas deben incluir estímulo, resultado esperado y criterio explícito de aprobación.
5. Un módulo se considera integrado cuando funciona dentro del sistema compartido, no solamente de forma aislada.
6. La ausencia de evidencia recibe cero puntos en el criterio correspondiente.
7. Los evaluadores deben registrar el nivel asignado y una observación breve que identifique la evidencia revisada.

## Niveles de desempeño

Los niveles se ordenan de mayor a menor. La puntuación de cada criterio se calcula multiplicando su peso por el factor del nivel alcanzado.

| Nivel | Desempeño | Factor |
|---|---|---:|
| 4 | Completo | 100 % |
| 3 | Aceptable | 70 % |
| 2 | Insuficiente | 40 % |
| 1 | Sin evidencia válida | 0 % |

No se deben promediar niveles para ocultar la ausencia de una evidencia obligatoria. Si el resultado se encuentra entre dos niveles, se asigna el nivel inferior hasta que el equipo presente la evidencia faltante.

## Criterios y pesos

| Código | Criterio | Tipo | Peso |
|---|---|---|---:|
| C1 | Especificación y restricciones | Equipo | 10 |
| C2 | Modelo y arquitectura del sistema | Equipo | 15 |
| C3 | Implementación técnica | Equipo | 20 |
| C4 | Integración hardware-software | Equipo | 10 |
| C5 | Verificación, pruebas y depuración | Equipo | 15 |
| C6 | Integración y funcionamiento del sistema | Equipo | 10 |
| C7 | Documentación y sustentación técnica | Equipo | 10 |
| C8 | Planificación, GitHub y responsabilidad individual | Individual | 10 |
|  | **Total** |  | **100** |

Los criterios C1–C7 producen hasta 90 puntos comunes para el equipo. C8 se califica individualmente; por tanto, integrantes del mismo equipo pueden obtener resultados diferentes.

## Matriz de evaluación

### C1. Especificación y restricciones — 10 puntos

| Nivel | Descriptor |
|---|---|
| 4 | Define función, interfaces, restricciones, mapa de memoria, entradas, salidas, condiciones de error y criterios de aceptación. Todas las decisiones son coherentes con el sistema general. |
| 3 | La especificación permite implementar el módulo, pero presenta una omisión menor en restricciones, errores o criterios de aceptación. |
| 2 | La especificación es incompleta o contiene ambigüedades que obligan a inferir interfaces, comportamiento o restricciones. |
| 1 | No existe una especificación verificable o contradice las interfaces definidas para el sistema. |

### C2. Modelo y arquitectura del sistema — 15 puntos

| Nivel | Descriptor |
|---|---|
| 4 | Presenta diagramas y modelos coherentes con la implementación. Identifica bloques, estados, datapath, control, buses, memorias y partición hardware-software. Justifica las decisiones y analiza alternativas relevantes. |
| 3 | La arquitectura es correcta y utilizable, pero falta justificar una decisión o actualizar una parte menor de los diagramas. |
| 2 | Los modelos son parciales, no corresponden completamente al código o no muestran cómo se integra el módulo con el sistema. |
| 1 | No existe un modelo técnico verificable o la arquitectura no permite implementar la función asignada. |

### C3. Implementación técnica — 20 puntos

| Nivel | Descriptor |
|---|---|
| 4 | Todos los módulos asignados están implementados, cumplen sus interfaces y requisitos funcionales, y no presentan fallos críticos conocidos. El código es sintetizable, organizado y reutiliza correctamente los bloques suministrados. |
| 3 | La función principal está implementada y es integrable, pero existe una limitación menor documentada que no impide la demostración requerida. |
| 2 | Solo funciona una parte del módulo, requiere modificaciones importantes para integrarse o incumple una interfaz definida. |
| 1 | No existe una implementación ejecutable o la evidencia presentada no corresponde al código entregado. |

### C4. Integración hardware-software — 10 puntos

| Nivel | Descriptor |
|---|---|
| 4 | El firmware configura, controla y verifica el hardware mediante las interfaces definidas. El mapa de memoria, los CSR, los controladores y el programa de prueba son coherentes y reproducibles. |
| 3 | La integración principal funciona, pero el firmware presenta una limitación menor de manejo de errores, organización o cobertura. |
| 2 | El firmware solo demuestra operaciones aisladas, usa valores no documentados o no verifica los resultados del hardware. |
| 1 | No existe interacción verificable entre el firmware y el hardware desarrollado. |

### C5. Verificación, pruebas y depuración — 15 puntos

| Nivel | Descriptor |
|---|---|
| 4 | Incluye pruebas reproducibles para casos normales, límites y errores. Cada prueba declara estímulos, resultado esperado y criterio de aprobación. El equipo interpreta las señales, identifica causas de fallos y documenta las correcciones. |
| 3 | Las funciones principales están verificadas y los resultados son reproducibles, pero falta un caso límite o parte del análisis de depuración. |
| 2 | Las pruebas son principalmente manuales, cubren pocos casos o muestran formas de onda sin relacionarlas con el comportamiento esperado. |
| 1 | No existe una prueba válida, no puede reproducirse o no demuestra el funcionamiento declarado. |

### C6. Integración y funcionamiento del sistema — 10 puntos

| Nivel | Descriptor |
|---|---|
| 4 | El módulo funciona en la plataforma objetivo dentro del sistema compartido y participa correctamente en la demostración final. Se verifican sus interfaces con los demás módulos. |
| 3 | La función principal opera en la plataforma objetivo e interactúa con el sistema, aunque existe una limitación menor documentada. |
| 2 | Solo se demuestra el módulo de forma aislada, la integración es parcial o el comportamiento en la plataforma objetivo es inestable. |
| 1 | No existe una demostración válida en la plataforma objetivo o el módulo no puede integrarse con el sistema. |

### C7. Documentación y sustentación técnica — 10 puntos

| Nivel | Descriptor |
|---|---|
| 4 | El repositorio permite reconstruir, ejecutar y verificar el trabajo. La documentación coincide con la versión entregada y la sustentación explica decisiones, resultados, limitaciones y contribuciones con lenguaje técnico preciso. |
| 3 | La documentación cubre el flujo principal, pero requiere una aclaración menor para reproducirlo o comprender una decisión. |
| 2 | La documentación es incompleta, está desactualizada o depende de explicaciones orales para ejecutar y verificar el proyecto. |
| 1 | No existe documentación utilizable o no corresponde al proyecto entregado. |

### C8. Planificación, GitHub y responsabilidad individual — 10 puntos

| Nivel | Descriptor |
|---|---|
| 4 | El estudiante tiene tareas explícitas en GitHub Projects, mantiene su estado y fechas, realiza contribuciones identificables, responde por sus dependencias y vincula issues, commits, pruebas y pull requests con evidencia verificable. |
| 3 | La contribución es identificable y cumple las tareas principales, pero presenta una omisión menor en actualización, trazabilidad o cierre de evidencia. |
| 2 | La participación es parcial, las tareas no se mantienen actualizadas o resulta difícil relacionar los commits y resultados con la responsabilidad asignada. |
| 1 | No existe evidencia verificable de una contribución individual al proyecto. |

## Perfiles de evidencia técnica por curso

Los siguientes perfiles corresponden a los cursos actuales. Los cursos posteriores deben agregar su propio perfil de evidencia, conservando la matriz general de evaluación.

### Digital 1

| Área | Evidencia mínima |
|---|---|
| Especificación | Función del periférico, protocolo, interfaces, registros CSR y región de memoria asignada. |
| Diseño | Diagramas de bloques, flujo y estados necesarios para comprender el periférico. |
| RTL | Código Verilog sintetizable y conectado al bus CSR sin modificar los bloques suministrados fuera de la tarea asignada. |
| Firmware | Driver o funciones C, incorporación al flujo de firmware y programa de prueba. |
| Verificación | Testbench automático, resultado aprobado y formas de onda relevantes interpretadas. |
| Hardware | Prueba del periférico en FPGA e integración con la consola compartida. |
| Gestión | Issue, responsable, fechas, commits y pull request hacia el repositorio general. |

### Digital 2

| Área | Evidencia mínima |
|---|---|
| Procesador | Análisis de las instrucciones asignadas: codificación, datapath, control, memoria, cambio del PC y señales observadas. |
| SoC | Construcción LiteX reproducible con femtoRV32, buses, memorias, CSR y periféricos documentados. |
| Red | Transmisión y recepción verificadas cumpliendo una función dentro del videojuego. |
| DMA | Transferencia completa con origen, destino, longitud, control, finalización y resultado verificado. |
| LiteScope | Configuración, condición de disparo, captura e interpretación de señales internas relevantes. |
| Firmware | Programa que configure y utilice los módulos desarrollados dentro del sistema integrado. |
| Hardware | Demostración de la consola conectada sobre FPGA. |
| Gestión | Issue, responsable, fechas, commits y pull request hacia el repositorio general. |

## Registro de calificación

La [hoja de evaluación para tres entregas y cinco grupos](evaluacion/README.md) permite registrar las calificaciones en línea después de importarla en Google Sheets. Los criterios comunes del equipo y la responsabilidad individual se mantienen separados.

| Criterio | Peso | Nivel | Puntos obtenidos | Evidencia revisada / observación |
|---|---:|---:|---:|---|
| C1. Especificación y restricciones | 10 |  |  |  |
| C2. Modelo y arquitectura | 15 |  |  |  |
| C3. Implementación técnica | 20 |  |  |  |
| C4. Integración hardware-software | 10 |  |  |  |
| C5. Verificación y depuración | 15 |  |  |  |
| C6. Funcionamiento del sistema | 10 |  |  |  |
| C7. Documentación y sustentación | 10 |  |  |  |
| C8. Responsabilidad individual | 10 |  |  |  |
| **Total** | **100** |  |  |  |

### Cálculo

Para cada fila:

```text
puntos obtenidos = peso × factor del nivel
```

Ejemplo: nivel 3 en un criterio de 15 puntos:

```text
15 × 0.70 = 10.5 puntos
```
