-- =============================================================================
-- CMF Academy · Migración 0600 · Asistente de IA, cuotas y presupuesto
--
-- Decisión 2 de la fase 0 (ADR-0007):
--   · Visitantes: 3 consultas diarias; registrados: 10 (editables en app_settings).
--   · Presupuesto global mensual con corte automático y un interruptor manual.
--   · El valor inicial es IA APAGADA y presupuesto 0 hasta aprobar un gasto.
--
-- Privacidad: los visitantes se identifican por un hash HMAC-SHA256 (IP +
-- agente de usuario + secreto del servidor que rota a diario). Nunca se guarda
-- la IP.
-- =============================================================================

create type public.ai_mode as enum ('tutor', 'researcher', 'comparator', 'organizer', 'critic');

create table public.conversations (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references public.profiles (id) on delete cascade,
  visitor_hash  text check (visitor_hash ~ '^[0-9a-f]{64}$'),
  topic_id      uuid references public.topics (id) on delete set null,
  mode          public.ai_mode not null default 'tutor',
  title         text check (char_length(title) <= 200),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint conversations_one_owner check ((user_id is null) <> (visitor_hash is null))
);

create index conversations_user_idx on public.conversations (user_id, created_at desc);

create trigger conversations_set_updated_at
  before update on public.conversations
  for each row execute function public.set_updated_at();

create table public.messages (
  id                 uuid primary key default gen_random_uuid(),
  conversation_id    uuid not null references public.conversations (id) on delete cascade,
  role               text not null check (role in ('user', 'assistant')),
  content            text not null,
  model              text,
  input_tokens       integer check (input_tokens >= 0),
  output_tokens      integer check (output_tokens >= 0),
  cache_read_tokens  integer check (cache_read_tokens >= 0),
  cost_usd           numeric(12, 6) check (cost_usd >= 0),
  created_at         timestamptz not null default now(),
  constraint messages_assistant_has_model check (role = 'user' or model is not null)
);

create index messages_conversation_idx on public.messages (conversation_id, created_at);

-- Cada cita apunta a un fragmento de la biblioteca o a una obra registrada.
-- Una cita a un PMID o DOI inexistente es imposible por diseño (regla 1 y 2).
create table public.citations (
  id            uuid primary key default gen_random_uuid(),
  message_id    uuid not null references public.messages (id) on delete cascade,
  chunk_id      uuid references public.chunks (id) on delete set null,
  work_id       uuid references public.works (id) on delete set null,
  cited_text    text,
  page          integer check (page > 0),
  source_scope  text not null check (source_scope in ('full_text', 'abstract_only')),
  position      smallint not null default 0,
  created_at    timestamptz not null default now(),
  constraint citations_has_source check (chunk_id is not null or work_id is not null)
);

create index citations_message_idx on public.citations (message_id);

-- -----------------------------------------------------------------------------
-- Consumo, cuotas y presupuesto
-- -----------------------------------------------------------------------------

create table public.ai_usage (
  id                  bigint generated always as identity primary key,
  -- 'user:<uuid>' | 'visitor:<hash>' | 'system:<proceso>'
  subject             text not null check (subject ~ '^(user|visitor|system):[A-Za-z0-9_-]+$'),
  feature             text not null,
  model               text not null,
  input_tokens        integer not null default 0 check (input_tokens >= 0),
  output_tokens       integer not null default 0 check (output_tokens >= 0),
  cache_read_tokens   integer not null default 0 check (cache_read_tokens >= 0),
  cache_write_tokens  integer not null default 0 check (cache_write_tokens >= 0),
  cost_usd            numeric(12, 6) not null check (cost_usd >= 0),
  created_at          timestamptz not null default now()
);

create index ai_usage_created_idx on public.ai_usage (created_at);
create index ai_usage_subject_idx on public.ai_usage (subject, created_at);

create table public.ai_quota_counters (
  subject  text not null,
  day      date not null,
  queries  integer not null default 0 check (queries >= 0),
  primary key (subject, day)
);

create or replace function public.app_setting(p_key text)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select value from public.app_settings where key = p_key;
$$;

create or replace function public.ai_local_now()
returns timestamp
language sql
stable
set search_path = public, pg_temp
as $$
  select now() at time zone coalesce(public.app_setting('ai.timezone') #>> '{}', 'America/Santiago');
$$;

-- Gasto de IA del mes calendario en curso (zona horaria configurada).
create or replace function public.ai_month_spend()
returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(sum(u.cost_usd), 0)
    from public.ai_usage u
   where u.created_at >= (
     date_trunc('month', public.ai_local_now())
       at time zone coalesce(public.app_setting('ai.timezone') #>> '{}', 'America/Santiago')
   );
$$;

create or replace function public.ai_budget_remaining()
returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select greatest(
    coalesce((public.app_setting('ai.monthly_budget_usd') #>> '{}')::numeric, 0) - public.ai_month_spend(),
    0
  );
$$;

-- Autoriza (y descuenta) una consulta al asistente. Es atómica: dos consultas
-- simultáneas del mismo sujeto no pueden superar la cuota.
create or replace function public.ai_try_consume(p_subject text, p_is_member boolean)
returns table (allowed boolean, reason text, remaining integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_enabled boolean := coalesce((public.app_setting('ai.public_enabled') #>> '{}')::boolean, false);
  v_quota   integer := coalesce((public.app_setting(
                         case when p_is_member then 'ai.daily_quota.member'
                              else 'ai.daily_quota.anonymous' end) #>> '{}')::integer, 0);
  v_day     date := public.ai_local_now()::date;
  v_used    integer;
begin
  if not v_enabled then
    return query select false, 'service_disabled'::text, 0;
    return;
  end if;
  if public.ai_budget_remaining() <= 0 then
    return query select false, 'budget_exhausted'::text, 0;
    return;
  end if;
  if v_quota <= 0 then
    return query select false, 'daily_quota_exceeded'::text, 0;
    return;
  end if;

  insert into public.ai_quota_counters as c (subject, day, queries)
  values (p_subject, v_day, 1)
  on conflict (subject, day) do update
     set queries = c.queries + 1
   where c.queries < v_quota
  returning c.queries into v_used;

  if v_used is null then
    return query select false, 'daily_quota_exceeded'::text, 0;
    return;
  end if;
  return query select true, null::text, v_quota - v_used;
end;
$$;

-- Registra el costo real de una llamada (asistente o worker).
create or replace function public.ai_record_usage(
  p_subject            text,
  p_feature            text,
  p_model              text,
  p_input_tokens       integer,
  p_output_tokens      integer,
  p_cost_usd           numeric,
  p_cache_read_tokens  integer default 0,
  p_cache_write_tokens integer default 0
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.ai_usage (
    subject, feature, model, input_tokens, output_tokens,
    cache_read_tokens, cache_write_tokens, cost_usd
  ) values (
    p_subject, p_feature, p_model, p_input_tokens, p_output_tokens,
    coalesce(p_cache_read_tokens, 0), coalesce(p_cache_write_tokens, 0), p_cost_usd
  );
$$;

-- Estado del presupuesto para el panel de administración (solo administradores).
create or replace function public.ai_budget_status()
returns table (
  monthly_budget_usd numeric,
  month_spend_usd    numeric,
  remaining_usd      numeric,
  spend_ratio        numeric,
  alert              boolean,
  public_enabled     boolean
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_budget numeric := coalesce((public.app_setting('ai.monthly_budget_usd') #>> '{}')::numeric, 0);
  v_ratio  numeric := coalesce((public.app_setting('ai.budget_alert_ratio') #>> '{}')::numeric, 0.8);
  v_spend  numeric := public.ai_month_spend();
begin
  -- Ojo: dentro de SECURITY DEFINER, current_user es el dueño de la función;
  -- por eso el servidor se reconoce por el rol de su JWT, no por current_user.
  if not (public.has_role('admin') or coalesce(auth.role(), '') = 'service_role') then
    raise exception 'Solo un administrador puede consultar el presupuesto de IA'
      using errcode = 'insufficient_privilege';
  end if;
  return query select
    v_budget,
    v_spend,
    greatest(v_budget - v_spend, 0),
    case when v_budget > 0 then round(v_spend / v_budget, 4) end,
    v_budget > 0 and v_spend >= v_budget * v_ratio,
    coalesce((public.app_setting('ai.public_enabled') #>> '{}')::boolean, false);
end;
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.conversations     enable row level security;
alter table public.messages          enable row level security;
alter table public.citations         enable row level security;
alter table public.ai_usage          enable row level security;
alter table public.ai_quota_counters enable row level security;

-- Las conversaciones son privadas de su dueño. Las de visitantes solo las
-- maneja el servidor.
create policy conversations_own on public.conversations
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and visitor_hash is null);

create policy messages_own_select on public.messages
  for select to authenticated
  using (exists (select 1 from public.conversations c where c.id = conversation_id));

create policy citations_own_select on public.citations
  for select to authenticated
  using (exists (select 1 from public.messages m where m.id = message_id));

create policy ai_usage_select_admin on public.ai_usage
  for select to authenticated using ((select public.has_role('admin')));

create policy ai_quota_counters_select_admin on public.ai_quota_counters
  for select to authenticated using ((select public.has_role('admin')));

-- Las funciones de cuota y consumo solo las invoca el servidor.
revoke execute on function public.ai_try_consume(text, boolean) from public, anon, authenticated;
revoke execute on function public.ai_record_usage(text, text, text, integer, integer, numeric, integer, integer)
  from public, anon, authenticated;
revoke execute on function public.app_setting(text) from public, anon, authenticated;
revoke execute on function public.ai_month_spend() from public, anon, authenticated;
revoke execute on function public.ai_budget_remaining() from public, anon, authenticated;
grant execute on function public.ai_try_consume(text, boolean) to service_role;
grant execute on function public.ai_record_usage(text, text, text, integer, integer, numeric, integer, integer)
  to service_role;
grant execute on function public.app_setting(text) to service_role;
grant execute on function public.ai_month_spend() to service_role;
grant execute on function public.ai_budget_remaining() to service_role;
revoke execute on function public.ai_budget_status() from public, anon;
grant execute on function public.ai_budget_status() to authenticated, service_role;
