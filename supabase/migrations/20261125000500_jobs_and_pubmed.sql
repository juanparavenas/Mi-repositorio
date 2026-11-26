-- =============================================================================
-- CMF Academy · Migración 0500 · Cola de trabajos y sincronización con PubMed
--
-- La cola vive en PostgreSQL (ADR-0003): sin infraestructura adicional, con
-- reintentos, estados visibles y costo registrado por trabajo. El worker toma
-- trabajos con FOR UPDATE SKIP LOCKED, por lo que varias instancias pueden
-- trabajar en paralelo sin tomar el mismo trabajo.
-- =============================================================================

create type public.job_status as enum ('queued', 'running', 'succeeded', 'failed', 'cancelled');

create table public.processing_jobs (
  id            uuid primary key default gen_random_uuid(),
  job_type      text not null check (job_type in (
                  'extract', 'metadata', 'classify', 'index',
                  'summarize', 'translate', 'pubmed_sync', 'media'
                )),
  file_id       uuid references public.files (id) on delete cascade,
  work_id       uuid references public.works (id) on delete cascade,
  payload       jsonb not null default '{}'::jsonb,
  status        public.job_status not null default 'queued',
  priority      smallint not null default 0,
  attempts      integer not null default 0 check (attempts >= 0),
  max_attempts  integer not null default 3 check (max_attempts between 1 and 10),
  run_after     timestamptz not null default now(),
  locked_at     timestamptz,
  locked_by     text,
  last_error    text,
  cost_usd      numeric(10, 4) not null default 0 check (cost_usd >= 0),
  created_by    uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  finished_at   timestamptz
);

create index processing_jobs_ready_idx
  on public.processing_jobs (priority desc, run_after)
  where status = 'queued';
create index processing_jobs_file_idx on public.processing_jobs (file_id);

-- Toma hasta `batch_size` trabajos listos y los marca como en ejecución.
create or replace function public.claim_jobs(
  worker_id  text,
  batch_size integer default 1,
  job_types  text[] default null
)
returns setof public.processing_jobs
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.processing_jobs j
     set status = 'running',
         locked_at = now(),
         locked_by = worker_id,
         attempts = j.attempts + 1
   where j.id in (
     select q.id
       from public.processing_jobs q
      where q.status = 'queued'
        and q.run_after <= now()
        and (job_types is null or q.job_type = any (job_types))
      order by q.priority desc, q.run_after
      for update skip locked
      limit greatest(batch_size, 1)
   )
  returning j.*;
$$;

create or replace function public.complete_job(p_job_id uuid, p_cost_usd numeric default 0)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.processing_jobs
     set status = 'succeeded',
         finished_at = now(),
         cost_usd = cost_usd + coalesce(p_cost_usd, 0),
         locked_at = null,
         locked_by = null,
         last_error = null
   where id = p_job_id and status = 'running';
$$;

-- Reintenta con espera creciente hasta max_attempts; después lo marca fallido.
create or replace function public.fail_job(
  p_job_id      uuid,
  p_error       text,
  p_retry_delay interval default interval '1 minute'
)
returns public.job_status
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status public.job_status;
begin
  update public.processing_jobs
     set status = case when attempts < max_attempts then 'queued'::public.job_status
                       else 'failed'::public.job_status end,
         run_after = case when attempts < max_attempts then now() + p_retry_delay * attempts
                          else run_after end,
         finished_at = case when attempts < max_attempts then null else now() end,
         last_error = left(p_error, 4000),
         locked_at = null,
         locked_by = null
   where id = p_job_id and status = 'running'
  returning status into v_status;
  return v_status;
end;
$$;

-- -----------------------------------------------------------------------------
-- PubMed: consultas guardadas por tema y registro de sincronizaciones
-- -----------------------------------------------------------------------------

create table public.pubmed_queries (
  id           uuid primary key default gen_random_uuid(),
  topic_id     uuid not null references public.topics (id) on delete cascade,
  query_term   text not null check (char_length(query_term) between 3 and 4000),
  -- Filtros estructurados: tipos de publicación, rango de años, idioma, etc.
  filters      jsonb not null default '{}'::jsonb,
  frequency    interval not null default interval '7 days' check (frequency >= interval '1 day'),
  enabled      boolean not null default true,
  last_run_at  timestamptz,
  next_run_at  timestamptz not null default now(),
  created_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index pubmed_queries_due_idx on public.pubmed_queries (next_run_at) where enabled;

create trigger pubmed_queries_set_updated_at
  before update on public.pubmed_queries
  for each row execute function public.set_updated_at();

create table public.pubmed_sync_runs (
  id              bigint generated always as identity primary key,
  query_id        uuid not null references public.pubmed_queries (id) on delete cascade,
  started_at      timestamptz not null default now(),
  finished_at     timestamptz,
  status          text not null default 'running' check (status in ('running', 'succeeded', 'failed')),
  records_found   integer check (records_found >= 0),
  records_new     integer check (records_new >= 0),
  error           text
);

create index pubmed_sync_runs_query_idx on public.pubmed_sync_runs (query_id, started_at desc);

-- La llama pg_cron (fase 3): encola una sincronización por cada consulta vencida
-- y reprograma la siguiente. No contacta a NCBI: eso lo hace el worker.
create or replace function public.enqueue_due_pubmed_syncs()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  with due as (
    update public.pubmed_queries q
       set next_run_at = now() + q.frequency
     where q.enabled
       and q.next_run_at <= now()
       and not exists (
         select 1 from public.processing_jobs j
          where j.job_type = 'pubmed_sync'
            and j.status in ('queued', 'running')
            and j.payload ->> 'query_id' = q.id::text
       )
    returning q.id, q.last_run_at
  )
  insert into public.processing_jobs (job_type, payload, priority)
  select 'pubmed_sync',
         jsonb_build_object('query_id', due.id, 'since', due.last_run_at),
         -1
    from due;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- -----------------------------------------------------------------------------
-- RLS: la cola y las consultas son internas (editores leen; el servidor escribe)
-- -----------------------------------------------------------------------------

alter table public.processing_jobs  enable row level security;
alter table public.pubmed_queries   enable row level security;
alter table public.pubmed_sync_runs enable row level security;

create policy processing_jobs_select_editor on public.processing_jobs
  for select to authenticated using ((select public.has_role('editor')));

create policy pubmed_queries_select_editor on public.pubmed_queries
  for select to authenticated using ((select public.has_role('editor')));
create policy pubmed_queries_editor_write on public.pubmed_queries
  for all to authenticated
  using ((select public.has_role('editor'))) with check ((select public.has_role('editor')));

create policy pubmed_sync_runs_select_editor on public.pubmed_sync_runs
  for select to authenticated using ((select public.has_role('editor')));

-- Solo el servidor (service_role) opera la cola.
revoke execute on function public.claim_jobs(text, integer, text[]) from public, anon, authenticated;
revoke execute on function public.complete_job(uuid, numeric) from public, anon, authenticated;
revoke execute on function public.fail_job(uuid, text, interval) from public, anon, authenticated;
revoke execute on function public.enqueue_due_pubmed_syncs() from public, anon, authenticated;
grant execute on function public.claim_jobs(text, integer, text[]) to service_role;
grant execute on function public.complete_job(uuid, numeric) to service_role;
grant execute on function public.fail_job(uuid, text, interval) to service_role;
grant execute on function public.enqueue_due_pubmed_syncs() to service_role;
