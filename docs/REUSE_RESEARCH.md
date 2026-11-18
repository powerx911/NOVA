# NOVA — Prior Game and Open-Source Reuse Research

Date: 2026-11-18  
Status: research baseline only; no implementation or asset copying has been approved by this document.

## Executive summary

Two prior projects owned/published under the user's GitHub account were inspected:

1. **NEXORA** — an Arabic/English portrait-first economic, corporate-management and social strategy simulation. Its useful design material is its interconnected economy, companies/properties, production chains, player market, organizations/RBAC, world events, skill progression, and auditable transaction model.
2. **VORZANE** — an Arabic RTL fantasy RPG built with Expo/React Native and exported to web. Its useful design material is its RPG progression, classes, combat modes, gear, pets, expeditions/offline rewards, roaming narrative events, long quests, save migration UX, mobile interaction design, and Supabase server-function patterns.

The two games represent different genres. NOVA's genre and core loop are not yet specified, so this research deliberately does **not** combine them into one game or select an engine. Use the relevant systems only after the user confirms the game direction.

## 1. User's previous games

### 1.1 NEXORA — economic/corporate strategy simulation

Repository: https://github.com/luffyk124-del/nexora-game  
Supplied live deployment: https://nexora-game-git-development-nexora-next-manus24.vercel.app/

The repository README and architecture document describe React 19 + TypeScript + Vite, Arabic RTL/English LTR, Firebase Authentication, Cloud Firestore, and Firebase Cloud Functions. Supabase appears in its documentation as a separate future/isolated backend target, not the live gameplay source of truth in the inspected README. The legacy app also has Vercel-specific API/deployment work; that infrastructure is **not** a candidate for NOVA because NOVA must use GitHub and its existing Supabase project.

**Systems worth considering if NOVA includes economy, crafting, management, player trade, or social groups:**

- A deterministic, pure economy calculation layer separated from UI and data transport.
- Player wallet plus append-only transaction ledger, with atomic balance/ledger updates.
- Market listings and orders with stock reservation/escrow, bounded fees, and anti-duplicate claims.
- Dynamic prices influenced by supply, active world events, and item scarcity.
- Multi-stage manufacturing recipes and trade contracts.
- Companies/business assets and properties that accrue revenue over time, with bounded collection windows.
- Skill progression that changes specific economic outcomes (trade, management, industry, negotiation, finance, leadership).
- Organizations with explicit role-based permissions and a shared treasury.
- Daily rewards, missions, achievements, notifications, and world events as separate data-driven systems.

**Security lessons to preserve:**

- Keep currency and progression invariants on the trusted server/database boundary, not in client-only calculations.
- Use atomic transactions for coupled wallet, ledger, inventory, market, company, and organization changes.
- Make financial/audit ledgers append-only and prevent duplicate reward claims.
- Keep private identity data separate from public player profiles.
- Validate ownership, exact amounts, allowed fields, state transitions, and role permissions on every sensitive operation.
- Treat the Firestore rules as a design reference only; NOVA uses Supabase, so equivalent invariants must be implemented with reviewed Postgres constraints/RPC/Edge Functions and Row Level Security rather than copying Firestore rules verbatim.

**Do not port without redesign:** Firebase Auth/Firestore wiring, Firebase-specific security rules, the Vercel API routes, or any assumption that client UI state is authoritative. Do not assume all described features have been live-tested merely because they are documented.

### 1.2 VORZANE — fantasy RPG

Repository: https://github.com/luffyk124-del/vorzane  
Supplied live deployment: https://luffyk124-del.github.io/vorzane/

The repository contains an extracted Expo application under `extracted-vorzane/VORZANE`. The inspected package manifest uses Expo Router, React Native, React Native Web, TypeScript, Supabase JS, AsyncStorage, Reanimated, SVG, audio, haptics, and Expo sharing/document picker modules. Its documented product direction is a dark Arabic fantasy RPG, portrait-first, with RTL and mobile-friendly interactions.

**Gameplay systems worth considering if NOVA is an RPG/adventure game:**

- Four hero archetypes/classes with distinct starting stats and progression.
- A pure game-engine/domain layer separated from screen components.
- XP, levels, stat points, derived combat stats, equipment slots, rarity, pets/companions, and inventory.
- Multiple battle modes (e.g. dungeon/tower/challenge) with mode-specific enemy pools and progression.
- Repeatable dungeon floors and increasingly difficult encounters.
- Timed expeditions, queueing, offline progression, and a reward report when the player returns.
- Roaming events with narrative choices and consequences, including multi-stage event chains, merchants, relics, and collection archives.
- Long-running quests whose progress is driven by actual gameplay counters.
- Settings for music/effects, plus haptic feedback and accessible motion.
- Arabic RTL UI with a clear portrait-first navigation shell.

**Architecture patterns worth reusing after review:**

- Keep deterministic game rules in pure modules that can be unit-tested without rendering the UI.
- Keep catalog/content definitions data-driven and separate from gameplay calculations.
- Version save data and normalize old saves with safe defaults.
- Preserve local progress during account changes/offline periods; make migration/import/export an explicit user-reviewed flow.
- Use authenticated read-only game-state endpoints that forward the caller's JWT so RLS still applies.
- Initialize a new save on the server from a canonical empty state rather than accepting an arbitrary client-supplied initial snapshot.
- For sensitive actions, use typed server commands, command IDs/idempotency receipts, expected save versions, strict payload validation, and atomic commits.

**Known legacy blocker — do not copy as-is:**

VORZANE's `SAVE_MUTATION_AUDIT.md` explicitly says the client still has generic whole-save upserts and a direct-delete reset path, while battle results are client-computed. Its server-authoritative cutover is incomplete. Any NOVA implementation must avoid trusting client-submitted balances, rewards, drops, battle results, progression, or arbitrary full-state snapshots. Server authority must cover every mutation path before claiming anti-cheat integrity.

**Assets and rights:** the old repository includes character art, a music file, icons, and fonts. The project research document records one MIT-licensed ProgressRing component and some Kenney CC0 use, but not every binary asset's provenance was verified in this review. Do not bulk-copy the assets or audio until each file's source and license are checked. The old repository's top-level code license was not confirmed during this inspection.

## 2. External open-source projects worth studying

### 2.1 Violencetown — browser 2D action RPG

Repository: https://github.com/RussellDangerr/violencetown  
License: MIT for its own code; its README separately identifies Kenney CC0 sprites and a font under SIL OFL.

Useful ideas:
- A single world clock where each action advances one game tick.
- One pure action-wheel model and one geometry function shared by preview, friendly-fire confirmation, and damage resolution.
- Seeded deterministic randomness for reproducible runs and saves.
- A unified NPC disposition value that can influence dialogue, alliances, and merchant prices.
- Versioned saves with atomic writes and a backup slot.
- Installable PWA and offline service-worker shell.
- Automated headless autoplay scored against a committed baseline, plus viewport/layout invariants.

This is a strong design reference for coherent systems and testing. It is turn-based and hand-authored; it is not a drop-in real-time game engine. Its MIT license permits code reuse subject to preserving the license notice, but every third-party asset retains its own license.

### 2.2 CodingQuests — modular Godot game systems

Repository: https://github.com/CodingQuests/CodingQuests  
Resource library: https://codingquests.io/resources  
The resource library describes twelve Godot 4.7 systems; code is MIT and listed art/font assets are CC0 with per-project asset notices.

Useful modules to study:
- Crash-safe save slots and persistent world-state changes.
- Inventory with stacking, item use, drag/drop, and UI-independent domain logic.
- Branching dialogue and event-driven quest objectives.
- Hitbox/hurtbox combat, knockback, hit-stop, invulnerability frames, and readable boss telegraphs.
- Enemy state machines.
- Stats/leveling and modifier attribution.
- Server-authoritative co-op starter with client prediction/reconciliation.
- Game-feel experiments that separate impact feedback into testable layers.

Compatibility note: these examples target Godot 4.7. They are useful architecture/gameplay references, but their GDScript implementation should not be copied into a TypeScript/React Native/Phaser project without an intentional engine decision.

### 2.3 Embervale — browser action RPG

Repository: https://github.com/dafioram/embervale

Useful design references surfaced in its project documentation:
- Clear separation between content data, world simulation, AI, combat, rendering, UI, audio, and save logic.
- Autosave plus multiple manual save slots.
- JSON save export/import and versioned migration defaults.
- Optional atmosphere effects and FPS display to scale visual load on weaker devices.
- Pathfinding, minimap/fog-of-war, gear, loot, quests, and procedural zones.

License and full code provenance were not verified in this review. Treat it as a design reference only until the repository's current license and relevant asset notices are checked.

### 2.4 Phaser — browser game framework reference

Official documentation: https://docs.phaser.io/

Phaser is an open-source HTML5 framework with WebGL/Canvas rendering and explicit support for desktop and mobile browsers. It can also be packaged for Android/iOS using third-party tooling. It is a candidate only if NOVA's gameplay requires a dedicated 2D canvas/game loop; it has **not** been selected.

## 3. Android and installable-web research

- MDN recommends a deliberate offline experience for installed PWAs, including a useful offline fallback and, where appropriate, real offline operation with local persistence and retry after reconnection: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Best_practices
- web.dev describes standalone PWA windows and notes that immersive PWA fullscreen is currently supported on Android: https://web.dev/learn/pwa/app-design
- Phaser documentation explicitly covers mobile web browsers: https://docs.phaser.io/
- NOVA's mandatory Android-first requirements are recorded in `PROJECT_STATUS.md`. PWA installation/fullscreen is not the same thing as a native APK; never claim native packaging without building and testing it.

## 4. Asset sources and licensing

- Kenney states that assets on its asset pages are CC0/public domain and may be used commercially; attribution is optional: https://kenney.nl/support
- Check the exact asset page and bundled license file for every pack. A bundle landing page or a third-party catalog is not sufficient evidence for every included file.
- Avoid moving old-game character portraits, music, or generated/commissioned art into NOVA until ownership and usage rights are confirmed.
- Maintain a `THIRD_PARTY_NOTICES.md` or equivalent for any reused external code, fonts, sound, or art, including source URL, license, author notice, and files copied.

## 5. Candidate reuse matrix

| Candidate | Best fit | Recommendation |
|---|---|---|
| VORZANE pure game rules, RPG catalogs, progression and quest concepts | RPG/adventure | High-value reference; selectively port only after engine and game loop are approved |
| VORZANE expedition/offline reward UX | Idle/progression RPG | High-value design reference; redesign settlement to be server-authoritative |
| VORZANE server read/init patterns | Any account-based persistent game | Reuse the security pattern, not blindly the old code; review JWT/RLS and server ownership |
| NEXORA atomic economy, ledger, market and org rules | Strategy/economy/social game | High-value domain reference if these mechanics belong in NOVA |
| Violencetown deterministic action model and NPC disposition | Turn-based RPG/simulation | Study and selectively reuse MIT code with notices if compatible |
| CodingQuests save/inventory/quest/combat modules | Godot project | MIT code candidates if NOVA selects Godot; otherwise use as behavior/design references |
| Embervale content/save/world separation | Browser action RPG | Design reference only pending license review |
| Kenney CC0 assets | Prototype art/UI/audio | Candidate asset source after choosing one coherent visual pack/style |
| Old-game music and character art | Any | Hold until per-file provenance/license is verified |

## 6. Recommended direction for NOVA (not yet an implementation decision)

1. Define NOVA's genre, core 30-second/5-minute gameplay loops, camera/perspective, and whether it is primarily action, turn-based, idle, management, or a hybrid.
2. Choose the engine and runtime based on that decision. Do not choose Phaser/Godot/Expo by habit.
3. Create a clean domain layer with deterministic, testable rules and data-driven content catalogs.
4. Define versioned saves, explicit offline/reconnect behavior, and safe import/recovery before substantial progression is added.
5. Put all valuable mutations behind authenticated server commands and atomic database transactions. Use idempotency keys and version checks.
6. Build the Android-first shell and test touch, safe areas, portrait/landscape, startup performance, and offline behavior before content scale-up.
7. Only then select and port individual legacy modules or licensed third-party modules, preserving attribution and testing each one independently.

## 7. Scope boundary

This document records research and candidate reuse only. It does not authorize:
- starting full game implementation;
- copying all legacy source or assets wholesale;
- importing Firebase, Vercel, or a legacy database into NOVA;
- making production Supabase schema/data changes;
- claiming any legacy system has been independently re-tested in NOVA.

The next implementation step requires a confirmed NOVA game concept and an explicitly selected first gameplay slice.
