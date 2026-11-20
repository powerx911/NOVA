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

  if [[ "$filename" == 20261120235000_nova_company_founding_parity_repair.sql ]]; then
    psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/ci/replay_patches/prepare_company_founding_parity.sql
  fi

  echo "Applying isolated E2E migration: $filename"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration"
done < <(find supabase/migrations -maxdepth 1 -type f -name '*.sql' -print0 | sort -z)

supabase test db
