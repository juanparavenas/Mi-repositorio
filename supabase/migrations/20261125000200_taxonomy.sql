-- =============================================================================
-- CMF Academy · Migración 0200 · Taxonomía de conocimiento
-- Árbol de profundidad libre (ADR-0005): especialidad → categoría → … → subtema.
-- Cada nodo tiene un padre canónico (ruta de navegación) y relaciones tipadas
-- con otros temas. La estructura se edita desde la administración, no en código.
-- =============================================================================

create table public.topics (
  id            uuid primary key default gen_random_uuid(),
  parent_id     uuid references public.topics (id) on delete restrict,
  slug          text not null
                check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 80),
  name          text not null check (char_length(name) between 1 and 160),
  summary       text check (char_length(summary) <= 600),
  position      integer not null default 0,
  -- Ruta materializada de ids (con "_" en vez de "-"); la calculan los triggers.
  path          extensions.ltree not null,
  depth         integer generated always as (extensions.nlevel(path)) stored,
  status        public.content_status not null default 'draft',
  search        tsvector generated always as (
                  setweight(to_tsvector('spanish', coalesce(name, '')), 'A') ||
                  setweight(to_tsvector('spanish', coalesce(summary, '')), 'B')
                ) stored,
  created_by    uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  published_at  timestamptz,
  constraint topics_sibling_slug_unique unique nulls not distinct (parent_id, slug),
  constraint topics_not_own_parent check (parent_id is distinct from id)
);

comment on table public.topics is
  'Nodo del árbol de conocimiento. La profundidad es libre; el tipo de nivel (especialidad, categoría, tema) se deduce de la profundidad en la interfaz.';

create index topics_path_gist_idx on public.topics using gist (path);
create index topics_parent_idx on public.topics (parent_id, position);
create index topics_search_idx on public.topics using gin (search);
create index topics_name_trgm_idx on public.topics using gin (name extensions.gin_trgm_ops);

create trigger topics_set_updated_at
  before update on public.topics
  for each row execute function public.set_updated_at();

-- Calcula la ruta del nodo e impide ciclos al mover un subárbol.
create or replace function public.topics_compute_path()
returns trigger
language plpgsql
set search_path = public, extensions, pg_temp
as $$
declare
  v_parent_path extensions.ltree;
  v_label       extensions.ltree := extensions.text2ltree(replace(new.id::text, '-', '_'));
begin
  if new.parent_id is null then
    new.path := v_label;
  else
    select t.path into v_parent_path from public.topics t where t.id = new.parent_id;
    if v_parent_path is null then
      raise exception 'El tema padre % no existe', new.parent_id using errcode = 'foreign_key_violation';
    end if;
    if tg_op = 'UPDATE' and v_parent_path operator(extensions.<@) old.path then
      raise exception 'No se puede mover un tema dentro de su propio subárbol'
        using errcode = 'check_violation';
    end if;
    new.path := v_parent_path operator(extensions.||) v_label;
  end if;
  return new;
end;
$$;

create trigger topics_path_before
  before insert or update of parent_id on public.topics
  for each row execute function public.topics_compute_path();

-- Al mover un nodo, actualiza la ruta de todos sus descendientes.
create or replace function public.topics_cascade_path()
returns trigger
language plpgsql
set search_path = public, extensions, pg_temp
as $$
begin
  if new.path is distinct from old.path then
    update public.topics t
       set path = new.path operator(extensions.||) extensions.subpath(t.path, extensions.nlevel(old.path))
     where t.path operator(extensions.<@) old.path
       and t.id <> new.id;
  end if;
  return null;
end;
$$;

create trigger topics_path_after
  after update of parent_id on public.topics
  for each row execute function public.topics_cascade_path();

-- Un tema solo se publica si su padre está publicado (la ruta de navegación
-- pública nunca apunta a un nodo oculto).
create or replace function public.topics_check_publish()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'published' then
    if new.parent_id is not null and not exists (
      select 1 from public.topics p where p.id = new.parent_id and p.status = 'published'
    ) then
      raise exception 'No se puede publicar "%" mientras su tema padre no esté publicado', new.name
        using errcode = 'check_violation';
    end if;
    new.published_at := coalesce(new.published_at, now());
  end if;
  return new;
end;
$$;

create trigger topics_check_publish
  before insert or update of status, parent_id on public.topics
  for each row execute function public.topics_check_publish();

-- -----------------------------------------------------------------------------
-- Relaciones entre temas (un tema puede vincularse con temas de otras ramas)
-- -----------------------------------------------------------------------------

create type public.topic_relation_type as enum (
  'related', 'technique_of', 'complication_of', 'differential_diagnosis', 'prerequisite'
);

create table public.topic_relations (
  source_topic_id  uuid not null references public.topics (id) on delete cascade,
  target_topic_id  uuid not null references public.topics (id) on delete cascade,
  relation_type    public.topic_relation_type not null,
  note             text check (char_length(note) <= 500),
  created_by       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now(),
  primary key (source_topic_id, target_topic_id, relation_type),
  constraint topic_relations_no_self check (source_topic_id <> target_topic_id)
);

create index topic_relations_target_idx on public.topic_relations (target_topic_id);

-- -----------------------------------------------------------------------------
-- Secciones académicas de cada tema, con versiones y revisión editorial
-- (ADR-0008: lo redactado por IA queda en borrador hasta que un editor aprueba)
-- -----------------------------------------------------------------------------

create table public.topic_sections (
  id           uuid primary key default gen_random_uuid(),
  topic_id     uuid not null references public.topics (id) on delete cascade,
  section_key  text not null check (section_key ~ '^[a-z_]+$'),
  title        text not null check (char_length(title) between 1 and 160),
  position     integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (topic_id, section_key)
);

create trigger topic_sections_set_updated_at
  before update on public.topic_sections
  for each row execute function public.set_updated_at();

create table public.topic_section_versions (
  id            uuid primary key default gen_random_uuid(),
  section_id    uuid not null references public.topic_sections (id) on delete cascade,
  version       integer not null check (version > 0),
  body_md       text not null,
  status        public.content_status not null default 'draft',
  origin        public.content_origin not null,
  ai_model      text,
  created_by    uuid references public.profiles (id) on delete set null,
  reviewed_by   uuid references public.profiles (id) on delete set null,
  reviewed_at   timestamptz,
  review_notes  text,
  created_at    timestamptz not null default now(),
  unique (section_id, version),
  constraint tsv_published_requires_review
    check (status <> 'published' or (reviewed_by is not null and reviewed_at is not null)),
  constraint tsv_ai_origin_requires_model
    check (origin = 'human' or ai_model is not null)
);

-- El revisor de cualquier contenido publicado o aprobado debe ser editor.
-- Se reutiliza en resúmenes y traducciones.
create or replace function public.assert_reviewer_is_editor()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status::text in ('published', 'approved')
     and not public.user_has_role(new.reviewed_by, 'editor') then
    raise exception 'Solo un editor puede aprobar o publicar contenido (tabla %)', tg_table_name
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger topic_section_versions_reviewer
  before insert or update of status, reviewed_by on public.topic_section_versions
  for each row execute function public.assert_reviewer_is_editor();

-- Versión publicada más reciente de cada sección (lo que ve el público).
create view public.topic_sections_published
with (security_invoker = true) as
select distinct on (s.id)
  s.id as section_id, s.topic_id, s.section_key, s.title, s.position,
  v.id as version_id, v.version, v.body_md, v.origin, v.reviewed_by, v.reviewed_at
from public.topic_sections s
join public.topic_section_versions v on v.section_id = s.id and v.status = 'published'
order by s.id, v.version desc;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.topics                 enable row level security;
alter table public.topic_relations        enable row level security;
alter table public.topic_sections         enable row level security;
alter table public.topic_section_versions enable row level security;

create policy topics_select on public.topics
  for select to anon, authenticated
  using (status = 'published' or (select public.has_role('editor')));

create policy topics_editor_write on public.topics
  for all to authenticated
  using ((select public.has_role('editor')))
  with check ((select public.has_role('editor')));

-- Visible si ambos temas son visibles para quien consulta (las subconsultas
-- respetan la RLS de topics).
create policy topic_relations_select on public.topic_relations
  for select to anon, authenticated
  using (
    exists (select 1 from public.topics t where t.id = source_topic_id)
    and exists (select 1 from public.topics t where t.id = target_topic_id)
  );

create policy topic_relations_editor_write on public.topic_relations
  for all to authenticated
  using ((select public.has_role('editor')))
  with check ((select public.has_role('editor')));

create policy topic_sections_select on public.topic_sections
  for select to anon, authenticated
  using (exists (select 1 from public.topics t where t.id = topic_id));

create policy topic_sections_editor_write on public.topic_sections
  for all to authenticated
  using ((select public.has_role('editor')))
  with check ((select public.has_role('editor')));

create policy topic_section_versions_select on public.topic_section_versions
  for select to anon, authenticated
  using (
    (select public.has_role('editor'))
    or (status = 'published'
        and exists (select 1 from public.topic_sections s where s.id = section_id))
  );

create policy topic_section_versions_editor_write on public.topic_section_versions
  for all to authenticated
  using ((select public.has_role('editor')))
  with check ((select public.has_role('editor')));
