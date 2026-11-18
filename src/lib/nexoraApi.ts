import { auth } from './firebase';

const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL || 'https://hmrprnjhyzyefocdmnxf.supabase.co';
const SUPABASE_PUBLISHABLE_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_T0zWZ-2mi1K5CW7nVlWy5w_TL9AMWAj';
const API_URL = `${SUPABASE_URL}/functions/v1/nexora-api`;
const READ_ONLY_ACTIONS = new Set(['bootstrap', 'username_available', 'fetch_org_pending_requests', 'fetch_leaderboards', 'get_public_player_profile', 'search_players', 'list_blocked_players', 'list_direct_conversations', 'list_direct_messages', 'list_global_chat_messages', 'list_organization_invites', 'get_players_presence', 'touch_player_presence', 'get_org_donation_ranking']);

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
  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ action, ...payload }),
  });

  const result = (await response.json().catch(() => ({}))) as ApiEnvelope<T>;
  if (!response.ok) {
    throw new NexoraApiError(
      typeof result.error === 'string' ? result.error : 'NEXORA_API_FAILED',
      response.status,
    );
  }
  if (result.ok !== true) throw new NexoraApiError('INVALID_API_RESPONSE', 502);
  if (!READ_ONLY_ACTIONS.has(action) && typeof window !== 'undefined') {
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
