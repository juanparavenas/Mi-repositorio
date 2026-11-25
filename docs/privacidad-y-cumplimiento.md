# Privacidad, datos sensibles y cumplimiento

CMF Academy se diseña con **privacidad por diseño y por defecto** desde la fase 0. Este documento resume el marco normativo considerado, qué datos se tratan, cómo se protegen y qué debe verificarse antes del lanzamiento público. **No es asesoría legal:** antes de lanzar, la normativa aplicable debe verificarse con un abogado o con la oficina jurídica de la institución.

## 1. Marco normativo considerado (Chile)

| Norma | Relevancia para CMF Academy | Estado considerado |
| --- | --- | --- |
| **Ley 19.628** sobre protección de la vida privada | Régimen de datos personales vigente mientras no entre en vigor la Ley 21.719 | Vigente |
| **Ley 21.719** que regula la protección y el tratamiento de los datos personales y crea la Agencia de Protección de Datos Personales | Nuevo estándar: bases de licitud, datos sensibles (incluidos los de salud), derechos de los titulares, seguridad, notificación de brechas y sanciones | Publicada el 13 de diciembre de 2024. **Su entrada en vigencia fue modificada al 15 de octubre de 2027 por la Ley 21.855, publicada el 23 de noviembre de 2026** |
| **Ley 20.584** sobre derechos y deberes de los pacientes | Confidencialidad de la ficha clínica y de la información de salud identificable | Vigente |
| **Ley 17.336** sobre propiedad intelectual | Reproducción, traducción y distribución de obras de terceros | Vigente |

Sobre la Ley 21.855: la fecha del 15 de octubre de 2027 coincide con la postergación aprobada por la comisión de la Cámara en noviembre de 2026 ([Cámara de Diputadas y Diputados](https://www.camara.cl/cms/2026/11/05/proteccion-de-datos-comision-aprobo-postergar-entrada-en-vigencia-de-la-ley/)). La ley se publicó después de lo que indexan los buscadores consultados, por lo que su texto oficial **debe confirmarse en la Biblioteca del Congreso Nacional (bcn.cl) o en el Diario Oficial antes del lanzamiento**. La plataforma se diseña para cumplir el estándar de la Ley 21.719 desde ahora, independientemente de su fecha de vigencia.

Si la plataforma recibe usuarios de la Unión Europea, deberá evaluarse además el RGPD (proyección internacional).

## 2. Datos que trata la plataforma

| Dato | Titular | Finalidad | Base de licitud prevista | Medidas |
| --- | --- | --- | --- | --- |
| Correo y nombre de la cuenta | Usuario registrado | Autenticación y atribución de aportes | Consentimiento al registrarse; ejecución de los términos de uso | Perfil con lo mínimo; el correo nunca se muestra |
| Perfil público (institución, especialidad, biografía, ORCID) | Usuario registrado | Comunidad académica | Consentimiento (campos opcionales) | Editable y eliminable por el usuario |
| Identificador de visitante | Visitante | Cuota diaria de IA y prevención de abuso | Interés legítimo de seguridad | Hash HMAC rotativo; la IP no se almacena |
| Conversaciones con el asistente | Usuario registrado | Historial propio | Consentimiento | Privadas (RLS); eliminables; no se usan para entrenar modelos |
| Imágenes clínicas, radiografías, CBCT | **Pacientes** (dato sensible de salud) | Docencia | Consentimiento del paciente gestionado por quien aporta | Ver sección 3 |
| Solicitudes por derechos de autor | Solicitante | Gestión de reclamos | Obligación legal e interés legítimo | Solo editores; retención limitada |

## 3. Imágenes clínicas y datos de pacientes

Reglas aplicadas en la base de datos ([ADR-0012](adr/0012-privacidad-por-diseno-e-imagenes-clinicas.md); prueba 08):

1. Toda fotografía clínica, radiografía o CBCT se considera **dato de paciente**, sin excepción.
2. No se publica sin **consentimiento obtenido** y **anonimización verificada por un editor**.
3. El documento de consentimiento **no se sube a la plataforma**: quien aporta lo conserva y registra solo una referencia interna.
4. Al subir una imagen: eliminación de metadatos EXIF, alerta automática si se detectan rostros o texto (nombres, RUT, fechas) y checklist obligatorio para quien aporta y para el editor.
5. No se aceptan nombres, RUT, fechas de nacimiento, números de ficha ni ningún identificador directo en títulos, leyendas o archivos.
6. Los estudios DICOM (fase 7) se anonimizan en sus encabezados antes de almacenarse.
7. Las imágenes clínicas nunca se envían a servicios de IA sin anonimización previa.

## 4. Inteligencia artificial y privacidad

- El asistente público no recibe datos personales del visitante.
- Los usuarios no deben ingresar datos de pacientes en el asistente; la interfaz lo advierte y el asistente es educativo, no de apoyo a decisiones clínicas.
- Por política del proveedor, los datos enviados por la API comercial de Anthropic no se usan para entrenar modelos. Esto se confirmará en los términos vigentes al activar el servicio.

## 5. Derechos de autor

Ver [ADR-0006](adr/0006-obra-archivo-derivados-y-distribucion.md). En resumen: tres estados de distribución, derechos verificados por un editor para publicar, procesamiento por IA solo con base legítima, derivados nunca más abiertos que su original, atribución y enlace a la fuente siempre visibles, y formulario de retiro con respuesta registrada.

## 6. Lista de verificación antes del lanzamiento público

- [ ] Confirmar el texto oficial de la Ley 21.855 y la fecha de vigencia de la Ley 21.719.
- [ ] Revisión legal de términos de uso, política de privacidad y política de derechos de autor.
- [ ] Definir el responsable del tratamiento de datos y un canal de contacto para los titulares.
- [ ] Registro de actividades de tratamiento con finalidad, base de licitud y plazos de retención.
- [ ] Procedimiento de respuesta a brechas de seguridad (detección, contención, notificación).
- [ ] Modelo de consentimiento para imágenes clínicas validado institucionalmente.
- [ ] Verificar que ninguna imagen publicada contenga datos identificables.
- [ ] Revisar las licencias de todo documento con estado "público".
- [ ] Confirmar las condiciones de privacidad de cada proveedor activado (Supabase, Vercel, Anthropic, Sentry).
- [ ] Prueba de eliminación de cuenta y de exportación de datos propios.
