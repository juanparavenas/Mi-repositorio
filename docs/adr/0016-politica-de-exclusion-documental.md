# ADR-0016 · Política de exclusión documental

- **Estado:** Aceptada (instrucciones del administrador del 25 y 26-11-2026)
- **Fecha:** 2026-11-26

## Contexto

El inventario de Google Drive (2.566 archivos) mostró que las carpetas académicas conviven con trabajo clínico: estudios DICOM, proyectos de ProPlan CMF y Mimics, modelos STL de un caso real, carpetas de pacientes, protocolos y epicrisis, y presentaciones con posibles fotografías de pacientes. Una importación masiva sin reglas copiaría datos sensibles de salud a Supabase, los enviaría a la IA y podría publicarlos.

## Decisión

- Se adopta una **política de exclusión obligatoria** para todo inventario, importación y carga ([politica-de-exclusion-documental.md](../politica-de-exclusion-documental.md)).
- Cada elemento recibe una de cuatro decisiones: permitido, revisión individual, cuarentena o excluido. Solo lo permitido se copia; lo excluido nunca se procesa con IA, se indexa ni se publica. Todo queda registrado con su motivo.
- Se excluyen los DICOM; los proyectos y archivos de trabajo de ProPlan CMF, Mimics, 3-matic e IPS CaseDesigner (este último por estructura, sin extensiones supuestas); el contenido de las carpetas de casos clínicos y de pacientes; las presentaciones; y las copias duplicadas.
- Los STL y OBJ académicos no se excluyen por su formato: esperan revisión. Los libros y capítulos se importan con el flujo normal de derechos.
- Ante la duda, cuarentena.
- Las reglas viven en un archivo versionado y las hacen cumplir un clasificador probado y la base de datos (migración 0800, prueba 09).
- Los originales de Google Drive nunca se modifican.

## Consecuencias

- La fase 2 incluye un importador de Google Drive de solo lectura que aplica esta política antes de copiar.
- Se abandona el plan de almacenar DICOM anonimizados y el visor DICOM de la fase 7.
- Parte del material docente queda fuera hasta su revisión (presentaciones, posibles fotografías clínicas, clases en carpetas de ProPlan).
- Al implementar la migración se corrigió una política RLS de la fase 0: el permiso de escritura de los editores sobre `files` también concedía lectura y se saltaba `can_read_file()`.

## Alternativas descartadas

- **Excluir por extensión solamente:** no reconoce IPS CaseDesigner ni las exportaciones (PNG, MP4, PDF) de un caso.
- **Excluir todo STL y OBJ:** perdería modelos anatómicos educativos.
- **Importar todo y filtrar después:** los datos sensibles llegarían a Supabase y a la IA antes de la revisión.
- **Anonimizar DICOM y proyectos:** costoso, propenso a errores y sin valor docente frente a su riesgo.
