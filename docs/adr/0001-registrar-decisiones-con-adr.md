# ADR-0001 · Registrar las decisiones con ADR

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

CMF Academy se construirá durante varias fases y con decisiones que afectan derechos de autor, privacidad, costos y calidad científica. Sin registro, el motivo de cada decisión se pierde y se vuelve a discutir.

## Decisión

Cada decisión técnica relevante se registra como un ADR (Architecture Decision Record) en `docs/adr/`, numerado, en español, con contexto, decisión, consecuencias y alternativas. Un ADR aceptado no se edita para cambiar su contenido: se reemplaza por uno nuevo que lo declara "Reemplazado por ADR-XXXX".

## Consecuencias

- Cada PR que cambie una decisión debe incluir o actualizar el ADR correspondiente.
- Los ADR sirven como documentación para nuevos editores o desarrolladores.
