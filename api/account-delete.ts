import { IdentityPoolClient } from 'google-auth-library';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import firebaseConfig from '../firebase-applet-config.json';

const PROJECT_ID = 'gen-lang-client-0074900177';
const PROJECT_NUMBER = '145581837596';
const DATABASE_ID = 'ai-studio-74843d9e-8228-49b7-a616-317cadd90bff';
const SERVICE_ACCOUNT = 'nexora-vercel-runtime@gen-lang-client-0074900177.iam.gserviceaccount.com';
const WIF_AUDIENCE = '//iam.googleapis.com/projects/' + PROJECT_NUMBER + '/locations/global/workloadIdentityPools/nexora-vercel-pool/providers/nexora-vercel';
const FIREBASE_ISSUER = 'https://securetoken.google.com/' + PROJECT_ID;
const FIREBASE_KEYS = createRemoteJWKSet(new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'));

type Req = IncomingMessage & { body?: unknown };
type Res = ServerResponse & { status: (code: number) => Res; json: (body: unknown) => void };
type Data = Record<string, unknown>;
type RestDocument = { name: string; fields?: Record<string, unknown> };
type RestWrite =
  | { delete: string }
  | { update: { name: string; fields: Record<string, unknown> }; updateMask: { fieldPaths: string[] } };

class DeleteError extends Error {
  constructor(public code: string, public status: number) { super(code); }
}

const documentName = (path: string) => 'projects/' + PROJECT_ID + '/databases/' + DATABASE_ID + '/documents/' + path;
const stringValue = (value: string) => ({ stringValue: value });
function decode(value: unknown): unknown {
  if (!value || typeof value !== 'object') return value;
  const v = value as Data;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return Date.parse(String(v.timestampValue));
  if ('mapValue' in v) {
    const fields = ((v.mapValue as Data).fields ?? {}) as Data;
    return Object.fromEntries(Object.entries(fields).map(([key, item]) => [key, decode(item)]));
  }
  if ('arrayValue' in v) return (((v.arrayValue as Data).values ?? []) as unknown[]).map(decode);
  return v;
}
function decodeDocument(document: RestDocument): Data {
  return Object.fromEntries(Object.entries(document.fields ?? {}).map(([key, value]) => [key, decode(value)]));
}

class FirestoreAdmin {
  constructor(private client: IdentityPoolClient) {}
  private async request<T>(method: string, body: unknown): Promise<T> {
    const response = await this.client.fetch(
      'https://firestore.googleapis.com/v1/projects/' + PROJECT_ID + '/databases/' + DATABASE_ID + '/documents:' + method,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
    );
    return response.data as T;
  }
  async query(collectionId: string, fieldPath: string, value: string): Promise<Array<{ name: string; data: Data }>> {
    const rows = await this.request<Array<{ document?: RestDocument }>>('runQuery', {
      structuredQuery: {
        from: [{ collectionId }],
        where: { fieldFilter: { field: { fieldPath }, op: 'EQUAL', value: stringValue(value) } },
      },
    });
    return rows.flatMap(row => row.document ? [{ name: row.document.name, data: decodeDocument(row.document) }] : []);
  }
  async getMany(paths: string[]): Promise<Array<Data | null>> {
    if (!paths.length) return [];
    const rows = await this.request<Array<{ found?: RestDocument; missing?: string }>>('batchGet', { documents: paths.map(documentName) });
    const map = new Map<string, Data | null>();
    for (const row of rows) {
      if (row.found) map.set(row.found.name, decodeDocument(row.found));
      else if (row.missing) map.set(row.missing, null);
    }
    return paths.map(path => map.get(documentName(path)) ?? null);
  }
  async commit(writes: RestWrite[]) {
    for (let index = 0; index < writes.length; index += 450) {
      await this.request('commit', { writes: writes.slice(index, index + 450) });
    }
  }
}

async function verifyPlayer(req: Req): Promise<{ uid: string; idToken: string }> {
  const header = req.headers.authorization;
  const match = typeof header === 'string' ? /^Bearer\s+(.+)$/i.exec(header) : null;
  if (!match) throw new DeleteError('UNAUTHENTICATED', 401);
  const idToken = match[1];
  const { payload } = await jwtVerify(idToken, FIREBASE_KEYS, { issuer: FIREBASE_ISSUER, audience: PROJECT_ID, algorithms: ['RS256'] });
  const firebaseClaim = payload.firebase && typeof payload.firebase === 'object' ? payload.firebase as Record<string, unknown> : {};
  const isAnonymous = firebaseClaim.sign_in_provider === 'anonymous';
  if (typeof payload.sub !== 'string' || !payload.sub || (payload.email_verified !== true && !isAnonymous)) {
    throw new DeleteError('UNAUTHENTICATED', 401);
  }
  return { uid: payload.sub, idToken };
}

function firestoreForRequest(req: Req): FirestoreAdmin {
  const raw = req.headers['x-vercel-oidc-token'];
  const oidcToken = Array.isArray(raw) ? raw[0] : raw;
  if (typeof oidcToken !== 'string' || oidcToken.length < 40) throw new DeleteError('BACKEND_IDENTITY_NOT_READY', 503);
  const client = new IdentityPoolClient({
    audience: WIF_AUDIENCE,
    subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
    token_url: 'https://sts.googleapis.com/v1/token',
    service_account_impersonation_url: 'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/' + SERVICE_ACCOUNT + ':generateAccessToken',
    subject_token_supplier: { getSubjectToken: async () => oidcToken },
  });
  client.scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  return new FirestoreAdmin(client);
}

function updateMemberCount(path: string, memberCount: number): RestWrite {
  return {
    update: { name: documentName(path), fields: { memberCount: { integerValue: String(memberCount) } } },
    updateMask: { fieldPaths: ['memberCount'] },
  };
}

export default async function handler(req: Req, res: Res): Promise<void> {
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  if (req.method !== 'POST') { res.status(405).json({ error: 'METHOD_NOT_ALLOWED' }); return; }

  try {
    const verified = await verifyPlayer(req);
    const uid = verified.uid;
    const db = firestoreForRequest(req);
    const memberships = await db.query('organization_members', 'uid', uid);
    const organizationsOwned = await db.query('organizations', 'leaderUid', uid);
    const orgIds = [...new Set(memberships.map(item => String(item.data.orgId || '')).filter(Boolean))];
    const orgDocs = await db.getMany(orgIds.map(id => 'organizations/' + id));
    const memberUpdates: RestWrite[] = [];
    const deleteNames = new Set<string>();

    for (let index = 0; index < memberships.length; index += 1) {
      const membership = memberships[index];
      const orgId = String(membership.data.orgId || '');
      const org = orgDocs[orgIds.indexOf(orgId)];
      if (!org) { deleteNames.add(membership.name); continue; }
      if (membership.data.role === 'leader') {
        const orgMembers = await db.query('organization_members', 'orgId', orgId);
        if (orgMembers.some(member => member.data.uid !== uid)) throw new DeleteError('LEADER_MUST_TRANSFER', 409);
        deleteNames.add(documentName('organizations/' + orgId));
        const requests = await db.query('organization_requests', 'orgId', orgId);
        const orgTransactions = await db.query('organization_transactions', 'orgId', orgId);
        requests.forEach(item => deleteNames.add(item.name));
        orgTransactions.forEach(item => deleteNames.add(item.name));
      } else {
        const count = typeof org.memberCount === 'number' ? org.memberCount : 1;
        memberUpdates.push(updateMemberCount('organizations/' + orgId, Math.max(1, count - 1)));
      }
      deleteNames.add(membership.name);
    }

    for (const owned of organizationsOwned) {
      const orgId = String(owned.data.id || '');
      if (orgId && !orgIds.includes(orgId)) {
        const orgMembers = await db.query('organization_members', 'orgId', orgId);
        if (orgMembers.some(member => member.data.uid !== uid)) throw new DeleteError('LEADER_MUST_TRANSFER', 409);
        deleteNames.add(owned.name);
        orgMembers.forEach(item => deleteNames.add(item.name));
        const requests = await db.query('organization_requests', 'orgId', orgId);
        const orgTransactions = await db.query('organization_transactions', 'orgId', orgId);
        requests.forEach(item => deleteNames.add(item.name));
        orgTransactions.forEach(item => deleteNames.add(item.name));
      }
    }

    const querySpecs: Array<[string, string]> = [
      ['inventory', 'uid'],
      ['transactions', 'fromUid'], ['transactions', 'toUid'],
      ['market_listings', 'sellerUid'],
      ['market_orders', 'buyerUid'], ['market_orders', 'sellerUid'],
      ['companies', 'ownerUid'], ['company_logs', 'ownerUid'], ['properties', 'ownerUid'],
      ['organization_requests', 'uid'], ['organization_transactions', 'uid'],
      ['player_missions', 'uid'], ['contract_claims', 'uid'], ['player_achievements', 'uid'],
      ['notifications', 'uid'], ['daily_claims', 'uid'], ['usernames', 'uid'],
    ];
    const results = await Promise.all(querySpecs.map(([collection, field]) => db.query(collection, field, uid)));
    results.flat().forEach(item => deleteNames.add(item.name));
    for (const path of ['profiles/' + uid, 'users_private/' + uid, 'wallets/' + uid]) deleteNames.add(documentName(path));

    const writes: RestWrite[] = [
      ...memberUpdates,
      ...Array.from(deleteNames, name => ({ delete: name } as RestWrite)),
    ];
    await db.commit(writes);

    const authResponse = await fetch('https://identitytoolkit.googleapis.com/v1/accounts:delete?key=' + firebaseConfig.apiKey, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: verified.idToken }),
    });
    if (!authResponse.ok) {
      const authError = await authResponse.json().catch(() => ({})) as { error?: { message?: string } };
      const code = authError.error?.message || '';
      const reauth = code.includes('CREDENTIAL_TOO_OLD') || code.includes('TOKEN_EXPIRED');
      res.status(reauth ? 409 : 502).json({ error: reauth ? 'REAUTHENTICATION_REQUIRED' : 'AUTH_ACCOUNT_DELETE_FAILED' });
      return;
    }
    res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof DeleteError) { res.status(error.status).json({ error: error.code }); return; }
    res.status(500).json({ error: 'ACCOUNT_DELETE_FAILED' });
  }
}
