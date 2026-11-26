# ADR-0004 · Claude como motor de IA, detrás de una capa de proveedor

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

El asistente debe citar fuentes, trabajar con documentos largos, traducir textos científicos con fidelidad y mantener costos bajos.

## Decisión

- Usar la **API de Anthropic (Claude)** con ruteo por tarea:
  - **Haiku 5.5** (US$0,10 / US$0,50 por millón de tokens de entrada / salida): clasificación, contexto de fragmentos, extracción de metadatos.
  - **Sonnet 5.5** (US$2 / US$10): tutor, investigador, resúmenes, traducciones.
  - **Opus 5.5** (US$4 / US$20): comparador y crítico científico.
- Usar citas nativas de la API, caché de prompts y procesamiento por lotes (50% de descuento) para la ingesta masiva.
- Todo acceso a modelos pasa por una capa propia (`lib/ai`) para poder cambiar de proveedor o de modelo sin tocar los módulos.
- La API **no tiene plan gratuito**: su activación requiere aprobación explícita del administrador (ADR-0010).

## Consecuencias

- Precios vigentes a noviembre de 2026; se registran por llamada en `ai_usage` para medir el costo real.
- La IA queda apagada hasta que se apruebe un presupuesto.

## Alternativas consideradas

- Otros proveedores comerciales: equivalentes en lo básico; la capa propia permite evaluarlos más adelante.
- Modelos abiertos autoalojados: sin costo por token, pero exigen servidores con GPU, que tampoco son gratuitos, y su calidad en traducción médica es menor.
