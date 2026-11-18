# NOVA

NOVA is an upcoming persistent online multiplayer game built around competitive alliances, diplomacy, an interconnected economy, armies, and wars. Player profiles, friendships, private messaging, and global chat are foundational systems.

## Project status

The online-first product requirements and technical foundation are being prepared. The final genre presentation, setting, client engine, and playable implementation have not yet been selected or started.

## Project infrastructure

- GitHub repository `powerx911/NOVA` for source control, pull requests, CI, releases, and deployment.
- GitHub Actions for checks and deployment workflows.
- GitHub Pages is the initial static hosting target; activation and a successful live deployment still require verification.
- Existing Supabase project `NOVA` is the backend foundation for authentication, persistent data, server-side rules, and authorized realtime features.

## Product foundation

- `docs/PRODUCT_VISION.md` — product vision, autonomy, quality gates, and roadmap.
- `docs/ONLINE_GAME_FOUNDATION.md` — player/social systems, alliances, economy, armies, wars, backend security, audio licensing, domains, and technology decision gates.
- `PROJECT_STATUS.md` — current project state and engineering handover.

## Security

Never commit secrets, service-role keys, or private credentials. Browser/mobile clients must use only public/publishable credentials, with database access protected by Row Level Security (RLS) and valuable game-state changes validated by trusted server-side logic.

## Delivery constraints

GitHub is the source of truth for code, review, merge, CI, and deployment. Vercel is not used for this project. No paid service, domain purchase, asset purchase, or production data destruction may occur without the required owner approval.
