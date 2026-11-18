# NOVA — Online Multiplayer Foundation

**Status:** Requirements confirmed; final genre presentation and engine intentionally undecided  
**Date:** 2026-11-18  
**Repository:** https://github.com/powerx911/NOVA  
**Design workspace:** https://www.figma.com/design/5bVPOQxGkZC8DXpm4yznvy

## 1. Product direction confirmed by the owner

NOVA must be an online game, not a single-player game with online extras. Its central experience must support:

- Competitive alliances, long-term rivalries, diplomacy, and shared objectives.
- An interconnected in-game economy with resources, production, trade, and meaningful scarcity.
- Armies, military preparation, strategic orders, wars, consequences, and recoverable losses.
- Professional player identities and profiles.
- Player discovery, friend requests, player connections, and block/report controls.
- Private conversations between players.
- A global chat where players can communicate with the wider world.
- Organized, high-quality mobile menus, navigation, visual hierarchy, and responsive states.
- A distinctive audio identity using real music and sound effects with verified reuse rights.
- A short, memorable web address and branded link previews when shared in messaging apps.

The exact genre label, setting, world fiction, visual style, camera, tactical presentation, match/session structure, and client engine are not selected yet. They must be compared against the requirements above rather than assumed from the older provisional adventure-RPG proposal.

The inspiration is the broad appeal of persistent political/strategic player competition (including diplomacy and alliance rivalry). NOVA must have its own world, rules, terminology, artwork, interface, balancing, and original content; do not reproduce another game's maps, copy, UI, assets, or protected expression.

## 2. Player identity and social layer

### Player identity and profiles
- Stable internal player ID, unique public handle, display name, avatar, optional biography, join date, level/rank only when those are meaningful to the chosen game, and public achievements.
- Profile visibility and privacy choices that avoid exposing email, real name, precise location, or other unnecessary personal data.
- Clear online/away/offline indicators with privacy-aware presence.
- Friend request lifecycle: send, accept, reject, cancel, remove; prevent duplicate or self-requests.
- Block and report actions available from profiles and conversations.
- Player search with abuse-resistant rate limits and safe handling of impersonation.

### Messaging and chat
- One-to-one conversations with durable history, timestamps, delivery/read state only where reliable, unread counts, pagination, and notification preferences.
- Global chat with server-enforced rate limits, anti-flood controls, message length limits, moderation, mute/report/block, and clear community rules.
- Future alliance chat and leadership/command channels should use the same authorization and moderation foundations.
- Never trust a client-supplied sender ID. Derive identity from the authenticated server session.
- Persist messages in Postgres; use Realtime only to deliver live events/notifications. Define retention, reporting, moderator access, and deletion/privacy behavior before public launch.
- Do not enable public Realtime topics for private messages or alliance content. Use private channels and membership-based RLS authorization. Consider public read-only broadcast only for intentionally public world announcements, after threat review.

## 3. Alliance and diplomacy layer

- Create, discover, apply to, invite, join, leave, and disband alliances under explicit rules.
- Alliance roles and permissions: founder/leader, officers, members, recruits, with granular action permissions rather than UI-only roles.
- Membership limits, invitation expiry, cooldowns, leadership succession, kick/ban rules, and audit trail.
- Alliance profile: emblem, name, description, language, recruitment status, membership, public achievements, and ranking.
- Shared objectives, contribution history, alliance treasury/resources, and transparent spending logs.
- Diplomacy relations such as neutral, pact, non-aggression, trade agreement, alliance, rivalry, and war. All relation changes need server validation and timestamps.
- Protection against rapid alliance hopping, shell alliances, fake membership, collusive farming, and leader abuse.
- Multi-party decisions should define who can propose, vote, approve, cancel, or declare conflict, and whether actions have cooldowns.

## 4. Economy and persistence

- Define resource creation, production rates, storage caps, upkeep, trade, taxes/fees, repair/recovery, and resource sinks together. Avoid infinite inflation and runaway leaders.
- Market and trade operations must be atomic. Reserve stock/funds before settlement; append immutable or auditable ledger entries; prevent duplicate orders and double spending.
- Use server-calculated production and bounded offline accrual. Client clocks and client calculations are not authoritative.
- Define new-player protection, catch-up mechanics, loss recovery, anti-snowball systems, seasonal resets or persistence policy, and transparent economic rules.
- Make scarcity and logistics strategically meaningful without creating mandatory pay-to-win pressure.
- Build deterministic pure game-rule modules where possible so economic outcomes can be unit-tested independently of UI and network code.

## 5. Armies, war, and competitive integrity

- The server validates every military command against ownership, resources, readiness, range, cooldowns, current treaties, and world rules.
- Battle resolution is deterministic or uses server-controlled randomness with auditable seeds/receipts; client-reported battle outcomes are never trusted.
- Use command IDs/idempotency keys, expected state versions, transaction boundaries, and replay protection for valuable actions.
- Define scouting/intelligence, travel times, supply, upkeep, defensive preparation, alliances joining conflicts, ceasefires, surrender, and post-war recovery only after core rules are balanced.
- Separate high-frequency visual animation from authoritative battle settlement.
- Leaderboards and season rewards are derived from validated server state; prevent duplicate claims and manipulation.
- Maintain event/audit records sufficient to investigate disputes without exposing sensitive data to all players.

## 6. Initial backend architecture principles (not yet implemented)

Existing backend: Supabase project `NOVA` in `eu-west-1`. Keep this project as the starting point; do not create a new paid backend or branch without cost review and approval.

Recommended separation of responsibilities:

| Concern | Initial responsibility |
|---|---|
| Authentication | Supabase Auth; stable user identity and verified session |
| Player profiles/social graph | Postgres tables protected by RLS and server validation |
| Durable chat history | Postgres messages/conversations, cursor pagination, report/retention policy |
| Live chat delivery | Supabase Realtime Broadcast on authorized channels |
| Online status | Realtime Presence for low-frequency presence only; use heartbeat/expiry policy for stale connections |
| Durable world state | Postgres canonical records and transactions |
| Economy/trade/war commands | Trusted server-side functions/transactions; validate, authorize, deduplicate, commit atomically |
| Notifications | Durable notification records plus Broadcast delivery |
| Media | Supabase Storage with constrained upload policy, validation, and safe image processing |

### Realtime use

Current Supabase documentation distinguishes:
- **Broadcast:** low-latency transient events and chat delivery notifications; recommended over broad Postgres Changes subscriptions for scalable fan-out.
- **Presence:** small, slow-changing online/active state, not frequent position or game-state streaming.
- **Postgres Changes:** convenient for simpler/low-volume subscriptions, not the default high-scale fan-out path.

Use private topics for player-specific, conversation, and alliance channels. Add Row Level Security policies on `realtime.messages` that authorize the authenticated user based on exact conversation/alliance membership and allowed action. Disable public channel access for production-private topics. Test revocation behavior and channel access after membership changes.

Important: Broadcast is transient transport, not the source of truth. Persist messages and important game actions in Postgres. Reconnect by fetching durable history/state, then resume live subscriptions. Do not broadcast secrets or unnecessary personal data.

### Server-authoritative command pattern

For any valuable mutation:
1. Client submits a typed command with the intended action, stable command ID, and expected state version.
2. Server derives the player identity from the validated session.
3. Server checks membership, permissions, state preconditions, cooldowns, quotas, and payload bounds.
4. Server executes the rule and ledger writes in one atomic transaction (or a carefully designed idempotent workflow).
5. Server stores the command receipt/result and emits a small event for subscribed clients.
6. Retries with the same command ID return the original result; they do not repeat the reward, transfer, battle, or purchase.

No whole-save client upserts, client-computed battle settlement, or client authority over currencies/resources/armies.

## 7. Security, moderation, and player trust

- Enable RLS for all exposed application tables; default deny, then add narrowly scoped policies.
- Keep secret/service-role credentials exclusively on trusted server infrastructure.
- Validate every client input on the server: schema, bounds, ownership, rate, and state transition.
- Use private Realtime channels with explicit authorization; never treat a hidden UI button as an access-control boundary.
- Add global and per-player throttles for chat, friend requests, invitations, market orders, and expensive actions.
- Provide block, mute, report, anti-spam, moderation queues, moderator audit logs, and clear community rules before public chat is opened.
- Design age-appropriate community safety and personal-data minimization. Do not expose real names/emails by default.
- No analytics collecting personal data, ads, real-money transactions, loot boxes, or pay-to-win without separate explicit approval.
- Include abuse handling, backups/restore, and incident response in operational readiness.

## 8. Mobile experience and interface quality

- Mobile-first and Android-first; choose portrait or landscape only after testing the actual interaction model.
- Provide a clear information architecture so home/world, profile, social, chat, alliance, economy, army, diplomacy, reports, settings, and notifications do not become a cluttered screen.
- Use consistent navigation, hierarchy, typography, iconography, touch targets, safe areas, visual feedback, and responsive states.
- All buttons must perform real actions. Include loading, empty, error, retry, offline, permission-denied, and reconnect states.
- Avoid requiring players to monitor the game continuously; notifications, timers, and command queues should communicate important state changes without manipulative pressure.
- Review Arabic RTL and English LTR, text overflow, numerals, accessibility labels, contrast, and device-size coverage.
- Figma workspace for product/interface exploration: https://www.figma.com/design/5bVPOQxGkZC8DXpm4yznvy.

## 9. Domain, share previews, and brand

- Target a concise, pronounceable URL suitable for sharing in chat.
- Evaluate a free provider subdomain as an interim option and a custom domain separately. Do not buy/register anything or activate a paid service without approval.
- Verify domain stability, ownership/control, HTTPS, redirect behavior, and future migration options before committing.
- Provide social metadata: Open Graph title, description, canonical URL, and official 1200×630 share artwork; Twitter/X card metadata as needed.
- A single static landing page can use one official preview. Dynamic player/alliance pages may require prerendering or server-side metadata so crawlers see the correct image/title even when app content is client-rendered.
- Test previews in actual messaging platforms; clients cache previews and may not refresh instantly. Never promise that every chat client will render exactly the same preview.
- The official NOVA emblem, wordmark, and share cover must be original and consistent.

## 10. Music, sound, and asset licensing

- Use real, high-quality music and designed sound effects that fit NOVA's eventual tone.
- Candidate sources for discovery include Kenney, OpenGameArt, and other libraries, but every specific track/file must be checked individually.
- Prefer CC0/public-domain or licenses that clearly permit commercial game use. If attribution is required, store the exact creator, title, source URL, license version, required attribution wording, and proof in an asset manifest.
- Verify whether edits, looping, redistribution inside a game bundle, app-store distribution, and commercial use are allowed.
- Do not treat "free download" as equivalent to "free for commercial use."
- Do not upload or commit unlicensed tracks or assets. Include master volume, music/effects toggles, and reasonable mobile data/storage behavior.

## 11. Technology evaluation gates (no selection yet)

Compare at least two viable client approaches after requirements are mapped:
- A browser-first 2D stack suitable for fast, touch-friendly persistent strategy interfaces.
- An engine-based mobile stack if the final visual/interaction model needs richer animation, simulation, or native packaging.

Score candidates on:
1. Android UX and mobile input quality.
2. Rich information-dense strategy UI and localization/RTL support.
3. Online networking and reconnect behavior.
4. Server-authoritative simulation fit.
5. Performance on mid-range devices.
6. Build, test, deploy, and debugging workflow using GitHub Actions.
7. PWA/native packaging options and app-store readiness.
8. Team size/maintenance, library health, security, accessibility, and total cost.
9. Long-term maintainability and ability to ship a small end-to-end vertical slice.

Do not choose an engine based only on popularity or old projects. No technology should require Vercel; GitHub remains the code/CI/deployment control plane.

## 12. Next preparation and decision sequence

1. Verify current GitHub Actions, Pages, Supabase Edge Function, endpoint health, and secret rotation requirement.
2. Map the product's core player/social/alliance/economy/war entities and trusted command boundaries before creating production tables.
3. Research Supabase Realtime limits and concurrency expectations against expected scale; do not promise millions of live players on the current plan.
4. Compare the client/game engine approaches using a weighted scorecard and a small technical spike only after choosing the interaction model.
5. Define social safety, moderation, retention, privacy, backup, and anti-abuse policies before enabling open public chat.
6. Establish the visual identity and navigation in Figma after the product structure is agreed.
7. Select the final game category/theme/presentation and approve the first vertical slice only after the evidence is available.

## 13. Open questions (must be answered by research, not pushed onto the owner)

- What exact world fiction and visual identity will make NOVA recognizable?
- What is the right strategic time scale: near-real-time orders, asynchronous turns, or a hybrid?
- How should territories and logistics work, if the chosen presentation uses a map?
- Which alliance decisions should be democratic, leader-controlled, or delegated?
- How can a new player make meaningful contributions without becoming instant prey?
- How can economy sinks, recovery, seasons, and matchmaking contain snowball effects?
- What concurrent player and message load can the selected hosting plan support at acceptable cost?
- Which client stack provides the best quality/cost trade-off for the validated experience?

These questions are product/engineering research tasks. The owner should not need to resolve implementation details.
