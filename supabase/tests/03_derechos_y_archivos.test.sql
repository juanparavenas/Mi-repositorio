-- Prueba 03 · Estados de distribución, permiso de IA y aislamiento de contenido
-- restringido (decisión 1 de la fase 0, ADR-0006).
begin;

do $$
declare
  v_editor   uuid := tests.create_user('editor.derechos@example.test', 'editor');
  v_member   uuid := tests.create_user('miembro.derechos@example.test');
  v_invited  uuid := tests.create_user('invitado.derechos@example.test');
  v_work     uuid;
  v_public   uuid;
  v_restr    uuid;
  v_meta     uuid;
  v_ext_pub  uuid;
  v_ext_res  uuid;
  v_trans    uuid;
  v_vec      text := '[' || array_to_string(array_fill(0.01::real, array[1024]), ',') || ']';
  v_count    integer;
begin
  insert into public.works (title, source, status, metadata_status)
  values ('Estudio de prueba sobre discopexia', 'manual', 'published', 'verified')
  returning id into v_work;

  -- Público exige derechos verificados por un editor.
  perform tests.assert_raises(format($sql$
    insert into public.files (work_id, kind, mime_type, size_bytes, sha256, storage_bucket, storage_path,
                              original_filename, distribution, status)
    values (%L, 'pdf', 'application/pdf', 1000, repeat('a', 64), 'originals', 'a.pdf', 'a.pdf', 'public', 'published')
  $sql$, v_work), 'un archivo público sin derechos verificados se rechaza', '23514');

  perform tests.assert_raises(format($sql$
    insert into public.files (work_id, kind, mime_type, size_bytes, sha256, storage_bucket, storage_path,
                              original_filename, distribution, rights_basis, rights_verified_by, rights_verified_at, status)
    values (%L, 'pdf', 'application/pdf', 1000, repeat('a', 64), 'originals', 'a.pdf', 'a.pdf', 'public',
            'Licencia CC BY 4.0', %L, now(), 'published')
  $sql$, v_work, v_member), 'un miembro no puede verificar derechos', '23514');

  insert into public.files (work_id, kind, mime_type, size_bytes, sha256, storage_bucket, storage_path,
                            original_filename, distribution, license, rights_basis, rights_verified_by,
                            rights_verified_at, ai_processing_allowed, status)
  values (v_work, 'pdf', 'application/pdf', 1000, repeat('a', 64), 'originals', 'a.pdf', 'a.pdf', 'public',
          'CC-BY-4.0', 'Licencia CC BY 4.0 verificada en PMC', v_editor, now(), true, 'published')
  returning id into v_public;

  insert into public.files (work_id, kind, mime_type, size_bytes, sha256, storage_bucket, storage_path,
                            original_filename, distribution, allowed_roles, rights_basis, rights_verified_by,
                            rights_verified_at, ai_processing_allowed, status)
  values (v_work, 'pdf', 'application/pdf', 2000, repeat('b', 64), 'originals', 'b.pdf', 'b.pdf', 'restricted',
          '{editor}', 'Autorización escrita del autor para uso interno', v_editor, now(), true, 'published')
  returning id into v_restr;

  -- Por defecto, todo archivo es "solo metadatos" y sin permiso de IA.
  insert into public.files (work_id, kind, mime_type, size_bytes, sha256, storage_bucket, storage_path,
                            original_filename, status)
  values (v_work, 'pdf', 'application/pdf', 3000, repeat('c', 64), 'originals', 'c.pdf', 'c.pdf', 'published')
  returning id into v_meta;
  perform tests.assert_eq((select distribution from public.files where id = v_meta),
    'metadata_only'::public.distribution_status, 'el estado por defecto es solo metadatos');

  insert into public.file_access_grants (file_id, user_id, granted_by) values (v_restr, v_invited, v_editor);

  -- Visibilidad de archivos.
  perform tests.authenticate_anon();
  select count(*) into v_count from public.files;
  perform tests.assert_eq(v_count, 1, 'el visitante solo ve el archivo público');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_member);
  select count(*) into v_count from public.files;
  perform tests.assert_eq(v_count, 1, 'un miembro sin permiso no ve el restringido');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_invited);
  select count(*) into v_count from public.files;
  perform tests.assert_eq(v_count, 2, 'el usuario con acceso concedido ve el restringido');
  perform tests.assert((select not exists (select 1 from public.files where id = v_meta)),
    'nadie fuera de los editores ve un archivo de solo metadatos');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_editor);
  select count(*) into v_count from public.files;
  perform tests.assert_eq(v_count, 3, 'el editor ve todos los archivos');
  perform tests.clear_authentication();

  -- Fragmentos: solo se indexa con permiso de IA, y heredan la visibilidad.
  insert into public.extractions (file_id, extractor, extractor_version) values (v_public, 'docling', '2')
  returning id into v_ext_pub;
  insert into public.extractions (file_id, extractor, extractor_version) values (v_restr, 'docling', '2')
  returning id into v_ext_res;

  insert into public.chunks (file_id, extraction_id, chunk_index, content, embedding, embedding_model)
  values (v_public, v_ext_pub, 0, 'Texto público sobre discopexia', v_vec::extensions.vector, 'modelo-prueba'),
         (v_restr, v_ext_res, 0, 'Texto RESTRINGIDO sobre discopexia', v_vec::extensions.vector, 'modelo-prueba');

  perform tests.assert_raises(format($sql$
    insert into public.extractions (file_id, extractor, extractor_version) values (%1$L, 'docling', '2');
    insert into public.chunks (file_id, extraction_id, chunk_index, content)
    select %1$L, id, 0, 'no debería indexarse' from public.extractions where file_id = %1$L;
  $sql$, v_meta), 'no se indexa un archivo sin permiso de IA', '23514');

  -- Una búsqueda semántica hecha por un visitante nunca devuelve texto restringido.
  perform tests.authenticate_anon();
  perform tests.assert_eq(
    (select count(*)::integer from (
       select c.id from public.chunks c
        order by c.embedding operator(extensions.<=>) v_vec::extensions.vector
        limit 10) s),
    1, 'la búsqueda del visitante solo recupera fragmentos públicos');
  perform tests.assert((select not exists (select 1 from public.chunks where content like '%RESTRINGIDO%')),
    'el texto restringido es invisible para el visitante');
  perform tests.clear_authentication();

  -- Un derivado no puede ser más abierto que su origen.
  perform tests.assert_raises(format($sql$
    insert into public.translations (file_id, status, distribution) values (%L, 'draft', 'public')
  $sql$, v_restr), 'la traducción de un restringido no puede ser pública', '23514');

  perform tests.assert_raises(format($sql$
    insert into public.translations (file_id, status) values (%L, 'draft')
  $sql$, v_meta), 'no se traduce un archivo sin permiso de IA', '23514');

  insert into public.translations (file_id, status, distribution, content_md, model)
  values (v_public, 'draft', 'public', '# Traducción', 'modelo-prueba')
  returning id into v_trans;

  -- Si el archivo se vuelve más restrictivo, la traducción lo sigue.
  update public.files set distribution = 'restricted' where id = v_public;
  perform tests.assert_eq((select distribution from public.translations where id = v_trans),
    'restricted'::public.distribution_status, 'la traducción hereda la restricción');

  -- Si se revoca el permiso de IA, se borran los fragmentos y se archivan los derivados.
  update public.files set ai_processing_allowed = false where id = v_public;
  perform tests.assert_eq((select count(*)::integer from public.chunks where file_id = v_public), 0,
    'se eliminan los fragmentos al revocar el permiso');
  perform tests.assert_eq((select status from public.translations where id = v_trans),
    'archived'::public.derivative_status, 'la traducción queda archivada');

  -- Los cambios de distribución quedan auditados.
  perform tests.assert(exists (
    select 1 from public.audit_log where entity_type = 'files' and entity_id = v_public::text and action = 'update'
  ), 'el cambio de distribución queda en la auditoría');
end;
$$;

rollback;
