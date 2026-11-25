# ADR-0008 · Revisión editorial obligatoria del contenido generado por IA

- **Estado:** Aceptada (decisión 3 de la fase 0)
- **Fecha:** 2026-11-25

## Contexto

La IA puede generar resúmenes, traducciones, descripciones de temas, análisis, clasificaciones y contenido académico. Publicar ese contenido sin revisión pondría afirmaciones no verificadas bajo la autoría de CMF Academy.

## Decisión

- Todo contenido académico redactado por IA nace como **borrador** y registra el modelo que lo generó.
- Solo se publica (o aprueba) con `reviewed_by` y `reviewed_at`, y el revisor debe tener rol de editor. Esto se valida en la base con restricciones y triggers.
- Las propuestas de clasificación de la IA (`work_topics.origin = 'ai'`) se muestran como "sin confirmar" hasta que un editor las confirma.
- Los aportes de usuarios nunca se publican automáticamente: pasan por moderación (`contributions`).
- **Administrador principal inicial:** Dr. Juan Pablo Aravena S., que puede incorporar editores académicos.

## Consecuencias

- La interfaz mostrará "Revisado por" en cada sección publicada.
- Probado en las pruebas 04 y 07.
