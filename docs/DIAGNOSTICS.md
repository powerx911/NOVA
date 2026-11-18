# NEXORA Diagnostics System (`docs/DIAGNOSTICS.md`)

> Last Updated: `2026-11-15`  
> Official Stack: **Firebase Authentication**, **Cloud Firestore Enterprise Edition**, **Firebase Cloud Functions Gen 2 (`nodejs22`)**

---

## 1. Overview & Purpose
The **NEXORA Diagnostics System** provides a **strictly read-only, owner-restricted** administrative health and security monitor inside the NEXORA app (`Profile -> Diagnostics / Settings`). Its sole purpose is to inspect live system health, database structure, and sanitized runtime errors, then generate a unified **JSON diagnostic report** suitable for external debugging and analysis (e.g., pasting into ChatGPT).

> **Honesty Note**: There is **no** direct ChatGPT API integration or outbound LLM key in NEXORA. The system exports a clean, redacted JSON report for manual copy-and-paste analysis.

---

## 2. Security & Access Control Model

### Owner-Only Enforcement (Zero Client Trust)
Diagnostics execution and JSON report generation are restricted exclusively to authorized project owners verified via:
1. **Firebase Auth Verified Email**: `request.auth != null && request.auth.token.email_verified == true`.
2. **Server-Verifiable Owner Proof** (any one of):
   - Firebase Auth Custom Claim: `diagnosticsOwner === true` (generic `admin: true` alone is explicitly rejected)
   - Read-only Firestore Admin Registry (`diagnostics_admins/{uid}` with `enabled === true` and `role === 'owner'`) — locked in `firestore.rules` with `allow list, create, update, delete: if false;` so no client can write or elevate permissions
   - Server-side Cloud Function environment allowlists (`DIAGNOSTICS_ALLOWED_UIDS` / `DIAGNOSTICS_ALLOWED_EMAILS`)

### Read-Only & Anti-Abuse Guarantees
- **Allowed Actions Only**: `run_diagnostics` and `health_ping`. Any mutation action (`write`, `create`, `update`, `delete`, `patch`, `transfer`, `adjust_balance`, `grant`) is explicitly rejected (`PERMISSION_DENIED`).
- **No Arbitrary Queries**: Any request containing `collection`, `collectionName`, `query`, `sql`, `where`, `path`, or `data` is rejected (`INVALID_ARGUMENT`).
- **Allowlisted Collections**: Only the exact 23 collections verified against `firebase-blueprint.json` and `firestore.rules` can be counted.
- **Rate Limiting**: Gen 2 Cloud Function enforces a per-UID sliding window (`6` requests per `60` seconds -> `RESOURCE_EXHAUSTED`).
- **Zero PII & Zero Secrets**: Both client (`src/lib/diagnosticsSanitizer.ts`) and server (`functions/src/diagnosticsCore.ts`) recursively strip emails, JWTs, Bearer tokens, Google API keys (`AIza...`), GitHub PATs, PEM private keys, passwords, and `serviceAccount` fields before returning or copying any report.

---

## 3. Architecture

### A. Backend (Cloud Functions Gen 2 — `/functions/`)
- **`functions/src/index.ts`**: Exports `nexoraDiagnostics` (`onCall`, `region: 'us-central1'`, `nodejs22`, `enforceAppCheck` configurable via `NEXORA_ENFORCE_APP_CHECK=true`), targeting the named Enterprise database `ai-studio-74843d9e-8228-49b7-a616-317cadd90bff`.
- Uses Firestore aggregation `count().get()` instead of downloading full collections.
- Performs bounded referential integrity checks (up to 50 sampled profiles for `orgId` consistency, negative wallet invariant check, active market listings with `remainingQty <= 0`).

### B. Client Diagnostics Layer (`/src/services/diagnosticsService.ts`)
- Verifies owner status via ID token claims, `diagnostics_admins/{uid}`, or `nexoraDiagnostics` health ping.
- Calls `nexoraDiagnostics` (`httpsCallable`) when deployed.
- If the Gen 2 Cloud Function is not deployed/reachable, honestly reports `firebaseHealth.backendFunctions.status = 'unavailable'` and executes **strictly rules-compliant read-only fallbacks** (using `getCountFromServer` on public/filtered/owner-scoped queries, while marking PII-restricted collections such as `users_private` as `'unavailable'`).

### C. Sanitized Error Monitor (`/src/lib/diagnosticsSanitizer.ts`)
- Captures sanitized errors from `handleFirestoreError` and `testFirestoreConnection` in `src/lib/firebase.ts` into a bounded in-memory ring buffer (max 40 entries), stripping all PII and tokens.

### D. Unified JSON Report Schema
Top-level keys exported by **Generate Diagnostic Report** / **Copy JSON Report**:
- `reportVersion`
- `generatedAt`
- `projectIdentifier`
- `environment`
- `firebaseHealth`
- `authenticationHealth`
- `databaseCollections`
- `gameSystems`
- `securityChecks`
- `recentSanitizedErrors`
- `warnings`
- `failedChecks`

---

## 4. Enabling Owner Access & Deploying Cloud Functions

### Step 1: Grant Owner Access (Choose One)
- **Option A (Recommended — Custom Claim via Firebase Admin SDK)**:
  ```js
  await getAuth().setCustomUserClaims('<OWNER_UID>', { diagnosticsOwner: true });
  ```
- **Option B (Firestore Console — `diagnostics_admins/{uid}`)**:
  Create document `diagnostics_admins/<OWNER_UID>` in database `ai-studio-74843d9e-8228-49b7-a616-317cadd90bff` with:
  ```json
  { "uid": "<OWNER_UID>", "enabled": true, "role": "owner", "updatedAt": "<server-timestamp>" }
  ```

### Step 2: Deploy Cloud Functions Gen 2
The `/functions` workspace is built and type-checked locally (`npm run build --prefix functions`), and `firebase.json` is configured. To deploy to Firebase from an authenticated terminal:
```bash
firebase login
firebase deploy --only functions --project gen-lang-client-0074900177
```
Optional App Check & server allowlist env vars on Cloud Functions:
- `NEXORA_ENFORCE_APP_CHECK=true`
- `DIAGNOSTICS_ALLOWED_UIDS=uid1,uid2`
- `DIAGNOSTICS_ALLOWED_EMAILS=owner@example.com`
