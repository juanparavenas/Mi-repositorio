# CMF Academy

**The Oral & Maxillofacial Knowledge Platform** · Creado por Dr. Juan Pablo Aravena S.

Biblioteca científica pública y plataforma académica colaborativa de Cirugía Oral y Maxilofacial: un árbol de conocimiento de profundidad libre en el que cada tema reúne síntesis revisadas, literatura de PubMed, documentos, multimedia y un asistente de IA que solo afirma lo que puede citar.

## Estado

**Fase 0 · Diseño y configuración.** Este repositorio contiene la arquitectura, las decisiones, el modelo de datos probado, la documentación de infraestructura y costos, y la identidad visual provisional. Todavía no hay aplicación desplegada ni servicios activados, y ninguno que cobre se activará sin aprobación explícita del administrador.

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
| [Identidad visual](docs/identidad-visual.md) | Tipografía, color y espécimen provisional |
| [Dominio](docs/dominio.md) | Recomendación de dominio |
| [Decisiones (ADR)](docs/adr/README.md) | Registro de decisiones de arquitectura |

## Estructura

```text
.
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

La estructura completa prevista para la aplicación (`apps/web`, `services/worker`, `packages/`) se crea en la fase 1; ver [arquitectura](docs/arquitectura.md).

## Pruebas

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
