# Costos

**Regla vigente:** costo cero. No se activa ningún servicio que cobre sin aprobación explícita del administrador ([ADR-0010](adr/0010-costo-cero-y-activacion-por-fase.md)). Este documento entrega la información que se pidió conocer **antes** de cualquier activación: costo de cada servicio, consumo estimado de IA, costo por documento, costo de almacenamiento y escenarios de crecimiento.

- Precios de Claude: vigentes a noviembre de 2026.
- Precios de los demás servicios: consultados el 25 de noviembre de 2026 en sus páginas oficiales o en fuentes secundarias (ver [Fuentes](#fuentes)). Se volverán a verificar antes de cualquier aprobación.
- Montos en dólares estadounidenses (US$).

## 1. Resumen

| Etapa | Costo mensual | Qué incluye |
| --- | --- | --- |
| Fases 0 a 3 (fundamentos, documentos sin IA, PubMed) | **US$0** | Planes gratuitos de GitHub, Supabase y Vercel; NCBI gratuito; worker en GitHub Actions |
| Fase 4 (IA) en piloto controlado | **Desde ~US$5–20** | Solo la API de Claude, con tope; **requiere tu aprobación** |
| Plataforma pública con uso real | ~US$100–700 | IA según tráfico + planes pagados de base de datos y hosting; **requiere tu aprobación** |

La IA es el único componente sin alternativa gratuita de calidad comparable: la API de Claude no tiene plan gratuito. Todo lo demás puede funcionar en planes gratuitos durante el piloto, con los límites indicados abajo.

## 2. Servicios: plan gratuito, límites y costo si se pagara

| Servicio | Fase | Plan gratuito (sin tarjeta) | Límites relevantes del plan gratuito | Plan pagado si hiciera falta |
| --- | --- | --- | --- | --- |
| GitHub (repositorio y Actions) | 0 | Sí | Actions: ilimitado en repositorios públicos; 2.000 min/mes en privados | No previsto |
| Supabase (base, Auth, Storage) | 1 | Sí | 500 MB de base de datos, 1 GB de archivos, 5 GB de transferencia; el proyecto se pausa tras 7 días sin actividad; sin respaldos automáticos | Pro: US$25/mes (8 GB base, 100 GB archivos, 250 GB transferencia, respaldos diarios, tope de gasto activado por defecto) |
| Vercel (hosting web) | 1 | Sí (Hobby) | Uso personal y no comercial; 100 GB de transferencia y 4 h de CPU activa al mes | Pro: US$20/mes por persona con US$20 de uso incluido |
| NCBI E-utilities | 3 | Sí, gratuito | 10 solicitudes/s con clave API | No existe plan pagado |
| Unpaywall, Crossref, DeCS | 3 | Sí, gratuitos | Uso razonable con correo de contacto | No existe plan pagado |
| Anthropic (API de Claude) | 4 | **No** | — | Pago por uso (sección 3) |
| Embeddings | 4 | Voyage: 200 millones de tokens gratis por cuenta; `bge-m3` autoalojado gratuito | Verificar si Voyage exige método de pago para límites normales | voyage-4-lite US$0,02 y voyage-4 US$0,06 por millón de tokens |
| Cloudflare Turnstile | 4 | Sí, gratuito | — | No necesario |
| Sentry | 1 | Sí (Developer) | 5.000 errores/mes, 1 usuario | Team: desde ~US$26/mes |
| Video | 5 | YouTube o Vimeo no listados, embebidos | Sin control de acceso fino | Cloudflare Stream: US$5 por 1.000 minutos almacenados + US$1 por 1.000 minutos vistos |
| Correo institucional | 3 | Cuenta gratuita de correo para registrar NCBI y Unpaywall | Sin dominio propio | Correo con dominio propio requiere comprar el dominio |
| Dominio | 6 | Subdominio gratuito `*.vercel.app` | Dirección menos memorable | `.org` ~US$10–15/año; `.cl` ~US$11,5/año ([dominio.md](dominio.md)) |

## 3. Consumo estimado de IA

Precios de Claude por millón de tokens (entrada / salida): **Haiku 5.5** US$0,10 / US$0,50 · **Sonnet 5.5** US$2 / US$10 · **Opus 5.5** US$4 / US$20. El procesamiento por lotes cuesta 50% menos. Las estimaciones incluyen un margen de 1,5× por el razonamiento interno del modelo, que se cobra como salida.

### Costo por documento procesado (artículo típico de ~12.000 tokens)

| Paso | Modelo | Costo aproximado | Con lotes (−50%) |
| --- | --- | --- | --- |
| Extracción, metadatos (PubMed/Crossref) | Sin IA | US$0 | US$0 |
| Clasificación y contexto de fragmentos | Haiku 5.5 | US$0,005 | US$0,003 |
| Embeddings | voyage-4-lite o bge-m3 | ≤ US$0,0003 (gratis dentro del cupo) | — |
| Resumen estructurado | Sonnet 5.5 | US$0,05–0,07 | US$0,03 |
| Traducción completa | Sonnet 5.5 | US$0,17–0,25 | US$0,09–0,13 |
| **Total con resumen y traducción** | | **~US$0,25–0,33** | **~US$0,13–0,17** |
| **Total solo con resumen** | | **~US$0,06–0,08** | **~US$0,03–0,04** |

### Costo por consulta al asistente

| Modo | Supuesto | Costo aproximado |
| --- | --- | --- |
| Tutor (visitante, respuesta ≤ 1.200 tokens) | 10.000 tokens de fuentes + respuesta, Sonnet 5.5 | US$0,03–0,05 |
| Tutor (registrado, respuesta ≤ 2.000 tokens) | Igual, respuesta más larga | US$0,04–0,06 |
| Investigador | Varias búsquedas en PubMed y biblioteca | US$0,10–0,20 |
| Comparador o Crítico | Opus 5.5 | US$0,15–0,30 |

### Escenarios mensuales de IA

| Escenario | Supuestos | IA al mes |
| --- | --- | --- |
| A. Piloto interno | Tú y 2–3 editores: 300 consultas; 100 documentos con resumen; 20 traducciones (por lotes) | **~US$15–20** |
| B. Piloto público acotado | A + 30 visitantes diarios × 2 consultas (1.800/mes) | ~US$75–110 |
| C. Uso público moderado | 300 usuarios activos: 9.000 consultas; 300 documentos con resumen | ~US$350–500 |
| D. Crecimiento | 1.000 usuarios activos: 30.000 consultas | ~US$1.000–1.500 |

Con cuotas de 3 y 10 consultas diarias, el gasto máximo diario está acotado por el número de visitantes. El presupuesto mensual (`ai.monthly_budget_usd`) corta el servicio automáticamente al alcanzarse, y la consola de Anthropic permite fijar además un límite de gasto propio del proveedor.

## 4. Almacenamiento

| Elemento | Tamaño típico | Capacidad del plan gratuito de Supabase |
| --- | --- | --- |
| PDF original | 2–5 MB | 1 GB de archivos ≈ **200–400 PDF** |
| Texto, fragmentos y embeddings por artículo | ~150–250 KB | 500 MB de base ≈ **1.500–2.500 artículos** (descontando el resto de las tablas) |
| Ficha bibliográfica sin archivo (PubMed) | ~5 KB | Decenas de miles |
| Imagen clínica optimizada (WebP) | 0,2–0,5 MB | Comparte el 1 GB de archivos |
| Video | — | No se aloja en Supabase durante el piloto |

**Primer límite que se alcanzará:** el 1 GB de archivos, cerca de los 300 PDF. Opciones en ese momento, todas sujetas a tu aprobación:

1. Supabase Pro (US$25/mes): 100 GB de archivos y respaldos diarios.
2. Mantener Supabase Free y mover los originales a un almacenamiento gratuito de 10 GB (Backblaze B2 o Cloudflare R2; verificar si exigen tarjeta).
3. Priorizar fichas bibliográficas (sin PDF) para la literatura protegida, que de todos modos es "solo metadatos".

## 5. Escenarios de crecimiento (todo incluido)

| Escenario | Infraestructura | IA | Total mensual |
| --- | --- | --- | --- |
| Fases 0–3, piloto sin IA | US$0 | US$0 | **US$0** |
| A. Piloto interno con IA | US$0 | ~US$15–20 | **~US$15–20** |
| B. Piloto público acotado | US$0–25 (Supabase Pro si se supera 1 GB) | ~US$75–110 | **~US$75–135** |
| C. Uso público moderado | ~US$45–70 (Supabase Pro + Vercel Pro + dominio) | ~US$350–500 | **~US$400–570** |
| D. Crecimiento | ~US$100–150 | ~US$1.000–1.500 | **~US$1.100–1.650** |

## 6. Cómo se pedirá cada aprobación

Antes de activar cualquier gasto, prepararé una solicitud con: servicio, motivo, costo mensual esperado y máximo, tope configurado en el proveedor, tope interno en la plataforma y forma de desactivarlo. Sin tu respuesta afirmativa explícita, no se activa.

Para financiar la IA sin costo personal puedes evaluar: fondos de investigación o docencia universitaria, patrocinios académicos sin fines comerciales, o programas de créditos de API para investigación o educación que ofrecen algunos proveedores, incluida Anthropic (hay que verificar la disponibilidad y las condiciones vigentes).

## Fuentes

- Claude: precios vigentes a noviembre de 2026 (documentación oficial de la API).
- Supabase: [precios](https://supabase.com/pricing) y [facturación](https://supabase.com/docs/guides/platform/billing-on-supabase).
- Vercel: [precios](https://vercel.com/pricing), [plan Hobby](https://vercel.com/docs/plans/hobby) y [uso justo](https://vercel.com/docs/limits/fair-use-guidelines).
- Voyage AI: [precios](https://docs.voyageai.com/pricing).
- Cloudflare: [precios de Stream](https://developers.cloudflare.com/stream/pricing/) y [Turnstile gratuito](https://blog.cloudflare.com/turnstile-ga/).
- Sentry: [precios](https://sentry.io/pricing/).
- Railway (alternativa descartada para el worker): [planes](https://docs.railway.com/reference/pricing/plans).
- NIC Chile: [tarifas en dólares](https://nic.cl/dominios/fees-usd.html).
