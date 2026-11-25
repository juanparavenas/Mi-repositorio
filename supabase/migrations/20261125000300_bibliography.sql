-- =============================================================================
-- CMF Academy · Migración 0300 · Bibliografía
-- La OBRA (artículo, libro, capítulo, guía) es una referencia bibliográfica
-- estructurada, independiente de cualquier archivo (ADR-0006). PubMed y
-- Crossref son la fuente de verdad de sus metadatos (ADR-0009).
-- =============================================================================

create type public.work_type as enum (
  'journal_article', 'review', 'book', 'book_chapter', 'guideline',
  'thesis', 'conference_paper', 'web_resource', 'other'
);

create type public.work_source as enum ('pubmed', 'crossref', 'upload', 'manual', 'link');

create type public.metadata_status as enum ('verified', 'auto_extracted', 'pending_review');

create type public.assignment_origin as enum ('ai', 'editor', 'pubmed_query');

create type public.evidence_source as enum ('publication_type', 'ai', 'editor');

-- -----------------------------------------------------------------------------
-- Revistas y autores
-- -----------------------------------------------------------------------------

create table public.journals (
  id                uuid primary key default gen_random_uuid(),
  title             text not null check (char_length(title) between 1 and 400),
  iso_abbreviation  text,
  issn_print        text check (issn_print ~ '^\d{4}-\d{3}[\dX]$'),
  issn_electronic   text check (issn_electronic ~ '^\d{4}-\d{3}[\dX]$'),
  nlm_unique_id     text unique,
  created_at        timestamptz not null default now()
);

create unique index journals_issn_print_key on public.journals (issn_print) where issn_print is not null;
create unique index journals_issn_electronic_key on public.journals (issn_electronic) where issn_electronic is not null;

create table public.authors (
  id               uuid primary key default gen_random_uuid(),
  last_name        text,
  fore_name        text,
  initials         text,
  collective_name  text,
  orcid            text unique check (orcid ~ '^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$'),
  created_at       timestamptz not null default now(),
  constraint authors_has_name check (last_name is not null or collective_name is not null)
);

create index authors_last_name_trgm_idx on public.authors using gin (last_name extensions.gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- Obras
-- -----------------------------------------------------------------------------

create table public.works (
  id                     uuid primary key default gen_random_uuid(),
  work_type              public.work_type not null default 'journal_article',
  title                  text not null check (char_length(title) between 1 and 2000),
  abstract               text,
  language               text check (language ~ '^[a-z]{2,3}$'),
  publication_year       smallint check (publication_year between 1800 and 2100),
  publication_date       date,
  journal_id             uuid references public.journals (id) on delete set null,
  volume                 text,
  issue                  text,
  pages                  text,
  -- Identificadores: únicos, normalizados y validados; nunca inventados (regla 2 de la IA).
  doi                    extensions.citext unique check (doi operator(extensions.~) '^10\.\d{4,9}/\S+$'),
  pmid                   bigint unique check (pmid > 0),
  pmcid                  text unique check (pmcid ~ '^PMC\d+$'),
  publication_types      text[] not null default '{}',
  -- Nivel de evidencia (Oxford CEBM 2011, 1 = más alto) y quién lo asignó.
  evidence_level         smallint check (evidence_level between 1 and 5),
  evidence_level_source  public.evidence_source,
  is_open_access         boolean not null default false,
  license                text,
  oa_url                 text check (oa_url ~ '^https://'),
  external_url           text check (external_url ~ '^https?://'),
  source                 public.work_source not null,
  metadata_status        public.metadata_status not null default 'pending_review',
  status                 public.content_status not null default 'draft',
  search                 tsvector generated always as (
                           setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
                           setweight(to_tsvector('english', coalesce(abstract, '')), 'B')
                         ) stored,
  created_by             uuid references public.profiles (id) on delete set null,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint works_evidence_pair
    check ((evidence_level is null) = (evidence_level_source is null)),
  constraint works_pubmed_has_pmid
    check (source <> 'pubmed' or pmid is not null)
);

comment on table public.works is
  'Obra científica como referencia bibliográfica. Puede existir sin archivo (ficha de PubMed) y tener cero o más archivos.';

create index works_search_idx on public.works using gin (search);
create index works_title_trgm_idx on public.works using gin (title extensions.gin_trgm_ops);
create index works_year_idx on public.works (publication_year desc);
create index works_journal_idx on public.works (journal_id);

create trigger works_set_updated_at
  before update on public.works
  for each row execute function public.set_updated_at();

create table public.work_authors (
  work_id      uuid not null references public.works (id) on delete cascade,
  position     smallint not null check (position > 0),
  author_id    uuid not null references public.authors (id) on delete restrict,
  affiliation  text,
  primary key (work_id, position),
  unique (work_id, author_id)
);

create index work_authors_author_idx on public.work_authors (author_id);

create table public.mesh_terms (
  ui       text primary key check (ui ~ '^D\d{6,9}$'),
  name     text not null,
  name_es  text
);

create table public.work_mesh (
  work_id         uuid not null references public.works (id) on delete cascade,
  mesh_ui         text not null references public.mesh_terms (ui) on delete restrict,
  is_major_topic  boolean not null default false,
  primary key (work_id, mesh_ui)
);

-- Una obra puede relacionarse con muchos temas. La IA propone; el editor confirma.
create table public.work_topics (
  work_id       uuid not null references public.works (id) on delete cascade,
  topic_id      uuid not null references public.topics (id) on delete cascade,
  relevance     real check (relevance between 0 and 1),
  origin        public.assignment_origin not null,
  confirmed_by  uuid references public.profiles (id) on delete set null,
  confirmed_at  timestamptz,
  created_at    timestamptz not null default now(),
  primary key (work_id, topic_id),
  constraint work_topics_confirmation_pair check ((confirmed_by is null) = (confirmed_at is null))
);

create index work_topics_topic_idx on public.work_topics (topic_id);

-- -----------------------------------------------------------------------------
-- RLS: los metadatos publicados son públicos; la escritura es editorial
-- (la sincronización con PubMed escribe desde el servidor con service_role).
-- -----------------------------------------------------------------------------

alter table public.journals     enable row level security;
alter table public.authors      enable row level security;
alter table public.works        enable row level security;
alter table public.work_authors enable row level security;
alter table public.mesh_terms   enable row level security;
alter table public.work_mesh    enable row level security;
alter table public.work_topics  enable row level security;

create policy journals_select on public.journals
  for select to anon, authenticated using (true);
create policy journals_editor_write on public.journals
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy authors_select on public.authors
  for select to anon, authenticated using (true);
create policy authors_editor_write on public.authors
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy works_select on public.works
  for select to anon, authenticated
  using (status = 'published' or (select public.has_role('editor')));
create policy works_editor_write on public.works
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy work_authors_select on public.work_authors
  for select to anon, authenticated
  using (exists (select 1 from public.works w where w.id = work_id));
create policy work_authors_editor_write on public.work_authors
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy mesh_terms_select on public.mesh_terms
  for select to anon, authenticated using (true);
create policy mesh_terms_editor_write on public.mesh_terms
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy work_mesh_select on public.work_mesh
  for select to anon, authenticated
  using (exists (select 1 from public.works w where w.id = work_id));
create policy work_mesh_editor_write on public.work_mesh
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy work_topics_select on public.work_topics
  for select to anon, authenticated
  using (
    exists (select 1 from public.works w where w.id = work_id)
    and exists (select 1 from public.topics t where t.id = topic_id)
  );
create policy work_topics_editor_write on public.work_topics
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));
