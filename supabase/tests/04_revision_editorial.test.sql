-- Prueba 04 · Lo redactado por IA queda en borrador hasta que un editor lo
-- aprueba (decisión 3 de la fase 0, ADR-0008).
begin;

do $$
declare
  v_editor   uuid := tests.create_user('editor.revision@example.test', 'editor');
  v_member   uuid := tests.create_user('miembro.revision@example.test');
  v_root     uuid;
  v_section  uuid;
  v_version  uuid;
  v_work     uuid;
  v_summary  uuid;
  v_count    integer;
begin
  select id into v_root from public.topics where parent_id is null and slug = 'cirugia-oral-y-maxilofacial';
  update public.topics set status = 'published' where id = v_root;

  insert into public.topic_sections (topic_id, section_key, title)
  values (v_root, 'introduction', 'Introducción y resumen general')
  returning id into v_section;

  perform tests.assert_raises(format($sql$
    insert into public.topic_section_versions (section_id, version, body_md, origin)
    values (%L, 1, 'Texto', 'ai')
  $sql$, v_section), 'un texto de IA debe registrar el modelo que lo generó', '23514');

  insert into public.topic_section_versions (section_id, version, body_md, origin, ai_model)
  values (v_section, 1, 'Borrador generado por IA con citas.', 'ai', 'claude-sonnet-5-5')
  returning id into v_version;

  perform tests.assert_raises(format($sql$
    update public.topic_section_versions set status = 'published' where id = %L
  $sql$, v_version), 'no se publica sin revisión', '23514');

  perform tests.assert_raises(format($sql$
    update public.topic_section_versions set status = 'published', reviewed_by = %L, reviewed_at = now() where id = %L
  $sql$, v_member, v_version), 'un miembro no puede aprobar contenido', '23514');

  -- El visitante no ve borradores.
  perform tests.authenticate_anon();
  select count(*) into v_count from public.topic_sections_published;
  perform tests.assert_eq(v_count, 0, 'sin versión publicada, el visitante no ve la sección');
  select count(*) into v_count from public.topic_section_versions;
  perform tests.assert_eq(v_count, 0, 'el visitante no ve versiones en borrador');
  perform tests.clear_authentication();

  update public.topic_section_versions
     set status = 'published', reviewed_by = v_editor, reviewed_at = now()
   where id = v_version;

  perform tests.authenticate_anon();
  select count(*) into v_count from public.topic_sections_published;
  perform tests.assert_eq(v_count, 1, 'tras la aprobación del editor, el visitante ve la sección');
  perform tests.clear_authentication();

  -- Resúmenes: mismas reglas.
  insert into public.works (title, abstract, source, pmid, status, metadata_status)
  values ('Artículo indexado en PubMed', 'Resumen original.', 'pubmed', 12345678, 'published', 'verified')
  returning id into v_work;

  insert into public.summaries (work_id, source_scope, content, model, distribution)
  values (v_work, 'abstract_only', '{"objetivo": {"texto": "...", "origen": "documento"}}', 'claude-sonnet-5-5', 'public')
  returning id into v_summary;

  perform tests.assert_raises(format($sql$
    update public.summaries set status = 'approved' where id = %L
  $sql$, v_summary), 'un resumen no se aprueba sin revisión', '23514');

  perform tests.assert_raises(format($sql$
    insert into public.summaries (work_id, source_scope, content, model) values (%L, 'full_text', '{}', 'x')
  $sql$, v_work), 'un resumen de texto completo debe indicar el archivo leído', '23514');

  perform tests.authenticate_anon();
  perform tests.assert_eq((select count(*)::integer from public.summaries), 0,
    'el visitante no ve resúmenes en borrador');
  perform tests.clear_authentication();

  update public.summaries set status = 'approved', reviewed_by = v_editor, reviewed_at = now() where id = v_summary;

  perform tests.authenticate_anon();
  perform tests.assert_eq((select count(*)::integer from public.summaries), 1,
    'el visitante ve el resumen aprobado');
  perform tests.assert_eq((select source_scope from public.summaries limit 1), 'abstract_only',
    'el resumen declara que se basó solo en el abstract');
  perform tests.clear_authentication();
end;
$$;

rollback;
