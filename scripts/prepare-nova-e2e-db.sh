#!/usr/bin/env bash
set -euo pipefail

eval "$(supabase status -o env)"
: "${DB_URL:?Supabase local DB_URL is required}"

# The checked-in production snapshot is the data-free baseline through
# 20261120202341. Replay every later migration in timestamp order so this
# environment follows the current branch without relying on a stale hardcoded list.
psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/ci/nexora_production_schema_snapshot.sql

while IFS= read -r -d '' migration; do
  filename="$(basename "$migration")"
  version="${filename:0:14}"
  [[ "$version" =~ ^[0-9]{14}$ ]] || continue
  [[ "$version" > "20261120202341" ]] || continue

  # The checked-in full production snapshot already contains the 2026-11-21
  # hardening state. These source migrations use strict text anchors that are
  # intentionally absent once their final functions are in the snapshot.
  # Skip that replay window and verify the resulting functions, RLS and indexes below.
  if [[ "$version" > "20261120235700" ]]; then
    echo "Snapshot already includes this hardening state; verifying instead of replaying: $filename"
    continue
  fi

  if [[ "$filename" == 20261120235000_nova_company_founding_parity_repair.sql ]]; then
    psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/ci/replay_patches/prepare_company_founding_parity.sql
  fi

  echo "Applying isolated E2E migration: $filename"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration"
done < <(find supabase/migrations -maxdepth 1 -type f -name '*.sql' -print0 | sort -z)

# Expose nexora only after the schema exists, then refresh PostgREST's configuration and cache.
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "GRANT USAGE ON SCHEMA nexora TO authenticator;"
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "ALTER ROLE authenticator SET pgrst.db_schemas = 'public, graphql_public, nexora';"
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "NOTIFY pgrst, 'reload config';"
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "NOTIFY pgrst, 'reload schema';"

# Deterministic system listing for the browser smoke test (the snapshot is data-free).
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "
  INSERT INTO nexora.market_listings
    (id, seller_uid, seller_name, item_id, quantity, remaining_qty, unit_price, status)
  VALUES
    ('nova-e2e-system-silicon', 'SYSTEM', 'NOVA', 'silicon_ore', 10, 10, 10, 'active')
  ON CONFLICT (id) DO UPDATE SET
    remaining_qty = EXCLUDED.remaining_qty,
    status = 'active',
    updated_at = now();
"

psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/ci/verify_production_schema_snapshot.sql

# pgTAP migration-chain suites run in the dedicated NOVA database-test workflow;
# this snapshot-backed browser environment validates schema parity, then exercises the live API.
