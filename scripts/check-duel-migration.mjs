import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
const sql=readFileSync("supabase/migrations/20261118174000_nova_competitive_duels.sql","utf8");
assert.match(sql,/create table if not exists public\.nova_competitive_battles/i);
assert.match(sql,/alter table public\.nova_competitive_battles enable row level security/i);
assert.match(sql,/auth\.uid\(\)[\s\S]*?challenger_id[\s\S]*?defender_id/i);
for (const fn of ["nova_challenge_player","nova_accept_challenge","nova_decline_challenge"]) {
  assert.ok(sql.includes("create or replace function private."+fn), "missing private battle implementation: "+fn);
  assert.ok(sql.includes("create or replace function public."+fn), "missing public battle wrapper: "+fn);
  assert.ok(sql.includes("grant execute on function private."+fn), "missing private battle grant: "+fn);
  assert.ok(sql.includes("grant execute on function public."+fn), "missing public battle grant: "+fn);
  assert.ok(sql.includes("revoke all on function public."+fn), "public battle wrapper must revoke public/anon: "+fn);
}
assert.match(sql,/winner_id uuid references auth\.users\(id\) on delete set null/i);
assert.match(sql,/nova_competitive_battles_pending_pair_idx/i);
assert.match(sql,/Only the challenged player can accept/i);
assert.match(sql,/Only the challenged player can decline/i);
assert.match(sql,/You cannot challenge yourself/i);
assert.match(sql,/You already have three pending challenges/i);
assert.match(sql,/floor\(random\(\)\*101\)/i,"battle scores must be server-generated");
assert.match(sql,/nova_regenerate_energy/i,"energy must regenerate server-side");
assert.match(sql,/energy_updated_at/i,"energy regeneration must persist its clock");
assert.match(sql,/interval '5 minutes'/i,"energy regeneration rate must be explicit");
assert.match(sql,/revoke all on function private\.nova_regenerate_energy\(uuid\)/i,"energy helper must not be directly executable");
assert.match(sql,/grant execute on function public\.nova_competitive_refresh_energy\(\) to authenticated/i);
assert.match(sql,/alter publication supabase_realtime add table public\.nova_competitive_battles/i);
assert.doesNotMatch(sql,/create policy[^;]+on public\.nova_competitive_battles for (insert|update|delete)/i,"clients must not write battle outcomes");
assert.match(sql,/status='resolved'[\s\S]*?winner_id=v_winner_id/i,"resolved battles must persist the server winner");
console.log("NOVA competitive duel security-contract checks passed.");
