# Hoja de evaluación

El archivo [`plantilla_evaluacion_proyectos.xlsx`](./plantilla_evaluacion_proyectos.xlsx) está preparado para registrar **tres evaluaciones durante el semestre** para **cinco grupos**.

## Contenido

- `Evaluaciones`: 15 registros, uno por grupo y evaluación, para los criterios comunes C1–C7.
- `Individual`: registros para C8, que debe calificarse por estudiante y no como nota común del grupo.
- `Resumen`: resultados de cada grupo en las tres evaluaciones y promedio del componente común.
- `Rubrica`: criterios, pesos y factores de los niveles.
- `Instrucciones`: procedimiento de uso y configuración de permisos.

## Uso en Google Sheets

1. Subir el archivo `.xlsx` a Google Drive.
2. Abrirlo con Google Sheets.
3. Seleccionar `Compartir` y dejar el acceso general como **Restringido**.
4. Mantener a Carlos Camargo como único **Editor**.
5. Si otras personas deben consultar resultados, agregarlas como **Lectores**.
6. Si los evaluadores deben registrar respuestas directamente, utilizar un Google Form sin concederles permiso de edición sobre la hoja.

Los permisos de propietario no pueden guardarse dentro de un archivo del repositorio. Deben configurarse en Google Drive después de subirlo.

## Escala

| Nivel | Factor |
|---|---:|
| 4 — Completo | 100 % |
| 3 — Aceptable | 70 % |
| 2 — Insuficiente | 40 % |
| 1 — Sin evidencia válida | 0 % |

La hoja calcula automáticamente los puntos según los pesos definidos en [`../rubrica_evaluacion_proyecto.md`](../rubrica_evaluacion_proyecto.md).
