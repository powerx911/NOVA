# NOVA

NOVA is an Android-first, portrait-oriented online competitive simulation game in development. Gameplay is built around player decisions, statistics, economic systems, operations, assets, organizations, and player-versus-player competition — not an open-world character game and not a map-based strategy game.

## Current client

The mobile-first client includes:
- A command center with player metrics, event highlights, and activity feed.
- Competitive operations and challenge surfaces.
- Asset management and inventory.
- A market interface.
- Player rankings, organization entry points, and profile/settings.
- Thumb-friendly navigation, translucent panels, responsive feedback, and reduced-motion support.

## Online foundation

The current feature branch now includes:
- Supabase email/password account registration and login.
- Player profile initialization and persistent player wallet.
- Server-authoritative operation simulation and asset upgrades.
- Idempotent command receipts and an auditable resource ledger.
- A safe public leaderboard RPC and public activity feed with Realtime inserts.
- Row Level Security on all new competitive tables. Clients can read their own wallet/assets but cannot directly mutate them.

**Deployment status:** The competitive migration is included in the open GitHub pull request and has not yet been applied to the live Supabase database. Until the PR checks pass, the migration is applied after merge, and account/command integration tests pass, do not treat the current Pages deployment as a live multiplayer game. The market, matchmaking/challenges, organizations, and player-versus-player season system are still future implementation phases.

## Infrastructure and safety

- GitHub is the source of truth for code, pull requests, CI, and GitHub Pages deployment.
- Existing Supabase project is used; no new project is required.
- The browser uses only the Supabase publishable key. Never expose a service-role or secret key in client code.
- Server-side functions own balances, asset upgrades, operation rewards, and ranking calculations.
- Vercel is not used.
