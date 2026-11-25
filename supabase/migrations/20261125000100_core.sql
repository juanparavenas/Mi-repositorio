-- =============================================================================
-- CMF Academy · Migración 0100 · Núcleo
-- Extensiones, tipos comunes, perfiles, roles, configuración y utilidades.
--
-- Estado: BORRADOR DE DISEÑO (fase 0). Validado localmente con las pruebas de
-- supabase/tests. No ha sido aplicado en ningún proyecto de Supabase.
-- =============================================================================

create schema if not exists extensions;
create extension if not exists vector   with schema extensions;
create extension if not exists ltree    with schema extensions;
create extension if not exists pg_trgm  with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists citext   with schema extensions;

-- -----------------------------------------------------------------------------
-- Tipos comunes
-- -----------------------------------------------------------------------------

-- Jerarquía de roles: el orden de declaración define el nivel (member < editor < admin).
-- El visitante sin registro no tiene fila: es el rol `anon` de Supabase.
create type public.app_role as enum ('member', 'editor', 'admin');

-- Estado editorial del contenido publicable.
create type public.content_status as enum ('draft', 'in_review', 'published', 'archived');

-- Origen del contenido académico redactado.
create type public.content_origin as enum ('human', 'ai', 'ai_edited');

-- Estado de distribución (ADR-0006). El orden va de más abierto a más cerrado.
create type public.distribution_status as enum ('public', 'restricted', 'metadata_only');

-- -----------------------------------------------------------------------------
-- Utilidades
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Verdadero cuando la operación la ejecuta el servidor (service_role) o una
-- migración, no un usuario final. Los guardias de moderación lo usan para no
-- bloquear procesos internos.
-- IMPORTANTE: solo es válida en funciones SECURITY INVOKER. Dentro de una
-- función SECURITY DEFINER, current_user es el dueño de la función y esta
-- comprobación daría siempre verdadero (la prueba 05 lo cubre).
create or replace function public.is_service_context()
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select current_user in ('postgres', 'service_role', 'supabase_admin');
$$;

-- -----------------------------------------------------------------------------
-- Perfiles
-- -----------------------------------------------------------------------------

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null check (char_length(display_name) between 1 and 120),
  institution   text check (char_length(institution) <= 200),
  specialty     text check (char_length(specialty) <= 120),
  bio           text check (char_length(bio) <= 2000),
  orcid         text unique check (orcid ~ '^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$'),
  avatar_path   text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.profiles is
  'Perfil público de cada cuenta. Solo contiene lo que el usuario decide mostrar (minimización de datos).';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Roles
-- -----------------------------------------------------------------------------

create table public.user_roles (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  role        public.app_role not null,
  granted_by  uuid references public.profiles (id) on delete set null,
  granted_at  timestamptz not null default now(),
  primary key (user_id, role)
);

-- ¿El usuario actual tiene al menos este rol? (admin ⊇ editor ⊇ member)
-- SECURITY DEFINER evita la recursión de RLS al consultar user_roles.
create or replace function public.has_role(required public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role >= required
  );
$$;

-- ¿Un usuario dado tiene al menos este rol? Se usa para validar revisores.
create or replace function public.user_has_role(uid uuid, required public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select uid is not null and exists (
    select 1
    from public.user_roles ur
    where ur.user_id = uid
      and ur.role >= required
  );
$$;

-- Nunca puede quedar la plataforma sin administrador.
create or replace function public.protect_last_admin()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.role = 'admin'
     and (tg_op = 'DELETE' or new.role <> 'admin')
     and (select count(*) from public.user_roles where role = 'admin') <= 1 then
    raise exception 'No se puede quitar el último administrador de CMF Academy'
      using errcode = 'check_violation';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger user_roles_protect_last_admin
  before update or delete on public.user_roles
  for each row execute function public.protect_last_admin();

-- Cada cuenta nueva recibe un perfil y el rol de miembro.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    left(coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Usuario'
    ), 120)
  );
  insert into public.user_roles (user_id, role) values (new.id, 'member');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Configuración editable desde la administración (sin cambiar código)
-- -----------------------------------------------------------------------------

create table public.app_settings (
  key          text primary key check (key ~ '^[a-z0-9_.]+$'),
  value        jsonb not null,
  description  text not null,
  updated_by   uuid references public.profiles (id) on delete set null,
  updated_at   timestamptz not null default now()
);

create trigger app_settings_set_updated_at
  before update on public.app_settings
  for each row execute function public.set_updated_at();

-- Valores iniciales conservadores: la IA queda APAGADA y con presupuesto 0
-- hasta que el administrador apruebe explícitamente un gasto (ADR-0010).
insert into public.app_settings (key, value, description) values
  ('ai.public_enabled',              'false', 'Interruptor general del asistente. Apagado hasta aprobar presupuesto.'),
  ('ai.monthly_budget_usd',          '0',     'Tope de gasto mensual de IA en USD. 0 = sin gasto autorizado.'),
  ('ai.budget_alert_ratio',          '0.8',   'Fracción del presupuesto que dispara la alerta al administrador.'),
  ('ai.daily_quota.anonymous',       '3',     'Consultas diarias por visitante sin registro.'),
  ('ai.daily_quota.member',          '10',    'Consultas diarias por usuario registrado.'),
  ('ai.max_output_tokens.anonymous', '1200',  'Máximo de tokens de salida por respuesta a visitantes.'),
  ('ai.max_output_tokens.member',    '2000',  'Máximo de tokens de salida por respuesta a usuarios registrados.'),
  ('ai.timezone',                    '"America/Santiago"', 'Zona horaria para cortes diarios y mensuales.');

-- -----------------------------------------------------------------------------
-- Auditoría (solo inserción)
-- -----------------------------------------------------------------------------

create table public.audit_log (
  id           bigint generated always as identity primary key,
  actor_id     uuid,
  actor_role   text not null default current_user,
  action       text not null,
  entity_type  text not null,
  entity_id    text,
  details      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index audit_log_entity_idx on public.audit_log (entity_type, entity_id);
create index audit_log_created_idx on public.audit_log (created_at desc);

-- Registra automáticamente los cambios en tablas sensibles.
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row jsonb := to_jsonb(coalesce(new, old));
begin
  insert into public.audit_log (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    coalesce(v_row ->> 'id', v_row ->> 'key', v_row ->> 'user_id'),
    jsonb_build_object(
      'old', case when tg_op <> 'INSERT' then to_jsonb(old) end,
      'new', case when tg_op <> 'DELETE' then to_jsonb(new) end
    )
  );
  return coalesce(new, old);
end;
$$;

create trigger user_roles_audit
  after insert or update or delete on public.user_roles
  for each row execute function public.audit_row_change();

create trigger app_settings_audit
  after insert or update or delete on public.app_settings
  for each row execute function public.audit_row_change();

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.profiles     enable row level security;
alter table public.user_roles   enable row level security;
alter table public.app_settings enable row level security;
alter table public.audit_log    enable row level security;

create policy profiles_select_all on public.profiles
  for select to anon, authenticated using (true);

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy user_roles_select_own_or_admin on public.user_roles
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.has_role('admin')));

create policy user_roles_admin_write on public.user_roles
  for all to authenticated
  using ((select public.has_role('admin')))
  with check ((select public.has_role('admin')));

create policy app_settings_select_editor on public.app_settings
  for select to authenticated using ((select public.has_role('editor')));

create policy app_settings_admin_write on public.app_settings
  for all to authenticated
  using ((select public.has_role('admin')))
  with check ((select public.has_role('admin')));

create policy audit_log_select_admin on public.audit_log
  for select to authenticated using ((select public.has_role('admin')));

-- La auditoría es de solo inserción para cualquier cliente.
revoke update, delete, truncate on public.audit_log from anon, authenticated;

-- Funciones internas: no invocables desde el cliente.
revoke execute on function public.user_has_role(uuid, public.app_role) from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.audit_row_change() from public, anon, authenticated;
revoke execute on function public.protect_last_admin() from public, anon, authenticated;
