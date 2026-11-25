# ADR-0005 · Taxonomía de profundidad libre con ruta materializada

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

El documento maestro pide una jerarquía Especialidad → Categoría → Subcategoría → Tema → Subtema → Contenido, sin límite artificial de profundidad, editable sin modificar código, y con temas relacionados entre ramas (por ejemplo, "Cirugía ortognática y ATM").

## Decisión

- **Un solo tipo de nodo** (`topics`) con `parent_id` (padre canónico) y una ruta materializada `ltree` calculada por triggers.
- El nombre del nivel (especialidad, categoría…) se deduce de la profundidad en la interfaz; no se almacena como tipo rígido.
- Las relaciones entre ramas se modelan con `topic_relations` tipadas (`related`, `technique_of`, `complication_of`, `differential_diagnosis`, `prerequisite`), no duplicando nodos.
- Un nodo solo se publica si su padre está publicado.

## Consecuencias

- Mover un subárbol completo es una sola actualización; los triggers recalculan las rutas (probado).
- Los ciclos son imposibles (probado).
- Consultas de "todos los descendientes" y "ruta de navegación" son índices GiST sobre `ltree`.

## Alternativas descartadas

- Tablas separadas por nivel: limitan la profundidad y obligan a cambiar código.
- Grafo sin padre canónico: la ruta de navegación sería ambigua.
