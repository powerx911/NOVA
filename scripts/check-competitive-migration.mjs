import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
const sql = readFileSync("supabase/migrations/20261118170000_nova_competitive_core.sql", "utf8");
const tables = ["nova_competitive_profiles","nova_competitive_wallets","nova_competitive_assets","nova_competitive_commands","nova_competitive_ledger","nova_competitive_activities"];
for (const table of tables) {
  assert.match(sql, new RegExp(`create table if not exists public\\.${table}\\b`, "i"), `missing table: ${table}`);
  assert.match(sql, new RegExp(`alter table public\\.${table} enable row level security`, "i"), `RLS missing: ${table}`);
}
for (const fn of ["nova_competitive_initialize","nova_competitive_simulate","nova_competitive_upgrade_asset","nova_competitive_leaderboard"]) {
  assert.match(sql, new RegExp(`create or replace function private\\.${fn}\\(`, "i"), `private implementation missing: ${fn}`);
  assert.match(sql, new RegExp(`create or replace function public\\.${fn}\\([\\s\\S]*?security invoker`, "i"), `public wrapper must be SECURITY INVOKER: ${fn}`);
}
assert.match(sql, /perform pg_advisory_xact_lock/i, "commands must be serialized for idempotency");
assert.match(sql, /where id = p_asset_id and user_id = v_user_id for update/i, "asset ownership must be checked");
assert.match(sql, /if v_wallet\.energy < 10/i, "operation energy cost must be validated server-side");
assert.match(sql, /unique \(user_id, command_id\)/i, "commands need per-player idempotency");
assert.match(sql, /grant execute on function private\.nova_competitive_leaderboard\(\) to anon, authenticated/i);
assert.match(sql, /grant execute on function public\.nova_competitive_leaderboard\(\) to anon, authenticated/i);
assert.match(sql, /alter publication supabase_realtime add table public\.nova_competitive_activities/i, "public activity must be realtime-enabled");
assert.match(sql, /revoke all on public\.nova_competitive_profiles[\s\S]*?from public, anon, authenticated/i);
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_competitive_wallets for (insert|update|delete)/i, "clients must not mutate wallets directly");
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_competitive_assets for (insert|update|delete)/i, "clients must not mutate assets directly");
console.log("NOVA competitive migration security-contract checks passed.");
