# ADR-0009 · PubMed como fuente de verdad bibliográfica, antes que la IA

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

La IA no debe inventar artículos, autores, DOI ni PMID. El modo Investigador y la verificación de referencias necesitan una fuente bibliográfica confiable.

## Decisión

- Usar las **E-utilities oficiales de NCBI** (ESearch, EFetch, ESummary, ELink) con clave API gratuita, `tool` y `email` institucional, respetando el límite de 10 solicitudes por segundo.
- Complementar con PMC OA, Unpaywall, Crossref, PMC ID Converter y DeCS.
- Sincronizar **registros bibliográficos**, nunca textos completos automáticamente.
- Implementar PubMed en la **fase 3, antes que la IA (fase 4)**: es gratuito, no tiene problemas de derechos de autor y deja la biblioteca poblada con metadatos verificados cuando llegue el asistente.
- Las pruebas usan respuestas XML reales guardadas; nunca respuestas inventadas.

## Consecuencias

- Cada referencia que muestre la IA se valida contra `works` o contra NCBI.
- Los nuevos registros se asignan a temas como "sin confirmar" hasta la revisión editorial.
