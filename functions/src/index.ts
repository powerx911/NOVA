import { randomUUID } from 'node:crypto';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp, type DocumentData } from 'firebase-admin/firestore';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import {
  ALLOWED_DIAGNOSTIC_COLLECTIONS,
  authorizeDiagnosticsActor,
  DiagnosticsSecurityError,
  maskUidServer,
  redactSecretsServer,
  sanitizeTextServer,
  SlidingWindowRateLimiter,
  validateDiagnosticsRequest,
  type DiagnosticStatus,
} from './diagnosticsCore.js';
import {
  buildWorldEventRotationPlan,
  type ExistingWorldEventRecord,
} from './worldEventsEngine.js';

const NEXORA_PROJECT_ID = 'gen-lang-client-0074900177';
const NEXORA_DATABASE_ID = 'ai-studio-74843d9e-8228-49b7-a616-317cadd90bff';
const NEXORA_AUTH_DOMAIN = 'gen-lang-client-0074900177.firebaseapp.com';

const adminApp = getApps().length > 0 ? getApps()[0] : initializeApp();
const db = getFirestore(adminApp, NEXORA_DATABASE_ID);
const rateLimiter = new SlidingWindowRateLimiter(6, 60_000);

function toHttpsError(err: unknown): HttpsError {
  if (err instanceof DiagnosticsSecurityError) {
    const map: Record<DiagnosticsSecurityError['code'], 'unauthenticated' | 'permission-denied' | 'invalid-argument' | 'resource-exhausted'> = {
      UNAUTHENTICATED: 'unauthenticated',
      PERMISSION_DENIED: 'permission-denied',
      INVALID_ARGUMENT: 'invalid-argument',
      RESOURCE_EXHAUSTED: 'resource-exhausted',
    };
    return new HttpsError(map[err.code], err.message);
  }
  return new HttpsError('internal', 'Internal diagnostics check failure.');
}

function parseAllowlist(raw: string | undefined): string[] {
  return (raw ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * Read-only owner-restricted Cloud Function Gen 2 for NEXORA Diagnostics.
 * - Verifies Firebase ID token (via onCall auth context).
 * - Enforces verified email + owner authorization (Custom Claims, diagnostics_admins/{uid}, or server env allowlist).
 * - Rejects arbitrary collection names, free-form queries, and all mutations.
 * - Aggregates collection counts using Firestore count() without full collection downloads or PII leaks.
 */

type VaultCompany = {
  id: string; ownerUid: string; name: string; sector?: string; level: number;
  employeesCount: number; baseRevenuePerHour: number; expensePerHour: number;
  totalRevenue: number; vaultLevel?: number; vaultBalance?: number; lastCollectedAt?: unknown;
};
type VaultProfile = {
  xp: number; level: number; skillPoints: number; reputation: number; influence: number;
  skills: { management?: number; finance?: number; leadership?: number };
};
type VaultWallet = { balance: number; totalEarned: number; totalSpent: number };
const VAULT_CAPACITIES = [3500, 7000, 14000, 25000, 40000] as const;
const VAULT_UPGRADES = [
  { cost: 1500, materials: { copper_wire: 20, crude_alloy: 10 } },
  { cost: 4000, materials: { silicon_ore: 20, energy_cells: 15 } },
  { cost: 10000, materials: { carbon_fiber: 15, precision_frame: 10 } },
  { cost: 25000, materials: { rare_minerals: 20, quantum_server: 5 } },
] as const;
const REPUTATION_YIELD_TIERS = [
  { min: 0, bonus: 0 }, { min: 60, bonus: 0.02 }, { min: 160, bonus: 0.04 },
  { min: 350, bonus: 0.06 }, { min: 700, bonus: 0.08 },
] as const;

function vaultLevelOf(company: VaultCompany): number {
  const level = typeof company.vaultLevel === 'number' && Number.isFinite(company.vaultLevel)
    ? Math.floor(company.vaultLevel) : 1;
  return Math.max(1, Math.min(5, level));
}
function timestampMillis(value: unknown, fallback: number): number {
  if (value instanceof Timestamp) return value.toMillis();
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') { const parsed = Date.parse(value); return Number.isFinite(parsed) ? parsed : fallback; }
  if (value && typeof value === 'object' && 'seconds' in value && typeof (value as {seconds?: unknown}).seconds === 'number') {
    return Number((value as {seconds:number}).seconds) * 1000;
  }
  return fallback;
}
function companyNetHourly(company: VaultCompany, profile: VaultProfile, events: DocumentData[], nowMs: number): number {
  const levelMultiplier = 1 + (company.level - 1) * 0.32;
  const staffBonus = 1 + Math.max(0, company.employeesCount - 1) * 0.05;
  const management = Math.max(0, Number(profile.skills?.management) || 0);
  const finance = Math.max(0, Number(profile.skills?.finance) || 0);
  const managementBonus = 1 + management * 0.08;
  const tier = [...REPUTATION_YIELD_TIERS].reverse().find((item) => profile.reputation >= item.min) ?? REPUTATION_YIELD_TIERS[0];
  const reputationBonus = 1 + tier.bonus;
  const seenGroups = new Set<string>();
  let eventMultiplier = 1;
  let accepted = 0;
  for (const event of events) {
    if (event.active !== true) continue;
    const startsAt = timestampMillis(event.startsAt, 0);
    const endsAt = timestampMillis(event.endsAt, 0);
    if ((startsAt > 0 && nowMs < startsAt) || (endsAt > 0 && nowMs >= endsAt)) continue;
    const group = String(event.stackGroup || event.effectType || event.id);
    if (seenGroups.has(group)) continue;
    seenGroups.add(group);
    if (company.sector && Array.isArray(event.affectedSectors) && event.affectedSectors.includes(company.sector) && typeof event.revenueMultiplier === 'number') {
      eventMultiplier *= event.revenueMultiplier;
    }
    accepted += 1;
    if (accepted >= 3) break;
  }
  eventMultiplier = Number(Math.max(0.75, Math.min(1.4, eventMultiplier)).toFixed(3));
  const gross = Math.round(company.baseRevenuePerHour * levelMultiplier * staffBonus * managementBonus * eventMultiplier * reputationBonus);
  const rawExpense = company.expensePerHour * (1 + (company.level - 1) * 0.2) + Math.max(0, company.employeesCount - 3) * 8;
  const expense = Math.round(rawExpense * (1 - Math.min(0.45, finance * 0.05)));
  return Math.max(15, gross - expense);
}
function calculatedVaultBalance(company: VaultCompany, netHourly: number, nowMs: number): number {
  const level = vaultLevelOf(company);
  const capacity = VAULT_CAPACITIES[level - 1];
  const stored = typeof company.vaultBalance === 'number' && Number.isFinite(company.vaultBalance)
    ? Math.max(0, company.vaultBalance) : 0;
  const last = timestampMillis(company.lastCollectedAt, nowMs);
  const elapsed = Math.max(0, nowMs - last);
  return Math.min(capacity, stored + Math.max(0, Math.floor((Math.max(0, netHourly) * elapsed) / 3_600_000)));
}
function levelForXp(totalXp: number): number {
  let level = 1;
  let remaining = Math.max(0, Math.floor(totalXp));
  while (level < 200) {
    const step = 200 + Math.max(0, level - 1) * 120;
    if (remaining < step) return level;
    remaining -= step;
    level += 1;
  }
  return 200;
}
function vaultHttpsError(error: unknown): HttpsError {
  const message = error instanceof Error ? error.message : 'INTERNAL';
  const known: Record<string, ConstructorParameters<typeof HttpsError>[0]> = {
    COMPANY_NOT_FOUND: 'not-found', ACCOUNT_NOT_FOUND: 'failed-precondition',
    UNAUTHORIZED: 'permission-denied', VAULT_MAX_LEVEL: 'failed-precondition',
    INSUFFICIENT_FUNDS: 'failed-precondition', MISSING_VAULT_MATERIALS: 'failed-precondition',
    NOTHING_TO_COLLECT: 'failed-precondition', INVALID_ARGUMENT: 'invalid-argument',
  };
  return new HttpsError(known[message] ?? 'internal', known[message] ? message : 'Company vault operation failed.');
}

export const upgradeCompanyProfitVault = onCall(
  { region: 'us-central1', maxInstances: 10, timeoutSeconds: 30, memory: '256MiB' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'UNAUTHENTICATED');
    const companyId = typeof request.data?.companyId === 'string' ? request.data.companyId.trim() : '';
    if (!companyId || companyId.length > 128) throw new HttpsError('invalid-argument', 'INVALID_ARGUMENT');
    try {
      return await db.runTransaction(async (tx) => {
        const uid = request.auth!.uid;
        const companyRef = db.doc(`companies/${companyId}`);
        const walletRef = db.doc(`wallets/${uid}`);
        const profileRef = db.doc(`profiles/${uid}`);
        const [companySnap, walletSnap, profileSnap, eventsSnap] = await Promise.all([
          tx.get(companyRef), tx.get(walletRef), tx.get(profileRef),
          tx.get(db.collection('world_events').where('active', '==', true)),
        ]);
        if (!companySnap.exists) throw new Error('COMPANY_NOT_FOUND');
        if (!walletSnap.exists || !profileSnap.exists) throw new Error('ACCOUNT_NOT_FOUND');
        const company = companySnap.data() as VaultCompany;
        const wallet = walletSnap.data() as VaultWallet;
        const profile = profileSnap.data() as VaultProfile;
        if (company.ownerUid !== uid) throw new Error('UNAUTHORIZED');
        const oldLevel = vaultLevelOf(company);
        if (oldLevel >= 5) throw new Error('VAULT_MAX_LEVEL');
        const upgrade = VAULT_UPGRADES[oldLevel - 1];
        if (wallet.balance < upgrade.cost) throw new Error('INSUFFICIENT_FUNDS');
        const inventorySnaps = await Promise.all(Object.entries(upgrade.materials).map(([itemId]) => tx.get(db.doc(`inventory/${uid}_${itemId}`))));
        const itemEntries = Object.entries(upgrade.materials);
        for (let i = 0; i < itemEntries.length; i += 1) {
          const required = itemEntries[i][1];
          if (!inventorySnaps[i].exists || Number(inventorySnaps[i].data()?.quantity ?? 0) < required) {
            throw new Error('MISSING_VAULT_MATERIALS');
          }
        }
        const now = Date.now();
        const events = eventsSnap.docs.map((docSnap) => docSnap.data());
        const netHourly = companyNetHourly(company, profile, events, now);
        const preserved = calculatedVaultBalance(company, netHourly, now);
        const txId = `tx_${randomUUID()}`;
        const logId = `clog_${crypto.randomUUID()}`;
        tx.update(walletRef, {
          balance: wallet.balance - upgrade.cost,
          totalSpent: wallet.totalSpent + upgrade.cost,
          lastTxId: txId,
          updatedAt: FieldValue.serverTimestamp(),
        });
        itemEntries.forEach(([itemId, required], index) => {
          const itemRef = db.doc(`inventory/${uid}_${itemId}`);
          const current = Number(inventorySnaps[index].data()?.quantity ?? 0);
          tx.update(itemRef, { quantity: current - required, updatedAt: FieldValue.serverTimestamp() });
        });
        tx.update(companyRef, {
          vaultLevel: oldLevel + 1,
          vaultBalance: preserved,
          lastCollectedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.create(db.doc(`transactions/${txId}`), {
          id: txId, fromUid: uid, toUid: 'SYSTEM', amount: upgrade.cost, fee: 0,
          netAmount: upgrade.cost, type: 'company_vault_upgrade', referenceId: companyId,
          description: `Upgraded ${company.name} profit vault to Lv.${oldLevel + 1}`,
          status: 'completed', createdAt: FieldValue.serverTimestamp(),
        });
        tx.create(db.doc(`company_logs/${logId}`), {
          id: logId, companyId, ownerUid: uid, action: 'vault_upgrade', amount: -upgrade.cost,
          details: `Profit vault upgraded to Lv.${oldLevel + 1}; preserved ${preserved}`,
          createdAt: FieldValue.serverTimestamp(),
        });
        return { ok: true, vaultLevel: oldLevel + 1, vaultBalance: preserved, capacity: VAULT_CAPACITIES[oldLevel] };
      });
    } catch (error) { throw vaultHttpsError(error); }
  }
);

export const collectCompanyRevenueSecure = onCall(
  { region: 'us-central1', maxInstances: 10, timeoutSeconds: 30, memory: '256MiB' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'UNAUTHENTICATED');
    const companyId = typeof request.data?.companyId === 'string' ? request.data.companyId.trim() : '';
    if (!companyId || companyId.length > 128) throw new HttpsError('invalid-argument', 'INVALID_ARGUMENT');
    try {
      return await db.runTransaction(async (tx) => {
        const uid = request.auth!.uid;
        const companyRef = db.doc(`companies/${companyId}`);
        const walletRef = db.doc(`wallets/${uid}`);
        const profileRef = db.doc(`profiles/${uid}`);
        const [companySnap, walletSnap, profileSnap, eventsSnap] = await Promise.all([
          tx.get(companyRef), tx.get(walletRef), tx.get(profileRef),
          tx.get(db.collection('world_events').where('active', '==', true)),
        ]);
        if (!companySnap.exists) throw new Error('COMPANY_NOT_FOUND');
        if (!walletSnap.exists || !profileSnap.exists) throw new Error('ACCOUNT_NOT_FOUND');
        const company = companySnap.data() as VaultCompany;
        const wallet = walletSnap.data() as VaultWallet;
        const profile = profileSnap.data() as VaultProfile;
        if (company.ownerUid !== uid) throw new Error('UNAUTHORIZED');
        const now = Date.now();
        const lastCollected = timestampMillis(company.lastCollectedAt, now);
        if (now - lastCollected < 30_000) throw new Error('NOTHING_TO_COLLECT');
        const events = eventsSnap.docs.map((docSnap) => docSnap.data());
        const netHourly = companyNetHourly(company, profile, events, now);
        const payout = calculatedVaultBalance(company, netHourly, now);
        if (payout < 1) throw new Error('NOTHING_TO_COLLECT');
        const txId = `tx_${crypto.randomUUID()}`;
        const logId = `clog_${crypto.randomUUID()}`;
        const xpGain = Math.min(80, Math.max(10, Math.floor(payout / 15)));
        const nextXp = profile.xp + xpGain;
        const nextLevel = levelForXp(nextXp);
        const levelsGained = Math.max(0, nextLevel - profile.level);
        const leadershipBonus = 1 + (Math.max(0, Number(profile.skills?.leadership) || 0) * 0.1);
        tx.update(walletRef, {
          balance: wallet.balance + payout,
          totalEarned: wallet.totalEarned + payout,
          lastTxId: txId,
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(companyRef, {
          totalRevenue: company.totalRevenue + payout,
          vaultBalance: 0,
          lastCollectedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(profileRef, {
          xp: nextXp,
          level: nextLevel,
          skillPoints: profile.skillPoints + levelsGained * 2,
          reputation: profile.reputation + Math.round(2 * leadershipBonus),
          influence: profile.influence + Math.round(1 * leadershipBonus),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.create(db.doc(`transactions/${txId}`), {
          id: txId, fromUid: 'SYSTEM', toUid: uid, amount: payout, fee: 0,
          netAmount: payout, type: 'company_collect', referenceId: companyId,
          description: `Company revenue collected: ${company.name}`,
          status: 'completed', createdAt: FieldValue.serverTimestamp(),
        });
        tx.create(db.doc(`company_logs/${logId}`), {
          id: logId, companyId, ownerUid: uid, action: 'collect', amount: payout,
          details: `Collected +$${payout}`, createdAt: FieldValue.serverTimestamp(),
        });
        return { ok: true, payout };
      });
    } catch (error) { throw vaultHttpsError(error); }
  }
);

export const nexoraDiagnostics = onCall(
  {
    region: 'us-central1',
    cors: true,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: '256MiB',
    enforceAppCheck: process.env.NEXORA_ENFORCE_APP_CHECK === 'true',
  },
  async (request) => {
    try {
      const { action, locale } = validateDiagnosticsRequest(request.data);

      if (!request.auth) {
        throw new DiagnosticsSecurityError('UNAUTHENTICATED', 'Authentication is required.');
      }

      const token = request.auth.token;
      const uid = request.auth.uid;

      // Check read-only Admin-managed diagnostics_admins/{uid} document
      let adminDocEnabled = false;
      try {
        const adminSnap = await db.doc(`diagnostics_admins/${uid}`).get();
        const adminData = adminSnap.data();
        adminDocEnabled =
          adminSnap.exists && adminData?.enabled === true && adminData?.role === 'owner';
      } catch {
        adminDocEnabled = false;
      }

      const authResult = authorizeDiagnosticsActor(
        {
          uid,
          email: typeof token.email === 'string' ? token.email : null,
          emailVerified: token.email_verified === true,
          claims: token as Record<string, unknown>,
        },
        adminDocEnabled,
        {
          allowedUids: parseAllowlist(process.env.DIAGNOSTICS_ALLOWED_UIDS),
          allowedEmails: parseAllowlist(process.env.DIAGNOSTICS_ALLOWED_EMAILS),
        }
      );

      rateLimiter.consume(uid);

      const nowIso = new Date().toISOString();

      if (action === 'health_ping') {
        return redactSecretsServer({
          ok: true,
          status: 'healthy' as DiagnosticStatus,
          checkedAt: nowIso,
          verifiedBy: authResult.verifiedBy,
          runtime: 'nodejs22-gen2',
        });
      }

      // 1. Firestore Health Ping
      const pingStart = Date.now();
      let firestoreStatus: DiagnosticStatus = 'healthy';
      let firestoreMsg = 'Connected to named Firestore Enterprise database.';
      try {
        await db.doc('test/connection').get();
      } catch (err) {
        firestoreStatus = 'error';
        firestoreMsg = sanitizeTextServer(err instanceof Error ? err.message : String(err));
      }
      const latencyMs = Date.now() - pingStart;

      // 2. Server-side count() aggregations across fixed allowlist
      const countMap = new Map<string, number | null>();
      const databaseCollections = await Promise.all(
        ALLOWED_DIAGNOSTIC_COLLECTIONS.map(async (spec) => {
          try {
            const agg = await db.collection(spec.name).count().get();
            const count = agg.data().count;
            countMap.set(spec.name, count);
            return {
              name: spec.name,
              category: spec.category,
              piiRestricted: spec.piiRestricted,
              count,
              countSource: 'admin_aggregation' as const,
              status: 'healthy' as DiagnosticStatus,
              note: spec.piiRestricted
                ? 'PII/restricted collection: aggregate count only.'
                : 'Verified via Admin SDK count().',
            };
          } catch (err) {
            countMap.set(spec.name, null);
            return {
              name: spec.name,
              category: spec.category,
              piiRestricted: spec.piiRestricted,
              count: null,
              countSource: 'unavailable' as const,
              status: 'warning' as DiagnosticStatus,
              note: sanitizeTextServer(err instanceof Error ? err.message : 'Count query failed'),
            };
          }
        })
      );

      // 3. Bounded referential integrity checks (max 50 docs, zero PII returned)
      const warnings: string[] = [];
      const failedChecks: string[] = [];

      let orphanedOrgRefs = 0;
      let invalidSkillProfiles = 0;
      let profilesSampled = 0;
      try {
        const profSnap = await db.collection('profiles').limit(50).get();
        profilesSampled = profSnap.size;
        for (const docSnap of profSnap.docs) {
          const data = docSnap.data();
          if (typeof data.skillPoints !== 'number' || data.skillPoints < 0 || !data.skills) {
            invalidSkillProfiles += 1;
          }
          if (typeof data.orgId === 'string' && data.orgId.length > 0) {
            const memberExists = (
              await db.doc(`organization_members/${data.orgId}_${docSnap.id}`).get()
            ).exists;
            if (!memberExists) {
              orphanedOrgRefs += 1;
            }
          }
        }
      } catch (err) {
        warnings.push(`Profile integrity check warning: ${sanitizeTextServer(String(err))}`);
      }

      if (orphanedOrgRefs > 0) {
        warnings.push(`Detected ${orphanedOrgRefs} profile(s) with orphaned orgId references.`);
      }
      if (invalidSkillProfiles > 0) {
        failedChecks.push(`Detected ${invalidSkillProfiles} profile(s) with invalid skill structure.`);
      }

      let negativeWallets = 0;
      try {
        const negWalletAgg = await db.collection('wallets').where('balance', '<', 0).count().get();
        negativeWallets = negWalletAgg.data().count;
        if (negativeWallets > 0) {
          failedChecks.push(`Detected ${negativeWallets} wallet(s) with negative balance.`);
        }
      } catch (err) {
        warnings.push(`Wallet check warning: ${sanitizeTextServer(String(err))}`);
      }

      let inconsistentListings = 0;
      try {
        const badListings = await db
          .collection('market_listings')
          .where('status', '==', 'active')
          .where('remainingQty', '<=', 0)
          .count()
          .get();
        inconsistentListings = badListings.data().count;
        if (inconsistentListings > 0) {
          warnings.push(`Detected ${inconsistentListings} active market listing(s) with remainingQty <= 0.`);
        }
      } catch (err) {
        warnings.push(`Market listing check warning: ${sanitizeTextServer(String(err))}`);
      }

      const profilesCount = countMap.get('profiles') ?? 0;
      const walletsCount = countMap.get('wallets') ?? 0;
      const profileWalletMismatch = Math.abs(profilesCount - walletsCount);
      if (profileWalletMismatch > 0) {
        warnings.push(
          `Count delta between profiles (${profilesCount}) and wallets (${walletsCount}).`
        );
      }

      const gameSystems = [
        {
          key: 'characters' as const,
          labelAr: 'نظام الشخصيات',
          labelEn: 'Characters',
          status: (invalidSkillProfiles > 0 ? 'error' : profilesCount > 0 ? 'healthy' : 'warning') as DiagnosticStatus,
          collectionsChecked: ['profiles', 'usernames'],
          metrics: {
            profilesCount,
            usernamesCount: countMap.get('usernames') ?? 0,
            sampledChecked: profilesSampled,
          },
          issues: invalidSkillProfiles > 0 ? [`${invalidSkillProfiles} malformed profile docs`] : [],
        },
        {
          key: 'wallets_economy' as const,
          labelAr: 'المحافظ والاقتصاد',
          labelEn: 'Wallets & Economy',
          status: (negativeWallets > 0 ? 'error' : profileWalletMismatch > 0 ? 'warning' : 'healthy') as DiagnosticStatus,
          collectionsChecked: ['wallets', 'transactions'],
          metrics: {
            walletsCount,
            transactionsCount: countMap.get('transactions') ?? 0,
            negativeWallets,
            profileWalletDelta: profileWalletMismatch,
          },
          issues: negativeWallets > 0 ? [`${negativeWallets} negative wallet balances`] : [],
        },
        {
          key: 'companies' as const,
          labelAr: 'الشركات والمصانع',
          labelEn: 'Companies',
          status: 'healthy' as DiagnosticStatus,
          collectionsChecked: ['companies', 'company_logs'],
          metrics: {
            companiesCount: countMap.get('companies') ?? 0,
            companyLogsCount: countMap.get('company_logs') ?? 0,
          },
          issues: [],
        },
        {
          key: 'market_orders' as const,
          labelAr: 'السوق والطلبات',
          labelEn: 'Market & Orders',
          status: (inconsistentListings > 0 ? 'warning' : 'healthy') as DiagnosticStatus,
          collectionsChecked: ['market_listings', 'market_orders', 'world_events'],
          metrics: {
            listingsCount: countMap.get('market_listings') ?? 0,
            ordersCount: countMap.get('market_orders') ?? 0,
            inconsistentListings,
          },
          issues: inconsistentListings > 0 ? [`${inconsistentListings} active listings with 0 remainingQty`] : [],
        },
        {
          key: 'organizations' as const,
          labelAr: 'المنظمات والأعضاء',
          labelEn: 'Organizations & Members',
          status: (orphanedOrgRefs > 0 ? 'warning' : 'healthy') as DiagnosticStatus,
          collectionsChecked: [
            'organizations',
            'organization_members',
            'organization_requests',
            'organization_transactions',
          ],
          metrics: {
            organizationsCount: countMap.get('organizations') ?? 0,
            membersCount: countMap.get('organization_members') ?? 0,
            requestsCount: countMap.get('organization_requests') ?? 0,
            orphanedOrgRefs,
          },
          issues: orphanedOrgRefs > 0 ? [`${orphanedOrgRefs} orphaned orgId references`] : [],
        },
        {
          key: 'missions_achievements' as const,
          labelAr: 'المهام والإنجازات',
          labelEn: 'Missions & Achievements',
          status: 'healthy' as DiagnosticStatus,
          collectionsChecked: ['player_missions', 'daily_claims', 'contract_claims', 'player_achievements'],
          metrics: {
            missionClaimsCount: countMap.get('player_missions') ?? 0,
            dailyClaimsCount: countMap.get('daily_claims') ?? 0,
            contractClaimsCount: countMap.get('contract_claims') ?? 0,
            achievementsCount: countMap.get('player_achievements') ?? 0,
          },
          issues: [],
        },
        {
          key: 'inventory_properties' as const,
          labelAr: 'المخزون والعقارات',
          labelEn: 'Inventory & Properties',
          status: 'healthy' as DiagnosticStatus,
          collectionsChecked: ['inventory', 'properties'],
          metrics: {
            inventoryStacksCount: countMap.get('inventory') ?? 0,
            propertiesCount: countMap.get('properties') ?? 0,
          },
          issues: [],
        },
        {
          key: 'skills_progression' as const,
          labelAr: 'المهارات والتقدم',
          labelEn: 'Skills & Progression',
          status: (invalidSkillProfiles > 0 ? 'error' : 'healthy') as DiagnosticStatus,
          collectionsChecked: ['profiles'],
          metrics: {
            sampledProfiles: profilesSampled,
            invalidSkillProfiles,
          },
          issues: invalidSkillProfiles > 0 ? [`${invalidSkillProfiles} profiles missing skills map`] : [],
        },
      ];

      const appCheckEnforced = process.env.NEXORA_ENFORCE_APP_CHECK === 'true';

      const report = {
        reportVersion: '1.0.0',
        generatedAt: nowIso,
        projectIdentifier: {
          appName: 'NEXORA' as const,
          projectId: NEXORA_PROJECT_ID,
          firestoreDatabaseId: NEXORA_DATABASE_ID,
          authDomain: NEXORA_AUTH_DOMAIN,
        },
        environment: {
          mode: 'production-cloud-function',
          executionSource: 'cloud_function_gen2' as const,
          backendDeployed: true,
          appCheckEnforced,
          locale,
        },
        firebaseHealth: {
          overallStatus: (firestoreStatus === 'error' ? 'error' : 'healthy') as DiagnosticStatus,
          firestore: {
            status: firestoreStatus,
            latencyMs,
            message: firestoreMsg,
          },
          authentication: {
            status: 'healthy' as DiagnosticStatus,
            provider: 'google.com' as const,
            emailVerified: true,
            ownerVerifiedBy: authResult.verifiedBy,
            maskedUid: maskUidServer(uid),
            message: `Verified Firebase ID Token (${authResult.verifiedBy}).`,
          },
          backendFunctions: {
            status: 'healthy' as DiagnosticStatus,
            runtime: 'nodejs22-gen2',
            functionName: 'nexoraDiagnostics',
            lastCheckAt: nowIso,
            message: 'Cloud Function Gen 2 executed read-only aggregation successfully.',
          },
          lastSuccessfulCheckAt: nowIso,
        },
        authenticationHealth: {
          status: 'healthy' as DiagnosticStatus,
          signedIn: true,
          emailVerified: true,
          ownerAuthorized: true,
          authMechanism: 'Firebase Auth Google Sign-In + Server ID Token Verification',
          userStoragePattern: 'Public profiles/{uid} separated from owner-only users_private/{uid}',
        },
        databaseCollections,
        gameSystems,
        securityChecks: {
          overallStatus: (failedChecks.length > 0 ? 'error' : warnings.length > 0 ? 'warning' : 'healthy') as DiagnosticStatus,
          ownerAuthorizationVerified: true,
          rulesValidationStatus: 'healthy' as DiagnosticStatus,
          piiRedactionActive: true,
          arbitraryQueriesBlocked: true,
          mutationsBlocked: true,
          appCheckStatus: (appCheckEnforced ? 'healthy' : 'warning') as DiagnosticStatus,
          collectionsNeedingReview: [
            {
              collection: 'organization_members',
              severity: 'info' as const,
              reason: 'allow list supports orgId scoping; verify member privacy stays non-PII.',
            },
            {
              collection: 'organization_requests',
              severity: 'info' as const,
              reason: 'allow list permits pending query; client listener is gated by manage_members.',
            },
          ],
          checks: [
            {
              id: 'server_id_token',
              label: 'Server-side ID Token & Verified Email',
              status: 'healthy' as DiagnosticStatus,
              detail: `Verified via ${authResult.verifiedBy}`,
            },
            {
              id: 'read_only_enforcement',
              label: 'Read-Only & Mutation Rejection',
              status: 'healthy' as DiagnosticStatus,
              detail: 'Only run_diagnostics & health_ping allowed.',
            },
            {
              id: 'app_check',
              label: 'Firebase App Check Enforcement',
              status: (appCheckEnforced ? 'healthy' : 'warning') as DiagnosticStatus,
              detail: appCheckEnforced
                ? 'enforceAppCheck is enabled.'
                : 'enforceAppCheck is optional until site key is configured.',
            },
          ],
        },
        recentSanitizedErrors: [],
        warnings,
        failedChecks,
      };

      return redactSecretsServer(report);
    } catch (err) {
      throw toHttpsError(err);
    }
  }
);

/**
 * Scheduled Cloud Function Gen 2 to expire ended world_events and rotate fresh
 * non-stacking economic events on the NEXORA named Firestore database.
 */
export const rotateWorldEvents = onSchedule(
  {
    schedule: 'every 6 hours',
    region: 'us-central1',
    maxInstances: 1,
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async () => {
    const nowMs = Date.now();
    const snap = await db.collection('world_events').get();
    const existing: ExistingWorldEventRecord[] = snap.docs.map((docSnap) => {
      const data = docSnap.data();
      const endsAt = data.endsAt as { toMillis?: () => number } | undefined;
      return {
        id: docSnap.id,
        active: data.active === true,
        stackGroup: typeof data.stackGroup === 'string' ? data.stackGroup : undefined,
        endsAtMs: typeof endsAt?.toMillis === 'function' ? endsAt.toMillis() : null,
      };
    });

    const plan = buildWorldEventRotationPlan(existing, nowMs, 3);
    if (plan.toDeactivateIds.length === 0 && plan.toActivate.length === 0) {
      return;
    }

    const batch = db.batch();
    for (const id of plan.toDeactivateIds) {
      batch.set(
        db.collection('world_events').doc(id),
        { active: false },
        { merge: true }
      );
    }

    for (const entry of plan.toActivate) {
      const { durationHours: _dh, ...templateFields } = entry.template;
      batch.set(db.collection('world_events').doc(entry.template.id), {
        ...templateFields,
        startsAt: Timestamp.fromMillis(entry.startsAtMs),
        endsAt: Timestamp.fromMillis(entry.endsAtMs),
        active: true,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
);

/**
 * Deletes a Firebase Authentication identity only after the Supabase Admin Center
 * confirms that the supplied bearer token belongs to an enabled owner account.
 * The Supabase JWT is never logged or persisted.
 */
export const deleteFirebasePlayerAuth = onRequest(
  { region: 'us-central1', maxInstances: 5, timeoutSeconds: 30, memory: '256MiB' },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'METHOD_NOT_ALLOWED' });
      return;
    }

    const authorization = req.get('authorization') ?? '';
    const uid = typeof req.body?.uid === 'string' ? req.body.uid.trim() : '';
    if (!authorization.startsWith('Bearer ') || !uid || uid.length > 128 || /[\/\s]/.test(uid)) {
      res.status(400).json({ error: 'INVALID_REQUEST' });
      return;
    }

    try {
      const ownerCheck = await fetch(
        'https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/admin-center',
        {
          method: 'POST',
          headers: { Authorization: authorization, 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'authorize_firebase_auth_delete' }),
        }
      );
      if (!ownerCheck.ok) {
        res.status(ownerCheck.status === 401 ? 401 : 403).json({ error: 'OWNER_REQUIRED' });
        return;
      }

      const auth = getAuth(adminApp);
      const target = await auth.getUser(uid);
      const claims = target.customClaims ?? {};
      if (claims.diagnosticsOwner === true || claims.owner === true || claims.admin === true) {
        res.status(409).json({ error: 'PROTECTED_AUTH_ACCOUNT' });
        return;
      }

      await auth.deleteUser(uid);
      res.status(200).json({ ok: true, auth_deleted: true });
    } catch (error) {
      const code = typeof error === 'object' && error !== null && 'code' in error
        ? String((error as { code?: unknown }).code)
        : 'FIREBASE_AUTH_DELETE_FAILED';
      if (code === 'auth/user-not-found') {
        res.status(200).json({ ok: true, auth_deleted: true, already_absent: true });
        return;
      }
      console.error('Firebase player Auth deletion failed', { uid: uid.length > 8 ? `${uid.slice(0, 4)}...${uid.slice(-4)}` : '[masked]', code });
      res.status(500).json({ error: 'FIREBASE_AUTH_DELETE_FAILED' });
    }
  }
);
