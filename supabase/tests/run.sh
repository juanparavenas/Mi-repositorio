#!/usr/bin/env bash
# =============================================================================
# Ejecuta las pruebas del modelo de datos de CMF Academy.
#
# Crea una base de datos desechable, aplica la simulación de Supabase, las
# migraciones en orden, las funciones auxiliares y la semilla; luego corre cada
# archivo de supabase/tests/*.test.sql dentro de una transacción que se revierte.
#
# Requiere PostgreSQL 15+ con las extensiones vector, ltree, pg_trgm, unaccent
# y citext. Usa las variables estándar de libpq (PGHOST, PGPORT, PGUSER,
# PGPASSWORD). Uso:
#
#   PGHOST=localhost PGUSER=postgres supabase/tests/run.sh
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DB="${TEST_DB:-cmf_academy_test}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)

if [[ ! "$TEST_DB" =~ ^[a-z_][a-z0-9_]*$ ]]; then
  echo "Nombre de base de datos de prueba no válido: $TEST_DB" >&2
  exit 2
fi

echo "==> Creando base de datos de prueba: $TEST_DB"
"${PSQL[@]}" -d postgres -c "drop database if exists $TEST_DB" -c "create database $TEST_DB"
"${PSQL[@]}" -d "$TEST_DB" -c "alter database $TEST_DB set search_path = \"\$user\", public, extensions"

run_file() {
  "${PSQL[@]}" -d "$TEST_DB" -f "$1"
}

echo "==> Simulación de Supabase"
run_file "$ROOT/supabase/tests/support/supabase_stub.sql"

echo "==> Migraciones"
for migration in "$ROOT"/supabase/migrations/*.sql; do
  echo "    $(basename "$migration")"
  run_file "$migration"
done

echo "==> Auxiliares de prueba y semilla"
run_file "$ROOT/supabase/tests/support/helpers.sql"
run_file "$ROOT/supabase/seed.sql"
# La semilla debe ser idempotente.
run_file "$ROOT/supabase/seed.sql"

echo "==> Pruebas"
passed=0
failed=0
for test_file in "$ROOT"/supabase/tests/*.test.sql; do
  name="$(basename "$test_file")"
  if output="$("${PSQL[@]}" -d "$TEST_DB" -f "$test_file" 2>&1)"; then
    echo "    ok    $name"
    passed=$((passed + 1))
  else
    echo "    FALLÓ $name"
    echo "$output" | sed 's/^/          /'
    failed=$((failed + 1))
  fi
done

echo "==> Resultado: $passed archivos aprobados, $failed con fallas"
if [[ "${KEEP_TEST_DB:-0}" != "1" ]]; then
  "${PSQL[@]}" -d postgres -c "drop database if exists $TEST_DB"
fi
[[ $failed -eq 0 ]]
