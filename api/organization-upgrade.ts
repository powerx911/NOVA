import { randomUUID } from 'node:crypto';
import { IdentityPoolClient } from 'google-auth-library';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { createRemoteJWKSet, jwtVerify } from 'jose';

const PROJECT_ID = 'gen-lang-client-0074900177';
const PROJECT_NUMBER = '145581837596';
const DATABASE_ID = 'ai-studio-74843d9e-8228-49b7-a616-317cadd90bff';
const SERVICE_ACCOUNT = 'nexora-vercel-runtime@gen-lang-client-0074900177.iam.gserviceaccount.com';
const WIF_AUDIENCE = `//iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/nexora-vercel-pool/providers/nexora-vercel`;
const FIREBASE_ISSUER = `https://securetoken.google.com/${PROJECT_ID}`;
const FIREBASE_KEYS = createRemoteJWKSet(new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'));

type Req = IncomingMessage & { body?: unknown };
type Res = ServerResponse & { status: (code: number) => Res; json: (body: unknown) => void };
type Data = Record<string, unknown>;
type Write = { update: { name: string; fields: Record<string, unknown> }; updateMask: { fieldPaths: string[] }; updateTransforms?: Array<{ fieldPath: string; setToServerValue: 'REQUEST_TIME' }> };
class ApiError extends Error { constructor(public code: string, public status: number) { super(code); } }
const docName = (path: string) => `projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents/${path}`;
function encode(value: unknown): unknown {
  if (value === null || value === undefined) return { nullValue: 'NULL_VALUE' };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === 'object') return { mapValue: { fields: Object.fromEntries(Object.entries(value as Data).map(([k, v]) => [k, encode(v)])) } };
  throw new ApiError('INVALID_ARGUMENT', 400);
}
function decode(value: unknown): unknown {
  if (!value || typeof value !== 'object') return value;
  const v = value as Data;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return Date.parse(String(v.timestampValue));
  if ('nullValue' in v) return null;
  if ('mapValue' in v) { const fields = ((v.mapValue as Data).fields ?? {}) as Data; return Object.fromEntries(Object.entries(fields).map(([k, x]) => [k, decode(x)])); }
  if ('arrayValue' in v) return (((v.arrayValue as Data).values ?? []) as unknown[]).map(decode);
  return v;
}
function write(path: string, fields: Data, timestamps: string[] = []): Write {
  const encoded = Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, encode(v)]));
  return { update: { name: docName(path), fields: encoded }, updateMask: { fieldPaths: Object.keys(encoded) }, ...(timestamps.length ? { updateTransforms: timestamps.map(fieldPath => ({ fieldPath, setToServerValue: 'REQUEST_TIME' as const })) } : {}) };
}
class FirestoreRest {
  constructor(private client: IdentityPoolClient) {}
  private async request<T>(method: string, body: unknown): Promise<T> {
    const response = await this.client.fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents:${method}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    return response.data as T;
  }
  async begin() { const r = await this.request<{ transaction?: string }>('beginTransaction', { options: { readWrite: {} } }); if (!r.transaction) throw new ApiError('TRANSACTION_START_FAILED', 503); return r.transaction; }
  async get(transaction: string, paths: string[]) {
    const rows = await this.request<Array<{ found?: { name: string; fields?: Data }; missing?: string }>>('batchGet', { documents: paths.map(docName), transaction });
    const map = new Map<string, Data | null>();
    for (const row of rows) if (row.found) map.set(row.found.name, Object.fromEntries(Object.entries(row.found.fields ?? {}).map(([k, v]) => [k, decode(v)]))); else if (row.missing) map.set(row.missing, null);
    return paths.map(path => map.get(docName(path)) ?? null);
  }
  async commit(transaction: string, writes: Write[]) { await this.request('commit', { transaction, writes }); }
  async rollback(transaction: string) { await this.request('rollback', { transaction }); }
}
async function verifyUid(req: Req): Promise<string> {
  const h = req.headers.authorization;
  const m = typeof h === 'string' ? /^Bearer\s+(.+)$/i.exec(h) : null;
  if (!m) throw new ApiError('UNAUTHENTICATED', 401);
  const { payload } = await jwtVerify(m[1], FIREBASE_KEYS, { issuer: FIREBASE_ISSUER, audience: PROJECT_ID, algorithms: ['RS256'] });
  const firebaseClaim = payload.firebase && typeof payload.firebase === 'object' ? payload.firebase as Record<string, unknown> : {};
  const isAnonymous = firebaseClaim.sign_in_provider === 'anonymous';
  if (typeof payload.sub !== 'string' || !payload.sub || (payload.email_verified !== true && !isAnonymous)) throw new ApiError('UNAUTHENTICATED', 401);
  return payload.sub;
}
function getDb(req: Req) {
  const raw = req.headers['x-vercel-oidc-token']; const token = Array.isArray(raw) ? raw[0] : raw;
  if (typeof token !== 'string' || token.length < 40) throw new ApiError('BACKEND_IDENTITY_NOT_READY', 503);
  const client = new IdentityPoolClient({ audience: WIF_AUDIENCE, subject_token_type: 'urn:ietf:params:oauth:token-type:jwt', token_url: 'https://sts.googleapis.com/v1/token', service_account_impersonation_url: `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${SERVICE_ACCOUNT}:generateAccessToken`, subject_token_supplier: { getSubjectToken: async () => token } });
  client.scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  return new FirestoreRest(client);
}
function number(value: unknown) { return typeof value === 'number' && Number.isFinite(value) ? value : 0; }
function durationMs(targetLevel: number, engineeringLevel: number) { return Math.round(8 * 60 * 60 * 1000 * Math.pow(1.5, Math.max(0, targetLevel - 2)) * (1 - Math.min(10, engineeringLevel) * 0.005)); }
function upgradeCost(currentLevel: number, financeLevel: number) { return Math.round(12000 * currentLevel * currentLevel * (1 - Math.min(10, financeLevel) * 0.005)); }
const RESEARCH_BASE_COSTS: Record<string, number> = { commerce: 25_000, engineering: 30_000, expansion: 20_000, finance: 35_000, diplomacy: 18_000 };
function researchLevel(research: unknown, key: string) { return research && typeof research === 'object' ? number((research as Data)[key]) : 0; }

export default async function handler(req: Req, res: Res): Promise<void> {
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  if (req.method !== 'POST') { res.status(405).json({ error: 'METHOD_NOT_ALLOWED' }); return; }
  const body = req.body && typeof req.body === 'object' ? req.body as Data : {};
  const orgId = typeof body.orgId === 'string' ? body.orgId : '';
  const action = body.action === 'complete' || body.action === 'research' ? body.action : 'start';
  const researchId = typeof body.researchId === 'string' ? body.researchId : '';
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(orgId)) { res.status(400).json({ error: 'INVALID_ORG' }); return; }
  try {
    const uid = await verifyUid(req); const db = getDb(req); const transaction = await db.begin();
    try {
      const [org, member] = await db.get(transaction, [`organizations/${orgId}`, `organization_members/${orgId}_${uid}`]);
      if (!org || !member) throw new ApiError('NOT_FOUND', 404);
      if (action !== 'complete' && member.role !== 'leader' && member.role !== 'deputy') throw new ApiError('UNAUTHORIZED', 403);
      const now = Date.now(); const endsAt = number(org.upgradeEndsAt); const target = number(org.upgradeTargetLevel);
      if (action === 'complete') {
        if (!endsAt || !target || now < endsAt) throw new ApiError('UPGRADE_NOT_READY', 409);
        const capacity = Math.min(80, 20 + (target - 1) * 5 + researchLevel(org.research, 'expansion'));
        await db.commit(transaction, [write(`organizations/${orgId}`, { level: target, memberCapacity: capacity, upgradeEndsAt: null, upgradeTargetLevel: null }, ['updatedAt'])]);
        res.status(200).json({ ok: true, level: target, memberCapacity: capacity }); return;
      }
      if (action === 'research') {
        if (!Object.prototype.hasOwnProperty.call(RESEARCH_BASE_COSTS, researchId)) throw new ApiError('INVALID_RESEARCH', 400);
        const currentResearch = researchLevel(org.research, researchId);
        if (currentResearch >= 10) throw new ApiError('RESEARCH_MAX_LEVEL', 409);
        const cost = RESEARCH_BASE_COSTS[researchId] * (currentResearch + 1) * (currentResearch + 1);
        if (number(org.treasuryBalance) < cost) throw new ApiError('INSUFFICIENT_TREASURY', 409);
        const research = org.research && typeof org.research === 'object' ? { ...(org.research as Data) } : {};
        research[researchId] = currentResearch + 1;
        const capacity = researchId === 'expansion'
          ? Math.min(80, 20 + (Math.max(1, number(org.level)) - 1) * 5 + currentResearch + 1)
          : number(org.memberCapacity) || Math.min(70, 20 + (Math.max(1, number(org.level)) - 1) * 5);
        const researchTxId = `org_research_${randomUUID()}`;
        await db.commit(transaction, [
          write(`organizations/${orgId}`, { treasuryBalance: number(org.treasuryBalance) - cost, research, memberCapacity: capacity }, ['updatedAt']),
          write(`organization_transactions/${researchTxId}`, { id: researchTxId, orgId, uid, username: typeof member.username === 'string' ? member.username : 'Member', type: 'upgrade', amount: cost, note: `Research ${researchId} advanced to Lv.${currentResearch + 1}` }, ['createdAt']),
        ]);
        res.status(200).json({ ok: true, researchId, level: currentResearch + 1, cost, memberCapacity: capacity });
        return;
      }
      if (endsAt > now) throw new ApiError('UPGRADE_IN_PROGRESS', 409);
      const currentLevel = Math.max(1, Math.floor(number(org.level) || 1));
      if (currentLevel >= 10) throw new ApiError('MAX_LEVEL', 409);
      const financeLevel = researchLevel(org.research, 'finance');
      const engineeringLevel = researchLevel(org.research, 'engineering');
      const cost = upgradeCost(currentLevel, financeLevel);
      if (number(org.treasuryBalance) < cost) throw new ApiError('INSUFFICIENT_TREASURY', 409);
      const nextLevel = currentLevel + 1; const finish = now + durationMs(nextLevel, engineeringLevel);
      const upgradeTxId = `org_upgrade_${randomUUID()}`;
      await db.commit(transaction, [
        write(`organizations/${orgId}`, { treasuryBalance: number(org.treasuryBalance) - cost, upgradeStartedAt: now, upgradeEndsAt: finish, upgradeTargetLevel: nextLevel }, ['updatedAt']),
        write(`organization_transactions/${upgradeTxId}`, { id: upgradeTxId, orgId, uid, username: typeof member.username === 'string' ? member.username : 'Member', type: 'upgrade', amount: cost, note: `Started organization upgrade to Lv.${nextLevel}` }, ['createdAt']),
      ]);
      res.status(200).json({ ok: true, targetLevel: nextLevel, endsAt: finish, cost, durationMs: finish - now });
    } catch (error) {
      await db.rollback(transaction).catch(() => undefined);
      throw error;
    }
  } catch (error) {
    if (error instanceof ApiError) { res.status(error.status).json({ error: error.code }); return; }
    const message = error instanceof Error ? error.message : '';
    if (message.includes('invalid_grant') || message.includes('unauthorized_client')) { res.status(503).json({ error: 'BACKEND_IDENTITY_NOT_READY' }); return; }
    res.status(500).json({ error: 'ORGANIZATION_UPGRADE_FAILED' });
  }
}
