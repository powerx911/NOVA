# NOVA

NOVA is an original, Android-first persistent online strategy game in development. Its world is built around personal castles, a shared kingdom map, alliances, diplomacy, an interconnected economy, armies, and wars.

## Current playable work

The repository now contains the first **local interactive prototype**:
- Castle management with four upgradeable buildings and resource costs.
- A shared-world map mock-up with selectable locations.
- A player bag with advanced relocation, random relocation, and supply items.
- Starter objectives, rewards, and local progress saving.
- Arabic-first, right-to-left, mobile-first interface.

This is a front-end gameplay prototype only. Progress is stored in the current browser/device. There is no account system, multiplayer world, authoritative backend gameplay, real relocation, battle simulation, or production database schema yet. Prototype actions must not be mistaken for live online game behavior.

## Project infrastructure

- GitHub repository `powerx911/NOVA` is the source of truth for source control, pull requests, CI, releases, and deployment.
- GitHub Actions validates prototype source changes.
- GitHub Pages is the intended initial static hosting target; activation and a successful live deployment must still be verified.
- Existing Supabase project `NOVA` is the planned backend foundation for authentication, persistent data, trusted game rules, and authorized realtime features.
- Vercel is not used.

## Product and engineering foundation

- `docs/PRODUCT_VISION.md` — product vision, autonomy, quality gates, and roadmap.
- `docs/ONLINE_GAME_FOUNDATION.md` — online systems, alliances, economy, armies, security, and backend boundaries.
- `docs/PLAYER_EXPERIENCE_AND_OPERATIONS.md` — progression, player experience, support, moderation, and live operations.
- `PROJECT_STATUS.md` — current project state and engineering handover.

## Security and delivery

Never commit secrets, service-role keys, or private credentials. Browser/mobile clients must never decide authoritative balances, inventory consumption, relocation validity, battle results, or rewards. Those operations must be validated and committed by trusted server-side logic with authorization, idempotency, and audit records.

GitHub is the source of truth for code, review, merge, CI, and deployment. No paid service, domain purchase, asset purchase, or destructive production data change may occur without the required owner approval.
