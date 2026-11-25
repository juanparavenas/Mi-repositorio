# ADR-0011 · Identidad visual provisional

- **Estado:** Aceptada como provisional (decisión 8 de la fase 0)
- **Fecha:** 2026-11-25

## Contexto

La identidad visual es prioritaria: editorial, científica, minimalista, sin apariencia de plantilla. No hay logotipo aprobado.

## Decisión

- Fondo blanco cálido, texto grafito y un único color de acento. Se proponen dos acentos: **verde petróleo** (recomendado) y **azul oscuro**; el administrador elige.
- Tipografía: **Newsreader** (serif editorial) para títulos y lectura larga, **Inter** para la interfaz e **IBM Plex Mono** para identificadores (DOI, PMID). Las tres tienen licencia libre (SIL OFL) y pueden alojarse en el propio sitio.
- Logotipo **tipográfico provisional** ("CMF Academy" en Newsreader); no se considera definitivo.
- Los valores viven como tokens CSS en `docs/diseno/tokens.css`, con contraste WCAG AA verificado.

## Consecuencias

- El sistema de diseño de la fase 1 parte de estos tokens.
- Cambiar el acento o la tipografía es cambiar un token, no rediseñar pantallas.
