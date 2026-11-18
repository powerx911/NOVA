# NOVA — Product Vision, Autonomy and Quality Charter

**Status:** Initial product direction approved by the user's explicit delegation of product and development decisions  
**Date:** 2026-11-18  
**Repository:** https://github.com/powerx911/NOVA

## 1. Product ambition

Build NOVA as an original, polished, Android-first game with the quality discipline expected of a serious Google Play release. It should feel like a game designed for a phone from the beginning—not a desktop website squeezed into a narrow viewport.

The ambition is to create a memorable game with a coherent world, satisfying moment-to-moment play, meaningful progression, responsive controls, excellent presentation, reliable saving, and enough depth to keep players returning. "Global quality" is an aspiration, not a claim that can be made before real testing, localization review, and release validation.

## 2. Confirmed product direction; final genre remains open

Current user-defined direction: **online-first, persistent multiplayer competition**, with alliances, diplomacy, economy, armies, and wars at its core. Professional player profiles, friends, private messaging, and global chat are foundational—not optional add-ons.

Why this direction:
- The owner requires a persistent online world where players form alliances, communicate, build economic strength, negotiate, command armies, and compete over time.
- The social and strategic loops must reinforce one another: diplomacy affects trade and war; the economy enables military readiness; wars change territory, resources, and alliance standing; profiles and communication make relationships visible.
- NEXORA may inform carefully scoped economy, market, organization, and production patterns. VORZANE may inform selected progression or event systems only if later evidence shows they fit. Neither project's code or assets should be copied without technical and license review.
- The final genre label, setting, art direction, camera, battle presentation, session cadence, map/world structure, and client engine remain intentionally undecided. Compare options and validate a focused prototype against the online-first requirements before locking them.

## 3. Delegated autonomy

The user explicitly authorizes the development agent to:
- Define and refine the game concept, feature set, UX, visual direction, technical architecture, and development roadmap.
- Inspect the game continuously and identify missing features, bugs, weak design, usability issues, performance problems, security risks, and opportunities.
- Prioritize work by player value, risk reduction, dependency order, and implementation cost.
- Implement features and improvements proactively without waiting for the user to provide a detailed task list.
- Research suitable open-source systems, tools, assets, and techniques, then verify compatibility and licensing before reuse.
- Write and improve player-facing copy, translations, onboarding, tutorials, error messages, accessibility labels, and store-facing materials.
- Add automated tests, static checks, CI workflows, documentation, telemetry-free diagnostics, and release checks where appropriate.
- Make ordinary reversible engineering and product decisions and record material decisions in the repository.

The user does not need to understand programming or supply technical implementation details. Explain important decisions in plain Arabic when reporting progress.

## 4. Approval boundaries

Explicit approval is still required before:
- Spending money, activating paid plans, purchasing assets, or creating paid infrastructure.
- Accepting legal terms, licenses that impose obligations beyond ordinary permissive reuse, or publishing legal/identity declarations.
- Using the user's identity, signing credentials, store-owner account, or making representations on their behalf.
- Destructive production database changes, deleting player data, or irreversible account/security changes.
- Introducing ads, tracking, analytics that collect personal data, loot boxes, pay-to-win mechanics, subscriptions, or real-money purchases.
- Publishing a public store release or making a release that commits the user to legal, financial, or platform obligations.

Never ask the user to paste secrets into chat. Use authorized integrations and secret stores; do not expose secret values in code, logs, PRs, or documentation.

## 5. Product principles

1. **Connected world before feature count:** profiles, friends, messages, chat, alliances, diplomacy, economy, armies, and conflict must form one coherent multiplayer ecosystem.
2. **Gameplay before feature count:** every system must support the core fantasy, create meaningful choices, or improve the player experience.
3. **Mobile-first, Android-first:** touch-first controls, portrait-first layouts unless gameplay demands landscape, safe areas, responsive scaling, readable type, haptics where useful, and efficient performance on mid-range devices.
4. **Immediate clarity:** the player should understand what they can do, what happened, what they earned, and what to do next.
5. **Meaningful strategic progression:** personal reputation, alliance contribution, economic development, military capabilities, diplomatic influence, and seasonal achievements should create long-term goals without runaway power gaps.
6. **Fairness and trust:** no fake rewards, deceptive timers, pay-to-win pressure, hidden costs, or arbitrary loss of progress.
7. **Reliable persistence:** versioned saves, recovery paths, clear offline behavior, and server authority for valuable shared state.
8. **Distinctive art and sound:** a consistent visual language and intentional audio identity; no random asset collage or unlicensed content.
9. **Accessibility and localization:** legible contrast, scalable text, understandable icons, accessible labels, and reviewed Arabic RTL/English LTR experiences.
10. **Performance as a feature:** fast startup, stable frame pacing, controlled memory use, responsive input, and graceful handling of weak networks/devices.
11. **Honest quality claims:** prototype, beta, release candidate, native package, and store publication must be described accurately.

## 6. Player-facing content and language quality gate

No player-facing placeholder text may ship. Disallow lorem ipsum, "test", "coming soon" presented as a functional feature, unexplained debug labels, broken localization keys, inconsistent terminology, and unnecessary filler.

Before a screen or feature is considered complete:
- Review every visible string in context, including buttons, dialogs, tutorials, tooltips, notifications, loading/empty/error/offline states, and accessibility labels.
- Check Arabic spelling, grammar, punctuation, terminology, RTL ordering, numerals, and text expansion/clipping.
- Check English spelling, grammar, tone, consistency, and natural phrasing when English is supported.
- Keep copy concise and useful. Remove text that does not help the player understand, decide, act, or recover.
- Use a consistent glossary for player profiles, alliances, resources, currencies, diplomacy, military orders, battles, and system messages; finalize exact terms only after the game model is selected.
- Test long strings and different screen sizes; do not rely on visual inspection of a single device size.

## 7. Definition of done

A feature is not complete merely because code exists or a build succeeds. Its definition of done includes, as relevant:
- A complete, understandable player flow with real behavior behind every control.
- Loading, empty, success, failure, retry, offline, and interrupted-session states.
- Input validation, authorization, safe persistence, and protection against duplicate or forged rewards.
- Unit/integration/e2e tests for important game rules and flows.
- Responsive Android viewport checks and touch-target review; real-device verification before release claims.
- Performance and accessibility review appropriate to the feature.
- Player-facing copy and localization review.
- Updated docs, known limitations, and changelog.
- PR review, successful required checks, merge, and separate deployment verification.

## 8. Technical and delivery constraints

- GitHub repository: `powerx911/NOVA`; GitHub is the source of truth for code, pull requests, merge, CI, and deployment.
- Existing Supabase project remains the backend foundation unless a documented technical evaluation proves a change is necessary and the user approves any migration.
- Vercel is prohibited for this project.
- Never work directly on `main`. Branch from latest `main`, implement, test, review the diff, open a PR, and merge only when ready.
- Update `PROJECT_STATUS.md` in the same PR as every project change.
- Verify the deployed service/site after deployment. A merge is not proof of deployment.
- Do not add dependencies without checking maintenance, license, bundle size, security, and Android/browser compatibility.
- Keep game rules deterministic and testable where practical; all valuable economy, inventory, production, alliance, military, ranking, and reward mutations must be server-authoritative.
- Realtime transports events; it is not the durable source of truth for chat history, balances, battle results, or world state.
- The final client engine and rendering stack remain open until a prototype and technical scorecard establish the right fit for this online-first product.

## 9. Autonomous roadmap

The agent should maintain and reprioritize a living roadmap. Initial order:

1. **Foundation audit:** verify repository, CI, deployment, Supabase services, security boundaries, and current runtime status.
2. **Online product definition:** detail player identity, profiles, friends, private/global/alliance chat, moderation, presence, alliances and roles, diplomacy, persistent economy, armies, war, seasons, and competition.
3. **Technical selection:** compare client/game stacks and hosting patterns against the online-first requirements, mobile experience, concurrency, authoritative simulation, cost, testability, and long-term maintenance.
4. **Prototype gate:** validate one narrow end-to-end online loop, including authentication, a player-facing social interaction, a server-authoritative shared-world action, persistence, and reconnect/retry behavior.
5. **Vertical slice:** turn the validated loop into a polished, cohesive experience with the required visual, audio, localization, accessibility, and mobile quality.
6. **Core systems and live world:** expand alliance, economy, diplomacy, military, social, event, and competitive systems in dependency order.
7. **Quality and release:** test security, anti-abuse, concurrency, performance, backups, device compatibility, privacy/data disclosures, Android packaging where selected, store requirements, staged rollout, and release approval.

The agent is authorized to select ordinary product and technical details based on evidence and document the decision. Stop for owner approval only when a defined financial, legal, identity, privacy/monetization, destructive-production, or public-release boundary is reached. Do not mistake this roadmap for a promise that all systems must be built; remove or defer features that do not improve the coherent online game.

## 10. Reporting standard

When reporting progress to the user:
- Say what changed and why in plain Arabic.
- Distinguish implemented, tested, merged, deployed, and published states.
- Report test evidence and unresolved risks.
- Avoid asking the user technical questions that the agent can reasonably decide through research or prototyping.
- Ask only when a decision crosses an approval boundary or depends on personal preference that cannot be inferred safely.

## 11. Kingdom, player castle, and tutorial model (owner-confirmed)

NOVA's world has two distinct spatial layers. A **kingdom** is the shared world/map containing its own established core cities, villages, neutral lands, resource sites, roads, and strategic locations. A **player castle** is the player's own city/settlement, founded at a valid location on the kingdom map and developed independently. Players do not build their personal cities inside the kingdom's capital or inside a shared kingdom city. The castle is the player's home base and contains the palace/keep, farms, barracks, workshops, storage, and other upgradeable buildings.

The first playable realm is provisionally **Kingdom 1**. The game entry flow is account sign-in/sign-up → kingdom selection → story-led tutorial (with a clearly visible skip option) → player's own castle. Additional separate kingdoms can be opened later using the same world rules and account identity, subject to capacity and fair-start design.

The opening story is that the player's once-powerful homeland was devastated by invading enemies. After the invaders leave, the player returns with a small council/advisors to rebuild their own stronghold. Tutorial chapters teach real actions in sequence—repair/construct a farm, collect or produce resources, upgrade the palace, establish barracks, train the first troops, and discover the kingdom map. The story must teach through playable objectives, not long walls of text. Skipping the tutorial must preserve access to optional help and the same fair starting state.

The broad inspiration is the player's childhood affection for *Al-Fatehoon*: learn from its satisfying strategic progression and sense of building a stronghold, but create original NOVA maps, names, rules, interface, art, story, and balance. Do not copy protected assets or exact expressive elements.

### Recommended map model
- The kingdom map is a shared strategic layer, divided into regions/provinces or tiles with distinct terrain, resource value, and travel connections.
- Existing core cities and villages are world locations with defined roles; they are not each player's personal castle.
- Each player owns one main castle placed on an eligible plot/settlement site. Its location matters for travel, nearby resources, neighbors, and strategic exposure.
- Neutral resource sites, wilderness, ruins, and frontier locations create exploration and competition beyond the castle.
- The map should communicate ownership, alliances, diplomacy, conflict, travel, and points of interest with clear mobile-friendly layers and filters.
- Additional castles/territorial holdings, if introduced, must be earned through a carefully balanced expansion system; they are not assumed for the first release.

### Confirmed initial combat and diplomacy scope
- Army classes: **infantry, cavalry, archers, and chariots** (Arabic player-facing terminology: مشاة، فرسان، رماة، عجلات). Their counters, strengths, movement, and costs require balancing; no class should dominate every situation.
- Alliance-to-alliance diplomatic status is deliberately limited to **neutral, war, and peace**. Do not add non-aggression pacts, trade treaties, defensive pacts, or alliance treaties to the initial diplomacy model. The exact transition permissions, declaration notice, cooldowns, and peace protections will be designed and tested before implementation.

