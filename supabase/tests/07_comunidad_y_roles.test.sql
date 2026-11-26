-- Prueba 07 · Cuentas, roles, moderación de aportes y comentarios.
begin;

do $$
declare
  v_admin    uuid := tests.create_user('admin.comunidad@example.test', 'admin');
  v_editor   uuid := tests.create_user('editor.comunidad@example.test', 'editor');
  v_member   uuid := tests.create_user('miembro.comunidad@example.test');
  v_other    uuid := tests.create_user('otro.comunidad@example.test');
  v_root     uuid;
  v_contrib  uuid;
  v_comment  uuid;
  v_count    integer;
begin
  -- Una cuenta nueva recibe perfil y rol de miembro.
  perform tests.assert(exists (select 1 from public.profiles where id = v_member),
    'la cuenta nueva tiene perfil');
  perform tests.assert_eq((select display_name from public.profiles where id = v_member), 'miembro.comunidad',
    'el nombre visible parte del correo, sin exponer el dominio');
  perform tests.assert(exists (select 1 from public.user_roles where user_id = v_member and role = 'member'),
    'la cuenta nueva es miembro');

  -- Un miembro no puede darse privilegios.
  perform tests.authenticate_as(v_member);
  perform tests.assert_raises(
    format('insert into public.user_roles (user_id, role) values (%L, %L)', v_member, 'editor'),
    'un miembro no puede hacerse editor', '42501');
  perform tests.assert(not public.has_role('editor'), 'el miembro no es editor');
  perform tests.clear_authentication();

  -- Nunca queda la plataforma sin administrador.
  perform tests.assert_raises(
    format('delete from public.user_roles where user_id = %L and role = %L', v_admin, 'admin'),
    'no se puede quitar el último administrador', '23514');
  insert into public.user_roles (user_id, role) values (v_editor, 'admin');
  delete from public.user_roles where user_id = v_admin and role = 'admin';
  perform tests.assert(not exists (select 1 from public.user_roles where user_id = v_admin and role = 'admin'),
    'con otro administrador, sí se puede quitar el rol');

  -- Aportes: quedan pendientes y no se autoaprueban.
  perform tests.authenticate_as(v_member);
  insert into public.contributions (contributor_id, kind, title, url, rights_declaration)
  values (v_member, 'link', 'Guía clínica de acceso abierto', 'https://example.org/guia', 'Es de acceso abierto')
  returning id into v_contrib;
  perform tests.assert_raises(
    format('insert into public.contributions (contributor_id, kind, title, url, status) values (%L, %L, %L, %L, %L)',
           v_member, 'link', 'Intento', 'https://example.org', 'approved'),
    'un aporte no puede nacer aprobado', '42501');
  perform tests.assert_raises(
    format('update public.contributions set status = %L, moderator_id = %L, moderated_at = now() where id = %L',
           'approved', v_member, v_contrib),
    'el aportante no puede aprobar su propio aporte', '42501');
  perform tests.assert_raises(
    format('insert into public.contributions (contributor_id, kind, title, url) values (%L, %L, %L, %L)',
           v_other, 'link', 'Suplantación', 'https://example.org'),
    'no se puede aportar a nombre de otro', '42501');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_other);
  select count(*) into v_count from public.contributions;
  perform tests.assert_eq(v_count, 0, 'un usuario no ve aportes ajenos');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_editor);
  update public.contributions
     set status = 'approved', moderator_id = v_editor, moderated_at = now(), moderator_notes = 'Verificado'
   where id = v_contrib;
  perform tests.clear_authentication();
  perform tests.assert_eq((select status from public.contributions where id = v_contrib),
    'approved'::public.moderation_status, 'el editor aprueba el aporte');

  -- Comentarios: el autor edita su texto; solo un editor modera.
  select id into v_root from public.topics where parent_id is null and slug = 'cirugia-oral-y-maxilofacial';
  update public.topics set status = 'published' where id = v_root;

  perform tests.authenticate_as(v_member);
  insert into public.comments (author_id, topic_id, body) values (v_member, v_root, 'Comentario académico')
  returning id into v_comment;
  update public.comments set body = 'Comentario académico corregido' where id = v_comment;
  perform tests.assert_raises(
    format('update public.comments set status = %L where id = %L', 'hidden', v_comment),
    'el autor no modera su comentario', '42501');
  perform tests.clear_authentication();
  perform tests.assert((select edited_at is not null from public.comments where id = v_comment),
    'la edición queda registrada');

  perform tests.authenticate_as(v_editor);
  update public.comments set status = 'hidden' where id = v_comment;
  perform tests.clear_authentication();

  perform tests.authenticate_anon();
  perform tests.assert_eq((select count(*)::integer from public.comments), 0,
    'el visitante no ve comentarios ocultos');
  perform tests.assert_eq((select count(*)::integer from public.copyright_requests), 0,
    'el visitante no lee solicitudes de derechos de autor');
  perform tests.clear_authentication();
end;
$$;

rollback;
