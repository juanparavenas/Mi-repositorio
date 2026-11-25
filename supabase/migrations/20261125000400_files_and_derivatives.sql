-- =============================================================================
-- CMF Academy · Migración 0400 · Archivos, derivados y multimedia
--
-- ARCHIVO: el original intacto (PDF, DOCX, PPTX, imagen, video, 3D).
-- DERIVADOS: extracción, fragmentos para RAG, traducciones y resúmenes.
--
-- Reglas de derechos de autor (ADR-0006, decisión 1 de la fase 0):
--   · public        → contenido propio, con licencia o autorizado. Requiere
--                     derechos verificados por un editor.
--   · restricted    → solo roles o usuarios autorizados.
--   · metadata_only → el texto completo no se distribuye; solo editores.
--   · La IA procesa un archivo solo si ai_processing_allowed = true, lo que
--     exige una base legítima registrada y verificada.
--   · Un derivado nunca puede ser más abierto que su archivo de origen.
-- =============================================================================

create type public.file_kind as enum ('pdf', 'docx', 'pptx', 'image', 'video', 'model_3d', 'other');

create table public.files (
  id                     uuid primary key default gen_random_uuid(),
  work_id                uuid references public.works (id) on delete set null,
  kind                   public.file_kind not null,
  mime_type              text not null check (mime_type ~ '^[a-z]+/[a-z0-9.+-]+$'),
  size_bytes             bigint not null check (size_bytes > 0 and size_bytes <= 2147483648),
  sha256                 text not null unique check (sha256 ~ '^[0-9a-f]{64}$'),
  storage_bucket         text not null,
  storage_path           text not null,
  original_filename      text not null check (char_length(original_filename) <= 255),
  -- Por defecto, lo más cerrado: nada se distribuye sin una decisión explícita.
  distribution           public.distribution_status not null default 'metadata_only',
  allowed_roles          public.app_role[] not null default '{editor}',
  license                text,
  rights_basis           text check (char_length(rights_basis) <= 2000),
  rights_verified_by     uuid references public.profiles (id) on delete set null,
  rights_verified_at     timestamptz,
  ai_processing_allowed  boolean not null default false,
  source_url             text check (source_url ~ '^https?://'),
  uploaded_by            uuid references public.profiles (id) on delete set null,
  status                 public.content_status not null default 'draft',
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (storage_bucket, storage_path),
  constraint files_rights_verification_pair
    check ((rights_verified_by is null) = (rights_verified_at is null)),
  constraint files_public_requires_verified_rights
    check (distribution <> 'public' or (rights_verified_by is not null and rights_basis is not null)),
  constraint files_ai_requires_verified_rights
    check (not ai_processing_allowed or (rights_verified_by is not null and rights_basis is not null))
);

comment on column public.files.rights_basis is
  'Base legal o autorización que permite distribuir o procesar el archivo (licencia, permiso escrito, autoría propia).';

create index files_work_idx on public.files (work_id);

create trigger files_set_updated_at
  before update on public.files
  for each row execute function public.set_updated_at();

create trigger files_audit
  after insert or update of distribution, allowed_roles, ai_processing_allowed, status or delete
  on public.files
  for each row execute function public.audit_row_change();

-- El verificador de derechos debe ser editor.
create or replace function public.files_check_rights_verifier()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.rights_verified_by is not null
     and not public.user_has_role(new.rights_verified_by, 'editor') then
    raise exception 'Solo un editor puede verificar los derechos de un archivo'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger files_check_rights_verifier
  before insert or update of rights_verified_by on public.files
  for each row execute function public.files_check_rights_verifier();

-- Accesos individuales a archivos restringidos.
create table public.file_access_grants (
  file_id     uuid not null references public.files (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  granted_by  uuid references public.profiles (id) on delete set null,
  granted_at  timestamptz not null default now(),
  expires_at  timestamptz,
  primary key (file_id, user_id)
);

-- ¿Puede el usuario actual leer el archivo (y sus fragmentos)?
create or replace function public.can_read_file(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.files f
    where f.id = fid
      and (
        public.has_role('editor')
        or (
          f.status = 'published'
          and (
            f.distribution = 'public'
            or (
              f.distribution = 'restricted'
              and (
                exists (
                  select 1 from public.user_roles ur
                  where ur.user_id = auth.uid() and ur.role = any (f.allowed_roles)
                )
                or exists (
                  select 1 from public.file_access_grants g
                  where g.file_id = f.id
                    and g.user_id = auth.uid()
                    and (g.expires_at is null or g.expires_at > now())
                )
              )
            )
          )
        )
      )
  );
$$;

-- -----------------------------------------------------------------------------
-- Extracción y fragmentos (RAG)
-- -----------------------------------------------------------------------------

create table public.extractions (
  id                 uuid primary key default gen_random_uuid(),
  file_id            uuid not null references public.files (id) on delete cascade,
  extractor          text not null,
  extractor_version  text not null,
  language           text check (language ~ '^[a-z]{2,3}$'),
  page_count         integer check (page_count >= 0),
  content_md         text,
  structure          jsonb,
  -- Secciones o páginas que no se pudieron extraer: se informan, no se ocultan.
  failed_sections    jsonb not null default '[]'::jsonb,
  created_at         timestamptz not null default now(),
  unique (file_id, extractor, extractor_version)
);

-- Dimensión 1024: compatible con los candidatos de embeddings evaluados
-- (Voyage, modelos abiertos como bge-m3, Cohere, OpenAI con reducción). ADR-0014.
create table public.chunks (
  id               uuid primary key default gen_random_uuid(),
  file_id          uuid not null references public.files (id) on delete cascade,
  extraction_id    uuid not null references public.extractions (id) on delete cascade,
  chunk_index      integer not null check (chunk_index >= 0),
  section          text,
  page_start       integer check (page_start > 0),
  page_end         integer,
  content          text not null,
  context          text,
  token_count      integer check (token_count > 0),
  embedding        extensions.vector(1024),
  embedding_model  text,
  search           tsvector generated always as (
                     to_tsvector('english', coalesce(context, '') || ' ' || content)
                   ) stored,
  created_at       timestamptz not null default now(),
  unique (extraction_id, chunk_index),
  constraint chunks_page_order check (page_end is null or page_end >= page_start),
  constraint chunks_embedding_pair check ((embedding is null) = (embedding_model is null))
);

create index chunks_file_idx on public.chunks (file_id);
create index chunks_search_idx on public.chunks using gin (search);
create index chunks_embedding_idx on public.chunks
  using hnsw (embedding extensions.vector_cosine_ops);

-- Solo se indexan archivos con autorización de procesamiento por IA.
create or replace function public.chunks_require_ai_permission()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.files f where f.id = new.file_id and f.ai_processing_allowed
  ) then
    raise exception 'El archivo % no tiene autorización para procesamiento por IA', new.file_id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger chunks_require_ai_permission
  before insert or update of file_id on public.chunks
  for each row execute function public.chunks_require_ai_permission();

-- -----------------------------------------------------------------------------
-- Traducciones y resúmenes
-- -----------------------------------------------------------------------------

create type public.derivative_status as enum (
  'pending', 'processing', 'draft', 'approved', 'failed', 'archived'
);

create table public.translations (
  id                     uuid primary key default gen_random_uuid(),
  file_id                uuid not null references public.files (id) on delete cascade,
  extraction_id          uuid references public.extractions (id) on delete set null,
  target_language        text not null default 'es' check (target_language ~ '^[a-z]{2,3}$'),
  status                 public.derivative_status not null default 'pending',
  distribution           public.distribution_status not null default 'metadata_only',
  content_md             text,
  untranslated_sections  jsonb not null default '[]'::jsonb,
  model                  text,
  glossary_version       text,
  cost_usd               numeric(10, 4) check (cost_usd >= 0),
  reviewed_by            uuid references public.profiles (id) on delete set null,
  reviewed_at            timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint translations_approved_requires_review
    check (status <> 'approved' or (reviewed_by is not null and reviewed_at is not null))
);

create index translations_file_idx on public.translations (file_id);

create trigger translations_set_updated_at
  before update on public.translations
  for each row execute function public.set_updated_at();

create trigger translations_reviewer
  before insert or update of status, reviewed_by on public.translations
  for each row execute function public.assert_reviewer_is_editor();

create table public.summaries (
  id            uuid primary key default gen_random_uuid(),
  work_id       uuid not null references public.works (id) on delete cascade,
  file_id       uuid references public.files (id) on delete set null,
  -- Regla 11 de la IA: declarar si se leyó el texto completo o solo el abstract.
  source_scope  text not null check (source_scope in ('full_text', 'abstract_only')),
  -- Cada campo distingue lo que dice el documento de la interpretación de la IA.
  content       jsonb not null,
  status        public.derivative_status not null default 'draft',
  distribution  public.distribution_status not null default 'metadata_only',
  model         text not null,
  cost_usd      numeric(10, 4) check (cost_usd >= 0),
  reviewed_by   uuid references public.profiles (id) on delete set null,
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint summaries_full_text_has_file check (source_scope = 'abstract_only' or file_id is not null),
  constraint summaries_approved_requires_review
    check (status <> 'approved' or (reviewed_by is not null and reviewed_at is not null))
);

create index summaries_work_idx on public.summaries (work_id);

create trigger summaries_set_updated_at
  before update on public.summaries
  for each row execute function public.set_updated_at();

create trigger summaries_reviewer
  before insert or update of status, reviewed_by on public.summaries
  for each row execute function public.assert_reviewer_is_editor();

-- Un derivado de un archivo exige permiso de IA y no puede ser más abierto que él.
create or replace function public.derivative_check_source()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_file public.files%rowtype;
begin
  if new.file_id is null then
    return new;
  end if;
  select * into v_file from public.files where id = new.file_id;
  -- El permiso de IA se exige al crear el derivado (o al cambiar su origen);
  -- si después se revoca, files_propagate_restrictions lo archiva.
  if (tg_op = 'INSERT' or new.file_id is distinct from old.file_id)
     and not v_file.ai_processing_allowed then
    raise exception 'El archivo de origen no tiene autorización para procesamiento por IA'
      using errcode = 'check_violation';
  end if;
  if new.distribution < v_file.distribution then
    raise exception 'Un derivado no puede ser más abierto (%) que su archivo de origen (%)',
      new.distribution, v_file.distribution
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger translations_check_source
  before insert or update of file_id, distribution on public.translations
  for each row execute function public.derivative_check_source();

create trigger summaries_check_source
  before insert or update of file_id, distribution on public.summaries
  for each row execute function public.derivative_check_source();

-- Si un archivo se vuelve más restrictivo, sus derivados lo siguen; si pierde
-- el permiso de IA, se eliminan sus fragmentos y se archivan sus derivados.
create or replace function public.files_propagate_restrictions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.distribution > old.distribution then
    update public.translations set distribution = new.distribution
     where file_id = new.id and distribution < new.distribution;
    update public.summaries set distribution = new.distribution
     where file_id = new.id and distribution < new.distribution;
  end if;
  if old.ai_processing_allowed and not new.ai_processing_allowed then
    delete from public.chunks where file_id = new.id;
    update public.translations set status = 'archived' where file_id = new.id;
    update public.summaries set status = 'archived' where file_id = new.id;
  end if;
  return new;
end;
$$;

create trigger files_propagate_restrictions
  after update of distribution, ai_processing_allowed on public.files
  for each row execute function public.files_propagate_restrictions();

-- ¿Puede el usuario actual leer un derivado aprobado?
create or replace function public.can_read_derivative(
  p_status public.derivative_status,
  p_distribution public.distribution_status,
  p_file_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_role('editor')
    or (
      p_status = 'approved'
      and (
        (p_distribution = 'public' and (p_file_id is null or public.can_read_file(p_file_id)))
        or (p_distribution = 'restricted' and p_file_id is not null and public.can_read_file(p_file_id))
      )
    );
$$;

-- -----------------------------------------------------------------------------
-- Multimedia (ADR-0012: imágenes clínicas y datos sensibles)
-- -----------------------------------------------------------------------------

create type public.media_type as enum (
  'clinical_photo', 'radiograph', 'cbct', 'schematic', 'surgical_diagram',
  'video', 'model_3d', 'presentation'
);

create type public.consent_status as enum ('not_required', 'pending', 'obtained', 'refused');

create table public.media_assets (
  id                     uuid primary key default gen_random_uuid(),
  file_id                uuid not null unique references public.files (id) on delete cascade,
  media_type             public.media_type not null,
  title                  text not null check (char_length(title) between 1 and 300),
  caption                text,
  credit                 text,
  width                  integer check (width > 0),
  height                 integer check (height > 0),
  duration_seconds       numeric(10, 2) check (duration_seconds > 0),
  stream_uid             text,
  contains_patient_data  boolean not null,
  consent                public.consent_status not null,
  -- Referencia interna al consentimiento. El documento firmado NO se almacena aquí.
  consent_reference      text,
  deidentified_by        uuid references public.profiles (id) on delete set null,
  deidentified_at        timestamptz,
  status                 public.content_status not null default 'draft',
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint media_clinical_types_are_patient_data
    check (media_type not in ('clinical_photo', 'radiograph', 'cbct') or contains_patient_data),
  constraint media_patient_data_needs_consent_decision
    check (not contains_patient_data or consent <> 'not_required'),
  constraint media_patient_publish_rules
    check (
      status <> 'published'
      or not contains_patient_data
      or (consent = 'obtained' and deidentified_by is not null and deidentified_at is not null)
    )
);

create trigger media_assets_set_updated_at
  before update on public.media_assets
  for each row execute function public.set_updated_at();

create table public.media_topics (
  media_id  uuid not null references public.media_assets (id) on delete cascade,
  topic_id  uuid not null references public.topics (id) on delete cascade,
  primary key (media_id, topic_id)
);

create index media_topics_topic_idx on public.media_topics (topic_id);

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.files              enable row level security;
alter table public.file_access_grants enable row level security;
alter table public.extractions        enable row level security;
alter table public.chunks             enable row level security;
alter table public.translations       enable row level security;
alter table public.summaries          enable row level security;
alter table public.media_assets       enable row level security;
alter table public.media_topics       enable row level security;

create policy files_select on public.files
  for select to anon, authenticated using (public.can_read_file(id));
create policy files_editor_write on public.files
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy file_access_grants_select on public.file_access_grants
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.has_role('editor')));
create policy file_access_grants_editor_write on public.file_access_grants
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

-- Extracciones y fragmentos: lectura con los mismos permisos del archivo.
-- La escritura la hace solo el worker (service_role).
create policy extractions_select on public.extractions
  for select to anon, authenticated using (public.can_read_file(file_id));

create policy chunks_select on public.chunks
  for select to anon, authenticated using (public.can_read_file(file_id));

create policy translations_select on public.translations
  for select to anon, authenticated
  using (public.can_read_derivative(status, distribution, file_id));
create policy translations_editor_write on public.translations
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy summaries_select on public.summaries
  for select to anon, authenticated
  using (
    public.can_read_derivative(status, distribution, file_id)
    and exists (select 1 from public.works w where w.id = work_id)
  );
create policy summaries_editor_write on public.summaries
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy media_assets_select on public.media_assets
  for select to anon, authenticated
  using ((select public.has_role('editor')) or (status = 'published' and public.can_read_file(file_id)));
create policy media_assets_editor_write on public.media_assets
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy media_topics_select on public.media_topics
  for select to anon, authenticated
  using (
    exists (select 1 from public.media_assets m where m.id = media_id)
    and exists (select 1 from public.topics t where t.id = topic_id)
  );
create policy media_topics_editor_write on public.media_topics
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

revoke execute on function public.files_propagate_restrictions() from public, anon, authenticated;
