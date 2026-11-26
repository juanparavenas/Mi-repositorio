-- Prueba 08 · Imágenes clínicas: datos de pacientes, consentimiento y
-- anonimización antes de publicar (ADR-0012).
begin;

do $$
declare
  v_editor  uuid := tests.create_user('editor.multimedia@example.test', 'editor');
  v_file    uuid;
  v_media   uuid;
begin
  insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path,
                            original_filename, distribution, rights_basis, rights_verified_by,
                            rights_verified_at, status)
  values ('image', 'image/webp', 5000, repeat('d', 64), 'media', 'caso-1.webp', 'caso-1.webp', 'public',
          'Imagen aportada por su autor con consentimiento del paciente', v_editor, now(), 'published')
  returning id into v_file;

  perform tests.assert_raises(format($sql$
    insert into public.media_assets (file_id, media_type, title, contains_patient_data, consent)
    values (%L, 'clinical_photo', 'Foto', false, 'not_required')
  $sql$, v_file), 'una fotografía clínica siempre cuenta como dato de paciente', '23514');

  perform tests.assert_raises(format($sql$
    insert into public.media_assets (file_id, media_type, title, contains_patient_data, consent)
    values (%L, 'clinical_photo', 'Foto', true, 'not_required')
  $sql$, v_file), 'con datos de paciente hay que decidir sobre el consentimiento', '23514');

  insert into public.media_assets (file_id, media_type, title, contains_patient_data, consent)
  values (v_file, 'clinical_photo', 'Vista intraoral preoperatoria', true, 'pending')
  returning id into v_media;

  perform tests.assert_raises(format($sql$
    update public.media_assets set status = 'published' where id = %L
  $sql$, v_media), 'no se publica sin consentimiento', '23514');

  update public.media_assets set consent = 'obtained', consent_reference = 'CONS-2026-001' where id = v_media;
  perform tests.assert_raises(format($sql$
    update public.media_assets set status = 'published' where id = %L
  $sql$, v_media), 'no se publica sin anonimización verificada', '23514');

  -- El visitante no ve la imagen mientras no esté publicada.
  perform tests.authenticate_anon();
  perform tests.assert_eq((select count(*)::integer from public.media_assets), 0,
    'el visitante no ve imágenes clínicas en revisión');
  perform tests.clear_authentication();

  update public.media_assets
     set deidentified_by = v_editor, deidentified_at = now(), status = 'published'
   where id = v_media;

  perform tests.authenticate_anon();
  perform tests.assert_eq((select count(*)::integer from public.media_assets), 1,
    'la imagen anonimizada y con consentimiento es visible');
  perform tests.clear_authentication();

  -- Los esquemas propios no requieren consentimiento.
  insert into public.files (kind, mime_type, size_bytes, sha256, storage_bucket, storage_path,
                            original_filename, distribution, rights_basis, rights_verified_by,
                            rights_verified_at, status)
  values ('image', 'image/svg+xml', 800, repeat('e', 64), 'media', 'esquema.svg', 'esquema.svg', 'public',
          'Contenido original de CMF Academy', v_editor, now(), 'published')
  returning id into v_file;
  insert into public.media_assets (file_id, media_type, title, contains_patient_data, consent, status)
  values (v_file, 'schematic', 'Esquema de la discopexia', false, 'not_required', 'published');
end;
$$;

rollback;
