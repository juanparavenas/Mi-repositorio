# ADR-0010 · Costo cero por defecto y activación de servicios por fase

- **Estado:** Aceptada (decisiones 4 y 5 de la fase 0, e instrucción del administrador: "no apruebes nada que me cobre")
- **Fecha:** 2026-11-25

## Contexto

El administrador no quiere incurrir en gastos. Cualquier servicio que cobre debe ser aprobado por él de forma explícita y con su costo conocido de antemano.

## Decisión

1. **Ningún servicio pagado se activa sin aprobación explícita y por escrito del administrador**, incluida la API de Claude.
2. Todo servicio se usa primero en su **plan gratuito sin tarjeta** cuando existe.
3. Cada servicio se incorpora **en la fase que lo necesita**, no antes (ver `docs/infraestructura.md`).
4. Las funciones que dependen de servicios pagados (IA, video administrado, dominio) se construyen de modo que la plataforma funcione sin ellas y se activen con una configuración.
5. Antes de pedir una aprobación se presenta: costo mensual, consumo estimado, escenarios de crecimiento y cómo se limitará el gasto.
6. Cuando se apruebe un gasto, se configurará también el tope de gasto del proveedor (por ejemplo, límite mensual en la consola de Anthropic) además del presupuesto interno.

## Consecuencias

- Fases 0 a 3, 5 y 6 pueden completarse con costo cero (con video alojado externamente en la fase 5).
- La fase 4 (IA) y los resúmenes y traducciones automáticos de la fase 2 requieren aprobación de gasto.
- Los planes gratuitos tienen límites que se monitorean (ver `docs/costos.md`).
