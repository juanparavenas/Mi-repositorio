# Política de exclusión documental

| | |
| --- | --- |
| Estado | **Obligatoria** para todo inventario, importación y carga de documentos |
| Versión | 1.1.0 (26-11-2026) |
| Decisión | [ADR-0016](adr/0016-politica-de-exclusion-documental.md) |
| Reglas ejecutables | [`config/politica-exclusion.json`](../config/politica-exclusion.json) |
| Clasificador de referencia | [`scripts/politica_exclusion.py`](../scripts/politica_exclusion.py) (pruebas en [`scripts/tests/`](../scripts/tests/test_politica_exclusion.py)) |
| Garantías en la base | Migración [`0800`](../supabase/migrations/20261125000800_exclusion_policy.sql) y prueba 09 |

CMF Academy importa literatura y material docente, nunca trabajo clínico. Esta política define qué archivos de Google Drive (o de cualquier otra fuente) **no entran a la plataforma**, cuáles esperan una revisión humana y cómo queda registrado cada caso. Se aplica desde el inventario, antes de copiar nada.

## 1. Las cuatro decisiones

| Decisión | Qué significa | ¿Se copia a Supabase? | ¿IA? | ¿RAG? | ¿Se publica? |
| --- | --- | --- | --- | --- | --- |
| **Permitido** (`allowed`) | Puede importarse. Sigue el flujo de derechos de autor y distribución ([ADR-0006](adr/0006-obra-archivo-derivados-y-distribucion.md)) | Sí | Solo con permiso de IA | Solo con permiso de IA | Según su estado de distribución |
| **Revisión individual** (`review_required`) | Potencialmente incorporable; una persona lo revisa uno por uno | No, hasta aprobarlo | No | No | No |
| **Cuarentena** (`quarantined`) | Hay incertidumbre sobre si pertenece a un caso o proyecto clínico | No, hasta que un administrador lo revise | No | No | No |
| **Excluido** (`excluded`) | No entra a la plataforma | **Nunca** | **Nunca** | **Nunca** | **Nunca** |

Todo elemento no permitido queda registrado en el **inventario de exclusión** con su regla y su motivo. **Ningún original de Google Drive se elimina, mueve ni modifica**, cualquiera sea la decisión.

## 2. Qué se excluye

### 2.1 Estudios DICOM

Excluidos siempre, sin excepción ni liberación posible (`EXC-DICOM`). Se reconocen por cualquiera de estas señales: extensión `.dcm` o `.dicom`, tipo MIME `application/dicom`, nombre `DICOMDIR`, firma `DICM` en el byte 128 de la cabecera o ubicación dentro de una carpeta llamada DICOM.

> Esta política reemplaza el plan anterior de almacenar estudios DICOM anonimizados y de un visor DICOM en la fase 7. Volver a admitirlos exigiría una nueva decisión de arquitectura.

### 2.2 Programas de planificación quirúrgica

Se excluyen los proyectos nativos, planificaciones, segmentaciones, modelos 3D de casos, archivos auxiliares y dependencias, respaldos, temporales, autoguardados y exportaciones derivadas de proyectos de pacientes de estos programas:

| Programa | Formatos de proyecto | Evidencia | Regla |
| --- | --- | --- | --- |
| ProPlan CMF (Materialise) | `.sppc` · MIME `application/sppc` | **Verificada**: proyecto de planificación ortognática presente en Drive, junto a su segmentación y su DICOM | `EXC-PROYECTO-PROPLAN` |
| Mimics / Mimics Medical (Materialise) | `.mcs` · MIME `application/mcs` | **Verificada**: «Segmentación inicial» presente en Drive; los tutoriales de 3-matic importan proyectos Mimics `.mcs` | `EXC-PROYECTO-MIMICS` |
| 3-matic / 3-matic Medical (Materialise) | `.mxp` | **Declarada** por el administrador; no confirmada en fuentes públicas accesibles ni presente en el inventario | `EXC-PROYECTO-3MATIC` |
| Programa por confirmar | `.sgc` | **Declarada** por el administrador; no confirmada ni presente en el inventario | `EXC-PROYECTO-DECLARADO` |
| IPS CaseDesigner (Nobel Biocare, sistema IPS de KLS Martin) | **Sin extensión propia verificada** | Se reconoce por estructura (ver 2.3) | `EXC-PROYECTO-IPS` |

La lista de extensiones **no es exhaustiva**: por eso las reglas por contexto (2.3 y 2.4) excluyen o ponen en cuarentena todo lo que está junto a un proyecto, aunque su formato no figure en la tabla, y todo formato desconocido queda en cuarentena.

### 2.3 IPS CaseDesigner: identificación por estructura

Sus instrucciones de uso (v2.5, GMT 84851) indican que el programa crea el modelo del paciente a partir de DICOM de CBCT, admite escaneos dentales en STL (superior, inferior y oclusión), genera archivos de férula para el plan quirúrgico y permite importar planes. No se inventan extensiones; un caso se reconoce por:

1. una carpeta cuyo nombre corresponde al programa (`IPS`, `CaseDesigner`, `KLS Martin`), y dentro de ella
2. una carpeta de caso: la que contiene un estudio DICOM, escaneos dentales o archivos de férula.

Todo archivo no documental de esa carpeta de caso se excluye con `EXC-PROYECTO-IPS`; los documentos quedan en cuarentena. El manual del programa guardado en una biblioteca (por ejemplo, el IFU en PDF) **no** se excluye.

### 2.4 Carpetas de casos clínicos

Una carpeta es **de caso clínico** cuando contiene un proyecto nativo, un estudio DICOM o tomográfico (también un comprimido llamado TC, TAC o CBCT) o datos de pacientes. Dentro de ella:

| Contenido | Decisión | Regla |
| --- | --- | --- |
| Respaldos, temporales, autoguardados, configuración | Excluido | `EXC-AUXILIAR-SOFTWARE` |
| Modelos 3D (STL, OBJ, PLY, 3MF, etc.) | Excluido hasta autorización expresa | `EXC-MODELO-3D-CLINICO` |
| Imágenes, capturas, videos, comprimidos y otros archivos | Excluido | `EXC-DERIVADO-CASO` |
| PDF y documentos (pueden ser informes de planificación) | Cuarentena | `CUA-DOCUMENTO-EN-CASO` |

### 2.5 Datos de pacientes

Carpetas de pacientes, protocolos operatorios, epicrisis, fichas clínicas y archivos con nombres, RUT, fechas de nacimiento o números de ficha (`EXC-DATOS-PACIENTE`). Excluidos sin liberación posible. Las imágenes clínicas con consentimiento y anonimización siguen su propio flujo ([privacidad-y-cumplimiento.md](privacidad-y-cumplimiento.md), sección 3), nunca la importación masiva.

### 2.6 Presentaciones

Por decisión del administrador (26-11-2026), las **presentaciones no se importan** (`EXC-PRESENTACION`): PowerPoint (`.ppt`, `.pptx`, `.pps`, `.ppsx`, `.pot`, `.potx`), Keynote (`.key`), OpenDocument (`.odp`) y Presentaciones de Google. Suelen contener fotografías de pacientes, datos clínicos, capturas de software y material protegido. Un administrador puede liberar una presentación concreta después de revisarla de forma individual.

### 2.7 Duplicados

De cada documento se importa **una sola copia**. Las demás quedan registradas como `EXC-DUPLICADO`, con referencia a la copia conservada. Criterios: mismo SHA-256 del contenido, mismo DOI o mismo PMID. Se conserva la copia de la carpeta temática más específica; a igualdad, la de mayor tamaño. La base de datos además rechaza dos archivos con el mismo SHA-256.

### 2.8 Archivos de sistema

`.DS_Store`, `Thumbs.db`, `desktop.ini`, accesos directos (`.lnk`, accesos directos de Drive) (`EXC-SISTEMA`).

## 3. Qué se permite

- **Libros completos y capítulos de libro** (PDF, EPUB): se leen e importan con el flujo normal de derechos de autor. El material protegido queda restringido o como "solo metadatos" según su licencia.
- Artículos científicos, guías, apuntes y documentos propios.
- **Modelos STL y OBJ académicos.** No se excluyen por su formato: un modelo fuera de un caso clínico queda en cuarentena hasta que una persona acredite su procedencia académica (`CUA-MODELO-3D-SIN-PROCEDENCIA`, o `CUA-MODELO-3D-PLANIFICACION` si su nombre sugiere una planificación). Los que estén en una carpeta declarada como de modelos educativos pasan a revisión individual (`REV-MODELO-3D-EDUCATIVO`).

## 4. Cuarentena: cuándo hay incertidumbre

| Situación | Regla |
| --- | --- |
| Documento dentro de un caso clínico | `CUA-DOCUMENTO-EN-CASO` |
| Material en una carpeta de un programa de planificación, sin un caso identificado (clases, capturas, videos) | `CUA-CARPETA-SOFTWARE` |
| Modelo 3D sin procedencia o con nombre de planificación | `CUA-MODELO-3D-*` |
| Comprimido (ZIP, RAR, 7z…): su contenido no se inspecciona sin autorización | `CUA-COMPRIMIDO` |
| Fotografía con nombre de cámara o teléfono (IMG_1234, DSC_1234, fecha y hora) | `CUA-IMAGEN-CLINICA-POSIBLE` |
| Formato no reconocido | `CUA-FORMATO-DESCONOCIDO` |

## 5. Reglas obligatorias del importador de Google Drive

1. **Solo lectura.** El importador nunca renombra, mueve, copia dentro de Drive, comparte, cambia permisos ni elimina archivos de Drive.
2. **Evaluar antes de copiar.** Cada archivo se clasifica con el clasificador de referencia y queda registrado en `source_items` antes de cualquier descarga.
3. **Sin descargas para decidir.** La decisión se toma con metadatos: nombre, tipo MIME, ruta, carpeta y archivos vecinos. Solo para un archivo sin extensión o de tipo `application/octet-stream` que no quedó excluido puede leer **como máximo 132 bytes** para detectar la firma DICOM.
4. **Contexto completo.** Primero se recorre la carpeta entera y se identifican los casos clínicos y las carpetas de programas; recién después se clasifica cada archivo.
5. **Solo se copia lo permitido.** Únicamente un elemento `allowed` puede convertirse en archivo; la base lo exige.
6. **Excluidos sin identificador.** De un elemento excluido no se conserva el ID de Drive: se reconoce en importaciones futuras por su huella, el SHA-256 de `fuente:identificador`.
7. **Nombres depurados.** Nombres y rutas de pacientes, de casos clínicos y de personas dentro de carpetas de programas se registran como `[carpeta de paciente]`, `[carpeta de caso clínico]`, `[archivo clínico]` o `[nombre redactado]`.
8. **No seguir accesos directos ni abrir comprimidos.**
9. **Respetar las revisiones humanas.** Una reevaluación no deshace una liberación humana salvo que cambie la versión de la política o el archivo (fecha de modificación o tamaño). Una reevaluación siempre puede endurecer una decisión, nunca liberarla.
10. **Duplicados.** Aplicar `mark_duplicates()` con DOI y PMID del inventario; al copiar, la base rechaza un SHA-256 repetido.
11. **Reclasificación.** Si un elemento ya importado deja de estar permitido, la base bloquea su archivo, borra extracciones, fragmentos, traducciones y resúmenes, cancela sus trabajos y ordena purgar el original del almacenamiento.
12. **Versión registrada.** Cada decisión guarda la versión de la política con que se tomó.

La **carga directa** de archivos (fase 2) y los **aportes de la comunidad** (fase 6) pasan por la misma evaluación; además, la base rechaza las extensiones y tipos MIME excluidos en cualquier ingreso.

## 6. Revisión humana y liberación

| Desde | Puede liberar | Requisito |
| --- | --- | --- |
| Revisión individual | Editor o administrador | Revisor, fecha y fundamento registrados |
| Cuarentena | Administrador | Revisor, fecha y fundamento registrados |
| Excluido liberable (`EXC-PRESENTACION`, `EXC-DUPLICADO`, `EXC-DERIVADO-CASO`, `EXC-MODELO-3D-CLINICO`) | Administrador | Autorización expresa registrada |
| Excluido permanente (DICOM, proyectos nativos, datos de pacientes, auxiliares, sistema) | **Nadie** | — |

Nadie puede cambiar a mano las reglas de un elemento: solo una reevaluación del importador. Así una exclusión no puede "suavizarse" antes de liberarla. Toda decisión queda en la auditoría sin el identificador de Drive.

## 7. Garantías en la base de datos

Migración 0800, verificada por la prueba 09:

- Tablas `exclusion_rules`, `blocked_extensions`, `blocked_mime_types` y `source_items` (inventario de importación y exclusión), con RLS: el inventario lo ve el administrador; los editores solo lo que deben revisar o revisaron.
- `files` rechaza extensiones y tipos MIME excluidos y archivos de elementos no permitidos.
- Un archivo bloqueado queda en "solo metadatos", sin IA, despublicado y visible solo para el administrador.
- No se aceptan trabajos de procesamiento sobre archivos bloqueados, salvo la purga.

## 8. Aplicación al inventario actual

Inventario de Drive del 25-11-2026, reclasificado con la versión 1.1.0 (`Inventario_CMF_Academy.xlsx`, hoja «Inventario de exclusión», e `Inventario_Exclusion_CMF_Academy.csv`, entregados al administrador fuera del repositorio):

| Decisión | Archivos | Detalle |
| --- | --- | --- |
| Permitido | 1.782 | Pasan al flujo de derechos de autor |
| Excluido | 465 | 282 datos de pacientes, 100 DICOM, 71 presentaciones, 50 de sistema, 38 copias sobrantes por DOI o PMID, 14 auxiliares de software, 7 modelos 3D clínicos, 1 proyecto de ProPlan, 1 de Mimics, 1 exportación de caso |
| Cuarentena | 319 | 182 posibles fotografías clínicas, 103 en carpetas de ProPlan, 33 formatos desconocidos, 1 comprimido |

Además, 13 ramas de carpetas no se recorrieron: 3 de pacientes (excluidas), 1 de configuración de ProPlan (cuarentena) y 9 fuera de alcance (cursos de pregrado, documentos personales y audios). Los duplicados por nombre y tamaño sin DOI ni PMID se resolverán con el SHA-256 al importar.

## 9. Cambios a esta política

La política se modifica solo mediante un pull request revisado por el administrador que actualice, en el mismo cambio, `config/politica-exclusion.json` (con nueva versión), la migración o una migración nueva, las pruebas y este documento. Las pruebas verifican que las reglas de la base coinciden con las del archivo de configuración.

| Versión | Fecha | Cambios |
| --- | --- | --- |
| 1.0.0 | 25-11-2026 | DICOM; ProPlan CMF, Mimics, 3-matic e IPS CaseDesigner; casos clínicos; modelos 3D; cuarentena; presentaciones con revisión individual |
| 1.1.0 | 26-11-2026 | Presentaciones excluidas de la importación; libros y capítulos permitidos expresamente; una sola copia por documento |
