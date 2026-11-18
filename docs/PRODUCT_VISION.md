# NOVA — Product Vision, Autonomy and Quality Charter

**Status:** Initial product direction approved by the user's explicit delegation of product and development decisions  
**Date:** 2026-11-18  
**Repository:** https://github.com/powerx911/NOVA

## 1. Product ambition

Build NOVA as an original, polished, Android-first game with the quality discipline expected of a serious Google Play release. It should feel like a game designed for a phone from the beginning—not a desktop website squeezed into a narrow viewport.

The ambition is to create a memorable game with a coherent world, satisfying moment-to-moment play, meaningful progression, responsive controls, excellent presentation, reliable saving, and enough depth to keep players returning. "Global quality" is an aspiration, not a claim that can be made before real testing, localization review, and release validation.

## 2. Initial genre and product direction

Current user-defined direction: **online-first, persistent multiplayer competition**, with alliances, diplomacy, economy, armies, and wars at its core. Professional player profiles, friends, private messaging, and global chat are foundational—not optional add-ons.

Why this direction:
- VORZANE provides a relevant prior RPG design foundation: character classes, progression, equipment, dungeons, expeditions, roaming events, and long quests.
- NEXORA provides optional supporting patterns for crafting, resource economies, trading, organizations, and world events.
- The two projects should not be indiscriminately merged. NOVA must have one understandable core fantasy and gameplay loop; secondary systems are added only when they strengthen it.

The exact setting, art direction, camera, combat model, multiplayer scope, and engine remain product decisions to be resolved through prototypes and technical evaluation. The agent is authorized to make and document these decisions without asking the user to design the game.

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
5. **Meaningful progression:** rewards, equipment, quests, difficulty, and unlocks should form a coherent progression curve.
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
- Use a consistent glossary for character attributes, currencies, items, quests, combat actions, and system messages.
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

1. **Foundation audit:** inspect repository, CI, deployment, Supabase function health, security boundaries, and current runtime state. Resolve blockers and document actual status.
2. **Game definition:** prototype the core loop, camera/perspective, input model, world structure, combat/interaction model, and progression before committing to a full engine/content pipeline.
3. **Technical selection:** compare a small number of viable stacks against Android feel, 2D/3D needs, performance, deployment constraints, testability, and long-term maintenance.
4. **Vertical slice:** build one small but polished playable segment demonstrating the real game loop, touch controls, visual direction, audio feedback, save/reload, and error/offline behavior.
5. **Core systems:** implement only the systems needed by the validated loop; add quests, inventory, equipment, progression, economy, social, or live operations in dependency order.
6. **Content and polish:** build coherent environments, characters, animations, sound, localization, onboarding, accessibility, and balanced progression.
7. **Quality and release:** device matrix, performance/crash testing, security review, privacy/data disclosures, Android package/signing, Play Console requirements, store listing, staged testing, and release approval.

Do not mistake this roadmap for a promise that all systems must be built. Remove or defer features that do not improve the game.

## 10. Reporting standard

When reporting progress to the user:
- Say what changed and why in plain Arabic.
- Distinguish implemented, tested, merged, deployed, and published states.
- Report test evidence and unresolved risks.
- Avoid asking the user technical questions that the agent can reasonably decide through research or prototyping.
- Ask only when a decision crosses an approval boundary or depends on personal preference that cannot be inferred safely.
