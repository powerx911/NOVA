import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
const sql = readFileSync("supabase/migrations/20261118172000_nova_shared_market.sql", "utf8");
const tables = ["nova_competitive_inventory","nova_market_listings","nova_market_orders","nova_market_inventory_ledger"];
for (const table of tables) {
  assert.match(sql, new RegExp("create table if not exists public\\." + table + "\\b", "i"), "missing market table: " + table);
  assert.match(sql, new RegExp("alter table public\\." + table + " enable row level security", "i"), "RLS missing: " + table);
}
for (const fn of ["nova_market_create_listing","nova_market_buy_listing","nova_market_cancel_listing"]) {
  assert.match(sql, new RegExp("create or replace function private\\." + fn + "\\(", "i"), "private implementation missing: " + fn);
  assert.match(sql, new RegExp("create or replace function public\\." + fn + "\\([\\s\\S]*?security invoker", "i"), "public wrapper must be SECURITY INVOKER: " + fn);
  assert.match(sql, new RegExp("grant execute on function public\\." + fn + "\\(", "i"), "public wrapper grant missing: " + fn);
}
assert.match(sql, /seller_id = v_user_id[\s\S]*?You cannot buy your own listing/i, "self-purchases must be blocked");
assert.match(sql, /where id = p_listing_id and seller_id = v_user_id[\s\S]*?for update/i, "listing cancellation must verify seller ownership");
assert.match(sql, /order by w\.user_id for update/i, "buyer/seller wallet locks must use deterministic order");
assert.match(sql, /credits = credits - v_total/i, "buyer must pay atomically");
assert.match(sql, /credits = credits \+ v_total/i, "seller must receive funds atomically");
assert.match(sql, /insert into public\.nova_market_orders/i, "purchases must create an order record");
assert.match(sql, /insert into public\.nova_competitive_commands/i, "market commands must be idempotently recorded");
assert.match(sql, /insert into public\.nova_market_inventory_ledger/i, "inventory movements must be auditable");
assert.match(sql, /after insert on public\.nova_competitive_profiles/i, "new players must receive starter inventory");
assert.match(sql, /p_item_code is null or p_item_code not in/i, "item codes must be validated");
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_competitive_inventory for (insert|update|delete)/i, "clients must not write inventory directly");
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_market_listings for (insert|update|delete)/i, "clients must not write listings directly");
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_market_orders for (insert|update|delete)/i, "clients must not write orders directly");
assert.doesNotMatch(sql, /create policy[^;]+on public\.nova_market_inventory_ledger for (insert|update|delete)/i, "clients must not write the inventory ledger directly");
assert.match(sql, /revoke all on function public\.nova_market_create_listing\(uuid,text,integer,bigint\) from public, anon/i);
assert.match(sql, /revoke all on function public\.nova_market_buy_listing\(uuid,uuid,integer\) from public, anon/i);
assert.match(sql, /revoke all on function public\.nova_market_cancel_listing\(uuid,uuid\) from public, anon/i);
assert.match(sql, /grant execute on function private\.nova_market_create_listing\(uuid,text,integer,bigint\) to authenticated/i);
assert.match(sql, /grant execute on function private\.nova_market_buy_listing\(uuid,uuid,integer\) to authenticated/i);
assert.match(sql, /grant execute on function private\.nova_market_cancel_listing\(uuid,uuid\) to authenticated/i);
assert.match(sql, /alter table public\.nova_competitive_commands[\s\S]*?market_list[\s\S]*?market_buy[\s\S]*?market_cancel/i, "market command types must be permitted by the receipt constraint");
console.log("NOVA shared market security-contract checks passed.");
