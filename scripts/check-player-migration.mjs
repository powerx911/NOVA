import { readFileSync } from 'node:fs'
import { strict as assert } from 'node:assert'

const sql = readFileSync('supabase/migrations/20261118160000_nova_player_core.sql', 'utf8')
const tables = [
  'nova_player_profiles',
  'nova_player_economy',
  'nova_castles',
  'nova_buildings',
  'nova_command_receipts',
  'nova_resource_ledger',
]

for (const table of tables) {
  assert.match(sql, new RegExp('create table if not exists public\\.' + table + '\\b', 'i'), `missing table: ${table}`)
  assert.match(sql, new RegExp('alter table public\\.' + table + ' enable row level security', 'i'), `RLS is not enabled: ${table}`)
}

assert.match(sql, /create or replace function public\.nova_initialize_player\([\s\S]*?security definer/i)
assert.match(sql, /create or replace function public\.nova_upgrade_building\([\s\S]*?security definer/i)
assert.match(sql, /revoke all on function public\.nova_initialize_player\(text\) from public, anon/i)
assert.match(sql, /revoke all on function public\.nova_upgrade_building\(uuid, uuid\) from public, anon/i)
assert.match(sql, /grant execute on function public\.nova_initialize_player\(text\) to authenticated/i)
assert.match(sql, /grant execute on function public\.nova_upgrade_building\(uuid, uuid\) to authenticated/i)
assert.match(sql, /revoke all on public\\.nova_player_profiles[\\s\\S]*?from public, anon, authenticated/i, 'table privileges must be explicitly revoked before narrow grants')
assert.match(sql, /perform pg_advisory_xact_lock/i, 'command retries must be serialized')
assert.match(sql, /where b\.id = p_building_id and c\.user_id = v_user_id/i, 'building ownership must be checked')
assert.match(sql, /insert into public\.nova_resource_ledger/i, 'resource mutations must be auditable')
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_player_economy for (insert|update|delete)/i, 'clients must not directly mutate economy')
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_buildings for (insert|update|delete)/i, 'clients must not directly mutate buildings')

console.log('NOVA player migration security-contract checks passed.')
