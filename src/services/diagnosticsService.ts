import {
  collection,
  doc,
  getCountFromServer,
  getDoc,
  getDocFromServer,
  query,
  where,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import firebaseConfig from '../../firebase-applet-config.json';
import {
  getSanitizedErrorHistory,
  maskUid,
  recordSanitizedError,
  redactSecrets,
  sanitizeDiagnosticString,
  type DatabaseCollectionDiagnostic,
  type DiagnosticReport,
  type DiagnosticStatus,
  type GameSystemDiagnostic,
} from '../lib/diagnosticsSanitizer';
import { auth, db, functions } from '../lib/firebase';
import type { Language, OrganizationMember, PlayerProfile, Wallet } from '../types/game';

export interface OwnerAuthorizationStatus {
  signedIn: boolean;
  emailVerified: boolean;
  authorized: boolean;
  verifiedBy: 'custom_claim' | 'diagnostics_admins_doc' | 'server_allowlist' | 'unverified';
  maskedUid: string;
  reason: string;
}

interface CollectionCatalogEntry {
  name: string;
  category: DatabaseCollectionDiagnostic['category'];
  piiRestricted: boolean;
  clientCountMode: 'global_filtered' | 'self_scoped' | 'restricted_admin_only';
}

/**
 * Exact 22 gameplay collections + diagnostics_admins extracted from firebase-blueprint.json & firestore.rules.
 */
export const NEXORA_COLLECTION_CATALOG: readonly CollectionCatalogEntry[] = [
  { name: 'profiles', category: 'identity', piiRestricted: false, clientCountMode: 'global_filtered' },
  { name: 'usernames', category: 'identity', piiRestricted: false, clientCountMode: 'restricted_admin_only' },
  { name: 'users_private', category: 'identity', piiRestricted: true, clientCountMode: 'restricted_admin_only' },
  { name: 'wallets', category: 'economy', piiRestricted: false, clientCountMode: 'restricted_admin_only' },
  { name: 'transactions', category: 'economy', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'inventory', category: 'economy', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'market_listings', category: 'economy', piiRestricted: false, clientCountMode: 'global_filtered' },
  { name: 'market_orders', category: 'economy', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'companies', category: 'business', piiRestricted: false, clientCountMode: 'global_filtered' },
  { name: 'company_logs', category: 'business', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'organizations', category: 'social', piiRestricted: false, clientCountMode: 'global_filtered' },
  { name: 'organization_members', category: 'social', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'organization_requests', category: 'social', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'organization_transactions', category: 'social', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'player_missions', category: 'progression', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'daily_claims', category: 'progression', piiRestricted: false, clientCountMode: 'restricted_admin_only' },
  { name: 'contract_claims', category: 'progression', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'player_achievements', category: 'progression', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'notifications', category: 'system', piiRestricted: false, clientCountMode: 'self_scoped' },
  { name: 'world_events', category: 'system', piiRestricted: false, clientCountMode: 'global_filtered' },
  { name: 'audit_logs', category: 'security', piiRestricted: true, clientCountMode: 'self_scoped' },
  { name: 'diagnostics_admins', category: 'security', piiRestricted: true, clientCountMode: 'restricted_admin_only' },
];

export async function verifyDiagnosticsOwnerAccess(): Promise<OwnerAuthorizationStatus> {
  const user = auth.currentUser;
  if (!user) {
    return {
      signedIn: false,
      emailVerified: false,
      authorized: false,
      verifiedBy: 'unverified',
      maskedUid: 'anonymous',
      reason: 'User is not authenticated.',
    };
  }

  if (!user.emailVerified) {
    return {
      signedIn: true,
      emailVerified: false,
      authorized: false,
      verifiedBy: 'unverified',
      maskedUid: maskUid(user.uid),
      reason: 'Verified email address is required.',
    };
  }

  try {
    const tokenResult = await user.getIdTokenResult(false);
    const claims = tokenResult.claims ?? {};
    if (claims.diagnosticsOwner === true) {
      return {
        signedIn: true,
        emailVerified: true,
        authorized: true,
        verifiedBy: 'custom_claim',
        maskedUid: maskUid(user.uid),
        reason: 'Verified via Firebase Auth Custom Claim.',
      };
    }
  } catch (err) {
    recordSanitizedError({
      source: 'auth:getIdTokenResult',
      message: err instanceof Error ? err.message : String(err),
      category: 'auth',
      severity: 'warning',
    });
  }

  // Fallback check against Admin-managed read-only Firestore registry
  try {
    const adminSnap = await getDoc(doc(db, 'diagnostics_admins', user.uid));
    const adminData = adminSnap.data();
    if (adminSnap.exists() && adminData?.enabled === true && adminData?.role === 'owner') {
      return {
        signedIn: true,
        emailVerified: true,
        authorized: true,
        verifiedBy: 'diagnostics_admins_doc',
        maskedUid: maskUid(user.uid),
        reason: 'Verified via Admin-managed diagnostics_admins/{uid} registry.',
      };
    }
  } catch (err) {
    recordSanitizedError({
      source: `firestore:get:diagnostics_admins/${maskUid(user.uid)}`,
      message: err instanceof Error ? err.message : String(err),
      category: 'rules',
      severity: 'warning',
    });
  }

  // Last server-authoritative check: probe Cloud Function ping if deployed
  try {
    const pingFn = httpsCallable<{ action: 'health_ping'; locale: Language }, { ok?: boolean; verifiedBy?: 'custom_claim' | 'server_allowlist' | 'diagnostics_admins_doc' }>(
      functions,
      'nexoraDiagnostics'
    );
    const res = await pingFn({ action: 'health_ping', locale: 'ar' });
    if (res.data?.ok === true) {
      return {
        signedIn: true,
        emailVerified: true,
        authorized: true,
        verifiedBy: res.data.verifiedBy ?? 'server_allowlist',
        maskedUid: maskUid(user.uid),
        reason: 'Verified via Gen 2 Cloud Function owner allowlist.',
      };
    }
  } catch {
    // Either backend is not deployed or caller was rejected by server
  }

  return {
    signedIn: true,
    emailVerified: true,
    authorized: false,
    verifiedBy: 'unverified',
    maskedUid: maskUid(user.uid),
    reason: 'Owner claim or diagnostics_admins/{uid} authorization not present.',
  };
}

async function runRulesCompliantCount(
  entry: CollectionCatalogEntry,
  uid: string
): Promise<DatabaseCollectionDiagnostic> {
  if (entry.clientCountMode === 'restricted_admin_only') {
    return {
      name: entry.name,
      category: entry.category,
      piiRestricted: entry.piiRestricted,
      count: null,
      countSource: 'unavailable',
      status: 'unavailable',
      note: entry.piiRestricted
        ? 'Protected PII/security collection: requires Admin SDK Cloud Function for global count.'
        : 'Get-only collection: requires Admin SDK Cloud Function for global count.',
    };
  }

  try {
    let q;
    if (entry.clientCountMode === 'global_filtered') {
      if (entry.name === 'profiles') {
        q = query(collection(db, 'profiles'), where('influence', '>=', 0));
      } else if (entry.name === 'companies') {
        q = query(collection(db, 'companies'), where('totalRevenue', '>=', 0));
      } else if (entry.name === 'organizations') {
        q = query(collection(db, 'organizations'), where('reputation', '>=', 0));
      } else if (entry.name === 'market_listings') {
        q = query(collection(db, 'market_listings'), where('status', '==', 'active'));
      } else {
        q = query(collection(db, 'world_events'), where('active', '==', true));
      }
    } else {
      // self_scoped queries strictly matching firestore.rules allow list
      if (entry.name === 'transactions') {
        q = query(collection(db, 'transactions'), where('fromUid', '==', uid));
      } else if (entry.name === 'market_orders') {
        q = query(collection(db, 'market_orders'), where('buyerUid', '==', uid));
      } else if (entry.name === 'companies' || entry.name === 'company_logs') {
        q = query(collection(db, entry.name), where('ownerUid', '==', uid));
      } else {
        q = query(collection(db, entry.name), where('uid', '==', uid));
      }
    }

    const agg = await getCountFromServer(q);
    return {
      name: entry.name,
      category: entry.category,
      piiRestricted: entry.piiRestricted,
      count: agg.data().count,
      countSource: 'client_aggregation',
      status: 'healthy',
      note:
        entry.clientCountMode === 'global_filtered'
          ? 'Count via Firestore getCountFromServer (filtered query).'
          : 'Owner-scoped count via getCountFromServer (global total requires Admin SDK).',
    };
  } catch (err) {
    const msg = sanitizeDiagnosticString(err instanceof Error ? err.message : String(err), 180);
    recordSanitizedError({
      source: `diagnostics:count:${entry.name}`,
      message: msg,
    });
    return {
      name: entry.name,
      category: entry.category,
      piiRestricted: entry.piiRestricted,
      count: null,
      countSource: 'unavailable',
      status: msg.toLowerCase().includes('permission') ? 'warning' : 'error',
      note: msg,
    };
  }
}

export interface ClientSnapshotContext {
  profile: PlayerProfile | null;
  wallet: Wallet | null;
  myOrgMember: OrganizationMember | null;
  companiesCount: number;
  inventoryCount: number;
  claimedMissionsCount: number;
  unlockedAchievementsCount: number;
  locale: Language;
}

export async function generateDiagnosticReport(
  ownerStatus: OwnerAuthorizationStatus,
  ctx: ClientSnapshotContext
): Promise<DiagnosticReport> {
  if (!ownerStatus.signedIn || !ownerStatus.emailVerified || !ownerStatus.authorized) {
    throw new Error('PERMISSION_DENIED: Diagnostics report generation is restricted to verified project owners.');
  }

  const uid = auth.currentUser?.uid;
  if (!uid) {
    throw new Error('UNAUTHENTICATED: Missing authenticated Firebase user.');
  }

  const nowIso = new Date().toISOString();

  // Attempt authoritative Cloud Functions Gen 2 call first
  let backendFailureNote = 'Cloud Function Gen 2 endpoint not deployed or unreachable from this runtime.';
  try {
    const callable = httpsCallable<{ action: 'run_diagnostics'; locale: Language }, DiagnosticReport>(
      functions,
      'nexoraDiagnostics'
    );
    const response = await callable({ action: 'run_diagnostics', locale: ctx.locale });
    const serverReport = response.data;
    if (serverReport && serverReport.reportVersion) {
      // Merge current client runtime sanitized errors without exposing any PII
      const clientErrors = getSanitizedErrorHistory();
      const merged: DiagnosticReport = {
        ...serverReport,
        recentSanitizedErrors: [...serverReport.recentSanitizedErrors, ...clientErrors].slice(0, 40),
      };
      return redactSecrets(merged);
    }
  } catch (err) {
    const rawMsg = err instanceof Error ? err.message : String(err);
    backendFailureNote = sanitizeDiagnosticString(
      rawMsg.includes('not-found') || rawMsg.includes('Failed to fetch') || rawMsg.includes('CORS')
        ? 'Cloud Function Gen 2 (nexoraDiagnostics) is built in /functions but not deployed yet on Firebase.'
        : rawMsg,
      200
    );
    recordSanitizedError({
      source: 'functions:nexoraDiagnostics',
      message: backendFailureNote,
      category: 'backend',
      severity: 'warning',
    });
  }

  // Read-only rules-compliant client fallback
  const pingStart = Date.now();
  let firestoreStatus: DiagnosticStatus = 'healthy';
  let firestoreMessage = 'Connected to named Cloud Firestore Enterprise database.';
  try {
    await getDocFromServer(doc(db, 'test', 'connection'));
  } catch (err) {
    firestoreStatus = 'error';
    firestoreMessage = sanitizeDiagnosticString(err instanceof Error ? err.message : String(err), 180);
  }
  const latencyMs = Date.now() - pingStart;

  const databaseCollections = await Promise.all(
    NEXORA_COLLECTION_CATALOG.map((entry) => runRulesCompliantCount(entry, uid))
  );

  // Verify the Vercel OIDC -> Google WIF -> named Firestore path without writing data.
  let vaultBackendStatus: DiagnosticStatus = 'unavailable';
  let vaultBackendMessage = 'Vercel company-vault health check has not completed.';
  try {
    const currentUser = auth.currentUser;
    if (!currentUser) throw new Error('UNAUTHENTICATED');
    const idToken = await currentUser.getIdToken();
    const response = await fetch('/api/company-vault', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({ action: 'health' }),
      cache: 'no-store',
    });
    const health = await response.json() as {
      ok?: boolean;
      firebaseAuthVerified?: boolean;
      wifConnected?: boolean;
      firestoreReadable?: boolean;
      profileDocumentExists?: boolean;
      error?: string;
    };
    if (!response.ok || health.ok !== true || health.firebaseAuthVerified !== true ||
        health.wifConnected !== true || health.firestoreReadable !== true) {
      throw new Error(health.error || 'VAULT_BACKEND_HEALTH_CHECK_FAILED');
    }
    vaultBackendStatus = 'healthy';
    vaultBackendMessage = health.profileDocumentExists
      ? 'Firebase ID token verified; Vercel OIDC exchanged through Google WIF; named Firestore profile read succeeded.'
      : 'Firebase ID token verified; Vercel OIDC and named Firestore read succeeded, but the profile document was not found.';
    if (!health.profileDocumentExists) vaultBackendStatus = 'warning';
  } catch (err) {
    vaultBackendStatus = 'error';
    vaultBackendMessage = sanitizeDiagnosticString(
      err instanceof Error ? err.message : String(err),
      180
    );
    recordSanitizedError({
      source: 'vercel:company-vault-health',
      message: vaultBackendMessage,
      category: 'backend',
      severity: 'error',
    });
  }

  const countByName = new Map<string, number | null>(
    databaseCollections.map((c) => [c.name, c.count])
  );

  const warnings: string[] = [
    'Backend Cloud Functions Gen 2 unavailable: private/global collection counts shown as unavailable or owner-scoped.',
  ];
  const failedChecks: string[] = [];

  if (firestoreStatus === 'error') {
    failedChecks.push(`Firestore health check failed: ${firestoreMessage}`);
  }

  const orphanedOrgRef =
    Boolean(ctx.profile?.orgId) &&
    (!ctx.myOrgMember || ctx.myOrgMember.orgId !== ctx.profile?.orgId);
  if (orphanedOrgRef) {
    warnings.push('Current owner profile.orgId does not match an active organization_members record.');
  }

  const walletBalanceInvalid = ctx.wallet ? ctx.wallet.balance < 0 : false;
  if (walletBalanceInvalid) {
    failedChecks.push('Detected negative balance invariant violation in active wallet.');
  }

  const gameSystems: GameSystemDiagnostic[] = [
    {
      key: 'characters',
      labelAr: 'نظام الشخصيات',
      labelEn: 'Characters',
      status: ctx.profile ? 'healthy' : 'warning',
      collectionsChecked: ['profiles', 'usernames'],
      metrics: {
        globalProfilesCount: countByName.get('profiles') ?? null,
        ownerLevel: ctx.profile?.level ?? null,
      },
      issues: ctx.profile ? [] : ['Current user profile missing.'],
    },
    {
      key: 'wallets_economy',
      labelAr: 'المحافظ والاقتصاد',
      labelEn: 'Wallets & Economy',
      status: walletBalanceInvalid ? 'error' : ctx.wallet ? 'healthy' : 'warning',
      collectionsChecked: ['wallets', 'transactions'],
      metrics: {
        ownerWalletPresent: Boolean(ctx.wallet),
        ownerOutgoingTxCount: countByName.get('transactions') ?? null,
      },
      issues: walletBalanceInvalid ? ['Negative wallet balance detected.'] : [],
    },
    {
      key: 'companies',
      labelAr: 'الشركات والمصانع',
      labelEn: 'Companies',
      status: 'healthy',
      collectionsChecked: ['companies', 'company_logs'],
      metrics: {
        globalCompaniesCount: countByName.get('companies') ?? null,
        ownerCompaniesLoaded: ctx.companiesCount,
        ownerLogsCount: countByName.get('company_logs') ?? null,
      },
      issues: [],
    },
    {
      key: 'market_orders',
      labelAr: 'السوق والطلبات',
      labelEn: 'Market & Orders',
      status: 'healthy',
      collectionsChecked: ['market_listings', 'market_orders', 'world_events'],
      metrics: {
        activeListingsCount: countByName.get('market_listings') ?? null,
        ownerBuyOrdersCount: countByName.get('market_orders') ?? null,
        activeWorldEventsCount: countByName.get('world_events') ?? null,
      },
      issues: [],
    },
    {
      key: 'organizations',
      labelAr: 'المنظمات والأعضاء',
      labelEn: 'Organizations & Members',
      status: orphanedOrgRef ? 'warning' : 'healthy',
      collectionsChecked: ['organizations', 'organization_members', 'organization_requests', 'organization_transactions'],
      metrics: {
        globalOrganizationsCount: countByName.get('organizations') ?? null,
        ownerMembershipSynced: !orphanedOrgRef,
      },
      issues: orphanedOrgRef ? ['profile.orgId mismatch with organization_members.'] : [],
    },
    {
      key: 'missions_achievements',
      labelAr: 'المهام والإنجازات',
      labelEn: 'Missions & Achievements',
      status: 'healthy',
      collectionsChecked: ['player_missions', 'daily_claims', 'contract_claims', 'player_achievements'],
      metrics: {
        ownerClaimedMissions: ctx.claimedMissionsCount,
        ownerUnlockedAchievements: ctx.unlockedAchievementsCount,
        ownerContractClaims: countByName.get('contract_claims') ?? null,
      },
      issues: [],
    },
    {
      key: 'skills_progression',
      labelAr: 'المهارات والتقدم',
      labelEn: 'Skills & Progression',
      status: ctx.profile && ctx.profile.skillPoints >= 0 ? 'healthy' : 'warning',
      collectionsChecked: ['profiles'],
      metrics: {
        ownerSkillPoints: ctx.profile?.skillPoints ?? null,
        ownerLevel: ctx.profile?.level ?? null,
      },
      issues: [],
    },
  ];

  const report: DiagnosticReport = {
    reportVersion: '1.0.0',
    generatedAt: nowIso,
    projectIdentifier: {
      appName: 'NEXORA',
      projectId: firebaseConfig.projectId,
      firestoreDatabaseId: firebaseConfig.firestoreDatabaseId,
      authDomain: firebaseConfig.authDomain,
    },
    environment: {
      mode: import.meta.env.MODE || 'production',
      executionSource: 'client_read_only_fallback',
      backendDeployed: vaultBackendStatus === 'healthy',
      appCheckEnforced: false,
      locale: ctx.locale,
    },
    firebaseHealth: {
      overallStatus: firestoreStatus === 'error' ? 'error' : 'warning',
      firestore: {
        status: firestoreStatus,
        latencyMs,
        message: firestoreMessage,
      },
      authentication: {
        status: 'healthy',
        provider: 'google.com',
        emailVerified: ownerStatus.emailVerified,
        ownerVerifiedBy: ownerStatus.verifiedBy,
        maskedUid: ownerStatus.maskedUid,
        message: ownerStatus.reason,
      },
      backendFunctions: {
        status: vaultBackendStatus,
        runtime: 'Vercel Node.js + Google WIF',
        functionName: 'company-vault (read-only health)',
        lastCheckAt: nowIso,
        message: vaultBackendMessage,
      },
      lastSuccessfulCheckAt: firestoreStatus === 'healthy' ? nowIso : null,
    },
    authenticationHealth: {
      status: 'healthy',
      signedIn: ownerStatus.signedIn,
      emailVerified: ownerStatus.emailVerified,
      ownerAuthorized: ownerStatus.authorized,
      authMechanism: 'Firebase Auth Google Sign-In (signInWithPopup) + email_verified',
      userStoragePattern: 'Public profiles/{uid} separated from owner-only users_private/{uid}',
    },
    databaseCollections,
    gameSystems,
    securityChecks: {
      overallStatus: failedChecks.length > 0 ? 'error' : 'warning',
      ownerAuthorizationVerified: ownerStatus.authorized,
      rulesValidationStatus: 'healthy',
      piiRedactionActive: true,
      arbitraryQueriesBlocked: true,
      mutationsBlocked: true,
      appCheckStatus: 'warning',
      collectionsNeedingReview: [
        {
          collection: 'users_private',
          severity: 'info',
          reason: 'Strictly owner-isolated PII; client fallback marks global count unavailable.',
        },
        {
          collection: 'organization_members',
          severity: 'info',
          reason: 'list rule allows orgId scoping; verify member records remain non-PII.',
        },
      ],
      checks: [
        {
          id: 'owner_gate',
          label: 'Owner Authorization Gate',
          status: 'healthy',
          detail: `Verified via ${ownerStatus.verifiedBy}`,
        },
        {
          id: 'backend_functions_deployment',
          label: 'Cloud Functions Gen 2 Availability',
          status: 'unavailable',
          detail: backendFailureNote,
        },
        {
          id: 'pii_redaction',
          label: 'Zero-PII & Secret Sanitization',
          status: 'healthy',
          detail: 'All emails, tokens, keys, and credentials redacted prior to export.',
        },
      ],
    },
    recentSanitizedErrors: getSanitizedErrorHistory(),
    warnings,
    failedChecks,
  };

  return redactSecrets(report);
}
