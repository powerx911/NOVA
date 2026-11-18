# NOVA

NOVA is an original, Android-first 2D persistent multiplayer world simulation game in development. Its new direction combines player-owned businesses, a living economy, territory competition, organizations, and simulated conflicts — without nation-state management or direct-action combat.

## Current experience

The first visual foundation is a mobile-first Arabic prototype featuring:
- A modern world dashboard and illustrated city hero scene.
- Player wallet, businesses, hourly income, and local business expansion.
- A stylized interactive sector map.
- A simulated player market and quick purchase action.
- Organization membership, social activity, and conflict simulation.
- Local preview persistence only.

**Important:** This is a front-end preview, not yet an online multiplayer game. Accounts, shared economy, live market orders, organization chat, real-time presence, territory ownership, and authoritative conflict resolution still require backend implementation and integration testing.

## Infrastructure

- GitHub repository `powerx911/NOVA` is the source of truth for source control, pull requests, CI, and deployment.
- GitHub Pages: https://powerx911.github.io/NOVA/
- Existing Supabase project remains the planned backend for authentication, persistent game state, trusted commands, and authorized realtime features.
- Vercel is not used.

Never commit credentials or service-role keys. Client code must not authoritatively decide balances, inventory, market trades, territory ownership, or battle outcomes. Those operations must be validated server-side with authorization, transactions, idempotency, and audit records.
