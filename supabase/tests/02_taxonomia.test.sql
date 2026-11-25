-- Prueba 02 · Taxonomía de profundidad libre, movimientos, publicación y permisos.
begin;

do $$
declare
  v_root    uuid;
  v_orto    uuid;
  v_maxilar uuid;
  v_lf1     uuid;
  v_atm     uuid;
  v_editor  uuid := tests.create_user('editor.taxonomia@example.test', 'editor');
  v_member  uuid := tests.create_user('miembro.taxonomia@example.test');
  v_count   integer;
begin
  select id into v_root from public.topics where parent_id is null and slug = 'cirugia-oral-y-maxilofacial';
  perform tests.assert(v_root is not null, 'la semilla crea la especialidad raíz');

  select count(*) into v_count from public.topics;
  perform tests.assert_eq(v_count, 51, 'la semilla crea 51 nodos y es idempotente');

  select id into v_orto from public.topics where parent_id = v_root and slug = 'cirugia-ortognatica';
  select id into v_maxilar from public.topics where parent_id = v_orto and slug = 'cirugia-maxilar';
  select id into v_lf1 from public.topics where parent_id = v_maxilar and slug = 'le-fort-i';
  select id into v_atm from public.topics where parent_id = v_root and slug = 'articulacion-temporomandibular';

  perform tests.assert_eq((select depth from public.topics where id = v_lf1), 4,
    'Le Fort I está en el nivel 4 (especialidad → categoría → subcategoría → tema)');
  perform tests.assert(
    (select path from public.topics where id = v_lf1) operator(extensions.<@) (select path from public.topics where id = v_orto),
    'Le Fort I es descendiente de Cirugía ortognática');

  -- Profundidad libre: se puede agregar un nivel 5 y 6 sin cambiar código.
  insert into public.topics (parent_id, slug, name)
  values (v_lf1, 'osteotomia-le-fort-i-segmentada', 'Osteotomía Le Fort I segmentada');
  insert into public.topics (parent_id, slug, name)
  select id, 'tecnica-de-dos-piezas', 'Técnica de dos piezas'
    from public.topics where slug = 'osteotomia-le-fort-i-segmentada';
  perform tests.assert_eq((select depth from public.topics where slug = 'tecnica-de-dos-piezas'), 6,
    'se admite un sexto nivel');

  -- Mover un subárbol actualiza la ruta de todos los descendientes.
  update public.topics set parent_id = v_atm where id = v_maxilar;
  perform tests.assert(
    (select path from public.topics where id = v_lf1) operator(extensions.<@) (select path from public.topics where id = v_atm),
    'al mover Cirugía maxilar, Le Fort I pasa a depender de ATM');
  perform tests.assert(
    (select path from public.topics where slug = 'tecnica-de-dos-piezas') operator(extensions.<@) (select path from public.topics where id = v_atm),
    'los nietos también se mueven');
  update public.topics set parent_id = v_orto where id = v_maxilar;

  -- No se permiten ciclos.
  perform tests.assert_raises(
    format('update public.topics set parent_id = %L where id = %L', v_lf1, v_root),
    'no se puede mover la raíz dentro de su descendiente', '23514');
  perform tests.assert_raises(
    format('update public.topics set parent_id = %L where id = %L', v_root, v_root),
    'un tema no puede ser su propio padre', '23514');

  -- El slug es único entre hermanos, pero puede repetirse en otra rama.
  perform tests.assert_raises(
    format('insert into public.topics (parent_id, slug, name) values (%L, %L, %L)', v_orto, 'complicaciones', 'Duplicado'),
    'slug duplicado entre hermanos', '23505');
  insert into public.topics (parent_id, slug, name) values (v_atm, 'complicaciones', 'Complicaciones');

  -- Un tema no se publica si su padre no está publicado.
  perform tests.assert_raises(
    format('update public.topics set status = %L where id = %L', 'published', v_orto),
    'no se publica un tema con el padre en borrador', '23514');
  update public.topics set status = 'published' where id = v_root;
  update public.topics set status = 'published' where id = v_orto;
  perform tests.assert((select published_at is not null from public.topics where id = v_orto),
    'al publicar se registra la fecha');

  -- Un visitante solo ve lo publicado.
  perform tests.authenticate_anon();
  select count(*) into v_count from public.topics;
  perform tests.assert_eq(v_count, 2, 'el visitante ve solo los 2 temas publicados');
  perform tests.assert_raises(
    'insert into public.topics (parent_id, slug, name) values (null, ''intruso'', ''Intruso'')',
    'un visitante no puede crear temas', '42501');
  perform tests.clear_authentication();

  -- Un miembro tampoco edita la taxonomía; un editor sí.
  perform tests.authenticate_as(v_member);
  perform tests.assert_raises(
    format('insert into public.topics (parent_id, slug, name) values (%L, %L, %L)', v_root, 'propuesta', 'Propuesta'),
    'un miembro no puede crear temas', '42501');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_editor);
  insert into public.topics (parent_id, slug, name) values (v_root, 'implantologia-avanzada', 'Implantología avanzada');
  select count(*) into v_count from public.topics;
  perform tests.assert(v_count > 2, 'el editor ve también los borradores');
  perform tests.clear_authentication();

  -- Relaciones entre temas de distintas ramas.
  insert into public.topic_relations (source_topic_id, target_topic_id, relation_type)
  values (v_lf1, v_atm, 'related');
  perform tests.assert_raises(
    format('insert into public.topic_relations (source_topic_id, target_topic_id, relation_type) values (%L, %L, %L)', v_lf1, v_lf1, 'related'),
    'un tema no se relaciona consigo mismo', '23514');
end;
$$;

rollback;
