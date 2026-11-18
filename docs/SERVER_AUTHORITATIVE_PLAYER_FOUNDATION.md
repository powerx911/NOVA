# NOVA — Server-authoritative player foundation

**Status:** Migration proposed on feature branch; not applied to the Supabase project.
**Scope:** First persistent player loop, not a complete multiplayer backend.

## Included data model

- `nova_player_profiles`: player-owned public display name.
- `nova_player_economy`: canonical food, wood, stone, iron, and gold balances.
- `nova_castles`: one personal castle per authenticated player, allocated a unique random coordinate in the starter kingdom grid.
- `nova_buildings`: six starter building types with levels 1–30.
- `nova_command_receipts`: idempotency records for valuable commands.
- `nova_resource_ledger`: append-only records for resource deductions.

All six tables enable row-level security. Players can read only their own profile, economy, castle, buildings, receipts, and ledger. Clients cannot directly insert or update economy, castle, building, receipt, or ledger rows. The profile is the only player-editable record in this first slice.

## Trusted commands

### `nova_initialize_player(display_name)`

Called after Supabase Auth succeeds. It creates the profile, starter balances, personal castle, and starter buildings if they do not already exist. Repeated calls do not grant duplicate starter resources or buildings. Castle placement retries unique-coordinate collisions.

### `nova_upgrade_building(command_id, building_id)`

The client submits only a UUID command ID and the building ID. The database function:

1. Requires a verified authenticated user.
2. Takes a transaction-scoped advisory lock for that user's command ID.
3. Returns the stored receipt when the same command is retried.
4. Verifies the building belongs to the caller.
5. Calculates costs on the server and locks the economy/building rows.
6. Checks and deducts resources, increments the level, writes ledger rows, and stores the receipt in one transaction.

The starter cost curve is intentionally simple and will be balanced later. It is not a final economy design.

## Security notes

- The two RPC functions are `SECURITY DEFINER` because they perform coordinated writes while direct client writes are denied by RLS. They use a fixed `search_path`, derive identity only from `auth.uid()`, validate ownership, and have execute revoked from `PUBLIC` and `anon`, then granted to `authenticated`.
- Do not use user-editable metadata for authorization.
- Never expose service-role keys in the client.
- No client-provided cost, balance, ownership, level, or reward value is trusted.
- The starter kingdom uses a 1000×1000 coordinate space with unique castle coordinates. Terrain, occupancy rules, relocation, region boundaries, and map rendering are not implemented in this migration.

## Not included yet

- Client authentication screens or account recovery.
- React/Vite/Phaser application migration.
- A map query API, terrain, neutral locations, or relocation commands.
- Army training, battles, alliances, chat, diplomacy, support, or admin tools.
- Rate limits, abuse controls, economy balancing, load testing, and production observability.

## Apply and verification plan

This SQL is a versioned migration proposal. Do not apply it to production until the PR has been reviewed and merged. After merge, apply it through the established Supabase migration workflow, then verify:

1. The six tables exist and RLS is enabled on all of them.
2. An authenticated test player can initialize exactly once.
3. A second player cannot read or mutate the first player's rows.
4. A player can upgrade an owned building with sufficient resources.
5. A repeated command ID returns the original receipt without another deduction.
6. Insufficient resources and foreign building IDs fail without partial writes.
7. Security and performance advisors report no unresolved relevant issue.
