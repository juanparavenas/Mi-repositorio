-- Prueba 05 · Cuotas diarias, presupuesto global e interruptor del asistente
-- (decisión 2 de la fase 0, ADR-0007).
begin;

do $$
declare
  v_admin    uuid := tests.create_user('admin.ia@example.test', 'admin');
  v_member   uuid := tests.create_user('miembro.ia@example.test');
  v_visitor  text := 'visitor:' || repeat('a', 64);
  v_visitor2 text := 'visitor:' || repeat('b', 64);
  v_user     text;
  v_result   record;
  i          integer;
begin
  v_user := 'user:' || v_member::text;

  -- Estado inicial: apagado.
  select * into v_result from public.ai_try_consume(v_visitor, false);
  perform tests.assert_eq(v_result.reason, 'service_disabled', 'la IA parte apagada');

  -- El administrador la enciende con un presupuesto (simulado en la prueba).
  update public.app_settings set value = 'true' where key = 'ai.public_enabled';
  update public.app_settings set value = '150' where key = 'ai.monthly_budget_usd';

  -- Visitante: 3 consultas diarias.
  for i in 1..3 loop
    select * into v_result from public.ai_try_consume(v_visitor, false);
    perform tests.assert(v_result.allowed, format('consulta %s del visitante permitida', i));
  end loop;
  perform tests.assert_eq(v_result.remaining, 0, 'tras la tercera consulta no quedan disponibles');
  select * into v_result from public.ai_try_consume(v_visitor, false);
  perform tests.assert(not v_result.allowed, 'la cuarta consulta del visitante se rechaza');
  perform tests.assert_eq(v_result.reason, 'daily_quota_exceeded', 'motivo: cuota diaria');

  -- La cuota es por visitante.
  select * into v_result from public.ai_try_consume(v_visitor2, false);
  perform tests.assert(v_result.allowed, 'otro visitante tiene su propia cuota');

  -- Registrado: 10 consultas diarias.
  for i in 1..10 loop
    select * into v_result from public.ai_try_consume(v_user, true);
    perform tests.assert(v_result.allowed, format('consulta %s del usuario registrado permitida', i));
  end loop;
  select * into v_result from public.ai_try_consume(v_user, true);
  perform tests.assert(not v_result.allowed, 'la consulta 11 del registrado se rechaza');

  -- Los límites son editables sin cambiar código.
  update public.app_settings set value = '12' where key = 'ai.daily_quota.member';
  select * into v_result from public.ai_try_consume(v_user, true);
  perform tests.assert(v_result.allowed, 'al subir la cuota a 12, se habilita una consulta más');

  -- Presupuesto: al llegar al tope, el servicio se restringe solo.
  perform public.ai_record_usage('system:worker', 'summarize', 'claude-sonnet-5-5', 1000, 500, 119.50);
  perform tests.authenticate_service();
  perform tests.assert_eq((select alert from public.ai_budget_status()), false, 'sin alerta bajo el 80%');
  perform tests.clear_authentication();
  perform public.ai_record_usage(v_user, 'assistant', 'claude-sonnet-5-5', 1000, 500, 0.50);
  perform tests.authenticate_service();
  perform tests.assert_eq((select alert from public.ai_budget_status()), true, 'alerta al llegar al 80%');
  perform tests.clear_authentication();
  perform public.ai_record_usage(v_user, 'assistant', 'claude-sonnet-5-5', 1000, 500, 30.00);
  perform tests.assert_eq(public.ai_budget_remaining(), 0::numeric, 'presupuesto agotado');
  select * into v_result from public.ai_try_consume(v_visitor2, false);
  perform tests.assert_eq(v_result.reason, 'budget_exhausted', 'al agotar el presupuesto se corta el servicio');

  -- Interruptor manual del administrador.
  update public.app_settings set value = '1000' where key = 'ai.monthly_budget_usd';
  update public.app_settings set value = 'false' where key = 'ai.public_enabled';
  select * into v_result from public.ai_try_consume(v_visitor2, false);
  perform tests.assert_eq(v_result.reason, 'service_disabled', 'el administrador puede apagar el servicio');

  -- Los cambios de configuración quedan auditados.
  perform tests.assert((select count(*) from public.audit_log where entity_type = 'app_settings') >= 5,
    'cada cambio de configuración queda en la auditoría');

  -- Ningún cliente puede saltarse la cuota llamando a la función directamente.
  perform tests.authenticate_anon();
  perform tests.assert_raises(format('select * from public.ai_try_consume(%L, true)', v_visitor),
    'el visitante no puede invocar ai_try_consume', '42501');
  perform tests.clear_authentication();

  perform tests.authenticate_as(v_member);
  perform tests.assert_raises('select * from public.ai_budget_status()',
    'un miembro no puede ver el presupuesto', '42501');
  -- Con RLS, la actualización no encuentra filas visibles y no cambia nada.
  update public.app_settings set value = 'true' where key = 'ai.public_enabled';
  perform tests.clear_authentication();
  perform tests.assert_eq((select value #>> '{}' from public.app_settings where key = 'ai.public_enabled'),
    'false', 'un miembro no puede encender la IA');

  perform tests.authenticate_as(v_admin);
  perform tests.assert((select monthly_budget_usd from public.ai_budget_status()) = 1000,
    'el administrador consulta el presupuesto');
  perform tests.clear_authentication();
end;
$$;

rollback;
