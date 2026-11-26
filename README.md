# CMF Academy

**The Oral & Maxillofacial Knowledge Platform** · Creado por Dr. Juan Pablo Aravena S.

Biblioteca científica pública y plataforma académica colaborativa de Cirugía Oral y Maxilofacial: un árbol de conocimiento de profundidad libre en el que cada tema reúne síntesis revisadas, literatura de PubMed, documentos, multimedia y un asistente de IA que solo afirma lo que puede citar.

## Estado

**Fase 1 · Fundamentos (en curso).** La fase 0 (arquitectura, decisiones, modelo de datos probado, política de exclusión documental y sistema de diseño) está integrada en `main`. La aplicación web ya tiene andamiaje, sistema de diseño con modo claro y oscuro, y navegación; todavía no está conectada a la base de datos ni desplegada. Ningún servicio que cobre se activará sin aprobación explícita del administrador.

## Documentación

| Documento | Contenido |
| --- | --- |
| [Arquitectura](docs/arquitectura.md) | Visión, arquitectura técnica, tecnologías, IA, PubMed, procesamiento, seguridad, riesgos y decisiones |
| [Modelo de datos](docs/modelo-de-datos.md) | Entidades, reglas y pruebas |
| [Plan de implementación](docs/plan-de-implementacion.md) | Ocho fases con PR y criterios de salida |
| [Infraestructura](docs/infraestructura.md) | Servicios por fase, entornos, configuración y respaldos |
| [Costos](docs/costos.md) | Planes gratuitos, costo por servicio, por documento y por consulta; escenarios |
| [Privacidad y cumplimiento](docs/privacidad-y-cumplimiento.md) | Normativa, datos sensibles, imágenes clínicas, verificación previa al lanzamiento |
| [Política de exclusión documental](docs/politica-de-exclusion-documental.md) | Qué no se importa (DICOM, proyectos clínicos, presentaciones, duplicados), cuarentena y reglas del importador de Google Drive |
| [Identidad visual](docs/identidad-visual.md) | Sistema de diseño con modo claro y oscuro, tokens, componentes y prototipo navegable |
| [Dominio](docs/dominio.md) | Recomendación de dominio |
| [Decisiones (ADR)](docs/adr/README.md) | Registro de decisiones de arquitectura |

## Estructura

```text
.
├── apps/web/                # Aplicación Next.js (App Router, TypeScript estricto)
│   ├── src/app/             # Rutas: las siete secciones, búsqueda y sistema de diseño
│   ├── src/components/      # Estructura, navegación, selector de tema y componentes
│   ├── src/styles/          # tokens.css (fuente única de diseño) y estilos.css
│   └── e2e/                 # Pruebas de extremo a extremo y de accesibilidad
├── docs/                    # Arquitectura, decisiones (adr/) y diseño (diseno/)
├── config/                  # Reglas versionadas (política de exclusión documental)
├── supabase/
│   ├── migrations/          # Esquema de la base de datos (borrador de diseño probado)
│   ├── tests/               # Pruebas del modelo de datos
│   └── seed.sql             # Taxonomía inicial (5 áreas, 51 temas)
├── scripts/                 # Utilidades de verificación y clasificador de la política de exclusión
├── .github/                 # CI y plantilla de pull request
└── .env.example             # Variables de entorno necesarias (sin valores)
```

El worker de procesamiento (`services/worker`) se crea en la fase 2; ver [arquitectura](docs/arquitectura.md).

## Aplicación web

Requiere Node.js 22 o superior y pnpm (`corepack enable`).

```bash
pnpm install
```

```bash
pnpm dev
```

La aplicación queda en `http://localhost:3000`. Verificaciones (las mismas que corre la CI):

```bash
pnpm format:check && pnpm lint && pnpm typecheck && pnpm test
```

```bash
pnpm build && pnpm e2e
```

Las pruebas de extremo a extremo necesitan Chromium (`pnpm --filter @cmf/web exec playwright install chromium`).

## Pruebas del modelo de datos y de las reglas

Requiere PostgreSQL 15 o superior con las extensiones `vector`, `ltree`, `pg_trgm`, `unaccent` y `citext`:

```bash
PGHOST=localhost PGUSER=postgres supabase/tests/run.sh
```

```bash
python3 scripts/check_docs_links.py
```

```bash
python3 -m unittest discover -s scripts/tests -v
```

## Flujo de trabajo

`main` es la rama estable. El trabajo se desarrolla en ramas y llega a `main` solo mediante pull requests revisados por el administrador.

## Derechos

La identidad y el contenido original de CMF Academy pertenecen a su creador. El material de terceros conserva sus derechos y se presenta con atribución y enlace a su fuente original.
