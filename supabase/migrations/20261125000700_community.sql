-- =============================================================================
-- CMF Academy · Migración 0700 · Comunidad, moderación y transparencia
--
-- Decisión 3 de la fase 0: los aportes de usuarios nunca se publican sin
-- moderación. Un usuario no puede aprobar su propio aporte ni cambiar el
-- estado de moderación de un comentario.
-- =============================================================================

create type public.moderation_status as enum ('pending', 'approved', 'rejected', 'changes_requested');

create table public.contributions (
  id                  uuid primary key default gen_random_uuid(),
  contributor_id      uuid not null references public.profiles (id) on delete cascade,
  kind                text not null check (kind in ('document', 'link', 'topic_proposal', 'correction')),
  title               text not null check (char_length(title) between 1 and 300),
  description         text check (char_length(description) <= 5000),
  file_id             uuid references public.files (id) on delete set null,
  work_id             uuid references public.works (id) on delete set null,
  url                 text check (url ~ '^https?://'),
  proposed_topic_ids  uuid[] not null default '{}',
  -- Declaración del aportante sobre su derecho a compartir el material.
  rights_declaration  text check (char_length(rights_declaration) <= 2000),
  status              public.moderation_status not null default 'pending',
  moderator_id        uuid references public.profiles (id) on delete set null,
  moderated_at        timestamptz,
  moderator_notes     text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint contributions_moderation_pair
    check (status = 'pending' or (moderator_id is not null and moderated_at is not null)),
  constraint contributions_document_has_file
    check (kind <> 'document' or file_id is not null),
  constraint contributions_link_has_url
    check (kind <> 'link' or url is not null)
);

create index contributions_status_idx on public.contributions (status, created_at);
create index contributions_contributor_idx on public.contributions (contributor_id);

create trigger contributions_set_updated_at
  before update on public.contributions
  for each row execute function public.set_updated_at();

create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references public.profiles (id) on delete cascade,
  topic_id    uuid references public.topics (id) on delete cascade,
  work_id     uuid references public.works (id) on delete cascade,
  parent_id   uuid references public.comments (id) on delete cascade,
  body        text not null check (char_length(body) between 1 and 5000),
  status      text not null default 'visible' check (status in ('visible', 'hidden', 'removed')),
  created_at  timestamptz not null default now(),
  edited_at   timestamptz,
  constraint comments_one_target check (num_nonnulls(topic_id, work_id) = 1)
);

create index comments_topic_idx on public.comments (topic_id, created_at);
create index comments_work_idx on public.comments (work_id, created_at);

-- Solo un editor (o el servidor) cambia campos de moderación.
create or replace function public.guard_moderation_fields()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if public.is_service_context() or public.has_role('editor') then
    return new;
  end if;

  if tg_table_name = 'contributions' then
    if tg_op = 'INSERT' then
      if new.status <> 'pending' or new.moderator_id is not null then
        raise exception 'Un aporte nuevo debe quedar pendiente de moderación'
          using errcode = 'insufficient_privilege';
      end if;
    elsif new.status is distinct from old.status
       or new.moderator_id is distinct from old.moderator_id
       or new.moderator_notes is distinct from old.moderator_notes
       or new.contributor_id is distinct from old.contributor_id then
      raise exception 'Solo un editor puede moderar aportes'
        using errcode = 'insufficient_privilege';
    end if;
  elsif tg_table_name = 'comments' then
    if tg_op = 'INSERT' then
      if new.status <> 'visible' then
        raise exception 'Estado inicial de comentario no permitido'
          using errcode = 'insufficient_privilege';
      end if;
    elsif new.status is distinct from old.status
       or new.author_id is distinct from old.author_id then
      raise exception 'Solo un editor puede moderar comentarios'
        using errcode = 'insufficient_privilege';
    else
      new.edited_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger contributions_guard_moderation
  before insert or update on public.contributions
  for each row execute function public.guard_moderation_fields();

create trigger comments_guard_moderation
  before insert or update on public.comments
  for each row execute function public.guard_moderation_fields();

-- -----------------------------------------------------------------------------
-- Solicitudes por derechos de autor (formulario público; ADR-0006)
-- Se reciben por el servidor tras verificar Turnstile; los datos de contacto
-- solo los ven los editores.
-- -----------------------------------------------------------------------------

create table public.copyright_requests (
  id               uuid primary key default gen_random_uuid(),
  requester_name   text not null check (char_length(requester_name) between 1 and 200),
  requester_email  text not null check (requester_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  work_id          uuid references public.works (id) on delete set null,
  file_id          uuid references public.files (id) on delete set null,
  reference_url    text check (reference_url ~ '^https?://'),
  claim            text not null check (char_length(claim) between 10 and 10000),
  status           text not null default 'received'
                   check (status in ('received', 'under_review', 'resolved_removed', 'resolved_kept')),
  handled_by       uuid references public.profiles (id) on delete set null,
  resolution_notes text,
  created_at       timestamptz not null default now(),
  resolved_at      timestamptz
);

-- -----------------------------------------------------------------------------
-- Historial público de actualizaciones (alimenta "temas recientes" y la fecha
-- de "última actualización" de cada tema)
-- -----------------------------------------------------------------------------

create table public.content_events (
  id           bigint generated always as identity primary key,
  entity_type  text not null check (entity_type in ('topic', 'work', 'file', 'media', 'section')),
  entity_id    uuid not null,
  topic_id     uuid references public.topics (id) on delete cascade,
  event        text not null check (event in ('created', 'updated', 'published', 'archived')),
  summary      text check (char_length(summary) <= 300),
  actor_id     uuid references public.profiles (id) on delete set null,
  is_public    boolean not null default false,
  created_at   timestamptz not null default now()
);

create index content_events_topic_idx on public.content_events (topic_id, created_at desc);
create index content_events_public_idx on public.content_events (created_at desc) where is_public;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.contributions      enable row level security;
alter table public.comments           enable row level security;
alter table public.copyright_requests enable row level security;
alter table public.content_events     enable row level security;

create policy contributions_select on public.contributions
  for select to authenticated
  using (contributor_id = (select auth.uid()) or (select public.has_role('editor')));

create policy contributions_insert_own on public.contributions
  for insert to authenticated
  with check (contributor_id = (select auth.uid()));

create policy contributions_update on public.contributions
  for update to authenticated
  using (
    (contributor_id = (select auth.uid()) and status in ('pending', 'changes_requested'))
    or (select public.has_role('editor'))
  )
  with check (contributor_id = (select auth.uid()) or (select public.has_role('editor')));

create policy contributions_delete on public.contributions
  for delete to authenticated
  using (
    (contributor_id = (select auth.uid()) and status = 'pending')
    or (select public.has_role('editor'))
  );

create policy comments_select on public.comments
  for select to anon, authenticated
  using (
    (select public.has_role('editor'))
    or author_id = (select auth.uid())
    or (
      status = 'visible'
      and (topic_id is null or exists (select 1 from public.topics t where t.id = topic_id))
      and (work_id is null or exists (select 1 from public.works w where w.id = work_id))
    )
  );

create policy comments_insert_own on public.comments
  for insert to authenticated
  with check (author_id = (select auth.uid()));

create policy comments_update on public.comments
  for update to authenticated
  using (author_id = (select auth.uid()) or (select public.has_role('editor')))
  with check (author_id = (select auth.uid()) or (select public.has_role('editor')));

create policy comments_delete_editor on public.comments
  for delete to authenticated using ((select public.has_role('editor')));

create policy copyright_requests_editor on public.copyright_requests
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy content_events_select on public.content_events
  for select to anon, authenticated
  using (is_public or (select public.has_role('editor')));
