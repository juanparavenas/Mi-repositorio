-- =============================================================================
-- CMF Academy · Migración 0800 · Política de exclusión documental
--
-- Documento canónico: docs/politica-de-exclusion-documental.md (ADR-0016).
-- Reglas versionadas: config/politica-exclusion.json (las pruebas verifican que
-- los códigos sembrados aquí coinciden con ese archivo).
--
-- Cada elemento de origen (archivo de Google Drive o carga directa) se evalúa
-- ANTES de copiarse y queda registrado en source_items con su decisión:
--
--   allowed          → puede importarse; sigue el flujo de derechos (0400).
--   review_required  → potencialmente incorporable; revisión individual previa.
--   quarantined      → incertidumbre; revisión de un administrador.
--   excluded         → nunca se copia, no se procesa con IA, no se indexa ni
--                      se publica. Solo queda registrado con su motivo.
--
-- Garantías en la base:
--   · Un archivo solo puede crearse desde un elemento "allowed".
--   · Las extensiones y tipos MIME excluidos se rechazan en cualquier ingreso,
--     también en la carga directa sin importador.
--   · Si un elemento deja de estar permitido, su archivo queda bloqueado: solo
--     metadatos, sin IA, despublicado, sin fragmentos ni extracciones, con sus
--     trabajos cancelados y una orden de purga del original en Storage.
--   · Los excluidos no conservan el identificador de Drive: se reconocen en
--     importaciones futuras por su huella (sha256 de fuente e identificador).
--   · Liberar un elemento exige revisión humana registrada; las exclusiones
--     duras (DICOM, proyectos nativos, datos de paciente) no se liberan nunca.
--   · Las presentaciones no se importan (EXC-PRESENTACION) y de cada documento
--     se importa una sola copia (EXC-DUPLICADO apunta a la conservada).
--     Los libros y capítulos se importan con el flujo normal de derechos.
-- =============================================================================

-- El orden importa: de menos a más restrictivo.
create type public.import_decision as enum ('allowed', 'review_required', 'quarantined', 'excluded');

-- -----------------------------------------------------------------------------
-- Reglas
-- -----------------------------------------------------------------------------

create table public.exclusion_rules (
  code            text primary key check (code ~ '^(EXC|CUA|REV)-[A-Z0-9-]+$'),
  decision        public.import_decision not null,
  releasable      boolean not null,
  title           text not null,
  policy_version  text not null,
  constraint exclusion_rules_prefix_matches_decision check (
    (code like 'EXC-%' and decision = 'excluded')
    or (code like 'CUA-%' and decision = 'quarantined')
    or (code like 'REV-%' and decision = 'review_required')
  )
);

insert into public.exclusion_rules (code, decision, releasable, title, policy_version) values
  ('EXC-SISTEMA', 'excluded', false, 'Archivo de sistema o acceso directo', '1.0.0'),
  ('EXC-DICOM', 'excluded', false, 'Estudio DICOM', '1.0.0'),
  ('EXC-PROYECTO-PROPLAN', 'excluded', false, 'Proyecto nativo de ProPlan CMF', '1.0.0'),
  ('EXC-PROYECTO-MIMICS', 'excluded', false, 'Proyecto nativo de Mimics / Mimics Medical', '1.0.0'),
  ('EXC-PROYECTO-3MATIC', 'excluded', false, 'Proyecto nativo de 3-matic / 3-matic Medical', '1.0.0'),
  ('EXC-PROYECTO-DECLARADO', 'excluded', false, 'Formato de proyecto declarado por el administrador', '1.0.0'),
  ('EXC-PROYECTO-IPS', 'excluded', false, 'Caso de IPS CaseDesigner', '1.0.0'),
  ('EXC-DATOS-PACIENTE', 'excluded', false, 'Datos de paciente', '1.0.0'),
  ('EXC-AUXILIAR-SOFTWARE', 'excluded', false, 'Archivo auxiliar, respaldo o temporal de un programa de planificación', '1.0.0'),
  ('EXC-DERIVADO-CASO', 'excluded', true, 'Exportación derivada de un caso clínico', '1.0.0'),
  ('EXC-MODELO-3D-CLINICO', 'excluded', true, 'Modelo 3D derivado de un caso clínico', '1.0.0'),
  ('CUA-DOCUMENTO-EN-CASO', 'quarantined', true, 'Documento dentro de un caso clínico', '1.0.0'),
  ('CUA-CARPETA-SOFTWARE', 'quarantined', true, 'Material dentro de una carpeta de un programa de planificación', '1.0.0'),
  ('CUA-MODELO-3D-PLANIFICACION', 'quarantined', true, 'Modelo 3D con nombre de planificación quirúrgica', '1.0.0'),
  ('CUA-MODELO-3D-SIN-PROCEDENCIA', 'quarantined', true, 'Modelo 3D sin procedencia académica acreditada', '1.0.0'),
  ('CUA-COMPRIMIDO', 'quarantined', true, 'Archivo comprimido de contenido desconocido', '1.0.0'),
  ('CUA-IMAGEN-CLINICA-POSIBLE', 'quarantined', true, 'Posible fotografía clínica', '1.0.0'),
  ('CUA-FORMATO-DESCONOCIDO', 'quarantined', true, 'Formato no reconocido', '1.0.0'),
  ('EXC-PRESENTACION', 'excluded', true, 'Presentación (PowerPoint, Keynote o Presentaciones de Google)', '1.1.0'),
  ('EXC-DUPLICADO', 'excluded', true, 'Copia sobrante de un documento ya incluido', '1.1.0'),
  ('REV-MODELO-3D-EDUCATIVO', 'review_required', true, 'Modelo 3D en una carpeta declarada como educativa', '1.0.0');

-- Extensiones que ningún ingreso acepta (importación o carga directa).
create table public.blocked_extensions (
  extension  text primary key check (extension ~ '^[a-z0-9]{1,10}$'),
  rule_code  text not null references public.exclusion_rules (code),
  software   text not null,
  evidence   text not null check (evidence in ('verified', 'declared'))
);

insert into public.blocked_extensions (extension, rule_code, software, evidence) values
  ('dcm', 'EXC-DICOM', 'Estándar DICOM', 'verified'),
  ('dicom', 'EXC-DICOM', 'Estándar DICOM', 'verified'),
  ('sppc', 'EXC-PROYECTO-PROPLAN', 'ProPlan CMF', 'verified'),
  ('mcs', 'EXC-PROYECTO-MIMICS', 'Mimics / Mimics Medical', 'verified'),
  ('mxp', 'EXC-PROYECTO-3MATIC', '3-matic / 3-matic Medical', 'declared'),
  ('sgc', 'EXC-PROYECTO-DECLARADO', 'Por confirmar', 'declared');

create table public.blocked_mime_types (
  mime_type  text primary key check (mime_type ~ '^[a-z]+/[a-z0-9.+-]+$'),
  rule_code  text not null references public.exclusion_rules (code)
);

insert into public.blocked_mime_types (mime_type, rule_code) values
  ('application/dicom', 'EXC-DICOM'),
  ('application/sppc', 'EXC-PROYECTO-PROPLAN'),
  ('application/mcs', 'EXC-PROYECTO-MIMICS');

-- -----------------------------------------------------------------------------
-- Inventario de importación y exclusión
-- -----------------------------------------------------------------------------

create table public.source_items (
  id                  uuid primary key default gen_random_uuid(),
  source              text not null check (source in ('google_drive', 'upload')),
  -- Identificador en el origen (ID de Drive). Solo mientras el elemento está
  -- permitido o pendiente de revisión; se borra al excluirlo.
  source_ref          text check (char_length(source_ref) <= 200),
  source_fingerprint  text not null check (source_fingerprint ~ '^[0-9a-f]{64}$'),
  -- Nombre y ruta ya depurados por el importador (sin nombres de pacientes).
  display_name        text not null check (char_length(display_name) between 1 and 300),
  display_path        text check (char_length(display_path) <= 2000),
  mime_type           text,
  extension           text check (extension ~ '^[a-z0-9]{0,10}$'),
  size_bytes          bigint check (size_bytes >= 0),
  source_modified_at  timestamptz,
  decision            public.import_decision not null,
  rule_codes          text[] not null default '{}',
  -- Copia conservada cuando este elemento es un duplicado (regla EXC-DUPLICADO).
  duplicate_of        uuid references public.source_items (id) on delete restrict,
  reason              text not null check (char_length(reason) between 1 and 2000),
  detected_software   text,
  policy_version      text not null,
  evaluated_at        timestamptz not null default now(),
  reviewed_by         uuid references public.profiles (id) on delete set null,
  reviewed_at         timestamptz,
  review_notes        text check (char_length(review_notes) <= 4000),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (source, source_fingerprint),
  constraint source_items_rules_required
    check (decision = 'allowed' or cardinality(rule_codes) > 0),
  constraint source_items_excluded_without_ref
    check (decision <> 'excluded' or source_ref is null),
  constraint source_items_review_pair
    check ((reviewed_by is null) = (reviewed_at is null)),
  constraint source_items_duplicate_pair
    check ((duplicate_of is not null) = ('EXC-DUPLICADO' = any (rule_codes))),
  constraint source_items_not_self_duplicate
    check (duplicate_of is distinct from id)
);

comment on table public.source_items is
  'Inventario de importación: decisión de la política de exclusión para cada elemento de origen, antes de copiarlo.';

create index source_items_decision_idx on public.source_items (decision);

create trigger source_items_set_updated_at
  before update on public.source_items
  for each row execute function public.set_updated_at();

-- Vínculo del archivo con el elemento de origen que lo autorizó.
alter table public.files
  add column source_item_id uuid unique references public.source_items (id) on delete restrict,
  add column policy_blocked boolean not null default false,
  add constraint files_policy_blocked_is_closed check (
    not policy_blocked
    or (distribution = 'metadata_only' and not ai_processing_allowed and status <> 'published')
  );

comment on column public.files.policy_blocked is
  'El elemento de origen dejó de estar permitido: el archivo no se distribuye, no se procesa y su original se purga.';

-- La purga del original en Storage la ejecuta el worker.
alter table public.processing_jobs drop constraint processing_jobs_job_type_check;
alter table public.processing_jobs add constraint processing_jobs_job_type_check check (job_type in (
  'extract', 'metadata', 'classify', 'index', 'summarize', 'translate', 'pubmed_sync', 'media',
  'purge_original'
));

-- -----------------------------------------------------------------------------
-- Reglas de source_items
-- -----------------------------------------------------------------------------

create or replace function public.source_items_enforce_policy()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_unknown    text[];
  v_expected   public.import_decision;
  v_releasable boolean;
  v_actor      uuid := auth.uid();
begin
  -- Toda regla citada debe existir.
  select array_agg(c) into v_unknown
    from unnest(new.rule_codes) c
   where not exists (select 1 from public.exclusion_rules r where r.code = c);
  if v_unknown is not null then
    raise exception 'Reglas de exclusión desconocidas: %', v_unknown using errcode = 'check_violation';
  end if;

  select coalesce(max(r.decision), 'allowed'), coalesce(bool_and(r.releasable), true)
    into v_expected, v_releasable
    from public.exclusion_rules r
   where r.code = any (new.rule_codes);

  -- Un elemento excluido nunca conserva su identificador de origen.
  if new.decision = 'excluded' then
    new.source_ref := null;
  end if;

  if tg_op = 'INSERT' then
    -- Al evaluarse, la decisión es exactamente la más restrictiva de sus reglas.
    if new.decision <> v_expected then
      raise exception 'La decisión % no corresponde a las reglas % (se esperaba %)',
        new.decision, new.rule_codes, v_expected using errcode = 'check_violation';
    end if;
    if new.reviewed_by is not null then
      raise exception 'Un elemento recién evaluado no puede venir revisado' using errcode = 'check_violation';
    end if;
    return new;
  end if;

  if new.source_fingerprint is distinct from old.source_fingerprint
     or new.source is distinct from old.source then
    raise exception 'La huella y la fuente de un elemento no se modifican' using errcode = 'check_violation';
  end if;
  -- Las reglas solo las cambia una reevaluación del importador (service_role),
  -- nunca una persona: así nadie puede "suavizar" una exclusión antes de liberarla.
  if new.rule_codes is distinct from old.rule_codes and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Las reglas de un elemento solo cambian por una reevaluación del importador'
      using errcode = 'insufficient_privilege';
  end if;

  -- Endurecer siempre está permitido (reevaluación o decisión humana), pero
  -- la decisión no puede quedar por debajo de lo que exigen sus reglas sin revisión.
  if new.decision >= old.decision then
    if new.decision < v_expected and new.reviewed_by is null then
      raise exception 'La decisión % es más abierta que sus reglas sin revisión humana', new.decision
        using errcode = 'check_violation';
    end if;
    return new;
  end if;

  -- Liberar (pasar a una decisión menos restrictiva) exige revisión humana.
  if v_actor is null or new.reviewed_by is distinct from v_actor
     or new.reviewed_at is null or coalesce(trim(new.review_notes), '') = '' then
    raise exception 'Liberar un elemento exige revisión humana registrada (revisor, fecha y fundamento)'
      using errcode = 'insufficient_privilege';
  end if;
  if old.decision = 'review_required' then
    if not public.user_has_role(v_actor, 'editor') then
      raise exception 'Solo un editor puede aprobar un elemento con revisión individual'
        using errcode = 'insufficient_privilege';
    end if;
  elsif not public.user_has_role(v_actor, 'admin') then
    raise exception 'Solo un administrador puede liberar un elemento en cuarentena o excluido'
      using errcode = 'insufficient_privilege';
  end if;
  if old.decision = 'excluded' and not v_releasable then
    raise exception 'Las reglas % son exclusiones permanentes y no se pueden liberar', new.rule_codes
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger source_items_enforce_policy
  before insert or update on public.source_items
  for each row execute function public.source_items_enforce_policy();

-- Si un elemento deja de estar permitido, su archivo se bloquea y se purga.
create or replace function public.source_items_block_files()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_file public.files%rowtype;
begin
  if new.decision = 'allowed' then
    return new;
  end if;
  for v_file in select * from public.files where source_item_id = new.id and not policy_blocked loop
    update public.files
       set policy_blocked = true,
           distribution = 'metadata_only',
           ai_processing_allowed = false,
           status = case when status = 'published' then 'archived'::public.content_status else status end
     where id = v_file.id;
    -- files_propagate_restrictions ya eliminó los fragmentos. Además se borran el
    -- texto extraído y los derivados: no debe quedar contenido del archivo.
    delete from public.extractions where file_id = v_file.id;
    delete from public.translations where file_id = v_file.id;
    delete from public.summaries where file_id = v_file.id;
    update public.processing_jobs
       set status = 'cancelled', finished_at = now(), last_error = 'Bloqueado por la política de exclusión'
     where file_id = v_file.id and status in ('queued', 'running');
    insert into public.processing_jobs (job_type, file_id, payload, priority)
    values ('purge_original', v_file.id,
            jsonb_build_object('storage_bucket', v_file.storage_bucket, 'storage_path', v_file.storage_path,
                               'source_item_id', new.id),
            100);
  end loop;
  return new;
end;
$$;

create trigger source_items_block_files
  after update of decision on public.source_items
  for each row execute function public.source_items_block_files();

-- Auditoría propia: registra la decisión y las reglas, nunca el identificador de origen.
create or replace function public.source_items_audit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.audit_log (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), lower(tg_op), 'source_items', new.id::text,
    jsonb_build_object(
      'old_decision', case when tg_op = 'UPDATE' then old.decision end,
      'new_decision', new.decision,
      'rule_codes', new.rule_codes,
      'policy_version', new.policy_version,
      'reviewed_by', new.reviewed_by,
      'review_notes', new.review_notes
    )
  );
  return new;
end;
$$;

create trigger source_items_audit
  after insert or update of decision, rule_codes, reviewed_by, review_notes on public.source_items
  for each row execute function public.source_items_audit();

-- -----------------------------------------------------------------------------
-- Reglas de files
-- -----------------------------------------------------------------------------

create or replace function public.files_enforce_exclusion_policy()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ext      text := lower(substring(new.original_filename from '\.([A-Za-z0-9]{1,10})$'));
  v_rule     text;
  v_decision public.import_decision;
begin
  select rule_code into v_rule from public.blocked_extensions where extension = v_ext;
  if v_rule is null then
    select rule_code into v_rule from public.blocked_mime_types where mime_type = lower(new.mime_type);
  end if;
  if v_rule is null and lower(new.original_filename) = 'dicomdir' then
    v_rule := 'EXC-DICOM';
  end if;
  if v_rule is not null then
    raise exception 'Archivo excluido por la política documental (%): %', v_rule, new.original_filename
      using errcode = 'check_violation';
  end if;

  if new.source_item_id is not null
     and (tg_op = 'INSERT' or new.source_item_id is distinct from old.source_item_id
          or (old.policy_blocked and not new.policy_blocked)) then
    select decision into v_decision from public.source_items where id = new.source_item_id;
    if v_decision <> 'allowed' then
      raise exception 'El elemento de origen está en estado % y no puede tener un archivo activo', v_decision
        using errcode = 'check_violation';
    end if;
  end if;

  if tg_op = 'INSERT' and new.policy_blocked then
    raise exception 'No se crean archivos bloqueados' using errcode = 'check_violation';
  end if;
  if tg_op = 'UPDATE' and old.policy_blocked and not new.policy_blocked and new.source_item_id is null then
    raise exception 'Un archivo bloqueado sin elemento de origen no se desbloquea' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger files_enforce_exclusion_policy
  before insert or update of original_filename, mime_type, source_item_id, policy_blocked on public.files
  for each row execute function public.files_enforce_exclusion_policy();

drop trigger files_audit on public.files;
create trigger files_audit
  after insert or update of distribution, allowed_roles, ai_processing_allowed, status, policy_blocked or delete
  on public.files
  for each row execute function public.audit_row_change();

-- Ningún trabajo de procesamiento (salvo la purga) sobre un archivo bloqueado.
create or replace function public.processing_jobs_respect_policy()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.file_id is not null and new.job_type <> 'purge_original'
     and exists (select 1 from public.files f where f.id = new.file_id and f.policy_blocked) then
    raise exception 'El archivo % está bloqueado por la política de exclusión', new.file_id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger processing_jobs_respect_policy
  before insert or update of file_id, job_type, status on public.processing_jobs
  for each row
  when (new.status in ('queued', 'running'))
  execute function public.processing_jobs_respect_policy();

-- Un archivo bloqueado solo lo ve un administrador (para revisar o purgar).
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
        (f.policy_blocked and public.has_role('admin'))
        or (
          not f.policy_blocked
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
        )
      )
  );
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

-- La política "for all" de 0400 también concedía SELECT a los editores y se
-- saltaba can_read_file(): un editor habría visto archivos bloqueados. Se separa
-- en inserción, modificación y eliminación; la lectura queda solo en files_select.
drop policy files_editor_write on public.files;
create policy files_editor_insert on public.files
  for insert to authenticated
  with check ((select public.has_role('editor')));
create policy files_editor_update on public.files
  for update to authenticated
  using ((select public.has_role('admin')) or ((select public.has_role('editor')) and not policy_blocked))
  with check ((select public.has_role('editor')));
create policy files_editor_delete on public.files
  for delete to authenticated
  using ((select public.has_role('admin')) or ((select public.has_role('editor')) and not policy_blocked));

alter table public.exclusion_rules    enable row level security;
alter table public.blocked_extensions enable row level security;
alter table public.blocked_mime_types enable row level security;
alter table public.source_items       enable row level security;

-- Las reglas son transparentes para el equipo editorial; solo cambian por migración.
create policy exclusion_rules_select on public.exclusion_rules
  for select to authenticated using ((select public.has_role('editor')));
create policy blocked_extensions_select on public.blocked_extensions
  for select to authenticated using ((select public.has_role('editor')));
create policy blocked_mime_types_select on public.blocked_mime_types
  for select to authenticated using ((select public.has_role('editor')));

-- El inventario puede describir material clínico: solo el administrador lo ve.
-- Los editores ven únicamente lo que les toca revisar (presentaciones y similares)
-- y lo que ellos mismos revisaron.
-- El importador escribe con service_role; nadie lo borra desde el cliente.
create policy source_items_select on public.source_items
  for select to authenticated
  using (
    (select public.has_role('admin'))
    or ((select public.has_role('editor'))
        and (decision = 'review_required' or reviewed_by = (select auth.uid())))
  );
create policy source_items_review on public.source_items
  for update to authenticated
  using (
    (select public.has_role('admin'))
    or (decision = 'review_required' and (select public.has_role('editor')))
  )
  with check ((select public.has_role('editor')));

revoke execute on function public.source_items_enforce_policy() from public, anon, authenticated;
revoke execute on function public.source_items_block_files() from public, anon, authenticated;
revoke execute on function public.source_items_audit() from public, anon, authenticated;
revoke execute on function public.files_enforce_exclusion_policy() from public, anon, authenticated;
revoke execute on function public.processing_jobs_respect_policy() from public, anon, authenticated;
