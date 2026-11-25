# ADR-0013 · Flujo de ramas, pull requests y CI

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

`main` debe mantenerse estable. El administrador revisa cada fase antes de integrarla.

## Decisión

- El desarrollo ocurre en ramas de trabajo (actualmente `claude/sweet-ride-5juqru`) y llega a `main` solo por **pull request** revisado y aprobado por el administrador.
- Cada fase termina con un PR que incluye cambios, pruebas, decisiones y documentación.
- **CI en GitHub Actions** en cada PR y push: pruebas de la base de datos (PostgreSQL 16 y 17 con pgvector) y verificación de enlaces de la documentación. Las fases siguientes agregan lint, tipos, pruebas unitarias, pruebas de extremo a extremo y evaluaciones del asistente.
- No se hacen despliegues a producción sin aprobación.

## Consecuencias

- GitHub Actions es gratuito en repositorios públicos y tiene 2.000 minutos mensuales gratis en repositorios privados de cuentas Free; sin un método de pago registrado no genera cobros.
