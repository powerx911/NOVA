import { beforeEach, describe, expect, it } from 'vitest';
import {
  ALLOWED_DIAGNOSTIC_COLLECTIONS,
  authorizeDiagnosticsActor,
  DiagnosticsSecurityError,
  redactSecretsServer,
  SlidingWindowRateLimiter,
  validateDiagnosticsRequest,
} from '../../functions/src/diagnosticsCore';
import {
  clearSanitizedErrorHistory,
  getSanitizedErrorHistory,
  maskUid,
  recordSanitizedError,
  redactSecrets,
} from '../lib/diagnosticsSanitizer';
import { NEXORA_COLLECTION_CATALOG } from '../services/diagnosticsService';

describe('NEXORA Diagnostics Security, Access Control & Redaction', () => {
  beforeEach(() => {
    clearSanitizedErrorHistory();
  });

  it('rejects unauthenticated callers and unverified emails', () => {
    expect(() => authorizeDiagnosticsActor(null, false)).toThrow(DiagnosticsSecurityError);
    expect(() =>
      authorizeDiagnosticsActor({ uid: 'player_1', email: 'p1@example.com', emailVerified: false }, true)
    ).toThrow(/verified email/i);
  });

  it('rejects regular signed-in players and generic admin:true claims without diagnosticsOwner', () => {
    expect(() =>
      authorizeDiagnosticsActor(
        { uid: 'regular_player_uid', email: 'player@example.com', emailVerified: true, claims: {} },
        false,
        { allowedUids: ['owner_uid_1'], allowedEmails: ['owner@example.com'] }
      )
    ).toThrow(/not authorized/i);

    expect(() =>
      authorizeDiagnosticsActor(
        {
          uid: 'generic_admin_uid',
          email: 'mod@example.com',
          emailVerified: true,
          claims: { admin: true },
        },
        false
      )
    ).toThrow(/not authorized/i);
  });

  it('authorizes verified project owners via custom claim, admin doc, or server allowlist', () => {
    expect(
      authorizeDiagnosticsActor(
        {
          uid: 'owner_1',
          email: 'owner@example.com',
          emailVerified: true,
          claims: { diagnosticsOwner: true },
        },
        false
      )
    ).toEqual({ authorized: true, verifiedBy: 'custom_claim' });

    expect(
      authorizeDiagnosticsActor(
        { uid: 'owner_2', email: 'owner2@example.com', emailVerified: true, claims: {} },
        true
      )
    ).toEqual({ authorized: true, verifiedBy: 'diagnostics_admins_doc' });

    expect(
      authorizeDiagnosticsActor(
        { uid: 'owner_3', email: 'owner3@example.com', emailVerified: true, claims: {} },
        false,
        { allowedUids: ['owner_3'] }
      )
    ).toEqual({ authorized: true, verifiedBy: 'server_allowlist' });
  });

  it('strictly rejects mutation, write, update, and delete actions', () => {
    const mutationActions = ['write', 'create', 'update', 'delete', 'patch', 'transfer', 'adjust_balance', 'grant'];
    for (const action of mutationActions) {
      expect(() => validateDiagnosticsRequest({ action })).toThrow(/prohibited/i);
    }

    expect(validateDiagnosticsRequest({ action: 'run_diagnostics', locale: 'ar' })).toEqual({
      action: 'run_diagnostics',
      locale: 'ar',
    });
    expect(validateDiagnosticsRequest({ action: 'health_ping', locale: 'en' })).toEqual({
      action: 'health_ping',
      locale: 'en',
    });
  });

  it('rejects arbitrary collection names and free-form query parameters', () => {
    const forbiddenPayloads = [
      { action: 'run_diagnostics', collection: 'users_private' },
      { action: 'run_diagnostics', collectionName: 'wallets' },
      { action: 'run_diagnostics', query: 'SELECT * FROM wallets' },
      { action: 'run_diagnostics', where: ['balance', '>', 0] },
      { action: 'run_diagnostics', path: 'users_private/secret' },
      { action: 'run_diagnostics', data: { balance: 999999 } },
    ];

    for (const payload of forbiddenPayloads) {
      expect(() => validateDiagnosticsRequest(payload)).toThrow(/forbidden/i);
    }
  });

  it('enforces per-UID sliding-window rate limiting', () => {
    const limiter = new SlidingWindowRateLimiter(3, 60_000);
    const t0 = 1_700_000_000_000;
    expect(limiter.consume('owner_1', t0).remaining).toBe(2);
    expect(limiter.consume('owner_1', t0 + 1000).remaining).toBe(1);
    expect(limiter.consume('owner_1', t0 + 2000).remaining).toBe(0);
    expect(() => limiter.consume('owner_1', t0 + 3000)).toThrow(/rate limit exceeded/i);
    // Window expires cleanly after all prior hits age out (> 60s from t0 + 2000)
    expect(limiter.consume('owner_1', t0 + 63_000).remaining).toBe(2);
  });

  it('redacts emails, JWTs, Bearer tokens, Google API keys, PATs, PEM keys, and sensitive keys completely', () => {
    const dirtyPayload = {
      reportVersion: '1.0.0',
      owner: {
        email: 'owner.secret@example.com',
        token: 'super-secret-id-token',
        password: 'MySecretPassword123!',
        apiKey: 'AIzaSyFakeSecretKey1234567890abcdef',
        serviceAccount: { client_email: 'sa@project.iam.gserviceaccount.com', private_key: 'abc' },
      },
      message:
        'Auth failed for user@domain.com using Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMifQ.signature123 and AIzaSyD8lDEEHIeMIC4E96Zebn_rTtVjwONfSSM and ghp_1234567890abcdefABCDEF1234',
      pem: '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0\n-----END PRIVATE KEY-----',
    };

    const clientClean = JSON.stringify(redactSecrets(dirtyPayload));
    const serverClean = JSON.stringify(redactSecretsServer(dirtyPayload));

    for (const serialized of [clientClean, serverClean]) {
      expect(serialized).not.toContain('owner.secret@example.com');
      expect(serialized).not.toContain('user@domain.com');
      expect(serialized).not.toContain('super-secret-id-token');
      expect(serialized).not.toContain('MySecretPassword123!');
      expect(serialized).not.toContain('AIzaSy');
      expect(serialized).not.toContain('eyJhbGci');
      expect(serialized).not.toContain('ghp_123456');
      expect(serialized).not.toContain('MIIEvQIBADANBgkqhkiG9w0');
      expect(serialized).toContain('[REDACTED]');
      expect(serialized).toContain('[REDACTED_EMAIL]');
    }
  });

  it('captures and sanitizes runtime errors in the diagnostic error monitor', () => {
    recordSanitizedError({
      source: 'firestore:get:users_private/abc',
      message: 'Missing or insufficient permissions for alice@example.com Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOiIxIn0.sig12345',
    });

    const history = getSanitizedErrorHistory();
    expect(history).toHaveLength(1);
    expect(history[0].category).toBe('rules');
    expect(history[0].code).toBe('permission-denied');
    expect(history[0].message).not.toContain('alice@example.com');
    expect(history[0].message).not.toContain('eyJhbGci');
    expect(maskUid('ViA03w1IUYM3zE3aq1eiilxiMkm1')).toBe('ViA0...Mkm1');
  });

  it('keeps client and backend collection allowlists synchronized with actual NEXORA collections', () => {
    const serverNames = ALLOWED_DIAGNOSTIC_COLLECTIONS.map((c) => c.name);
    const clientNames = NEXORA_COLLECTION_CATALOG.map((c) => c.name);
    expect(clientNames).toEqual(serverNames);
    expect(serverNames).toContain('profiles');
    expect(serverNames).toContain('users_private');
    expect(serverNames).toContain('wallets');
    expect(serverNames).toContain('organization_members');
    expect(serverNames).toContain('diagnostics_admins');
  });

  it('produces valid unified JSON report structure without leaking PII when serialized', () => {
    const sampleReport = redactSecrets({
      reportVersion: '1.0.0',
      generatedAt: new Date().toISOString(),
      projectIdentifier: {
        appName: 'NEXORA',
        projectId: 'gen-lang-client-0074900177',
        firestoreDatabaseId: 'ai-studio-74843d9e-8228-49b7-a616-317cadd90bff',
        authDomain: 'gen-lang-client-0074900177.firebaseapp.com',
      },
      environment: {
        mode: 'test',
        executionSource: 'client_read_only_fallback',
        backendDeployed: false,
        appCheckEnforced: false,
        locale: 'ar',
      },
      firebaseHealth: { overallStatus: 'warning' },
      authenticationHealth: { status: 'healthy', email: 'secret@example.com' },
      databaseCollections: [],
      gameSystems: [],
      securityChecks: { overallStatus: 'healthy' },
      recentSanitizedErrors: [],
      warnings: [],
      failedChecks: [],
    });

    const parsed = JSON.parse(JSON.stringify(sampleReport));
    const requiredKeys = [
      'reportVersion',
      'generatedAt',
      'projectIdentifier',
      'environment',
      'firebaseHealth',
      'authenticationHealth',
      'databaseCollections',
      'gameSystems',
      'securityChecks',
      'recentSanitizedErrors',
      'warnings',
      'failedChecks',
    ];
    for (const key of requiredKeys) {
      expect(parsed).toHaveProperty(key);
    }
    expect(parsed.authenticationHealth.email).toBe('[REDACTED]');
  });
});
