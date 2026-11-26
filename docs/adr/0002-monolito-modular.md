# ADR-0002 · Monolito modular con Next.js y un worker en Python

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

El proyecto necesita interfaz web, API, procesamiento de documentos, IA y tareas programadas. Lo desarrolla un equipo muy pequeño y debe ser mantenible y escalable.

## Decisión

- Una aplicación **Next.js (App Router) + TypeScript** para interfaz, API del servidor y administración.
- Un **worker en Python** para todo lo lento: extracción de documentos, metadatos, IA documental y sincronización con PubMed.
- Ambos comparten una sola base de datos (ADR-0003). El código se organiza por dominios (`taxonomy`, `library`, `documents`, `pubmed`, `assistant`, `search`, `media`, `community`, `admin`) con fronteras explícitas.

## Consecuencias

- Dos lenguajes, pero cada uno donde rinde más: Python domina la extracción de PDF científicos (Docling, PyMuPDF).
- La web nunca espera procesamientos largos: los encola.
- Un módulo puede extraerse como servicio si algún día lo exige la escala.

## Alternativas descartadas

- **Microservicios:** multiplican despliegues, monitoreo y costos sin beneficio a esta escala.
- **Todo en Node.js:** la extracción de PDF a dos columnas, tablas y números de página es notablemente peor.
- **Backend separado (FastAPI) + SPA:** el doble de piezas y peor SEO para las páginas públicas de temas.
