# NOVA Database Architecture

**Last verified:** 2026-11-20  
**Supabase project:** hmrprnjhyzyefocdmnxf  
**Active schema:** nexora  
**Server API:** nexora-api

## Source of truth

- Product/game name: **NOVA**.
- Firebase Authentication establishes player identity.
- Supabase PostgreSQL is authoritative for game state, wallets, inventory, companies, factories, organizations, auctions, contracts, manufacturing and notifications.
- The browser calls the Supabase Edge Function nexora-api with a Firebase ID token. It never receives the service-role key.
- Firestore remains a legacy diagnostics/older-function surface; it is not the authoritative game economy.

The nexora schema and nexora-api function names are legacy technical identifiers. Keep them until a coordinated compatibility migration is approved; do not rename them with a bulk replacement.

## Live production inventory

Read-only catalog verification on 2026-11-20 returned:

| Object | Count |
|---|---:|
| Tables | 46 |
| Functions | 151 |
| SECURITY DEFINER functions | 138 |
| Triggers | 40 |
| Indexes | 102 |
| Constraints | 169 |
| Active pg_cron jobs | 8 |
| RLS-enabled tables | 46 |
| RLS-disabled tables | 0 |

The production snapshot verifier enforces these counts and checks key function/security invariants. All 46 tables have RLS enabled. Direct table access is not granted to anon or authenticated; manufacturing_jobs additionally has no direct-access policies or read grants for service_role.

## Security boundary

1. The client authenticates with Firebase and sends its signed ID token to nexora-api.
2. The Edge Function verifies the Firebase signature, issuer and audience, then derives the UID from the verified token.
3. Non-anonymous account deletion requires a signed Firebase auth_time no older than five minutes. This check occurs before Supabase account cleanup.
4. The Edge Function uses its server-side service-role client to call trusted RPCs and read permitted data.
5. Financial, ownership and manufacturing invariants belong in PostgreSQL transactions and trusted server functions, not client-only checks.

## Financial and gameplay invariants

- Wallet balances must remain non-negative.
- Wallet mutations and their transaction-ledger records must be atomic.
- Player-to-player transfers, market purchases and organization treasury deposits use an idempotency key. The same key and payload return the stored result; reusing a key with a different payload is rejected.
- Organization treasury deposits are one-way. Withdrawals are disabled at the UI, API and database RPC layers to prevent the treasury from acting as a player-to-player transfer intermediary.
- Auction bids reserve funds in company_auction_escrows. Settlement must release or refund the reserved amount; missing underlying assets must not strand bidder escrow.
- Company revenue collection grants minimum XP/reputation/influence rewards, scales reputation/influence with leadership, and caps collection XP.
- Factory progression uses a resource-specific curve. The server cron owns periodic production synchronization.
- Manufacturing recipe cost, inputs, XP and cancellation refunds must agree with the canonical server recipe and job snapshot.

## Manufacturing access

manufacturing_jobs has RLS enabled and no broad direct-access policies. The browser must use the existing server RPC boundary. The manufacturing RPCs remain SECURITY DEFINER functions owned by the trusted database role. The two nullable auction foreign keys, company_auctions.company_id and factory_id, have partial supporting indexes for non-null values.

## Account deletion

Account deletion is a two-system operation:

1. nexora.delete_player_account(p_uid) performs transactional Supabase cleanup.
2. Immutable financial/audit history is retained and narrowly pseudonymized; private/progression state is removed.
3. Deletion is rejected when the player has a live winning bid on another player's auction or a leadership state that cannot be safely transferred.
4. The Edge Function then deletes the Firebase Auth identity.
5. If Firebase deletion is pending after database cleanup, the player can reauthenticate and retry; the database cleanup is idempotent.

Do not test deletion against real player accounts.

## Migration history and snapshots

The production migration ledger contains **83 applied records**. The repository has **80 tracked migration files**. The current manifest maps all 83 applied records to canonical source paths and Git blob hashes; 21 records use recovered-history sources, and 21 records have additional historical variants. Eighteen local migration files remain unmapped by name to the current ledger. They are not automatically considered pending or unapplied.

Two data-free snapshots serve different purposes:

- supabase/ci/nexora_schema_snapshot.sql is the historical starting baseline for replaying the curated migration chain.
- supabase/ci/nexora_production_schema_snapshot.sql is synchronized to the current live production catalog and is used by the strict catalog verifier.

The isolated database workflow restores the historical baseline, applies the ordered migration chain and runs pgTAP. The production snapshot verification runs separately against a disposable schema and checks the current live catalog shape and key function definitions.

Never run supabase db push or migration repair to paper over history drift. Keep timestamped migration order and source hashes intact. Apply production changes only after disposable replay, pgTAP and snapshot verification pass.

## Regression suites

Database regression tests live under supabase/tests/database, including:

- financial_idempotency.test.sql
- biotech_recipe_integrity.test.sql
- company_revenue_minimum_rewards.test.sql
- manufacturing_rls_auction_fk_indexes.test.sql
- unified_account_deletion.test.sql
- factory_resource_progression.test.sql

Run these only in disposable PostgreSQL/Supabase environments, never against production.
