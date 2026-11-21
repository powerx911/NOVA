import type { PlayerProfile } from '../types/game';

/**
 * A new account can authenticate before it has a character. Anything that is not
 * a real profile (null, an empty object, or an object that only carries mission
 * counters) must be treated as "no profile" so the player is routed to character
 * creation instead of crashing the main screens.
 */
export function normalizeBootstrapProfile(raw: unknown): PlayerProfile | null {
  if (!raw || typeof raw !== 'object') return null;
  const candidate = raw as Partial<PlayerProfile>;
  if (typeof candidate.uid !== 'string' || candidate.uid.length === 0) return null;
  if (typeof candidate.username !== 'string' || candidate.username.length === 0) return null;
  return candidate as PlayerProfile;
}
