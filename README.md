# NOVA

NOVA is an Android-first, portrait-oriented online competitive simulation game in development. Gameplay is designed around player decisions, statistics, economic systems, operations, assets, alliances, and player-versus-player competition — not an open-world character game and not a map-based strategy game.

## Current experience

The current GitHub Pages client is an interactive visual prototype:
- A command center with player metrics, event highlights, and activity feed.
- Competitive operations and challenge cards.
- Asset management and inventory surfaces.
- A market interface and local demonstration purchase.
- Player rankings, organization entry points, and profile/settings surfaces.
- Thumb-friendly bottom navigation, translucent panels, responsive feedback, and reduced-motion support.

**Important:** Interactions that change credits, materials, energy, or upgrades are local preview state only. Rankings, events, prices, participants, alliances, and challenge cards are illustrative sample content. This is not yet a live multiplayer game.

## Online architecture and safety

- GitHub is the source of truth for code, pull requests, CI, and GitHub Pages deployment.
- The existing Supabase project remains the planned backend.
- Server-authoritative services must own balances, inventory, production, market trades, challenge participation, rankings, organization membership, operations, and outcomes.
- Realtime events must be authorized; durable records belong in the database.
- Do not claim multiplayer, live data, real matchmaking, or server persistence until implemented and integration-tested.

Vercel is not used. Never commit credentials or service-role keys.
