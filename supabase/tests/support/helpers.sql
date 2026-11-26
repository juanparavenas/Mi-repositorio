-- =============================================================================
-- Funciones auxiliares para las pruebas de base de datos.
-- Se cargan después de las migraciones y solo existen en la base de pruebas.
-- =============================================================================

create schema if not exists tests;
grant usage on schema tests to anon, authenticated, service_role;

create or replace function tests.assert(condition boolean, message text)
returns void
language plpgsql
as $$
begin
  if condition is not true then
    raise exception 'FALLÓ: %', message;
  end if;
end;
$$;

create or replace function tests.assert_eq(actual anyelement, expected anyelement, message text)
returns void
language plpgsql
as $$
begin
  if actual is distinct from expected then
    raise exception 'FALLÓ: % (esperado: %, obtenido: %)', message, expected, actual;
  end if;
end;
$$;

-- Ejecuta la sentencia y exige que falle (opcionalmente con un SQLSTATE dado).
create or replace function tests.assert_raises(statement text, message text, expected_sqlstate text default null)
returns void
language plpgsql
as $$
begin
  begin
    execute statement;
  exception when others then
    if expected_sqlstate is not null and sqlstate <> expected_sqlstate then
      raise exception 'FALLÓ: % (se esperaba SQLSTATE %, se obtuvo %: %)',
        message, expected_sqlstate, sqlstate, sqlerrm;
    end if;
    return;
  end;
  raise exception 'FALLÓ: % (la sentencia no produjo error)', message;
end;
$$;

-- Crea una cuenta (dispara handle_new_user) y le asigna un rol adicional.
create or replace function tests.create_user(p_email text, p_role public.app_role default 'member')
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  insert into auth.users (email) values (p_email) returning id into v_id;
  if p_role <> 'member' then
    insert into public.user_roles (user_id, role) values (v_id, p_role);
  end if;
  return v_id;
end;
$$;

-- Simula una petición de un usuario autenticado (como PostgREST).
create or replace function tests.authenticate_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;

-- Simula una petición de un visitante sin registro.
create or replace function tests.authenticate_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
end;
$$;

-- Simula el servidor con la clave secreta (service_role).
create or replace function tests.authenticate_service()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
end;
$$;

-- Vuelve al superusuario de la prueba.
create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end;
$$;

grant execute on all functions in schema tests to anon, authenticated, service_role;
