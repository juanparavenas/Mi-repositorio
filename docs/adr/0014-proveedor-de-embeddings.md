# ADR-0014 · Proveedor de embeddings: decisión diferida con criterios

- **Estado:** Propuesta (se decide en la fase 4)
- **Fecha:** 2026-11-25

## Contexto

La búsqueda semántica necesita embeddings multilingües: preguntas en español sobre literatura mayoritariamente en inglés. El administrador pidió evaluar Voyage AI y alternativas, con costo cero mientras no apruebe gastos.

## Decisión

- Fijar desde ahora la **dimensión 1024** en el esquema, compatible con todos los candidatos.
- Elegir el proveedor en la fase 4 con un set de evaluación propio (preguntas reales de la especialidad, en español) que mida si la fuente correcta aparece entre las recuperadas.

| Candidato | Costo | Observaciones |
| --- | --- | --- |
| Voyage AI `voyage-4-lite` / `voyage-4` | US$0,02 / US$0,06 por millón de tokens; primeros 200 millones gratis por cuenta | Multilingüe, 1024 dimensiones; verificar límites de uso sin método de pago |
| BAAI `bge-m3` (abierto, autoalojado) | US$0 en el worker | Multilingüe, 1024 dimensiones; los embeddings de consultas en tiempo real requieren un servidor propio |
| Cohere `embed-v4` | Pago por uso | Multilingüe; dimensiones configurables |
| OpenAI `text-embedding-3-large` | Pago por uso | Admite reducir a 1024 dimensiones |

- Mientras no haya proveedor, la búsqueda funciona en modo **léxico** (texto completo + trigramas), que es gratuito.
- Cada fragmento registra `embedding_model`, para poder recalcular si se cambia de proveedor.

## Consecuencias

- Cambiar de proveedor implica recalcular embeddings, no cambiar el esquema.
