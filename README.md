# NOVA

NOVA is an Android-first, portrait-oriented online competitive simulation game in development. Gameplay is built around player decisions, statistics, economic systems, operations, assets, organizations, and player-versus-player competition — not an open-world character game and not a map-based strategy game.

## Current client

The mobile-first client includes:
- A command center with player metrics, event highlights, and activity feed.
- Competitive operations and challenge surfaces.
- Asset management and persistent inventory.
- A shared player-to-player market with listings, partial purchases, and cancellation.
- Player rankings, organization entry points, and profile/settings.
- Thumb-friendly navigation, translucent panels, responsive feedback, and reduced-motion support.

## Online foundation

The current main branch includes:
- Supabase email/password registration and login client.
- Persistent competitive player profiles, wallets, and assets.
- Server-authoritative operation simulation and asset upgrades.
- Idempotent command receipts and an auditable resource ledger.
- A safe public leaderboard RPC and public activity feed with Realtime inserts.
- Row Level Security on all competitive tables. Clients cannot directly mutate wallets, assets, or ledgers.

**Shared market status:** A second migration and client integration are being developed on the open shared-market PR. It adds inventory-backed player listings, partial purchases, cancellation, atomic buyer/seller wallet transfers, and order/inventory ledgers. It is not live until that PR passes checks, is merged, and the migration is applied.

No real player accounts have been created or end-to-end integration-tested yet. Email confirmation requires the Pages URL `https://powerx911.github.io/NOVA/` to be present in Supabase Auth's redirect allowlist.

Asynchronous player challenges and server-simulated duels are merged in the client, but their database migration is undergoing a small SQL quoting repair in PR #25. The duel migration must be applied before authenticated battle features are usable. Organizations, season system, and broader PvP features remain future implementation phases.

## Infrastructure and safety

- GitHub is the source of truth for code, pull requests, CI, and GitHub Pages deployment.
- GitHub Pages deployment succeeded for main commit `fc52f0420072d6a6484170a71204b34dd09f0a6a`: https://powerx911.github.io/NOVA/.
- Existing Supabase project is used; no new project is required.
- The browser uses only the Supabase publishable key. Never expose a service-role or secret key in client code.
- Server-side functions own balances, asset upgrades, operation rewards, market transfers, and ranking calculations.
- Vercel is not used.
