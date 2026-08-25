# Planificación del proyecto — Digital 2

## Herramienta

Utilizar **GitHub Projects** como planificador común del curso. Los *issues* pueden pertenecer al repositorio general o a los repositorios de los equipos, pero todos deben agregarse al mismo proyecto general.

## Configuración del proyecto

Crear estos campos:

| Campo | Tipo recomendado |
|---|---|
| Estado | Selección: pendiente, en desarrollo, bloqueada, terminada |
| Equipo | Selección |
| Responsable | Persona |
| Fecha de inicio | Fecha |
| Fecha de entrega | Fecha |
| Dependencias | Texto o vínculo a otro *issue* |
| Repositorio | Repositorio |
| Evidencia / Pull request | Texto o vínculo |

Crear dos vistas:

1. **Seguimiento:** tabla agrupada por equipo y ordenada por estado.
2. **Cronograma:** *roadmap* basado en las fechas de inicio y entrega.

## Uso

1. Crear la tarea con el formulario `tarea.yml`.
2. Asignar una persona responsable.
3. Agregar el *issue* al GitHub Project general.
4. Completar fechas, dependencias y equipo.
5. Vincular el *pull request* que implementa la tarea.
6. Cerrar la tarea únicamente cuando exista evidencia verificable.

Al copiar esta plantilla al repositorio de un equipo, el directorio `.github/ISSUE_TEMPLATE/` debe quedar en la raíz del nuevo repositorio para que GitHub habilite el formulario.
