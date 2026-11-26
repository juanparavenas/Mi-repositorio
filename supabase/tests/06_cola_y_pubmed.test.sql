-- Prueba 06 · Cola de trabajos (reintentos, concurrencia) y programación de
-- sincronizaciones con PubMed. No contacta a NCBI.
begin;

do $$
declare
  v_member  uuid := tests.create_user('miembro.cola@example.test');
  v_root    uuid;
  v_job     uuid;
  v_first   uuid[];
  v_second  uuid[];
  v_status  public.job_status;
  v_count   integer;
begin
  insert into public.processing_jobs (job_type, payload) values
    ('extract', '{"n": 1}'), ('extract', '{"n": 2}'), ('metadata', '{"n": 3}');

  -- Dos tomas consecutivas nunca entregan el mismo trabajo.
  select array_agg(id) into v_first from public.claim_jobs('worker-a', 2);
  select array_agg(id) into v_second from public.claim_jobs('worker-b', 2);
  perform tests.assert_eq(cardinality(v_first), 2, 'el primer worker toma 2 trabajos');
  perform tests.assert_eq(cardinality(v_second), 1, 'el segundo worker toma el restante');
  perform tests.assert(not (v_first && v_second), 'no hay trabajos duplicados entre workers');
  perform tests.assert_eq((select count(*)::integer from public.claim_jobs('worker-c', 5)), 0,
    'no quedan trabajos disponibles');

  -- Filtro por tipo.
  insert into public.processing_jobs (job_type) values ('translate'), ('summarize');
  perform tests.assert_eq((select job_type from public.claim_jobs('worker-d', 5, array['summarize'])), 'summarize',
    'el worker puede tomar solo un tipo de trabajo');

  -- Completar registra el costo.
  perform public.complete_job(v_first[1], 0.0123);
  perform tests.assert_eq((select status from public.processing_jobs where id = v_first[1]),
    'succeeded'::public.job_status, 'trabajo completado');
  perform tests.assert_eq((select cost_usd from public.processing_jobs where id = v_first[1]),
    0.0123::numeric(10, 4), 'se registra el costo del trabajo');

  -- Reintentos con espera y falla definitiva al agotar intentos.
  insert into public.processing_jobs (job_type, max_attempts) values ('index', 2) returning id into v_job;
  perform public.claim_jobs('worker-e', 1, array['index']);
  v_status := public.fail_job(v_job, 'Error transitorio de red', interval '1 minute');
  perform tests.assert_eq(v_status, 'queued'::public.job_status, 'el primer fallo se reintenta');
  perform tests.assert((select run_after > now() from public.processing_jobs where id = v_job),
    'el reintento espera antes de volver a correr');
  perform tests.assert_eq((select count(*)::integer from public.claim_jobs('worker-e', 1, array['index'])), 0,
    'un trabajo en espera no se toma antes de tiempo');

  update public.processing_jobs set run_after = now() where id = v_job;
  perform public.claim_jobs('worker-e', 1, array['index']);
  v_status := public.fail_job(v_job, 'Error persistente');
  perform tests.assert_eq(v_status, 'failed'::public.job_status, 'tras agotar los intentos queda fallido');
  perform tests.assert_eq((select last_error from public.processing_jobs where id = v_job), 'Error persistente',
    'se conserva el último error');

  -- PubMed: se encola una sincronización por consulta vencida, sin duplicar.
  select id into v_root from public.topics where parent_id is null and slug = 'cirugia-oral-y-maxilofacial';
  insert into public.pubmed_queries (topic_id, query_term, next_run_at)
  values (v_root, '"Temporomandibular Joint"[MeSH] AND discopexy', now() - interval '1 hour');

  perform tests.assert_eq(public.enqueue_due_pubmed_syncs(), 1, 'se encola la consulta vencida');
  perform tests.assert_eq(public.enqueue_due_pubmed_syncs(), 0, 'no se encola dos veces');
  select count(*) into v_count from public.processing_jobs where job_type = 'pubmed_sync';
  perform tests.assert_eq(v_count, 1, 'existe un único trabajo de sincronización');
  perform tests.assert((select next_run_at > now() + interval '6 days' from public.pubmed_queries limit 1),
    'la siguiente ejecución queda programada según la frecuencia');

  -- Los clientes no operan la cola.
  perform tests.authenticate_as(v_member);
  perform tests.assert_raises('select * from public.claim_jobs(''intruso'', 1)',
    'un usuario no puede tomar trabajos', '42501');
  perform tests.assert_eq((select count(*)::integer from public.processing_jobs), 0,
    'un usuario no ve la cola');
  perform tests.clear_authentication();
end;
$$;

rollback;
