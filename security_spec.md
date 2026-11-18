# NEXORA Firestore Security Specification

## 1. Data Invariants
1. **Identity & PII Isolation**: `users_private/{uid}` (email, preferences) is readable and writable strictly by `request.auth.uid == uid` with `email_verified == true`. Public `profiles/{uid}` never stores PII.
2. **Unique Usernames**: `usernames/{usernameLower}` cannot be overwritten by another UID.
3. **Wallet Integrity & Anti-Negative Guard**: `wallets/{uid}` initializes once at exact starting capital (`balance == 2500`). Any update requires `balance >= 0` and an atomic `transactions/{txId}` entry created in the same transaction whose `amount` / `netAmount` matches the exact balance delta.
4. **Immutable Ledgers**: `transactions`, `market_orders`, `organization_transactions`, `company_logs`, and `audit_logs` are append-only (`allow update, delete: if false`).
5. **No Double Claims**: `player_missions/{uid}_{missionId}`, `daily_claims/{uid}_{dateKey}`, and `contract_claims/{uid}_{contractId}` are create-once and immutable.
6. **Organization RBAC**: Treasury withdrawals, member role modifications, and join request approvals check the actor's `organization_members/{orgId}_{request.auth.uid}` role/permissions via `get()`.
7. **Market Escrow Integrity**: Buying a listing requires decrementing `remainingQty` atomically (`remainingQty >= 0`) and paying `unitPrice * qty` via a verified `market_buy` transaction.

## 2. The "Dirty Dozen" Attack Payloads (Expected: PERMISSION_DENIED)
1. **Direct Wallet Inflation**: `{ balance: 999999 }` update on `wallets/{uid}` without an atomic `transactions/{txId}`.
2. **Negative Balance Drain**: `{ balance: -100 }` update on `wallets/{uid}`.
3. **Shadow Field Injection**: `{ uid, username, ..., isAdmin: true }` on `profiles/{uid}`.
4. **PII Snooping**: `get` on `users_private/{otherUid}` by another authenticated user.
5. **Unverified Email Write**: Any write where `request.auth.token.email_verified == false`.
6. **Identity Spoofing**: Creating `companies/{id}` with `ownerUid: otherUid`.
7. **Duplicate Mission Claim**: Re-creating `player_missions/{uid}_tut_1` or updating it.
8. **Fake Mission Reward Amount**: Creating `transactions/{txId}` with `type: 'mission_reward'`, `amount: 500000`.
9. **Unauthorized Org Treasury Withdrawal**: Member with `role: 'member'` withdrawing from `organizations/{orgId}.treasuryBalance`.
10. **Username Hijacking**: Overwriting `usernames/{existingName}` with `uid: attackerUid`.
11. **Oversized Resource Poisoning**: Document ID > 128 chars or containing invalid symbols like `../admin`.
12. **Terminal State Reopening**: Updating a `market_listings/{id}` with `status: 'sold'` back to `status: 'active'`.
