# ADR-0006 · Obra, archivo y derivados; estados de distribución

- **Estado:** Aceptada (decisión 1 de la fase 0)
- **Fecha:** 2026-11-25

## Contexto

CMF Academy es una biblioteca pública, pero gran parte de la literatura está protegida por derechos de autor. Estar disponible en internet no autoriza a reproducir un artículo. El documento maestro exige diferenciar contenido original, aportes de usuarios, publicaciones de terceros, acceso abierto y material restringido.

## Decisión

1. Separar **obra** (`works`, metadatos públicos), **archivo** (`files`, el original) y **derivados** (`extractions`, `chunks`, `translations`, `summaries`).
2. Tres estados de distribución por archivo:
   - **Público:** contenido original, propio o con licencia o autorización de distribución. Exige que un editor registre y verifique la base legal.
   - **Restringido:** acceso limitado a roles (`allowed_roles`) o usuarios autorizados (`file_access_grants`).
   - **Solo metadatos:** se referencia la obra, pero su texto completo no se distribuye; solo los editores acceden al archivo.
3. El valor por defecto es **solo metadatos**.
4. La IA procesa un archivo solo con `ai_processing_allowed = true`, que exige una base legítima registrada y verificada.
5. Un derivado no puede ser más abierto que su archivo; si el archivo se restringe, sus derivados lo siguen; si se revoca el permiso de IA, se eliminan los fragmentos y se archivan los derivados.
6. La búsqueda del asistente se ejecuta con los permisos de quien pregunta: un visitante nunca recupera fragmentos restringidos.
7. Se conserva siempre el enlace a la fuente original (`external_url`, `doi`, `pmid`, `oa_url`).
8. Existe un formulario de solicitudes por derechos de autor (`copyright_requests`).

## Consecuencias

- Todas estas reglas están en la base de datos y probadas (prueba 03).
- La respuesta pública del asistente puede citar obras restringidas solo mediante su ficha y enlace, nunca con su texto.
- Las traducciones completas de material protegido quedan restringidas a editores salvo autorización expresa.
