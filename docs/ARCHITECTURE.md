# NEXORA Technical Architecture

## 1. Official Platform Stack
- **Frontend**: React 19, TypeScript, Vite 8, Tailwind CSS v4, Lucide Icons, Motion.
- **Authentication**: Firebase Authentication (`GoogleAuthProvider` via `signInWithPopup`).
- **Database & Persistence**: Cloud Firestore Enterprise Edition (`ai-studio-74843d9e-8228-49b7-a616-317cadd90bff`), configured via `firebase-applet-config.json`.
- **Backend Functions**: Firebase Cloud Functions Gen 2 (`functions/`, Node 22) providing owner-restricted read-only diagnostics aggregations (`nexoraDiagnostics`).
- **Server-Enforced Integrity**: `firestore.rules` (compiled and deployed via Firebase Rules Engine, validated with `@firebase/eslint-plugin-security-rules`).

---

## 2. Layered Codebase Structure
- `src/types/game.ts`: TypeScript domain interfaces for profiles, private user data, wallets, transactions, inventory items, recipes, market listings/orders, companies, properties, organizations, missions, achievements, notifications, and world events.
- `src/data/catalog.ts`: Deterministic game constants, commodity tiers, 3-tier manufacturing recipes, 5 company sectors, 3 property tiers, trade contracts, missions, achievements, and starter world events.
- `src/lib/economy.ts`: Pure deterministic calculation engine for XP/level curves, market tax rates, dynamic item pricing, hourly company and property net yields, manufacturing cost discounts, daily stipends, progression bounds, transfer validation, and RBAC permission helpers.
- `src/lib/firebase.ts`: Initializes Firebase App, Firebase Auth, Cloud Firestore (`firebaseConfig.firestoreDatabaseId`), and Cloud Functions (`us-central1`). Runs `testFirestoreConnection()` (`getDocFromServer`) at startup and routes errors through `handleFirestoreError()` + sanitized diagnostic monitor.
- `src/services/gameService.ts`: Implements atomic Firestore `runTransaction` mutations so balance updates, ledger records, inventory changes, asset updates, and organization treasury changes commit together or roll back atomically.
- `src/services/diagnosticsService.ts`: Owner-gated, read-only client diagnostics runner interfacing with `nexoraDiagnostics` Gen 2 callable and rules-compliant read-only fallbacks.
- `src/hooks/useGameData.ts`: Manages `onAuthStateChanged` lifecycle, resets all scoped state on sign-out, refreshes UTC date key across midnight, guards org-membership profile synchronization with `orgMemberLoaded`, and scopes `organization_requests` subscriptions to applicants and authorized member managers.
- `src/features/*`: Modular portrait-first views (`auth`, `home`, `business`, `market`, `organization`, `profile`, and lazy-loaded `diagnostics`).
- `src/components/ui/*`: Shared UI primitives (`AppShell`, `EconomicChart`, `ConfirmDialog`, `ToastProvider`).
- `functions/src/*`: Cloud Functions Gen 2 (`nexoraDiagnostics`) with ID Token verification, `diagnosticsOwner` / `diagnostics_admins/{uid}` authorization, rate limiting, and secret/PII redaction.

---

## 3. Authentication & Session Lifecycle
1. `onAuthStateChanged` resolves user session state (`authReady`).
2. Unauthenticated users see Google Sign-In (`AuthOnboardingView` in `signin` mode) with localized error feedback for popup/network issues.
3. Authenticated users without `profiles/{uid}` enter character onboarding (`onboarding` mode), reserving a unique lowercase username in `usernames/{usernameLower}` and atomically creating `profiles/{uid}`, `users_private/{uid}`, `wallets/{uid}` (`2,500 N-Credits`), and an initial notification.
4. `firestore.rules` rejects all read/write operations (except `test/connection`) unless `request.auth != null && request.auth.token.email_verified == true`.

---

## 4. Server-Enforced Atomic Operations (Firestore Rules + `runTransaction`)
Because NEXORA runs directly on Cloud Firestore without a separate custom API server, critical state invariants are enforced server-side by Google's Firestore Security Rules engine on every transaction commit:
- **Wallets & Ledger**: `wallets/{uid}` cannot be edited directly; every balance delta must reference a newly created `transactions/{txId}` in the same transaction (`getAfter`), and `isWalletDeltaValid` verifies exact arithmetic (`oldBalance - amount` or `oldBalance + netAmount`).
- **Inventory & Market Escrow**: Creating a listing atomically deducts seller inventory; buying atomically updates `remainingQty`, debits buyer wallet, credits seller wallet (with bounded tax `0 <= fee <= 12% + 0.5`), creates `transactions/{txId}` + `market_orders/{orderId}` (linked by `txId`), and credits buyer inventory matching listing item & quantity delta; cancelling atomically refunds seller inventory using `lastListingId`.
- **Companies & Properties**: Upgrades, staff hiring (`company_hire` at 250 N-Credits), and revenue/rent collections must pair with matching atomic wallet transactions and enforce immutable base revenue/rent/expense parameters plus time-proportional collection caps (`request.time - lastCollectedAt`).
- **Organizations (RBAC & Treasury)**: Role changes, join approvals, and treasury withdrawals check `organization_members/{orgId}_{request.auth.uid}` permissions via `get()` on Firestore servers. Join request listing is restricted to applicants and `manage_members` managers. Treasury deposits/withdrawals require exact matching `org_deposit` / `org_withdraw` wallet transactions.
- **No Duplicate Claims**: `daily_claims`, `player_missions`, and `contract_claims` use deterministic IDs and immutable `allow update, delete: if false` rules.
