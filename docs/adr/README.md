# Registro de decisiones de arquitectura (ADR)

Cada decisión relevante de CMF Academy se documenta aquí (ver [ADR-0001](0001-registrar-decisiones-con-adr.md)).

| ADR | Título | Estado |
| --- | --- | --- |
| [0001](0001-registrar-decisiones-con-adr.md) | Registrar las decisiones con ADR | Aceptada |
| [0002](0002-monolito-modular.md) | Monolito modular con Next.js y un worker en Python | Aceptada |
| [0003](0003-postgresql-como-fuente-de-verdad.md) | PostgreSQL (Supabase) como fuente de verdad, incluida la cola | Aceptada |
| [0004](0004-claude-como-motor-de-ia.md) | Claude como motor de IA, detrás de una capa de proveedor | Aceptada |
| [0005](0005-taxonomia-de-profundidad-libre.md) | Taxonomía de profundidad libre con ruta materializada | Aceptada |
| [0006](0006-obra-archivo-derivados-y-distribucion.md) | Obra, archivo y derivados; estados de distribución | Aceptada (decisión 1 de la fase 0) |
| [0007](0007-acceso-publico-a-la-ia.md) | Acceso público a la IA con cuotas, presupuesto e interruptor | Aceptada (decisión 2 de la fase 0) |
| [0008](0008-revision-editorial-obligatoria.md) | Revisión editorial obligatoria del contenido generado por IA | Aceptada (decisión 3 de la fase 0) |
| [0009](0009-pubmed-fuente-de-verdad-bibliografica.md) | PubMed como fuente de verdad bibliográfica, antes que la IA | Aceptada |
| [0010](0010-costo-cero-y-activacion-por-fase.md) | Costo cero por defecto y activación de servicios por fase | Aceptada (decisiones 4 y 5 de la fase 0, e instrucción del administrador: "no apruebes nada que me cobre") |
| [0011](0011-identidad-visual-provisional.md) | Identidad visual provisional | Aceptada como provisional (decisión 8 de la fase 0) |
| [0012](0012-privacidad-por-diseno-e-imagenes-clinicas.md) | Privacidad por diseño e imágenes clínicas | Aceptada |
| [0013](0013-flujo-de-ramas-pr-y-ci.md) | Flujo de ramas, pull requests y CI | Aceptada |
| [0014](0014-proveedor-de-embeddings.md) | Proveedor de embeddings: decisión diferida con criterios | Propuesta (se decide en la fase 4) |
| [0015](0015-worker-en-github-actions-durante-el-piloto.md) | Worker en GitHub Actions durante el piloto | Aceptada |

## Plantilla

```markdown
# ADR-NNNN · Título

- **Estado:** Propuesta | Aceptada | Reemplazada por ADR-XXXX
- **Fecha:** AAAA-MM-DD

## Contexto
## Decisión
## Consecuencias
## Alternativas descartadas
```
