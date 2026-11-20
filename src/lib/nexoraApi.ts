import { auth } from './firebase';

const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL || 'https://hmrprnjhyzyefocdmnxf.supabase.co';
const SUPABASE_PUBLISHABLE_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_T0zWZ-2mi1K5CW7nVlWy5w_TL9AMWAj';
const API_URL = `${SUPABASE_URL}/functions/v1/nexora-api`;
const READ_ONLY_ACTIONS = new Set(['bootstrap', 'username_available', 'fetch_org_pending_requests', 'fetch_leaderboards', 'get_public_player_profile', 'search_players', 'list_blocked_players', 'list_direct_conversations', 'list_direct_messages', 'list_global_chat_messages', 'list_organization_invites', 'get_players_presence', 'touch_player_presence', 'get_org_donation_ranking', 'validate_transfer_recipient', 'get_dynamic_contract_board', 'get_org_weekly_goals', 'get_manufacturing_job', 'fetch_market_price_history']);
const IDEMPOTENT_ACTIONS = new Set(['transfer_credits', 'buy_market_listing', 'buy_missing_resources', 'org_treasury_deposit']);
const inMemoryRequestIds = new Map<string, string>();

function payloadFingerprint(payload: Record<string, unknown>): string {
  const source = JSON.stringify(payload);
  let hash = 2166136261;
  for (let index = 0; index < source.length; index += 1) {
    hash ^= source.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(36);
}

function createRequestId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  return `${Date.now()}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`;
}

type ApiEnvelope<T> = { ok?: boolean; data?: T; error?: string } & Record<string, unknown>;

export class NexoraApiError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, status: number) {
    super(code);
    this.name = 'NexoraApiError';
    this.code = code;
    this.status = status;
  }
}

export async function nexoraApi<T>(
  action: string,
  payload: Record<string, unknown> = {},
): Promise<T> {
  const user = auth.currentUser;
  if (!user) throw new NexoraApiError('UNAUTHENTICATED', 401);

  const token = await user.getIdToken();
  let requestStorageKey: string | null = null;
  let requestPayload = payload;
  if (IDEMPOTENT_ACTIONS.has(action) && typeof window !== 'undefined') {
    requestStorageKey = `nova:idempotency:${user.uid}:${action}:${payloadFingerprint(payload)}`;
    let requestId: string | null = inMemoryRequestIds.get(requestStorageKey) ?? null;
    try { requestId = window.sessionStorage.getItem(requestStorageKey) ?? requestId; } catch { /* Session storage may be disabled. */ }
    if (!requestId) requestId = createRequestId();
    inMemoryRequestIds.set(requestStorageKey, requestId);
    try { window.sessionStorage.setItem(requestStorageKey, requestId); } catch { /* The in-memory key remains available for retries. */ }
    requestPayload = { ...payload, requestId };
  }
  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ action, ...requestPayload }),
  });

  const result = (await response.json().catch(() => ({}))) as ApiEnvelope<T>;
  if (!response.ok) {
    throw new NexoraApiError(
      typeof result.error === 'string' ? result.error : 'NEXORA_API_FAILED',
      response.status,
    );
  }
  if (result.ok !== true) throw new NexoraApiError('INVALID_API_RESPONSE', 502);
  if (requestStorageKey && typeof window !== 'undefined') {
    inMemoryRequestIds.delete(requestStorageKey);
    try { window.sessionStorage.removeItem(requestStorageKey); } catch { /* Ignore storage cleanup failures. */ }
  }
  if (!READ_ONLY_ACTIONS.has(action) && action !== 'delete_account' && typeof window !== 'undefined') {
    window.dispatchEvent(new Event('nova:refresh-game'));
  }
  return result.data as T;
}

export async function checkNexoraApiHealth(): Promise<boolean> {
  const response = await fetch(API_URL, {
    method: 'GET',
    headers: { apikey: SUPABASE_PUBLISHABLE_KEY },
    cache: 'no-store',
  });
  if (!response.ok) return false;
  const result = (await response.json().catch(() => null)) as { ok?: boolean } | null;
  return result?.ok === true;
}
