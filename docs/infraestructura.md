# Infraestructura

Este documento define qué servicios usa CMF Academy, **en qué fase se incorpora cada uno**, qué se necesita para configurarlo y cómo se protege. Ningún servicio se activa en la fase 0. Ninguno que cobre se activa sin aprobación explícita del administrador ([ADR-0010](adr/0010-costo-cero-y-activacion-por-fase.md)).

## 1. Servicios por fase

| Servicio | Fase en que se necesita | Para qué | Plan | Requiere aprobación de gasto |
| --- | --- | --- | --- | --- |
| GitHub | 0 (ya conectado) | Repositorio, PR, CI, worker del piloto | Gratuito | No |
| Supabase | 1 | Base de datos, Auth, Storage, pg_cron | Free | No (Pro sí) |
| Vercel | 1 | Hosting de la web y entornos de vista previa por PR | Hobby | No (Pro sí) |
| Sentry | 1 | Registro de errores | Developer (gratuito) | No |
| Google Cloud (solo OAuth) | 1 | Inicio de sesión con Google | Gratuito, sin facturación | No |
| Correo del proyecto | 3 | Contacto exigido por NCBI y Unpaywall | Cuenta de correo gratuita | No |
| NCBI E-utilities | 3 | PubMed | Gratuito con clave API | No |
| Unpaywall, Crossref, DeCS | 3 | Acceso abierto, metadatos, términos en español | Gratuitos | No |
| Anthropic | 2 (resúmenes y traducciones) y 4 (asistente) | Modelos Claude | Pago por uso | **Sí** |
| Embeddings | 4 | Búsqueda semántica | Cupo gratuito o modelo abierto | Solo si se excede el cupo |
| Cloudflare Turnstile | 4 | Antibots del asistente público | Gratuito | No |
| Video | 5 | Videos de procedimientos | YouTube/Vimeo no listados | Cloudflare Stream sí |
| Dominio | 6 o lanzamiento | Dirección propia | — | **Sí** |

## 2. Entornos

| Entorno | Dónde | Datos | Cuándo |
| --- | --- | --- | --- |
| Local | Computador del desarrollador o sesión de Claude | Semilla y datos de prueba | Desde la fase 1 |
| CI | GitHub Actions | Base desechable por ejecución | Desde la fase 0 |
| Vista previa | Vercel (un despliegue por PR) + proyecto Supabase de desarrollo | Datos de prueba | Desde la fase 1 |
| Producción | Vercel + proyecto Supabase de producción | Datos reales | Solo cuando apruebes el lanzamiento |

Supabase Free permite 2 proyectos activos: uno de desarrollo y otro de producción.

**En la fase 0 no se despliega nada.** El primer despliegue (de vista previa, no público) ocurre en la fase 1, previa revisión del PR de esa fase.

## 3. Cuentas y configuración por servicio

Las cuentas se crean **a nombre del proyecto**, con un correo del proyecto y doble factor activado. Tú creas las cuentas y cargas las claves; las claves nunca se pegan en el chat ni en el repositorio.

### Supabase (fase 1)

1. Crear una organización "CMF Academy" en plan **Free**, **sin registrar tarjeta**.
2. Crear dos proyectos: `cmf-academy-dev` y, más adelante, `cmf-academy-prod`. Región sugerida: São Paulo (`sa-east-1`), la más cercana a Chile.
3. Activar el inicio de sesión con Google y con enlace mágico; exigir doble factor a editores y administradores.
4. Aplicar las migraciones de `supabase/migrations/` y la semilla.
5. Copiar a las variables de entorno: URL del proyecto, clave publicable y clave secreta (ver [`.env.example`](../.env.example)).
6. **Asignar el administrador inicial** (una sola vez, desde el editor SQL, después de que inicies sesión por primera vez):

   ```sql
   insert into public.user_roles (user_id, role)
   select id, 'admin' from auth.users where email = '<tu correo>';
   ```

### Vercel (fase 1)

1. Cuenta **Hobby** vinculada a GitHub, sin tarjeta.
2. Importar el repositorio; directorio raíz `apps/web`.
3. Cargar las variables de entorno de Supabase en "Preview" y, cuando corresponda, en "Production".
4. Despliegues de vista previa automáticos por PR; producción solo desde `main`.

El plan Hobby está limitado a uso personal y no comercial. CMF Academy no tiene fines de lucro, lo que encaja con ese uso. Si alguna vez se monetiza o se institucionaliza, habrá que pasar a un plan que lo permita (con aprobación).

### Anthropic (solo con aprobación)

1. Crear la organización en la consola de Anthropic.
2. Crear un **workspace** "cmf-academy" con un **límite de gasto mensual** igual al presupuesto aprobado.
3. Crear una clave de API para ese workspace y cargarla como `ANTHROPIC_API_KEY` en Vercel y en los secretos del worker.
4. Fijar en la plataforma `ai.monthly_budget_usd` al mismo valor (o menor) y encender `ai.public_enabled`.

Hasta entonces, la IA permanece apagada y el código funciona sin la clave.

### NCBI E-utilities (fase 3)

1. Crear una cuenta en NCBI con el correo del proyecto y generar una clave API (gratuita).
2. Cargar `NCBI_API_KEY`, `NCBI_TOOL=cmf-academy` y `NCBI_EMAIL`.
3. El cliente respeta un máximo de 10 solicitudes por segundo y se identifica con `tool` y `email`.

### Cloudflare Turnstile (fase 4)

Crear un widget gratuito para el dominio de la plataforma y cargar `NEXT_PUBLIC_TURNSTILE_SITE_KEY` y `TURNSTILE_SECRET_KEY`.

### Sentry (fase 1)

Proyecto en el plan Developer gratuito; cargar `SENTRY_DSN` y `NEXT_PUBLIC_SENTRY_DSN`. Se configura para **no enviar datos personales** (sin IP ni cuerpos de solicitudes).

## 4. Worker del piloto en GitHub Actions

Ver [ADR-0015](adr/0015-worker-en-github-actions-durante-el-piloto.md). Un flujo programado ejecuta el worker cada 30 minutos (y bajo demanda). Toma trabajos con `claim_jobs()`, los procesa y termina. Sus credenciales (`SUPABASE_DB_URL`, `NCBI_API_KEY` y, si se aprueba, `ANTHROPIC_API_KEY`) se guardan como **secretos del repositorio**. Se implementa en la fase 2.

## 5. Variables de entorno

La lista completa, con la fase en que se necesita cada una y si es pública o secreta, está en [`.env.example`](../.env.example). Reglas:

- Solo las variables con prefijo `NEXT_PUBLIC_` llegan al navegador, y ninguna de ellas es secreta.
- Los secretos viven en Vercel, en los secretos de GitHub Actions o en un `.env.local` que Git ignora.
- CI busca secretos filtrados en cada PR.

## 6. Respaldos

| Plan | Mecanismo |
| --- | --- |
| Supabase Free (piloto) | Flujo de GitHub Actions nocturno con `pg_dump` del esquema y los datos, guardado como artefacto privado del flujo (retención de 90 días). Exportación periódica de Storage. |
| Supabase Pro (si se aprueba) | Respaldos diarios automáticos + el mismo respaldo propio como segunda copia. |

Además, el esquema completo vive versionado en `supabase/migrations/`, y la taxonomía inicial en `supabase/seed.sql`.

Se probará la **restauración** en un proyecto de desarrollo al menos una vez por fase.

## 7. Monitoreo de límites gratuitos

El panel de administración (fase 1) mostrará el uso de la base y de Storage frente a los límites del plan Free. Una alerta al 80% dará tiempo para decidir (ver [costos.md](costos.md), sección 4) antes de llegar al límite.
