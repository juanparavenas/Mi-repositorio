# ADR-0011 · Identidad visual provisional

- **Estado:** Aceptada. Acento definitivo: verde petróleo (decisión del administrador, 26-11-2026). El logotipo sigue siendo provisional.
- **Fecha:** 2026-11-25

## Contexto

La identidad visual es prioritaria: editorial, científica, minimalista, sin apariencia de plantilla. No hay logotipo aprobado.

## Decisión

- Fondo blanco cálido, texto grafito y un único color de acento: **verde petróleo** (`#0F5257` en modo claro, `#6CC3C0` en modo oscuro), elegido por el administrador el 26-11-2026. El azul oscuro propuesto como alternativa se descarta.
- Tipografía: **Newsreader** (serif editorial) para títulos y lectura larga, **Inter** para la interfaz e **IBM Plex Mono** para identificadores (DOI, PMID). Las tres tienen licencia libre (SIL OFL) y pueden alojarse en el propio sitio.
- Logotipo **tipográfico provisional** ("CMF Academy" en Newsreader); no se considera definitivo.
- Los valores viven como tokens CSS en `apps/web/src/styles/tokens.css`, con modo claro y oscuro y contraste WCAG AA verificado en CI.

## Consecuencias

- El sistema de diseño de la fase 1 parte de estos tokens.
- Cambiar el acento o la tipografía es cambiar un token, no rediseñar pantallas.
