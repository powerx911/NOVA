export type DiagnosticStatus = 'healthy' | 'warning' | 'error' | 'unavailable';

export interface CollectionSpec {
  name: string;
  category: 'identity' | 'economy' | 'business' | 'social' | 'progression' | 'system' | 'security';
  piiRestricted: boolean;
}

/**
 * Exact, immutable list of NOVA Firestore collections verified against firebase-blueprint.json & firestore.rules.
 * Diagnostics backend NEVER accepts arbitrary collection names from the client.
 */
export const ALLOWED_DIAGNOSTIC_COLLECTIONS: readonly CollectionSpec[] = [
  { name: 'profiles', category: 'identity', piiRestricted: false },
  { name: 'usernames', category: 'identity', piiRestricted: false },
  { name: 'users_private', category: 'identity', piiRestricted: true },
  { name: 'wallets', category: 'economy', piiRestricted: false },
  { name: 'transactions', category: 'economy', piiRestricted: false },
  { name: 'inventory', category: 'economy', piiRestricted: false },
  { name: 'market_listings', category: 'economy', piiRestricted: false },
  { name: 'market_orders', category: 'economy', piiRestricted: false },
  { name: 'companies', category: 'business', piiRestricted: false },
  { name: 'company_logs', category: 'business', piiRestricted: false },
  { name: 'organizations', category: 'social', piiRestricted: false },
  { name: 'organization_members', category: 'social', piiRestricted: false },
  { name: 'organization_requests', category: 'social', piiRestricted: false },
  { name: 'organization_transactions', category: 'social', piiRestricted: false },
  { name: 'player_missions', category: 'progression', piiRestricted: false },
  { name: 'daily_claims', category: 'progression', piiRestricted: false },
  { name: 'contract_claims', category: 'progression', piiRestricted: false },
  { name: 'player_achievements', category: 'progression', piiRestricted: false },
  { name: 'notifications', category: 'system', piiRestricted: false },
  { name: 'world_events', category: 'system', piiRestricted: false },
  { name: 'audit_logs', category: 'security', piiRestricted: true },
  { name: 'diagnostics_admins', category: 'security', piiRestricted: true },
] as const;

export type AllowedDiagnosticAction = 'run_diagnostics' | 'health_ping';

export interface DiagnosticsActor {
  uid: string;
  email?: string | null;
  emailVerified: boolean;
  claims?: Record<string, unknown>;
}

export interface DiagnosticsAllowlistConfig {
  allowedUids?: string[];
  allowedEmails?: string[];
}

export type OwnerVerificationSource =
  | 'custom_claim'
  | 'server_allowlist'
  | 'diagnostics_admins_doc';

export class DiagnosticsSecurityError extends Error {
  public readonly code:
    | 'UNAUTHENTICATED'
    | 'PERMISSION_DENIED'
    | 'INVALID_ARGUMENT'
    | 'RESOURCE_EXHAUSTED';
  public readonly httpStatus: number;

  constructor(
    code: 'UNAUTHENTICATED' | 'PERMISSION_DENIED' | 'INVALID_ARGUMENT' | 'RESOURCE_EXHAUSTED',
    message: string
  ) {
    super(message);
    this.name = 'DiagnosticsSecurityError';
    this.code = code;
    this.httpStatus =
      code === 'UNAUTHENTICATED'
        ? 401
        : code === 'PERMISSION_DENIED'
        ? 403
        : code === 'RESOURCE_EXHAUSTED'
        ? 429
        : 400;
  }
}

const FORBIDDEN_MUTATION_ACTIONS = new Set([
  'write',
  'create',
  'update',
  'delete',
  'remove',
  'patch',
  'set',
  'mutate',
  'transfer',
  'adjust_balance',
  'reset',
  'grant',
  'revoke',
  'exec',
]);

const FORBIDDEN_QUERY_KEYS = [
  'collection',
  'collectionName',
  'collections',
  'query',
  'sql',
  'path',
  'docPath',
  'filter',
  'where',
  'orderBy',
  'limit',
  'data',
  'payload',
  'updates',
  'mutation',
] as const;

const ALLOWED_REQUEST_KEYS = new Set(['action', 'locale']);

export function validateDiagnosticsRequest(rawPayload: unknown): {
  action: AllowedDiagnosticAction;
  locale: 'ar' | 'en';
} {
  if (!rawPayload || typeof rawPayload !== 'object' || Array.isArray(rawPayload)) {
    throw new DiagnosticsSecurityError(
      'INVALID_ARGUMENT',
      'Diagnostics payload must be a plain object.'
    );
  }

  const record = rawPayload as Record<string, unknown>;

  for (const forbiddenKey of FORBIDDEN_QUERY_KEYS) {
    if (forbiddenKey in record && record[forbiddenKey] !== undefined) {
      throw new DiagnosticsSecurityError(
        'INVALID_ARGUMENT',
        `Arbitrary parameter "${forbiddenKey}" is forbidden in read-only diagnostics.`
      );
    }
  }

  for (const key of Object.keys(record)) {
    if (!ALLOWED_REQUEST_KEYS.has(key)) {
      throw new DiagnosticsSecurityError(
        'INVALID_ARGUMENT',
        `Unsupported diagnostics parameter "${key}".`
      );
    }
  }

  const action = record.action;
  if (typeof action !== 'string') {
    throw new DiagnosticsSecurityError('INVALID_ARGUMENT', 'Diagnostics action is required.');
  }

  if (FORBIDDEN_MUTATION_ACTIONS.has(action.toLowerCase())) {
    throw new DiagnosticsSecurityError(
      'PERMISSION_DENIED',
      'Mutation or write actions are strictly prohibited in NEXORA Diagnostics.'
    );
  }

  if (action !== 'run_diagnostics' && action !== 'health_ping') {
    throw new DiagnosticsSecurityError(
      'INVALID_ARGUMENT',
      `Action "${action}" is not in the read-only diagnostics allowlist.`
    );
  }

  const locale = record.locale === 'en' ? 'en' : 'ar';
  return { action, locale };
}

export function authorizeDiagnosticsActor(
  actor: DiagnosticsActor | null | undefined,
  adminDocEnabled: boolean,
  config: DiagnosticsAllowlistConfig = {}
): { authorized: true; verifiedBy: OwnerVerificationSource } {
  if (!actor || !actor.uid || typeof actor.uid !== 'string') {
    throw new DiagnosticsSecurityError(
      'UNAUTHENTICATED',
      'Authentication with a valid Firebase ID token is required.'
    );
  }

  if (actor.emailVerified !== true) {
    throw new DiagnosticsSecurityError(
      'PERMISSION_DENIED',
      'A verified email address is required for diagnostics access.'
    );
  }

  const claims = actor.claims ?? {};
  if (claims.diagnosticsOwner === true) {
    return { authorized: true, verifiedBy: 'custom_claim' };
  }

  if (adminDocEnabled === true) {
    return { authorized: true, verifiedBy: 'diagnostics_admins_doc' };
  }

  const uidAllowlist = new Set(
    (config.allowedUids ?? []).map((u) => u.trim()).filter(Boolean)
  );
  if (uidAllowlist.has(actor.uid)) {
    return { authorized: true, verifiedBy: 'server_allowlist' };
  }

  const emailAllowlist = new Set(
    (config.allowedEmails ?? []).map((e) => e.trim().toLowerCase()).filter(Boolean)
  );
  if (actor.email && emailAllowlist.has(actor.email.trim().toLowerCase())) {
    return { authorized: true, verifiedBy: 'server_allowlist' };
  }

  throw new DiagnosticsSecurityError(
    'PERMISSION_DENIED',
    'Caller is not authorized as a NEXORA diagnostics owner.'
  );
}

export class SlidingWindowRateLimiter {
  private readonly hits = new Map<string, number[]>();
  private readonly maxRequests: number;
  private readonly windowMs: number;

  constructor(maxRequests = 6, windowMs = 60_000) {
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
  }

  public consume(uid: string, nowMs = Date.now()): { remaining: number; resetAtMs: number } {
    const cutoff = nowMs - this.windowMs;
    const recent = (this.hits.get(uid) ?? []).filter((ts) => ts > cutoff);
    if (recent.length >= this.maxRequests) {
      this.hits.set(uid, recent);
      const oldest = recent[0] ?? nowMs;
      throw new DiagnosticsSecurityError(
        'RESOURCE_EXHAUSTED',
        `Diagnostics rate limit exceeded. Retry after ${Math.ceil((oldest + this.windowMs - nowMs) / 1000)}s.`
      );
    }
    recent.push(nowMs);
    this.hits.set(uid, recent);
    return {
      remaining: Math.max(0, this.maxRequests - recent.length),
      resetAtMs: (recent[0] ?? nowMs) + this.windowMs,
    };
  }
}

const SENSITIVE_KEY_PATTERN =
  /^(email|e-mail|password|passwd|secret|token|idtoken|id_token|refreshtoken|refresh_token|accesstoken|access_token|apikey|api_key|privatekey|private_key|authorization|cookie|set-cookie|credential|credentials|clientsecret|client_secret|serviceaccount|service_account|private_key_id|client_email)$/i;

const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
const BEARER_REGEX = /Bearer\s+[A-Za-z0-9\-._~+/]+=*/gi;
const JWT_REGEX = /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{6,}\b/g;
const GOOGLE_API_KEY_REGEX = /AIza[0-9A-Za-z_-]{20,}/g;
const PEM_KEY_REGEX = /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g;
const GH_TOKEN_REGEX = /\b(ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{12,}\b/g;

export function maskUidServer(uid: string | null | undefined): string {
  if (!uid || typeof uid !== 'string') return 'anonymous';
  const trimmed = uid.trim();
  if (trimmed.length <= 8) return `${trimmed.slice(0, 2)}***`;
  return `${trimmed.slice(0, 4)}...${trimmed.slice(-4)}`;
}

export function sanitizeTextServer(input: string, maxLength = 320): string {
  const cleaned = input
    .replace(PEM_KEY_REGEX, '[REDACTED_PRIVATE_KEY]')
    .replace(BEARER_REGEX, 'Bearer [REDACTED_TOKEN]')
    .replace(JWT_REGEX, '[REDACTED_JWT]')
    .replace(GOOGLE_API_KEY_REGEX, '[REDACTED_API_KEY]')
    .replace(GH_TOKEN_REGEX, '[REDACTED_PAT]')
    .replace(EMAIL_REGEX, '[REDACTED_EMAIL]');

  if (cleaned.length <= maxLength) return cleaned;
  return `${cleaned.slice(0, maxLength)}...[truncated]`;
}

export function redactSecretsServer<T>(value: T, depth = 0): T {
  if (depth > 12 || value === null || value === undefined) return value;

  if (typeof value === 'string') {
    return sanitizeTextServer(value, 2000) as unknown as T;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => redactSecretsServer(item, depth + 1)) as unknown as T;
  }

  if (typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
      if (SENSITIVE_KEY_PATTERN.test(key)) {
        out[key] = '[REDACTED]';
      } else {
        out[key] = redactSecretsServer(val, depth + 1);
      }
    }
    return out as T;
  }

  return value;
}
