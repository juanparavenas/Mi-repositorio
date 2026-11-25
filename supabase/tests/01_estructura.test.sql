-- Prueba 01 · Reglas estructurales que deben cumplir todas las migraciones.
begin;

do $$
declare
  r record;
begin
  -- Toda tabla de public tiene RLS activada (denegar por defecto).
  for r in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  loop
    raise exception 'FALLÓ: la tabla public.% no tiene RLS', r.relname;
  end loop;

  -- Toda tabla tiene clave primaria.
  for r in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
       and not exists (select 1 from pg_constraint k where k.conrelid = c.oid and k.contype = 'p')
  loop
    raise exception 'FALLÓ: la tabla public.% no tiene clave primaria', r.relname;
  end loop;

  -- Toda vista respeta la RLS de quien consulta.
  for r in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'v'
       and not coalesce('security_invoker=true' = any (c.reloptions), false)
  loop
    raise exception 'FALLÓ: la vista public.% no usa security_invoker', r.relname;
  end loop;

  -- Toda función SECURITY DEFINER fija su search_path.
  for r in
    select p.proname
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef
       and not exists (
         select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%'
       )
  loop
    raise exception 'FALLÓ: la función public.% es SECURITY DEFINER sin search_path', r.proname;
  end loop;

  -- Las funciones de operación interna no son invocables desde el cliente.
  for r in
    select unnest(array[
      'public.ai_try_consume(text, boolean)',
      'public.ai_record_usage(text, text, text, integer, integer, numeric, integer, integer)',
      'public.ai_month_spend()',
      'public.ai_budget_remaining()',
      'public.app_setting(text)',
      'public.claim_jobs(text, integer, text[])',
      'public.complete_job(uuid, numeric)',
      'public.fail_job(uuid, text, interval)',
      'public.enqueue_due_pubmed_syncs()',
      'public.user_has_role(uuid, public.app_role)',
      'public.files_propagate_restrictions()'
    ]) as fn
  loop
    perform tests.assert(not has_function_privilege('anon', r.fn, 'execute'),
      format('anon no debe ejecutar %s', r.fn));
    perform tests.assert(not has_function_privilege('authenticated', r.fn, 'execute'),
      format('authenticated no debe ejecutar %s', r.fn));
  end loop;

  -- El servidor sí puede operar la cola y las cuotas.
  perform tests.assert(has_function_privilege('service_role', 'public.claim_jobs(text, integer, text[])', 'execute'),
    'service_role ejecuta claim_jobs');
  perform tests.assert(has_function_privilege('service_role', 'public.ai_try_consume(text, boolean)', 'execute'),
    'service_role ejecuta ai_try_consume');

  -- La auditoría es de solo inserción para los clientes.
  perform tests.assert(not has_table_privilege('authenticated', 'public.audit_log', 'update'),
    'authenticated no puede modificar la auditoría');
  perform tests.assert(not has_table_privilege('authenticated', 'public.audit_log', 'delete'),
    'authenticated no puede borrar la auditoría');

  -- Valores iniciales seguros: IA apagada y presupuesto 0.
  perform tests.assert_eq((select value #>> '{}' from public.app_settings where key = 'ai.public_enabled'),
    'false', 'la IA parte apagada');
  perform tests.assert_eq((select value #>> '{}' from public.app_settings where key = 'ai.monthly_budget_usd'),
    '0', 'el presupuesto de IA parte en 0');
  perform tests.assert_eq((select value #>> '{}' from public.app_settings where key = 'ai.daily_quota.anonymous'),
    '3', 'cuota de visitantes = 3');
  perform tests.assert_eq((select value #>> '{}' from public.app_settings where key = 'ai.daily_quota.member'),
    '10', 'cuota de registrados = 10');
end;
$$;

rollback;
