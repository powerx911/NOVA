export type DiagnosticStatus = 'healthy' | 'warning' | 'error' | 'unavailable';

export interface SanitizedDiagnosticError {
  id: string;
  timestamp: string;
  source: string;
  category: 'firestore' | 'auth' | 'rules' | 'backend' | 'runtime';
  severity: 'warning' | 'error' | 'critical';
  code?: string;
  message: string;
}

export interface DatabaseCollectionDiagnostic {
  name: string;
  category: 'identity' | 'economy' | 'business' | 'social' | 'progression' | 'system' | 'security';
  piiRestricted: boolean;
  count: number | null;
  countSource: 'admin_aggregation' | 'client_aggregation' | 'unavailable';
  status: DiagnosticStatus;
  note: string;
}

export interface GameSystemDiagnostic {
  key:
    | 'characters'
    | 'wallets_economy'
    | 'companies'
    | 'market_orders'
    | 'organizations'
    | 'missions_achievements'
    | 'inventory_properties'
    | 'skills_progression';
  labelAr: string;
  labelEn: string;
  status: DiagnosticStatus;
  collectionsChecked: string[];
  metrics: Record<string, number | string | boolean | null>;
  issues: string[];
}

export interface DiagnosticReport {
  reportVersion: string;
  generatedAt: string;
  projectIdentifier: {
    appName: 'NEXORA';
    projectId: string;
    firestoreDatabaseId: string;
    authDomain: string;
  };
  environment: {
    mode: string;
    executionSource: 'cloud_function_gen2' | 'client_read_only_fallback';
    backendDeployed: boolean;
    appCheckEnforced: boolean;
    locale: 'ar' | 'en';
  };
  firebaseHealth: {
    overallStatus: DiagnosticStatus;
    firestore: {
      status: DiagnosticStatus;
      latencyMs: number | null;
      message: string;
    };
    authentication: {
      status: DiagnosticStatus;
      provider: 'google.com';
      emailVerified: boolean;
      ownerVerifiedBy: 'custom_claim' | 'server_allowlist' | 'diagnostics_admins_doc' | 'unverified';
      maskedUid: string;
      message: string;
    };
    backendFunctions: {
      status: DiagnosticStatus;
      runtime: string;
      functionName: string;
      lastCheckAt: string;
      message: string;
    };
    lastSuccessfulCheckAt: string | null;
  };
  authenticationHealth: {
    status: DiagnosticStatus;
    signedIn: boolean;
    emailVerified: boolean;
    ownerAuthorized: boolean;
    authMechanism: string;
    userStoragePattern: string;
  };
  databaseCollections: DatabaseCollectionDiagnostic[];
  gameSystems: GameSystemDiagnostic[];
  securityChecks: {
    overallStatus: DiagnosticStatus;
    ownerAuthorizationVerified: boolean;
    rulesValidationStatus: DiagnosticStatus;
    piiRedactionActive: boolean;
    arbitraryQueriesBlocked: boolean;
    mutationsBlocked: boolean;
    appCheckStatus: DiagnosticStatus;
    collectionsNeedingReview: Array<{
      collection: string;
      severity: 'info' | 'warning' | 'error';
      reason: string;
    }>;
    checks: Array<{
      id: string;
      label: string;
      status: DiagnosticStatus;
      detail: string;
    }>;
  };
  recentSanitizedErrors: SanitizedDiagnosticError[];
  warnings: string[];
  failedChecks: string[];
}

const SENSITIVE_KEY_PATTERN =
  /^(email|e-mail|password|passwd|secret|token|idtoken|id_token|refreshtoken|refresh_token|accesstoken|access_token|apikey|api_key|privatekey|private_key|authorization|cookie|set-cookie|credential|credentials|clientsecret|client_secret|serviceaccount|service_account|private_key_id|client_email)$/i;

const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
const BEARER_REGEX = /Bearer\s+[A-Za-z0-9\-._~+/]+=*/gi;
const JWT_REGEX = /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{6,}\b/g;
const GOOGLE_API_KEY_REGEX = /AIza[0-9A-Za-z_-]{20,}/g;
const PEM_KEY_REGEX = /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g;
const GH_TOKEN_REGEX = /\b(ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{12,}\b/g;

export function maskUid(uid: string | null | undefined): string {
  if (!uid || typeof uid !== 'string') return 'anonymous';
  const trimmed = uid.trim();
  if (trimmed.length <= 8) return `${trimmed.slice(0, 2)}***`;
  return `${trimmed.slice(0, 4)}...${trimmed.slice(-4)}`;
}

export function sanitizeDiagnosticString(input: string, maxLength = 320): string {
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

export function redactSecrets<T>(value: T, depth = 0): T {
  if (depth > 12 || value === null || value === undefined) return value;

  if (typeof value === 'string') {
    return sanitizeDiagnosticString(value, 2000) as unknown as T;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => redactSecrets(item, depth + 1)) as unknown as T;
  }

  if (typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
      if (SENSITIVE_KEY_PATTERN.test(key)) {
        out[key] = '[REDACTED]';
      } else {
        out[key] = redactSecrets(val, depth + 1);
      }
    }
    return out as T;
  }

  return value;
}

const MAX_MONITOR_ERRORS = 40;
const errorBuffer: SanitizedDiagnosticError[] = [];

export function classifyErrorCategory(
  source: string,
  message: string
): { category: SanitizedDiagnosticError['category']; severity: SanitizedDiagnosticError['severity']; code?: string } {
  const lower = `${source} ${message}`.toLowerCase();
  if (lower.includes('permission-denied') || lower.includes('insufficient permissions')) {
    return { category: 'rules', severity: 'error', code: 'permission-denied' };
  }
  if (lower.includes('unauthenticated') || lower.includes('auth/') || lower.includes('id-token')) {
    return { category: 'auth', severity: 'error', code: 'auth-error' };
  }
  if (lower.includes('failed-precondition') || lower.includes('index')) {
    return { category: 'firestore', severity: 'warning', code: 'index-or-precondition' };
  }
  if (lower.includes('functions') || lower.includes('backend') || lower.includes('resource-exhausted')) {
    return { category: 'backend', severity: 'warning', code: 'backend-error' };
  }
  if (lower.includes('offline') || lower.includes('unavailable') || lower.includes('network')) {
    return { category: 'firestore', severity: 'warning', code: 'network-unavailable' };
  }
  return { category: 'runtime', severity: 'error' };
}

export function recordSanitizedError(input: {
  source: string;
  message: string;
  category?: SanitizedDiagnosticError['category'];
  severity?: SanitizedDiagnosticError['severity'];
  code?: string;
}): SanitizedDiagnosticError {
  const sanitizedMessage = sanitizeDiagnosticString(input.message, 280);
  const sanitizedSource = sanitizeDiagnosticString(input.source, 96);
  const inferred = classifyErrorCategory(sanitizedSource, sanitizedMessage);

  const entry: SanitizedDiagnosticError = {
    id: `err_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    timestamp: new Date().toISOString(),
    source: sanitizedSource,
    category: input.category ?? inferred.category,
    severity: input.severity ?? inferred.severity,
    code: input.code ?? inferred.code,
    message: sanitizedMessage,
  };

  errorBuffer.unshift(entry);
  if (errorBuffer.length > MAX_MONITOR_ERRORS) {
    errorBuffer.length = MAX_MONITOR_ERRORS;
  }
  return entry;
}

export function getSanitizedErrorHistory(): SanitizedDiagnosticError[] {
  return redactSecrets([...errorBuffer]);
}

export function clearSanitizedErrorHistory(): void {
  errorBuffer.length = 0;
}
