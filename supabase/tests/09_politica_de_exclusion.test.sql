-- Prueba 09 · Política de exclusión documental (ADR-0016, migración 0800).
begin;

do $$
declare
  v_admin   uuid := tests.create_user('admin.exclusion@example.test', 'admin');
  v_editor  uuid := tests.create_user('editor.exclusion@example.test', 'editor');
  v_member  uuid := tests.create_user('miembro.exclusion@example.test');
  v_ok      uuid;
  v_quar    uuid;
  v_dicom   uuid;
  v_model   uuid;
  v_pres    uuid;
  v_file    uuid;
  v_ext     uuid;
  v_job     uuid;
  v_count   integer;
  v_fp      text;
begin
  -- 1. Las extensiones y tipos excluidos se rechazan en cualquier ingreso.
  perform tests.assert_raises($sql$
    insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path, original_filename)
    values ('other', 'application/octet-stream', 10, repeat('1', 64), 'originals', 'x1', 'Avance maxilar.SPPC')
  $sql$, 'un proyecto de ProPlan (.sppc, sin importar mayúsculas) se rechaza', '23514');
  perform tests.assert_raises($sql$
    insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path, original_filename)
    values ('other', 'application/octet-stream', 10, repeat('2', 64), 'originals', 'x2', 'Segmentacion.mcs')
  $sql$, 'un proyecto de Mimics (.mcs) se rechaza', '23514');
  perform tests.assert_raises($sql$
    insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path, original_filename)
    values ('image', 'application/dicom', 10, repeat('3', 64), 'originals', 'x3', 'IM0001')
  $sql$, 'un DICOM sin extensión se rechaza por su tipo MIME', '23514');
  perform tests.assert_raises($sql$
    insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path, original_filename)
    values ('other', 'application/octet-stream', 10, repeat('4', 64), 'originals', 'x4', 'DICOMDIR')
  $sql$, 'un índice DICOMDIR se rechaza', '23514');

  -- 2. Inventario: coherencia de decisiones y reglas.
  v_fp := encode(sha256('google_drive:abc'::bytea), 'hex');
  perform tests.assert_raises(format($sql$
    insert into public.source_items (source, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
    values ('google_drive', %L, 'x', 'allowed', '{EXC-DICOM}', 'x', '1.0.0')
  $sql$, v_fp), 'la decisión debe ser la más restrictiva de sus reglas', '23514');
  perform tests.assert_raises(format($sql$
    insert into public.source_items (source, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
    values ('google_drive', %L, 'x', 'excluded', '{EXC-NO-EXISTE}', 'x', '1.0.0')
  $sql$, v_fp), 'una regla desconocida se rechaza', '23514');
  perform tests.assert_raises(format($sql$
    insert into public.source_items (source, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
    values ('google_drive', %L, 'x', 'quarantined', '{}', 'x', '1.0.0')
  $sql$, v_fp), 'un elemento no permitido exige reglas', '23514');

  insert into public.source_items (source, source_ref, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
  values ('google_drive', 'drive-dicom', encode(sha256('google_drive:drive-dicom'::bytea), 'hex'), 'IM0001',
          'excluded', '{EXC-DICOM}', 'extensión .dcm', '1.0.0')
  returning id into v_dicom;
  perform tests.assert((select source_ref is null from public.source_items where id = v_dicom),
    'un elemento excluido no conserva el identificador de Drive');

  insert into public.source_items (source, source_ref, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
  values ('google_drive', 'drive-ok', encode(sha256('google_drive:drive-ok'::bytea), 'hex'), 'articulo.pdf',
          'allowed', '{}', 'sin reglas aplicables', '1.0.0') returning id into v_ok;
  insert into public.source_items (source, source_ref, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
  values ('google_drive', 'drive-quar', encode(sha256('google_drive:drive-quar'::bytea), 'hex'), 'informe.pdf',
          'quarantined', '{CUA-DOCUMENTO-EN-CASO}', 'documento en caso clínico', '1.0.0') returning id into v_quar;
  insert into public.source_items (source, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
  values ('google_drive', encode(sha256('google_drive:drive-stl'::bytea), 'hex'), 'Maxilar.stl',
          'excluded', '{EXC-MODELO-3D-CLINICO}', 'modelo 3D en caso clínico', '1.0.0') returning id into v_model;
  insert into public.source_items (source, source_ref, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
  values ('google_drive', 'drive-edu', encode(sha256('google_drive:drive-edu'::bytea), 'hex'), 'Craneo.stl',
          'review_required', '{REV-MODELO-3D-EDUCATIVO}', 'modelo 3D en carpeta educativa', '1.0.0') returning id into v_pres;

  -- Presentaciones y duplicados.
  insert into public.source_items (source, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
  values ('google_drive', encode(sha256('google_drive:drive-ppt'::bytea), 'hex'), 'Clase.pptx',
          'excluded', '{EXC-PRESENTACION}', 'presentación: no se importa', '1.1.0');
  perform tests.assert_raises(format($sql$
    insert into public.source_items (source, source_fingerprint, display_name, decision, rule_codes, reason, policy_version)
    values ('google_drive', %L, 'copia.pdf', 'excluded', '{EXC-DUPLICADO}', 'copia', '1.1.0')
  $sql$, encode(sha256('google_drive:dup-sin-original'::bytea), 'hex')),
    'un duplicado debe indicar la copia conservada', '23514');
  insert into public.source_items (source, source_fingerprint, display_name, decision, rule_codes, reason,
                                   policy_version, duplicate_of)
  values ('google_drive', encode(sha256('google_drive:drive-dup'::bytea), 'hex'), 'copia.pdf',
          'excluded', '{EXC-DUPLICADO}', 'copia sobrante', '1.1.0', v_quar);

  -- 3. Solo un elemento permitido puede tener un archivo.
  perform tests.assert_raises(format($sql$
    insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path, original_filename, source_item_id)
    values ('pdf', 'application/pdf', 10, repeat('5', 64), 'originals', 'q.pdf', 'informe.pdf', %L)
  $sql$, v_quar), 'un elemento en cuarentena no puede copiarse', '23514');

  insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path, original_filename,
                            source_item_id, distribution, rights_basis, rights_verified_by, rights_verified_at,
                            ai_processing_allowed, status)
  values ('pdf', 'application/pdf', 10, repeat('6', 64), 'originals', 'ok.pdf', 'articulo.pdf', v_ok, 'public',
          'Licencia CC BY 4.0', v_editor, now(), true, 'published')
  returning id into v_file;
  insert into public.extractions (file_id, extractor, extractor_version, content_md)
  values (v_file, 'docling', '1', 'texto') returning id into v_ext;
  insert into public.chunks (file_id, extraction_id, chunk_index, content) values (v_file, v_ext, 0, 'fragmento');
  insert into public.processing_jobs (job_type, file_id) values ('index', v_file) returning id into v_job;

  -- 4. Reevaluación (importador): el elemento pasa a cuarentena y el archivo se bloquea.
  perform tests.authenticate_service();
  update public.source_items
     set decision = 'quarantined', rule_codes = '{CUA-IMAGEN-CLINICA-POSIBLE}', reason = 'reevaluado'
   where id = v_ok;
  perform tests.clear_authentication();

  perform tests.assert((select policy_blocked and distribution = 'metadata_only' and not ai_processing_allowed
                               and status = 'archived' from public.files where id = v_file),
    'el archivo queda bloqueado, cerrado, sin IA y despublicado');
  select count(*) into v_count from public.chunks where file_id = v_file;
  perform tests.assert_eq(v_count, 0, 'sus fragmentos se eliminan del RAG');
  select count(*) into v_count from public.extractions where file_id = v_file;
  perform tests.assert_eq(v_count, 0, 'su texto extraído se elimina');
  perform tests.assert_eq((select status from public.processing_jobs where id = v_job),
    'cancelled'::public.job_status, 'sus trabajos pendientes se cancelan');
  select count(*) into v_count from public.processing_jobs where file_id = v_file and job_type = 'purge_original';
  perform tests.assert_eq(v_count, 1, 'se encola la purga del original en Storage');
  perform tests.assert_raises(format($sql$ insert into public.processing_jobs (job_type, file_id) values ('extract', %L) $sql$, v_file),
    'no se aceptan trabajos nuevos sobre un archivo bloqueado', '23514');
  perform tests.assert_raises(format($sql$ update public.files set distribution = 'public' where id = %L $sql$, v_file),
    'un archivo bloqueado no puede hacerse público', '23514');
  perform tests.assert_raises(format($sql$ update public.files set policy_blocked = false where id = %L $sql$, v_file),
    'un archivo no se desbloquea mientras su elemento no esté permitido', '23514');

  -- 5. Visibilidad: solo el administrador ve el archivo bloqueado y el inventario.
  perform tests.authenticate_as(v_editor);
  select count(*) into v_count from public.files where id = v_file;
  perform tests.assert_eq(v_count, 0, 'un editor no ve un archivo bloqueado');
  select count(*) into v_count from public.source_items;
  perform tests.assert_eq(v_count, 1, 'un editor solo ve lo que requiere revisión individual');
  perform tests.clear_authentication();
  perform tests.authenticate_anon();
  select count(*) into v_count from public.files where id = v_file;
  perform tests.assert_eq(v_count, 0, 'un visitante no ve un archivo bloqueado');
  perform tests.clear_authentication();
  perform tests.authenticate_as(v_admin);
  select count(*) into v_count from public.files where id = v_file;
  perform tests.assert_eq(v_count, 1, 'el administrador ve el archivo bloqueado');
  select count(*) into v_count from public.source_items;
  perform tests.assert_eq(v_count, 7, 'el administrador ve todo el inventario');
  perform tests.clear_authentication();

  -- 6. Liberaciones: siempre con revisión humana registrada.
  perform tests.authenticate_service();
  perform tests.assert_raises(format($sql$ update public.source_items set decision = 'allowed' where id = %L $sql$, v_quar),
    'el importador no puede liberar un elemento en cuarentena', '42501');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_editor);
  update public.source_items
     set decision = 'allowed', reviewed_by = v_editor, reviewed_at = now(),
         review_notes = 'Modelo anatómico de un repositorio con licencia CC BY, sin datos de pacientes'
   where id = v_pres;
  perform tests.clear_authentication();
  perform tests.assert_eq((select decision from public.source_items where id = v_pres),
    'allowed'::public.import_decision, 'un editor aprueba un modelo educativo revisado');

  perform tests.authenticate_as(v_admin);
  perform tests.assert_raises(format($sql$
    update public.source_items set decision = 'allowed', reviewed_by = %L, reviewed_at = now() where id = %L
  $sql$, v_admin, v_quar), 'liberar exige el fundamento de la revisión', '42501');
  perform tests.assert_raises(format($sql$
    update public.source_items set decision = 'allowed', reviewed_by = %L, reviewed_at = now(),
           review_notes = 'Autorizado' where id = %L
  $sql$, v_admin, v_dicom), 'una exclusión permanente (DICOM) no se libera ni con un administrador', '42501');
  perform tests.assert_raises(format($sql$
    update public.source_items set rule_codes = '{EXC-DERIVADO-CASO}' where id = %L
  $sql$, v_dicom), 'una persona no puede cambiar las reglas de un elemento', '42501');
  update public.source_items
     set decision = 'allowed', reviewed_by = v_admin, reviewed_at = now(),
         review_notes = 'Modelo anonimizado con autorización expresa del paciente para docencia'
   where id = v_model;
  perform tests.clear_authentication();
  perform tests.assert_eq((select decision from public.source_items where id = v_model),
    'allowed'::public.import_decision, 'el administrador libera un modelo 3D clínico con autorización expresa');

  -- 7. La auditoría no guarda identificadores de Drive.
  select count(*) into v_count from public.audit_log
   where entity_type = 'source_items' and details::text like '%drive-%';
  perform tests.assert_eq(v_count, 0, 'la auditoría del inventario no registra identificadores de origen');
end;
$$;

rollback;
