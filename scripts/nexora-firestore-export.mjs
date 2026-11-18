#!/usr/bin/env node
import process from 'node:process';

const FIRESTORE_PROJECT_ID = 'gen-lang-client-0074900177';
const FIRESTORE_DATABASE_ID = 'ai-studio-74843d9e-8228-49b7-a616-317cadd90bff';
const SUPABASE_URL = 'https://dmeupqmhsyojxlgalxrc.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_PCsjX_kcS-D8FY4PobPl4w_2BwpeilC';
const IMPORT_AUDIENCE = `${SUPABASE_URL}/functions/v1/nexora-migration-import`;
const EXPORT_MODE = process.env.EXPORT_MODE === 'import' ? 'import' : 'scan';
const PAGE_SIZE = 100;

const COLLECTIONS = [
  'profiles','usernames','users_private','wallets','transactions','inventory',
  'market_listings','market_orders','companies','company_auctions','company_logs',
  'properties','organizations','organization_members','organization_requests',
  'organization_transactions','player_missions','daily_claims','contract_claims',
  'player_achievements','notifications','world_events','audit_logs','user_blocks',
  'chat_rate_limits','conversations','global_chat_messages','organization_invites',
  'player_reports',
];

const googleAccessToken = process.env.GOOGLE_ACCESS_TOKEN;
if (!googleAccessToken) throw new Error('GOOGLE_ACCESS_TOKEN is missing; configure GitHub OIDC with Google Cloud WIF.');
if (EXPORT_MODE === 'import' && (!process.env.ACTIONS_ID_TOKEN_REQUEST_URL || !process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN)) {
  throw new Error('GitHub OIDC request environment is missing; grant id-token: write to this workflow.');
}

function decodeValue(raw) {
  if (!raw || typeof raw !== 'object') return raw;
  if ('stringValue' in raw) return raw.stringValue;
  if ('integerValue' in raw) return Number(raw.integerValue);
  if ('doubleValue' in raw) return raw.doubleValue;
  if ('booleanValue' in raw) return raw.booleanValue;
  if ('nullValue' in raw) return null;
  if ('timestampValue' in raw) return raw.timestampValue;
  if ('referenceValue' in raw) return raw.referenceValue;
  if ('bytesValue' in raw) return raw.bytesValue;
  if ('geoPointValue' in raw) return raw.geoPointValue;
  if ('mapValue' in raw) {
    const fields = raw.mapValue?.fields ?? {};
    return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
  }
  if ('arrayValue' in raw) return (raw.arrayValue?.values ?? []).map(decodeValue);
  return raw;
}

function decodeDocument(doc) {
  const fields = doc.fields ?? {};
  const path = String(doc.name ?? '');
  return {
    id: path.split('/').pop() ?? '',
    path,
    fields: Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)])),
  };
}

async function fetchFirestorePage(sourcePath, pageToken = '') {
  const url = new URL(`https://firestore.googleapis.com/v1/projects/${FIRESTORE_PROJECT_ID}/databases/${FIRESTORE_DATABASE_ID}/documents/${sourcePath}`);
  url.searchParams.set('pageSize', String(PAGE_SIZE));
  if (pageToken) url.searchParams.set('pageToken', pageToken);
  const response = await fetch(url, { headers: { Authorization: `Bearer ${googleAccessToken}` } });
  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`Firestore export failed for ${sourcePath}: HTTP ${response.status} ${detail.slice(0,180)}`);
  }
  return response.json();
}

async function getGitHubOidcToken() {
  const url = new URL(process.env.ACTIONS_ID_TOKEN_REQUEST_URL);
  url.searchParams.set('audience', IMPORT_AUDIENCE);
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN}` },
  });
  if (!response.ok) throw new Error(`GitHub OIDC token request failed: HTTP ${response.status}`);
  const result = await response.json();
  if (typeof result.value !== 'string' || result.value.length < 100) throw new Error('GitHub OIDC token response was invalid.');
  return result.value;
}

async function importPage(collection, parentId, documents) {
  if (!documents.length || EXPORT_MODE !== 'import') return;
  const oidcToken = await getGitHubOidcToken();
  const response = await fetch(`${SUPABASE_URL}/functions/v1/nexora-migration-import`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${oidcToken}`,
      apikey: SUPABASE_PUBLISHABLE_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ collection, parentId: parentId || undefined, documents }),
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || result.ok !== true) {
    throw new Error(`Supabase import failed for ${collection}: ${result.error ?? `HTTP ${response.status}`}`);
  }
  process.stdout.write(`  imported ${result.imported ?? documents.length} rows; checksum ${result.checksum ?? 'n/a'}\n`);
}

const conversationIds = [];

async function exportCollection(collection, parentId = '') {
  const sourcePath = parentId ? `conversations/${parentId}/messages` : collection;
  let pageToken = '';
  let total = 0;
  do {
    const page = await fetchFirestorePage(sourcePath, pageToken);
    const documents = (page.documents ?? []).map(decodeDocument);
    if (collection === 'conversations' && !parentId) {
      for (const document of documents) if (document.id && !conversationIds.includes(document.id)) conversationIds.push(document.id);
    }
    total += documents.length;
    if (documents.length) await importPage(collection, parentId, documents);
    pageToken = page.nextPageToken ?? '';
  } while (pageToken);
  process.stdout.write(`${collection}${parentId ? `/${parentId}` : ''}: ${total} records\n`);
  return total;
}

let total = 0;
for (const collection of COLLECTIONS) {
  total += await exportCollection(collection);
}
let messageCount = 0;
for (const conversationId of conversationIds) {
  messageCount += await exportCollection('conversation_messages', conversationId);
}
total += messageCount;
process.stdout.write(`NEXORA Firestore export ${EXPORT_MODE} complete: ${total} records across ${COLLECTIONS.length + conversationIds.length} collections/subcollections.\n`);
