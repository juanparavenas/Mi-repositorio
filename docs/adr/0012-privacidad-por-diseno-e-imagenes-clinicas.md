# ADR-0012 · Privacidad por diseño e imágenes clínicas

- **Estado:** Aceptada
- **Fecha:** 2026-11-25

## Contexto

La plataforma tratará datos de usuarios y, en la fase 5, imágenes clínicas, radiografías y CBCT. En Chile rige la Ley 19.628 y la Ley 21.719 de protección de datos personales, cuya vigencia fue modificada al 15 de octubre de 2027 por la Ley 21.855; la Ley 20.584 protege la información de la ficha clínica.

## Decisión

- **Minimización:** el perfil guarda solo lo que el usuario decide mostrar; los visitantes se identifican con un hash rotativo, nunca con su IP.
- **Imágenes clínicas:** fotografías clínicas, radiografías y CBCT se tratan siempre como datos de paciente. Solo se publican con consentimiento obtenido y anonimización verificada por un editor (reglas en la base; prueba 08).
- **Anonimización técnica:** eliminación de metadatos EXIF y alerta automática de rostros o texto identificable. Los estudios DICOM no se almacenan: quedan excluidos por la [ADR-0016](0016-politica-de-exclusion-documental.md), que reemplaza el plan inicial de limpiar sus encabezados.
- **El documento de consentimiento no se almacena en la plataforma:** solo una referencia interna.
- **Derechos de los titulares:** eliminación de cuenta y exportación de datos propios.
- **Verificación legal antes del lanzamiento público** (ver `docs/privacidad-y-cumplimiento.md`).

## Consecuencias

- La fase 5 incluye el flujo de consentimiento y anonimización como requisito, no como mejora posterior.
