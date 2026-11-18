import { randomUUID } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { IdentityPoolClient } from 'google-auth-library';
import { createRemoteJWKSet, jwtVerify } from 'jose';

const PROJECT_ID = 'gen-lang-client-0074900177';
const PROJECT_NUMBER = '145581837596';
const DATABASE_ID = 'ai-studio-74843d9e-8228-49b7-a616-317cadd90bff';
const SERVICE_ACCOUNT = 'nexora-vercel-runtime@gen-lang-client-0074900177.iam.gserviceaccount.com';
const WIF_AUDIENCE = `//iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/nexora-vercel-pool/providers/nexora-vercel`;
const FIREBASE_ISSUER = `https://securetoken.google.com/${PROJECT_ID}`;
const FIREBASE_KEYS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com')
);

type ApiRequest = IncomingMessage & { body?: unknown };
type ApiResponse = ServerResponse & {
  status: (code: number) => ApiResponse;
  json: (body: unknown) => void;
};
type Data = Record<string, unknown>;
type RestDocument = { name: string; fields?: Record<string, unknown> };
type RestWrite = {
  update: { name: string; fields: Record<string, unknown> };
  updateMask: { fieldPaths: string[] };
  updateTransforms?: Array<{ fieldPath: string; setToServerValue: 'REQUEST_TIME' }>;
  currentDocument?: { exists: boolean };
};

class OrganizationError extends Error {
  constructor(public readonly code: string, public readonly status: number) {
    super(code);
  }
}

function numberOrZero(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function decodeValue(value: unknown): unknown {
  if (!value || typeof value !== 'object') return value;
  const item = value as Record<string, unknown>;
  if ('stringValue' in item) return item.stringValue;
  if ('integerValue' in item) return Number(item.integerValue);
  if ('doubleValue' in item) return Number(item.doubleValue);
  if ('booleanValue' in item) return item.booleanValue;
  if ('timestampValue' in item) return item.timestampValue;
  if ('nullValue' in item) return null;
  if ('mapValue' in item) {
    const fields = (item.mapValue as { fields?: Record<string, unknown> } | undefined)?.fields ?? {};
    return Object.fromEntries(Object.entries(fields).map(([key, child]) => [key, decodeValue(child)]));
  }
  if ('arrayValue' in item) {
    const values = (item.arrayValue as { values?: unknown[] } | undefined)?.values ?? [];
    return values.map(decodeValue);
  }
  return item;
}

function decodeDocument(document: RestDocument): Data {
  return Object.fromEntries(
    Object.entries(document.fields ?? {}).map(([key, value]) => [key, decodeValue(value)])
  );
}

function encodeValue(value: unknown): unknown {
  if (value === null || value === undefined) return { nullValue: 'NULL_VALUE' };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value as Record<string, unknown>).map(([key, child]) => [key, encodeValue(child)])
        ),
      },
    };
  }
  throw new OrganizationError('INVALID_ARGUMENT', 400);
}

function documentName(path: string): string {
  return `projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents/${path}`;
}

function writeDocument(
  path: string,
  fields: Data,
  serverTimestampFields: string[] = [],
  createOnly = false
): RestWrite {
  const encoded = Object.fromEntries(
    Object.entries(fields)
      .filter(([, value]) => value !== undefined)
      .map(([key, value]) => [key, encodeValue(value)])
  );
  return {
    update: { name: documentName(path), fields: encoded },
    updateMask: { fieldPaths: Object.keys(encoded) },
    ...(serverTimestampFields.length
      ? { updateTransforms: serverTimestampFields.map((fieldPath) => ({
          fieldPath,
          setToServerValue: 'REQUEST_TIME' as const,
        })) }
      : {}),
    ...(createOnly ? { currentDocument: { exists: false } } : {}),
  };
}

class FirestoreRest {
  constructor(private readonly authClient: IdentityPoolClient) {}

  private async request<T>(method: string, body: unknown): Promise<T> {
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents:${method}`;
    const response = await this.authClient.fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    return response.data as T;
  }

  async begin(): Promise<string> {
    const result = await this.request<{ transaction?: string }>('beginTransaction', {
      options: { readWrite: {} },
    });
    if (!result.transaction) throw new OrganizationError('TRANSACTION_START_FAILED', 503);
    return result.transaction;
  }

  async getMany(transaction: string, paths: string[]): Promise<Array<Data | null>> {
    const rows = await this.request<Array<{ found?: RestDocument; missing?: string }>>('batchGet', {
      documents: paths.map(documentName),
      transaction,
    });
    const documents = new Map<string, Data | null>();
    for (const row of rows) {
      if (row.found) documents.set(row.found.name, decodeDocument(row.found));
      else if (row.missing) documents.set(row.missing, null);
    }
    return paths.map((path) => documents.get(documentName(path)) ?? null);
  }

  async commit(transaction: string, writes: RestWrite[]): Promise<void> {
    await this.request('commit', { transaction, writes });
  }

  async rollback(transaction: string): Promise<void> {
    await this.request('rollback', { transaction });
  }
}

async function verifyPlayer(req: ApiRequest): Promise<string> {
  const header = req.headers.authorization;
  const match = typeof header === 'string' ? /^Bearer\s+(.+)$/i.exec(header) : null;
  if (!match) throw new OrganizationError('UNAUTHENTICATED', 401);
  const { payload } = await jwtVerify(match[1], FIREBASE_KEYS, {
    issuer: FIREBASE_ISSUER,
    audience: PROJECT_ID,
    algorithms: ['RS256'],
  });
  const firebaseClaim = payload.firebase && typeof payload.firebase === 'object' ? payload.firebase as Record<string, unknown> : {};
  const isAnonymous = firebaseClaim.sign_in_provider === 'anonymous';
  if (
    typeof payload.sub !== 'string' ||
    payload.sub.length === 0 ||
    payload.sub.length > 128 ||
    (payload.email_verified !== true && !isAnonymous)
  ) {
    throw new OrganizationError('UNAUTHENTICATED', 401);
  }
  return payload.sub;
}

function firestoreForRequest(req: ApiRequest): FirestoreRest {
  const rawToken = req.headers['x-vercel-oidc-token'];
  const oidcToken = Array.isArray(rawToken) ? rawToken[0] : rawToken;
  if (typeof oidcToken !== 'string' || oidcToken.length < 40) {
    throw new OrganizationError('BACKEND_IDENTITY_NOT_READY', 503);
  }
  const authClient = new IdentityPoolClient({
    audience: WIF_AUDIENCE,
    subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
    token_url: 'https://sts.googleapis.com/v1/token',
    service_account_impersonation_url: `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${SERVICE_ACCOUNT}:generateAccessToken`,
    subject_token_supplier: { getSubjectToken: async () => oidcToken },
  });
  authClient.scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  return new FirestoreRest(authClient);
}

function levelForXp(totalXp: number): number {
  let level = 1;
  let remaining = Math.max(0, Math.floor(totalXp));
  while (level < 200) {
    const step = 200 + (level - 1) * 120;
    if (remaining < step) return level;
    remaining -= step;
    level += 1;
  }
  return 200;
}

async function createOrganization(
  db: FirestoreRest,
  uid: string,
  name: string,
  tag: string,
  description: string
): Promise<{ ok: true; orgId: string }> {
  const transaction = await db.begin();
  try {
    const [walletRaw, profileRaw] = await db.getMany(transaction, [
      `wallets/${uid}`,
      `profiles/${uid}`,
    ]);
    if (!walletRaw || !profileRaw) throw new OrganizationError('ACCOUNT_NOT_FOUND', 404);

    const wallet = walletRaw;
    const profile = profileRaw;
    if (typeof profile.orgId === 'string' && profile.orgId.length > 0) {
      throw new OrganizationError('ALREADY_IN_ORG', 409);
    }
    const balance = numberOrZero(wallet.balance);
    const cost = 1000;
    if (balance < cost) throw new OrganizationError('INSUFFICIENT_FUNDS', 409);

    const username = typeof profile.username === 'string' ? profile.username : '';
    if (!username) throw new OrganizationError('ACCOUNT_NOT_FOUND', 409);

    const orgId = `org_${randomUUID()}`;
    const txId = `tx_${randomUUID()}`;
    const xp = numberOrZero(profile.xp) + 150;
    const nextLevel = levelForXp(xp);
    const levelsGained = Math.max(0, nextLevel - numberOrZero(profile.level));
    const leadership = numberOrZero((profile.skills as Record<string, unknown> | undefined)?.leadership);
    const reputationGain = Math.round(20 * (1 + leadership * 0.1));
    const influenceGain = Math.round(25 * (1 + leadership * 0.1));

    const writes: RestWrite[] = [
      writeDocument(`organizations/${orgId}`, {
        id: orgId,
        name,
        tag,
        description,
        leaderUid: uid,
        leaderName: username,
        treasuryBalance: 0,
        memberCount: 1,
        reputation: 15,
        level: 1,
      }, ['createdAt', 'updatedAt'], true),
      writeDocument(`organization_members/${orgId}_${uid}`, {
        orgId,
        uid,
        username,
        role: 'leader',
        permissions: ['manage_members', 'manage_roles', 'manage_treasury', 'manage_org'],
      }, ['joinedAt'], true),
      writeDocument(`transactions/${txId}`, {
        id: txId,
        fromUid: uid,
        toUid: 'SYSTEM',
        amount: cost,
        fee: 0,
        netAmount: cost,
        type: 'org_create',
        referenceId: orgId,
        description: `Founded organization [${tag}] ${name}`,
        status: 'completed',
      }, ['createdAt'], true),
      writeDocument(`wallets/${uid}`, {
        balance: balance - cost,
        totalSpent: numberOrZero(wallet.totalSpent) + cost,
        lastTxId: txId,
      }, ['updatedAt']),
      writeDocument(`profiles/${uid}`, {
        xp,
        level: nextLevel,
        skillPoints: numberOrZero(profile.skillPoints) + levelsGained * 2,
        reputation: numberOrZero(profile.reputation) + reputationGain,
        influence: numberOrZero(profile.influence) + influenceGain,
        orgId,
      }, ['updatedAt']),
    ];

    await db.commit(transaction, writes);
    return { ok: true, orgId };
  } catch (error) {
    await db.rollback(transaction).catch(() => undefined);
    if (error instanceof OrganizationError) throw error;
    const message = error instanceof Error ? error.message : '';
    if (message.includes('ABORTED')) throw new OrganizationError('RETRY_OPERATION', 409);
    if (message.includes('PERMISSION_DENIED') || message.includes('permission')) {
      throw new OrganizationError('BACKEND_FIRESTORE_WRITE_DENIED', 503);
    }
    throw new OrganizationError('ORGANIZATION_CREATE_FAILED', 500);
  }
}

export default async function handler(req: ApiRequest, res: ApiResponse): Promise<void> {
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'METHOD_NOT_ALLOWED' });
    return;
  }

  const body = req.body && typeof req.body === 'object' ? req.body as Record<string, unknown> : {};
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const tag = typeof body.tag === 'string' ? body.tag.trim().toUpperCase() : '';
  const description = typeof body.description === 'string' ? body.description.trim().slice(0, 240) : '';

  if (name.length < 3 || name.length > 40) {
    res.status(400).json({ error: 'INVALID_NAME' });
    return;
  }
  if (tag.length < 2 || tag.length > 6) {
    res.status(400).json({ error: 'INVALID_TAG' });
    return;
  }

  try {
    const uid = await verifyPlayer(req);
    const db = firestoreForRequest(req);
    const result = await createOrganization(db, uid, name, tag, description);
    res.status(200).json(result);
  } catch (error) {
    if (error instanceof OrganizationError) {
      res.status(error.status).json({ error: error.code });
      return;
    }
    const message = error instanceof Error ? error.message : '';
    if (message.includes('invalid_grant') || message.includes('unauthorized_client')) {
      res.status(503).json({ error: 'BACKEND_IDENTITY_NOT_READY' });
      return;
    }
    res.status(500).json({ error: 'ORGANIZATION_CREATE_FAILED' });
  }
}
