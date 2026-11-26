# ADR-0003 · PostgreSQL (Supabase) como fuente de verdad, incluida la cola

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

Se necesitan datos relacionales, búsqueda semántica, búsqueda de texto, árboles de temas, autenticación, archivos, permisos y una cola de trabajos.

## Decisión

- **Supabase** como plataforma: PostgreSQL, Auth, Storage y pg_cron.
- En PostgreSQL: `pgvector` (búsqueda semántica), `ltree` (taxonomía), texto completo y `pg_trgm` (búsqueda global), y **RLS** para permisos.
- La **cola de trabajos es una tabla** (`processing_jobs`) con `FOR UPDATE SKIP LOCKED`, reintentos con espera creciente y costo por trabajo. Se descarta pgmq para mantener el esquema portable y probado localmente.
- Las reglas críticas (derechos, revisión editorial, cuotas, consentimiento) se hacen cumplir en la base con restricciones, triggers y RLS.

## Consecuencias

- Un solo motor que respaldar y monitorear; los permisos se aplican también a la búsqueda vectorial.
- PostgreSQL es estándar: el proyecto puede migrar a otro proveedor sin reescribir el modelo.
- El plan gratuito tiene límites (500 MB de base, 1 GB de archivos, pausa por inactividad); ver `docs/costos.md`.

## Alternativas descartadas

- Base vectorial separada (Pinecone, Weaviate, Qdrant): otra sincronización, otros permisos, otro costo.
- Redis o SQS para la cola: infraestructura extra innecesaria.
- Firebase: modelo no relacional, poco adecuado para metadatos bibliográficos estructurados.
