# NOVA Database Architecture

**Last verified:** 2026-11-19

## Source of truth

- Product/game name: **NOVA**
- Supabase project reference: `hmrprnjhyzyefocdmnxf`
- Active application schema: `nexora` (legacy internal namespace retained for compatibility)
- Server API: Supabase Edge Function `nexora-api`
- Identity provider: Firebase Authentication. Firebase is used for identity only; game state and economy are stored in Supabase.
- Authoritative gameplay data and the economy are not stored in Cloud Firestore. The current owner-only diagnostics screen still reads a small legacy Firestore diagnostics surface; that dependency must be migrated before deleting the Firestore rules/config.

The brand is NOVA. The `nexora` schema and `nexora-api` function names are legacy technical identifiers. They are intentionally not renamed in-place because changing the schema requires a coordinated compatibility migration across every RPC, edge-function query, grant and migration. Do not rename them with a blind search/replace.

## Live schema snapshot

The production project currently has **34 tables** in schema `nexora`, all with Row Level Security enabled. The latest read-only access audit found no direct table grants to `anon` or `authenticated`. There are currently no views in this schema.

### Player identity and progression
- `player_profiles`
- `player_private`
- `usernames`
- `player_presence`
- `player_achievements`
- `player_missions`

### Wallet and economy
- `wallets`
- `transactions`
- `inventory`
- `market_listings`
- `market_orders`
- `contract_claims`
- `daily_claims`
- `world_events`

### Companies and factories
- `companies`
- `company_logs`
- `factories`
- `company_auctions`
- `company_auction_bids`
- `company_auction_escrows`

### Organizations and community
- `organizations`
- `organization_members`
- `organization_requests`
- `organization_invites`
- `organization_transactions`
- `conversations`
- `conversation_messages`
- `global_chat_messages`
- `chat_rate_limits`
- `user_blocks`
- `player_reports`

### Operations and safety
- `notifications`
- `audit_logs`
- `diagnostics_admins`

## Security boundary

1. The browser authenticates with Firebase Authentication and sends its signed ID token to `nexora-api`.
2. The Edge Function verifies the token and derives the player UID from the verified identity. It uses the Supabase service-role credential only on the server.
3. The browser must never receive the service-role key or write directly to the economy tables.
4. All 34 tables in `nexora` currently have RLS enabled. The latest audit found zero direct table grants to `anon` and `authenticated`.
5. Wallet balances are constrained to be non-negative. Financial changes are recorded in `transactions`; wallet updates and their ledger rows must be performed atomically by trusted server operations.

## Economic invariants

- `wallets.balance >= 0`.
- For the current wallet model, the opening balance is 2,500 credits. The reconstructed balance is:
  `2500 + incoming transaction net_amount - outgoing transaction amount`.
- A live read-only check on 2026-11-19 found no negative wallets and no difference between reconstructed ledger balances and the three existing wallet balances.
- Factory pause is server-side: `set_factory_active` synchronizes the elapsed active production before setting `is_active = false`. A subsequent sync while paused must not charge a second operating cost.

## Migrations: release blocker — do not push

A read-only comparison on 2026-11-19 found **42 applied records** in Supabase and **31 SQL files** in the repository. Matching by migration name (not timestamp alone) gives:

| Audit result | Count |
|---|---:|
| Applied migration records | 42 |
| Local SQL files | 31 |
| Names present both locally and remotely | 21 |
| Shared names whose local timestamp still differs from the applied version | 14 |
| Local-only migration names not found in applied history | 10 |
| Applied migration names with no local SQL source file | 21 |

The known `nova_skill_reset_and_factories` filename mismatch was corrected in PR #57; the counts above include that correction. The remaining mismatches must be reconciled individually. The 10 local-only names and 21 remote-only names mean the migration folder is not yet a faithful representation of production history. A blind `supabase db push` can replay an already-applied change, apply an unreviewed local migration, or fail on an existing object.

**Local-only names (not present in the applied history):**
- `nexora_companies_properties`
- `nexora_company_vault_rpcs`
- `nexora_contract_rpc`
- `nexora_economy_rpcs`
- `nexora_manufacturing_rpc`
- `nexora_market_rpcs`
- `nexora_player_settings_notifications`
- `nexora_seed_world`
- `nova_advanced_resource_recipes`
- `nova_factory_business_auctions`

**Applied names missing a local SQL source file:**
- `20261118151500_harden_player_rpc_schema`
- `20261118160000_nova_player_core`
- `add_advanced_resource_manufacturing_recipes`
- `balance_advanced_resource_recipe_costs`
- `correct_market_purchase_rewards`
- `nexora_character_creation_rpc`
- `nexora_core_schema_v1`
- `nexora_firebase_identity_boundary`
- `nexora_username_compatibility`
- `nova_competitive_core`
- `nova_competitive_duels`
- `nova_factory_auction_capacity_reservations`
- `nova_factory_auction_support`
- `nova_factory_profit_margin_v2`
- `nova_factory_warehouse_and_level_100`
- `nova_market_fk_indexes`
- `nova_remove_property_achievement_path`
- `nova_shared_market`
- `remove_legacy_nova_functions`
- `remove_legacy_nova_game_tables`
- `remove_market_purchase_reputation_influence`

- The migration-history audit was read-only; production was not changed.
- Do not run `supabase db push`, `migration repair`, or create empty placeholder migrations until the missing SQL is recovered or explicitly accounted for, every shared migration is mapped to its applied version, and the complete sequence is tested on a genuinely isolated branch.
- The Supabase branch listing currently reports the same project reference as production, so it is **not considered safe for writes or pgTAP execution**. Do not use it as a test target until Supabase confirms a separate branch project reference.

## Testing

- TypeScript and unit tests run through the GitHub Actions CI workflow.
- pgTAP regression tests live under `supabase/tests/database` and should be run against a disposable Supabase branch/local database, never against production.
- Playwright smoke tests cover email sign-in, character onboarding, buying a market listing, and founding a company. They run only when the GitHub secrets `NOVA_E2E_BASE_URL`, `NOVA_E2E_EMAIL`, and `NOVA_E2E_PASSWORD` point to a dedicated isolated test environment.
