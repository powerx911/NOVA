import type { IncomingMessage, ServerResponse } from 'node:http';
import { createRemoteJWKSet, jwtVerify } from 'jose';

type Req = IncomingMessage & { body?: unknown };
type Res = ServerResponse & { status: (code: number) => Res; json: (body: unknown) => void };

const PROJECT_ID = 'gen-lang-client-0074900177';
const FIREBASE_ISSUER = `https://securetoken.google.com/${PROJECT_ID}`;
const FIREBASE_KEYS = createRemoteJWKSet(new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'));
const DESTINATION = 'ptube7575@gmail.com';
const MAX_MESSAGE_LENGTH = 3_000;

async function verifyPlayer(req: Req): Promise<string> {
  const header = req.headers.authorization;
  const match = typeof header === 'string' ? /^Bearer\s+(.+)$/i.exec(header) : null;
  if (!match) throw new Error('UNAUTHENTICATED');
  const { payload } = await jwtVerify(match[1], FIREBASE_KEYS, { issuer: FIREBASE_ISSUER, audience: PROJECT_ID, algorithms: ['RS256'] });
  const firebaseClaim = payload.firebase && typeof payload.firebase === 'object' ? payload.firebase as Record<string, unknown> : {};
  if (typeof payload.sub !== 'string' || !payload.sub || (payload.email_verified !== true && firebaseClaim.sign_in_provider !== 'anonymous')) throw new Error('UNAUTHENTICATED');
  return payload.sub;
}

export default async function handler(req: Req, res: Res): Promise<void> {
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  if (req.method !== 'POST') { res.status(405).json({ error: 'METHOD_NOT_ALLOWED' }); return; }

  const body = req.body && typeof req.body === 'object' ? req.body as Record<string, unknown> : {};
  const type = body.type === 'suggestion' ? 'suggestion' : body.type === 'issue' ? 'issue' : '';
  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (!type || message.length < 10 || message.length > MAX_MESSAGE_LENGTH) {
    res.status(400).json({ error: 'INVALID_FEEDBACK' }); return;
  }

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) { res.status(503).json({ error: 'FEEDBACK_SERVICE_NOT_CONFIGURED' }); return; }

  let uid: string;
  try { uid = await verifyPlayer(req); } catch { res.status(401).json({ error: 'UNAUTHENTICATED' }); return; }

  const subject = type === 'issue' ? 'NEXORA — Player issue report' : 'NEXORA — Player suggestion';
  const text = [
    subject,
    '',
    `Type: ${type}`,
    `Player UID: ${uid}`,
    `Received at: ${new Date().toISOString()}`,
    '',
    message,
  ].join('\n');

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: process.env.RESEND_FROM_EMAIL || 'NEXORA <onboarding@resend.dev>',
        to: [DESTINATION],
        subject,
        text,
      }),
    });
    if (!response.ok) {
      res.status(502).json({ error: 'FEEDBACK_DELIVERY_FAILED' });
      return;
    }
    res.status(200).json({ ok: true });
  } catch {
    res.status(502).json({ error: 'FEEDBACK_DELIVERY_FAILED' });
  }
}
