# ADR-0015 · Worker en GitHub Actions durante el piloto

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

El worker de Python necesita ejecutarse en algún lugar. Los servicios de hosting permanente (Railway, Fly.io, Render) cobran desde pocos dólares al mes, y el administrador no quiere gastar.

## Decisión

- Durante el piloto, el worker corre como un **flujo de GitHub Actions**: programado (por ejemplo, cada 30 minutos) y bajo demanda.
- Cada ejecución toma trabajos de la cola con `claim_jobs()`, los procesa y termina. Las credenciales se guardan como secretos del repositorio.
- El código del worker es el mismo que correría en un servidor permanente; solo cambia el disparador.

## Consecuencias

- Costo cero (gratis en repositorios públicos; 2.000 minutos mensuales gratis en privados).
- El procesamiento no es inmediato: un documento puede tardar hasta el siguiente ciclo. Aceptable en el piloto.
- Cuando el volumen lo justifique, se propondrá un servidor permanente con su costo, para aprobación.

## Alternativas descartadas

- Railway (US$5/mes) o Fly.io (desde ~US$2/mes): implican cobro.
- Supabase Edge Functions: gratuitas, pero no ejecutan Python ni Docling.
