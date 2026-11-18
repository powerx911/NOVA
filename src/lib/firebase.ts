import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider } from 'firebase/auth';
import { doc, getDocFromServer, getFirestore } from 'firebase/firestore';
import { getFunctions } from 'firebase/functions';
import firebaseConfig from '../../firebase-applet-config.json';
import {
  maskUid,
  recordSanitizedError,
  sanitizeDiagnosticString,
} from './diagnosticsSanitizer';

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app, firebaseConfig.firestoreDatabaseId);
export const auth = getAuth(app);
export const functions = getFunctions(app, 'us-central1');
export const googleAuthProvider = new GoogleAuthProvider();
googleAuthProvider.setCustomParameters({ prompt: 'select_account' });

export enum OperationType {
  CREATE = 'create',
  UPDATE = 'update',
  DELETE = 'delete',
  LIST = 'list',
  GET = 'get',
  WRITE = 'write',
}

export interface FirestoreErrorInfo {
  error: string;
  code?: string | null;
  operationType: OperationType;
  path: string | null;
  authInfo: {
    userId?: string | null;
    emailVerified?: boolean | null;
    isAnonymous?: boolean | null;
    tenantId?: string | null;
    providerIds?: string[];
  };
}

export function handleFirestoreError(
  error: unknown,
  operationType: OperationType,
  path: string | null
): never {
  const rawMessage = error instanceof Error ? error.message : String(error);
  const sanitizedMessage = sanitizeDiagnosticString(rawMessage, 280);
  const errorCode =
    typeof error === 'object' && error !== null && 'code' in error &&
    typeof (error as { code?: unknown }).code === 'string'
      ? (error as { code: string }).code
      : null;
  const errInfo: FirestoreErrorInfo = {
    error: sanitizedMessage,
    code: errorCode,
    authInfo: {
      userId: maskUid(auth.currentUser?.uid),
      emailVerified: auth.currentUser?.emailVerified ?? null,
      isAnonymous: auth.currentUser?.isAnonymous ?? null,
      tenantId: auth.currentUser?.tenantId ?? null,
      providerIds:
        auth.currentUser?.providerData?.map((provider) => provider.providerId).filter(Boolean) || [],
    },
    operationType,
    path,
  };
  recordSanitizedError({
    source: path ? `firestore:${operationType}:${path}` : `firestore:${operationType}`,
    message: sanitizedMessage,
  });
  console.error('Firestore Error:', JSON.stringify(errInfo));
  throw new Error(JSON.stringify(errInfo));
}

export async function testFirestoreConnection(): Promise<boolean> {
  try {
    await getDocFromServer(doc(db, 'test', 'connection'));
    return true;
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    recordSanitizedError({
      source: 'firestore:test/connection',
      message: msg,
      category: 'firestore',
      severity: 'warning',
    });
    if (msg.includes('the client is offline')) {
      console.error('Firestore client is offline. Please verify Firebase configuration.');
    }
    return false;
  }
}

// Firestore is retained only for the legacy owner diagnostics screen; do not probe it during normal gameplay startup.
