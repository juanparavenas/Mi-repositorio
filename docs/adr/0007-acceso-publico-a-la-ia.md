# ADR-0007 · Acceso público a la IA con cuotas, presupuesto e interruptor

- **Estado:** Aceptada (decisión 2 de la fase 0)
- **Fecha:** 2026-11-25

## Contexto

El administrador quiere mantener el asistente abierto también a visitantes sin registro. Sin límites, un uso abusivo o automatizado puede generar costos sin techo.

## Decisión

- **Cuotas diarias:** 3 consultas por visitante y 10 por usuario registrado, editables en `app_settings` sin cambiar código.
- **Identificación de visitantes sin datos personales:** hash HMAC-SHA256 de IP + agente de usuario con un secreto del servidor que rota a diario. La IP nunca se almacena.
- **Antibots:** Cloudflare Turnstile antes de cada conversación de visitante.
- **Control de tokens:** tope de tokens de salida por respuesta (1.200 visitantes, 2.000 registrados) y modos avanzados solo para registrados.
- **Presupuesto global mensual** (`ai.monthly_budget_usd`), alerta al 80% y **corte automático** al 100%.
- **Interruptor manual** (`ai.public_enabled`) para restringir temporalmente el servicio.
- `ai_try_consume()` aplica todo lo anterior de forma atómica y solo el servidor puede invocarla.
- **Valores iniciales:** IA apagada y presupuesto 0, hasta que el administrador apruebe un gasto (ADR-0010).

## Consecuencias

- Probado en la prueba 05: cuotas, cuota editable, alerta, corte, interruptor y bloqueo de invocación directa.
- Las respuestas en caché, si se implementan, se separan por nivel de acceso para no filtrar contenido restringido.
