# Plan de implementación

Ocho fases (0 a 7). Cada una termina con un **pull request hacia `main`** que tú revisas y apruebas antes de empezar la siguiente ([ADR-0013](adr/0013-flujo-de-ramas-pr-y-ci.md)). Una funcionalidad está terminada solo si funciona con datos reales, tiene una interfaz coherente, está probada, maneja errores, persiste lo que corresponde, está integrada y documentada (documento maestro, sección 15).

**Regla de costos:** ninguna tarea activa un servicio pagado sin tu aprobación explícita ([ADR-0010](adr/0010-costo-cero-y-activacion-por-fase.md)). Las tareas que lo requieren están marcadas con **[$]**.

---

## Fase 0 · Diseño y configuración (este PR)

| Entregable | Estado |
| --- | --- |
| Inspección del repositorio | Hecho: solo contenía `README.md` |
| Arquitectura y decisiones | [arquitectura.md](arquitectura.md), 15 ADR |
| Modelo de datos | 8 migraciones SQL + semilla de 51 temas + 9 archivos de pruebas |
| Política de exclusión documental | [politica-de-exclusion-documental.md](politica-de-exclusion-documental.md), reglas versionadas, clasificador con pruebas, migración 0800 |
| Infraestructura, variables de entorno, costos | [infraestructura.md](infraestructura.md), [`.env.example`](../.env.example), [costos.md](costos.md) |
| Privacidad y cumplimiento | [privacidad-y-cumplimiento.md](privacidad-y-cumplimiento.md) |
| Dominio | [dominio.md](dominio.md) |
| Identidad tipográfica provisional | [identidad-visual.md](identidad-visual.md), tokens y espécimen |
| Sistema de diseño v2 (adelanto de la fase 1.3) | Modo claro y oscuro con selector, tokens verificados por contraste en CI, componentes y prototipo navegable de cinco pantallas |
| CI | GitHub Actions: pruebas de base de datos (PostgreSQL 16 y 17), pruebas del clasificador de exclusión, enlaces de la documentación, búsqueda de secretos |

**Criterio de salida:** apruebas este PR. El color de acento ya está elegido: verde petróleo (26-11-2026).

---

## Fase 1 · Fundamentos · US$0

**Objetivo:** navegar el árbol de conocimiento real en una aplicación desplegada en vista previa.

| PR | Contenido | Criterio de aceptación |
| --- | --- | --- |
| 1.1 Andamiaje | Monorepo pnpm, `apps/web` (Next.js + TypeScript estricto), lint, formato, Vitest, Playwright, CI ampliada | CI verde; `pnpm dev` levanta la aplicación |
| 1.2 Supabase | Proyecto Free de desarrollo, migraciones aplicadas, tipos generados, clientes de servidor y navegador | Las pruebas SQL pasan también contra el proyecto real; RLS verificada desde la API |
| 1.3 Sistema de diseño | Tokens, tipografía alojada en el propio sitio, componentes base (botón, campo, tabla, insignia, panel, navegación), modo oscuro, accesibilidad con teclado | Página de componentes; contraste AA verificado automáticamente |
| 1.4 Autenticación y roles | Google y enlace mágico, doble factor para editores, asignación del administrador inicial, guardas en el servidor | Pruebas de extremo a extremo: visitante, miembro, editor y administrador ven lo que corresponde |
| 1.5 Navegación y layout | Barra lateral de 7 secciones, barra superior, búsqueda de temas, pie con créditos | Navegación completa con teclado; sin desplazamiento horizontal en teléfono |
| 1.6 Biblioteca jerárquica | Explorador del árbol, rutas legibles (`/biblioteca/...`), migas de pan | Los 51 temas de la semilla navegables; un tema nuevo aparece sin tocar código |
| 1.7 Páginas de tema | Encabezado y secciones A–H (vacías donde no hay datos, sin contenido simulado); versiones y revisión editorial | Un editor crea, revisa y publica una sección; el visitante solo ve lo publicado |
| 1.8 Administración de taxonomía | Crear, editar, mover, ordenar y relacionar temas; publicar | Mover un subárbol desde la interfaz actualiza rutas y navegación |
| 1.9 Dashboard | Búsqueda global, especialidades, temas recientes y estadísticas reales desde la base | Las cifras coinciden con consultas directas a la base |
| 1.10 Institucional | Acerca de, créditos, borradores de términos, privacidad y política de derechos de autor | Revisión de textos por ti |

**Criterio de salida:** despliegue de vista previa en Vercel Hobby (no público) con la taxonomía inicial publicada por ti.

---

## Fase 2 · Gestión documental · US$0 sin IA

| PR | Contenido |
| --- | --- |
| 2.0 Importador de Google Drive | Solo lectura. Recorre la carpeta completa, aplica la [política de exclusión documental](politica-de-exclusion-documental.md) antes de copiar, registra cada archivo en `source_items` con su decisión y motivo, resuelve duplicados y copia únicamente lo permitido. Nunca modifica Drive |
| 2.1 Carga | Arrastrar y soltar (solo editores en esta fase), validación de tipo real, tamaño y SHA-256, detección de duplicados, la misma política de exclusión que el importador, Storage privado con políticas |
| 2.2 Worker | Paquete Python, cliente de cola (`claim_jobs`, `complete_job`, `fail_job`), flujo de GitHub Actions programado, registros y reintentos |
| 2.3 Extracción | Docling y PyMuPDF; OCR; tablas, figuras y páginas; secciones fallidas informadas |
| 2.4 Metadatos | DOI y PMID desde el texto, Crossref y PubMed, detección de idioma, deduplicación de obras |
| 2.5 Derechos | Flujo editorial de estado de distribución, base legal, verificación y permiso de IA; panel de revisión de la cuarentena y de las liberaciones |
| 2.6 Lector | PDF.js con apertura en página exacta, ficha de la obra, enlaces a la fuente |
| 2.7 Imágenes | Optimización, miniaturas y eliminación de metadatos EXIF |
| 2.8 Clasificación, resumen y traducción **[$]** | Se construyen y prueban con un pequeño presupuesto aprobado; sin aprobación quedan desactivados y la clasificación es manual |

**Criterio de salida:** 50 documentos reales cargados, con metadatos verificados y estado de distribución definido por ti; ningún archivo excluido o en cuarentena con copia en Storage. Si apruebas presupuesto: 10 resúmenes y 5 traducciones validados por ti.

---

## Fase 3 · PubMed · US$0

| PR | Contenido |
| --- | --- |
| 3.1 Cliente E-utilities | ESearch, EFetch, ESummary, ELink; límite de 10 solicitudes/s; reintentos; pruebas con XML real guardado |
| 3.2 Búsqueda | Por palabra clave, autor, año, tipo de estudio, patología y procedimiento; filtros; enlaces a PubMed, DOI y PMC |
| 3.3 Fichas y biblioteca | Guardar registros como obras públicas, nivel de evidencia según tipo de publicación, relación con varios temas |
| 3.4 Acceso abierto | PMC OA, Unpaywall; licencia registrada; nunca incorporación automática de textos completos |
| 3.5 Actualización por tema | Consultas guardadas, `pg_cron`, sincronización programada, "Publicaciones recientes", confirmación editorial |

**Criterio de salida:** cada área inicial muestra publicaciones recientes reales, actualizadas semanalmente sin intervención.

---

## Fase 4 · Inteligencia artificial · [$] requiere aprobación

Antes de comenzar te presentaré una solicitud de presupuesto con el escenario A de [costos.md](costos.md) (~US$15–20/mes) y los topes configurados.

| PR | Contenido |
| --- | --- |
| 4.1 Capa de proveedor | `lib/ai` con ruteo de modelos, caché de prompts, registro de costo, manejo de errores y rechazos |
| 4.2 Embeddings | Evaluación de proveedores ([ADR-0014](adr/0014-proveedor-de-embeddings.md)), indexación, búsqueda híbrida con permisos del usuario |
| 4.3 Set de evaluación | 50–100 preguntas reales con fuente esperada y preguntas trampa; corre en CI |
| 4.4 Asistente | Tutor general y por tema, citas nativas, validación de referencias, separación evidencia/interpretación |
| 4.5 Protección | Turnstile, cuotas 3/10, tope de tokens, presupuesto, interruptor, panel de costos |
| 4.6 Modos avanzados | Investigador (con PubMed), Comparador, Crítico, Organizador |

**Criterio de salida:** el set de evaluación supera los umbrales acordados y ninguna referencia inventada pasa la validación.

---

## Fase 5 · Multimedia · US$0 con video externo

Galerías por tema, visor con zoom, video embebido (YouTube o Vimeo no listados; Cloudflare Stream solo con aprobación **[$]**), esquemas, modelos 3D (three.js) y el flujo completo de consentimiento y anonimización.

**Criterio de salida:** una imagen clínica solo se publica tras completar el checklist; probado de extremo a extremo.

---

## Fase 6 · Comunidad · US$0

Registro abierto, perfiles, aportes de documentos y enlaces con moderación, comentarios, panel de moderación, formulario de derechos de autor, eliminación de cuenta y exportación de datos propios. Revisión legal previa al lanzamiento público ([privacidad-y-cumplimiento.md](privacidad-y-cumplimiento.md)). Compra de dominio **[$]**, si la apruebas.

**Criterio de salida:** un aporte recorre todo el flujo hasta publicarse o rechazarse con motivo.

---

## Fase 7 · Herramientas académicas avanzadas · según uso de IA

Flashcards, preguntas tipo examen, tablas comparativas, esquemas conceptuales, algoritmos diagnósticos y terapéuticos, casos clínicos para discusión y presentaciones académicas generadas desde las fuentes. El visor DICOM previsto inicialmente se descarta: la [ADR-0016](adr/0016-politica-de-exclusion-documental.md) excluye los estudios DICOM. Todo material generado enlaza a sus fuentes y pasa por revisión editorial.

---

## Riesgos técnicos y limitaciones conocidas

| Riesgo | Mitigación |
| --- | --- |
| Límites de Supabase Free (500 MB de base, 1 GB de archivos, pausa por inactividad) | Monitoreo con alerta al 80%; respaldo propio; decisión informada antes del límite |
| Worker en GitHub Actions: procesamiento no inmediato | Aceptable en el piloto; ejecución bajo demanda disponible |
| Extracción imperfecta de PDF escaneados o complejos | Secciones fallidas visibles; revisión editorial |
| Sin IA aprobada, la clasificación y los resúmenes son manuales | La plataforma es útil igual: árbol, documentos, PubMed y lector funcionan sin IA |
| Cambios en las API externas (NCBI, Anthropic) | Clientes aislados, pruebas con respuestas reales guardadas, versiones fijadas |
| Normativa en cambio | Diseño conforme desde el inicio y revisión legal antes del lanzamiento |
