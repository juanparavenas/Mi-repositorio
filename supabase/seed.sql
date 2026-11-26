-- =============================================================================
-- CMF Academy · Semilla de la taxonomía inicial (decisión 7 de la fase 0)
--
-- Cinco áreas iniciales tomadas del documento maestro. La estructura es
-- ilustrativa: los editores la amplían y reorganizan desde la administración.
-- Las áreas sin subtemas en el documento maestro quedan vacías a propósito
-- (no se inventan contenidos).
--
-- Todos los nodos quedan en BORRADOR: un editor los revisa y publica.
-- Es idempotente: puede ejecutarse varias veces sin duplicar nodos.
-- =============================================================================

create or replace function pg_temp.seed_topic(
  p_parent   uuid,
  p_slug     text,
  p_name     text,
  p_position integer
)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  select id into v_id
    from public.topics
   where parent_id is not distinct from p_parent and slug = p_slug;

  if v_id is null then
    insert into public.topics (parent_id, slug, name, position)
    values (p_parent, p_slug, p_name, p_position)
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

do $$
declare
  root      uuid;
  anatomia  uuid;
  orto      uuid;
  maxilar   uuid;
  mandib    uuid;
  atm       uuid;
  patol     uuid;
  minimo    uuid;
  abierto   uuid;
  recon     uuid;
begin
  root := pg_temp.seed_topic(null, 'cirugia-oral-y-maxilofacial', 'Cirugía Oral y Maxilofacial', 0);

  -- Anatomía quirúrgica
  anatomia := pg_temp.seed_topic(root, 'anatomia-quirurgica', 'Anatomía quirúrgica', 1);
  perform pg_temp.seed_topic(anatomia, 'anatomia-mandibular', 'Anatomía mandibular', 1);
  perform pg_temp.seed_topic(anatomia, 'anatomia-maxilar', 'Anatomía maxilar', 2);
  perform pg_temp.seed_topic(anatomia, 'anatomia-de-la-atm', 'Anatomía de la ATM', 3);
  perform pg_temp.seed_topic(anatomia, 'anatomia-vascular', 'Anatomía vascular', 4);
  perform pg_temp.seed_topic(anatomia, 'anatomia-nerviosa', 'Anatomía nerviosa', 5);
  perform pg_temp.seed_topic(anatomia, 'anatomia-cervical', 'Anatomía cervical', 6);
  perform pg_temp.seed_topic(anatomia, 'espacios-faciales', 'Espacios faciales', 7);
  perform pg_temp.seed_topic(anatomia, 'anatomia-quirurgica-orbitaria', 'Anatomía quirúrgica orbitaria', 8);

  -- Cirugía ortognática
  orto := pg_temp.seed_topic(root, 'cirugia-ortognatica', 'Cirugía ortognática', 2);
  perform pg_temp.seed_topic(orto, 'diagnostico-y-planificacion', 'Diagnóstico y planificación', 1);
  perform pg_temp.seed_topic(orto, 'analisis-cefalometrico', 'Análisis cefalométrico', 2);
  perform pg_temp.seed_topic(orto, 'planificacion-virtual', 'Planificación virtual', 3);
  maxilar := pg_temp.seed_topic(orto, 'cirugia-maxilar', 'Cirugía maxilar', 4);
  perform pg_temp.seed_topic(maxilar, 'le-fort-i', 'Le Fort I', 1);
  perform pg_temp.seed_topic(maxilar, 'le-fort-ii', 'Le Fort II', 2);
  perform pg_temp.seed_topic(maxilar, 'le-fort-iii', 'Le Fort III', 3);
  perform pg_temp.seed_topic(maxilar, 'segmentacion-maxilar', 'Segmentación maxilar', 4);
  mandib := pg_temp.seed_topic(orto, 'cirugia-mandibular', 'Cirugía mandibular', 5);
  perform pg_temp.seed_topic(mandib, 'bssro', 'Osteotomía sagital bilateral de rama (BSSRO)', 1);
  perform pg_temp.seed_topic(mandib, 'osteotomia-vertical-de-rama', 'Osteotomía vertical de rama', 2);
  perform pg_temp.seed_topic(mandib, 'genioplastia', 'Genioplastia', 3);
  perform pg_temp.seed_topic(orto, 'cirugia-bimaxilar', 'Cirugía bimaxilar', 6);
  perform pg_temp.seed_topic(orto, 'cirugia-de-avance', 'Cirugía de avance', 7);
  perform pg_temp.seed_topic(orto, 'cirugia-de-retroceso', 'Cirugía de retroceso', 8);
  perform pg_temp.seed_topic(orto, 'cirugia-segmentaria', 'Cirugía segmentaria', 9);
  perform pg_temp.seed_topic(orto, 'complicaciones', 'Complicaciones', 10);
  perform pg_temp.seed_topic(orto, 'recidiva-y-estabilidad', 'Recidiva y estabilidad', 11);

  -- Articulación temporomandibular
  atm := pg_temp.seed_topic(root, 'articulacion-temporomandibular', 'Articulación temporomandibular', 3);
  perform pg_temp.seed_topic(atm, 'anatomia-y-fisiologia', 'Anatomía y fisiología', 1);
  perform pg_temp.seed_topic(atm, 'diagnostico-por-imagenes', 'Diagnóstico por imágenes', 2);
  patol := pg_temp.seed_topic(atm, 'patologia-articular', 'Patología articular', 3);
  perform pg_temp.seed_topic(patol, 'desplazamiento-discal', 'Desplazamiento discal', 1);
  perform pg_temp.seed_topic(patol, 'osteoartritis', 'Osteoartritis', 2);
  perform pg_temp.seed_topic(patol, 'anquilosis', 'Anquilosis', 3);
  perform pg_temp.seed_topic(patol, 'osteocondritis-disecante', 'Osteocondritis disecante', 4);
  perform pg_temp.seed_topic(patol, 'reabsorcion-condilar-idiopatica', 'Reabsorción condilar idiopática', 5);
  perform pg_temp.seed_topic(atm, 'tratamiento-conservador', 'Tratamiento conservador', 4);
  minimo := pg_temp.seed_topic(atm, 'tratamiento-minimamente-invasivo', 'Tratamiento mínimamente invasivo', 5);
  perform pg_temp.seed_topic(minimo, 'artrocentesis', 'Artrocentesis', 1);
  perform pg_temp.seed_topic(minimo, 'artroscopia', 'Artroscopia', 2);
  abierto := pg_temp.seed_topic(atm, 'tratamiento-quirurgico-abierto', 'Tratamiento quirúrgico abierto', 6);
  perform pg_temp.seed_topic(abierto, 'discopexia', 'Discopexia', 1);
  perform pg_temp.seed_topic(abierto, 'discectomia', 'Discectomía', 2);
  perform pg_temp.seed_topic(abierto, 'condilectomia', 'Condilectomía', 3);
  recon := pg_temp.seed_topic(atm, 'reconstruccion-articular', 'Reconstrucción articular', 7);
  perform pg_temp.seed_topic(recon, 'protesis-aloplastica', 'Prótesis aloplástica', 1);
  perform pg_temp.seed_topic(recon, 'reconstruccion-autogena', 'Reconstrucción autógena', 2);

  -- Áreas sin subtemas definidos en el documento maestro
  perform pg_temp.seed_topic(root, 'crecimiento-y-desarrollo-craneofacial', 'Crecimiento y desarrollo craneofacial', 4);
  perform pg_temp.seed_topic(root, 'traumatologia-maxilofacial', 'Traumatología maxilofacial', 5);
end;
$$;
