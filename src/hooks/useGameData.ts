import { createUserWithEmailAndPassword, getRedirectResult, onAuthStateChanged, sendEmailVerification, signInAnonymously, signInWithEmailAndPassword, signInWithPopup, signInWithRedirect, signOut, type User } from 'firebase/auth';
import {
  collection,
  doc,
  limit,
  onSnapshot,
  orderBy,
  query,
  where,
} from 'firebase/firestore';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ACHIEVEMENTS } from '../data/catalog';
import { hasOrgPermission, timestampToMs } from '../lib/economy';
import { auth, db, googleAuthProvider, handleFirestoreError, OperationType } from '../lib/firebase';
import {
  checkAndUnlockAchievements,
  ensureBootstrapWorldData,
  getUtcDateKey,
  syncSelfOrgMembership,
} from '../services/gameService';
import type {
  Company,
  CompanyLog,
  GameNotification,
  InventoryItem,
  Language,
  MarketListing,
  MarketOrder,
  Organization,
  OrganizationMember,
  OrganizationRequest,
  OrganizationTransaction,
  PlayerMissionClaim,
  PlayerProfile,
  PropertyAsset,
  TransactionRecord,
  UserPrivate,
  Wallet,
  WorldEvent,
} from '../types/game';

export interface GameDataState {
  authUser: User | null;
  authReady: boolean;
  profile: PlayerProfile | null;
  profileLoading: boolean;
  userPrivate: UserPrivate | null;
  wallet: Wallet | null;
  inventory: InventoryItem[];
  transactions: TransactionRecord[];
  marketListings: MarketListing[];
  marketOrders: MarketOrder[];
  companies: Company[];
  companyLogs: CompanyLog[];
  properties: PropertyAsset[];
  organizations: Organization[];
  myOrgMember: OrganizationMember | null;
  orgMembers: OrganizationMember[];
  orgRequests: OrganizationRequest[];
  myPendingOrgIds: Set<string>;
  orgTransactions: OrganizationTransaction[];
  claimedMissions: PlayerMissionClaim[];
  claimedDailyToday: boolean;
  claimedContractsToday: Set<string>;
  unlockedAchievements: Set<string>;
  notifications: GameNotification[];
  worldEvents: WorldEvent[];
  isOnline: boolean;
  language: Language;
  setLanguageLocal: (lang: Language) => void;
  loginWithGoogle: () => Promise<void>;
  loginWithEmail: (email: string, password: string) => Promise<void>;
  registerWithEmail: (email: string, password: string) => Promise<void>;
  loginAsGuest: () => Promise<void>;
  logout: () => Promise<void>;
}

function sortByCreatedAtDesc<T extends { createdAt?: unknown }>(items: T[]): T[] {
  return [...items].sort(
    (a, b) => timestampToMs(b.createdAt, 0) - timestampToMs(a.createdAt, 0)
  );
}

export function useGameData(): GameDataState {
  const [authUser, setAuthUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [profile, setProfile] = useState<PlayerProfile | null>(null);
  const [profileLoading, setProfileLoading] = useState(true);
  const [userPrivate, setUserPrivate] = useState<UserPrivate | null>(null);
  const [wallet, setWallet] = useState<Wallet | null>(null);
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [transactions, setTransactions] = useState<TransactionRecord[]>([]);
  const [marketListings, setMarketListings] = useState<MarketListing[]>([]);
  const [marketOrders, setMarketOrders] = useState<MarketOrder[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [companyLogs, setCompanyLogs] = useState<CompanyLog[]>([]);
  const [properties, setProperties] = useState<PropertyAsset[]>([]);
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [myOrgMember, setMyOrgMember] = useState<OrganizationMember | null>(null);
  const [orgMemberLoaded, setOrgMemberLoaded] = useState(false);
  const [orgMembers, setOrgMembers] = useState<OrganizationMember[]>([]);
  const [orgRequests, setOrgRequests] = useState<OrganizationRequest[]>([]);
  const [myPendingOrgIds, setMyPendingOrgIds] = useState<Set<string>>(new Set());
  const [orgTransactions, setOrgTransactions] = useState<OrganizationTransaction[]>([]);
  const [claimedMissions, setClaimedMissions] = useState<PlayerMissionClaim[]>([]);
  const [claimedDailyToday, setClaimedDailyToday] = useState(false);
  const [claimedContractsToday, setClaimedContractsToday] = useState<Set<string>>(new Set());
  const [unlockedAchievements, setUnlockedAchievements] = useState<Set<string>>(new Set());
  const [notifications, setNotifications] = useState<GameNotification[]>([]);
  const [worldEvents, setWorldEvents] = useState<WorldEvent[]>([]);
  const [utcDateKey, setUtcDateKey] = useState(() => getUtcDateKey());
  const [isOnline, setIsOnline] = useState(() =>
    typeof navigator !== 'undefined' ? navigator.onLine : true
  );
  const [language, setLanguage] = useState<Language>('ar');
  const attemptedAchievementsRef = useRef<Set<string>>(new Set());
  const bootstrappedUidRef = useRef<string | null>(null);
  const activeUidRef = useRef<string | null>(null);

  const setLanguageLocal = useCallback((lang: Language) => {
    setLanguage(lang);
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  }, []);

  useEffect(() => {
    document.documentElement.lang = language;
    document.documentElement.dir = language === 'ar' ? 'rtl' : 'ltr';
  }, [language]);

  useEffect(() => {
    const syncDateKey = () => {
      const latest = getUtcDateKey();
      setUtcDateKey((prev) => (prev === latest ? prev : latest));
    };
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    const interval = setInterval(syncDateKey, 60_000);
    window.addEventListener('focus', syncDateKey);
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    return () => {
      clearInterval(interval);
      window.removeEventListener('focus', syncDateKey);
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const clearSessionState = useCallback(() => {
    attemptedAchievementsRef.current.clear();
    setProfile(null);
    setProfileLoading(false);
    setUserPrivate(null);
    setWallet(null);
    setInventory([]);
    setTransactions([]);
    setMarketListings([]);
    setMarketOrders([]);
    setCompanies([]);
    setCompanyLogs([]);
    setProperties([]);
    setOrganizations([]);
    setMyOrgMember(null);
    setOrgMemberLoaded(false);
    setOrgMembers([]);
    setOrgRequests([]);
    setMyPendingOrgIds(new Set());
    setOrgTransactions([]);
    setClaimedMissions([]);
    setClaimedDailyToday(false);
    setClaimedContractsToday(new Set());
    setUnlockedAchievements(new Set());
    setNotifications([]);
    setWorldEvents([]);
  }, []);

  useEffect(() => {
    let redirectResolved = false;
    let authStateObserved = false;

    const unsub = onAuthStateChanged(auth, (user) => {
      const nextUid = user?.uid ?? null;
      if (activeUidRef.current && activeUidRef.current !== nextUid) {
        clearSessionState();
      }
      activeUidRef.current = nextUid;
      setAuthUser(user);
      authStateObserved = true;
      if (redirectResolved) setAuthReady(true);
      if (!user) {
        bootstrappedUidRef.current = null;
        clearSessionState();
      }
    });

    // Complete the Google redirect flow before showing the signed-out screen.
    getRedirectResult(auth)
      .catch((error) => {
        console.error('Google redirect sign-in result error:', error);
      })
      .finally(() => {
        redirectResolved = true;
        if (authStateObserved) setAuthReady(true);
      });

    return () => unsub();
  }, [clearSessionState]);

  useEffect(() => {
    if (!authUser) return;
    setProfileLoading(true);
    setOrgMemberLoaded(false);

    const uid = authUser.uid;
    if (bootstrappedUidRef.current !== uid) {
      bootstrappedUidRef.current = uid;
      ensureBootstrapWorldData();
    }
    const unsubs: (() => void)[] = [];

    const onSnapErr = (path: string) => (error: unknown) => {
      try {
        handleFirestoreError(error, OperationType.GET, path);
      } catch {
        // Error already logged cleanly via handleFirestoreError
      }
    };

    unsubs.push(
      onSnapshot(
        doc(db, 'profiles', uid),
        (snap) => {
          setProfile(snap.exists() ? (snap.data() as PlayerProfile) : null);
          setProfileLoading(false);
        },
        (err) => {
          setProfileLoading(false);
          onSnapErr(`profiles/${uid}`)(err);
        }
      )
    );

    unsubs.push(
      onSnapshot(
        doc(db, 'users_private', uid),
        (snap) => {
          if (snap.exists()) {
            const data = snap.data() as UserPrivate;
            setUserPrivate(data);
            setLanguageLocal(data.language);
          }
        },
        onSnapErr(`users_private/${uid}`)
      )
    );

    unsubs.push(
      onSnapshot(
        doc(db, 'wallets', uid),
        (snap) => {
          setWallet(snap.exists() ? (snap.data() as Wallet) : null);
        },
        onSnapErr(`wallets/${uid}`)
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'inventory'), where('uid', '==', uid)),
        (snap) => {
          setInventory(snap.docs.map((d) => d.data() as InventoryItem));
        },
        onSnapErr('inventory')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'transactions'), where('fromUid', '==', uid), limit(30)),
        (fromSnap) => {
          const sent = fromSnap.docs.map((d) => d.data() as TransactionRecord);
          setTransactions((prev) => {
            const receivedOnly = prev.filter((t) => t.toUid === uid && t.fromUid !== uid);
            const map = new Map<string, TransactionRecord>();
            [...sent, ...receivedOnly].forEach((t) => map.set(t.id, t));
            return sortByCreatedAtDesc(Array.from(map.values())).slice(0, 40);
          });
        },
        onSnapErr('transactions/fromUid')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'transactions'), where('toUid', '==', uid), limit(30)),
        (toSnap) => {
          const received = toSnap.docs.map((d) => d.data() as TransactionRecord);
          setTransactions((prev) => {
            const sentOnly = prev.filter((t) => t.fromUid === uid);
            const map = new Map<string, TransactionRecord>();
            [...sentOnly, ...received].forEach((t) => map.set(t.id, t));
            return sortByCreatedAtDesc(Array.from(map.values())).slice(0, 40);
          });
        },
        onSnapErr('transactions/toUid')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'market_listings'), where('status', '==', 'active'), limit(100)),
        (snap) => {
          setMarketListings(snap.docs.map((d) => d.data() as MarketListing));
        },
        onSnapErr('market_listings')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'market_orders'), where('buyerUid', '==', uid), limit(25)),
        (snap) => {
          setMarketOrders(sortByCreatedAtDesc(snap.docs.map((d) => d.data() as MarketOrder)));
        },
        onSnapErr('market_orders')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'companies'), where('ownerUid', '==', uid)),
        (snap) => {
          setCompanies(snap.docs.map((d) => d.data() as Company));
        },
        onSnapErr('companies')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'company_logs'), where('ownerUid', '==', uid), limit(25)),
        (snap) => {
          setCompanyLogs(sortByCreatedAtDesc(snap.docs.map((d) => d.data() as CompanyLog)));
        },
        onSnapErr('company_logs')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'properties'), where('ownerUid', '==', uid)),
        (snap) => {
          setProperties(snap.docs.map((d) => d.data() as PropertyAsset));
        },
        onSnapErr('properties')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'organizations'), where('reputation', '>=', 0), orderBy('reputation', 'desc'), limit(40)),
        (snap) => {
          setOrganizations(snap.docs.map((d) => d.data() as Organization));
        },
        onSnapErr('organizations')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'organization_members'), where('uid', '==', uid), limit(1)),
        (snap) => {
          const member = snap.docs[0]?.data() as OrganizationMember | undefined;
          setMyOrgMember(member ?? null);
          setOrgMemberLoaded(true);
        },
        (err) => {
          setOrgMemberLoaded(true);
          onSnapErr('organization_members/self')(err);
        }
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'organization_requests'), where('uid', '==', uid)),
        (snap) => {
          const pendingIds = new Set<string>();
          snap.docs.forEach((d) => {
            const req = d.data() as OrganizationRequest;
            if (req.status === 'pending') {
              pendingIds.add(req.orgId);
            }
          });
          setMyPendingOrgIds(pendingIds);
        },
        onSnapErr('organization_requests/self')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'player_missions'), where('uid', '==', uid)),
        (snap) => {
          setClaimedMissions(snap.docs.map((d) => d.data() as PlayerMissionClaim));
        },
        onSnapErr('player_missions')
      )
    );

    unsubs.push(
      onSnapshot(
        doc(db, 'daily_claims', `${uid}_${utcDateKey}`),
        (snap) => {
          setClaimedDailyToday(snap.exists());
        },
        onSnapErr(`daily_claims/${uid}_${utcDateKey}`)
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'contract_claims'), where('uid', '==', uid)),
        (snap) => {
          const ids = new Set<string>();
          snap.docs.forEach((d) => {
            const c = d.data() as { contractId: string };
            ids.add(c.contractId);
          });
          setClaimedContractsToday(ids);
        },
        onSnapErr('contract_claims')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'player_achievements'), where('uid', '==', uid)),
        (snap) => {
          const ids = new Set<string>();
          snap.docs.forEach((d) => {
            const data = d.data() as { achievementId: string };
            ids.add(data.achievementId);
          });
          setUnlockedAchievements(ids);
        },
        onSnapErr('player_achievements')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'notifications'), where('uid', '==', uid), limit(30)),
        (snap) => {
          setNotifications(sortByCreatedAtDesc(snap.docs.map((d) => d.data() as GameNotification)));
        },
        onSnapErr('notifications')
      )
    );

    unsubs.push(
      onSnapshot(
        query(collection(db, 'world_events'), where('active', '==', true)),
        (snap) => {
          setWorldEvents(snap.docs.map((d) => d.data() as WorldEvent));
        },
        onSnapErr('world_events')
      )
    );

    return () => {
      unsubs.forEach((fn) => fn());
    };
  }, [authUser, setLanguageLocal, utcDateKey]);

  // Sync organization membership onto profile if approved while away
  useEffect(() => {
    if (!authUser || !profile || !orgMemberLoaded) return;
    if (myOrgMember && profile.orgId !== myOrgMember.orgId) {
      syncSelfOrgMembership(authUser.uid, myOrgMember.orgId);
    } else if (!myOrgMember && profile.orgId) {
      syncSelfOrgMembership(authUser.uid, null);
    }
  }, [authUser, profile, myOrgMember, orgMemberLoaded]);

  // Subscribe to current organization's members, requests, and treasury ledger
  useEffect(() => {
    if (!authUser || !myOrgMember?.orgId) {
      setOrgMembers([]);
      setOrgRequests([]);
      setOrgTransactions([]);
      return;
    }

    const onOrgErr = (path: string) => (error: unknown) => {
      try {
        handleFirestoreError(error, OperationType.GET, path);
      } catch {
        // Logged via handleFirestoreError
      }
    };

    const orgId = myOrgMember.orgId;
    const canManageMembers = hasOrgPermission(myOrgMember, 'manage_members');

    const u1 = onSnapshot(
      query(collection(db, 'organization_members'), where('orgId', '==', orgId)),
      (snap) => {
        setOrgMembers(snap.docs.map((d) => d.data() as OrganizationMember));
      },
      onOrgErr(`organization_members/${orgId}`)
    );

    const u2 = canManageMembers
      ? onSnapshot(
          query(
            collection(db, 'organization_requests'),
            where('orgId', '==', orgId),
            where('status', '==', 'pending')
          ),
          (snap) => {
            setOrgRequests(snap.docs.map((d) => d.data() as OrganizationRequest));
          },
          onOrgErr(`organization_requests/${orgId}`)
        )
      : (() => {
          setOrgRequests([]);
          return () => {};
        })();

    const u3 = onSnapshot(
      query(collection(db, 'organization_transactions'), where('orgId', '==', orgId), limit(40)),
      (snap) => {
        setOrgTransactions(
          sortByCreatedAtDesc(snap.docs.map((d) => d.data() as OrganizationTransaction))
        );
      },
      onOrgErr(`organization_transactions/${orgId}`)
    );

    return () => {
      u1();
      u2();
      u3();
    };
  }, [authUser, myOrgMember]);

  // Auto-unlock eligible achievements (deduplicated per session)
  useEffect(() => {
    if (!authUser || !profile) return;
    const alreadySkipped = new Set([
      ...unlockedAchievements,
      ...attemptedAchievementsRef.current,
    ]);
    const pendingToAttempt = ACHIEVEMENTS.filter((a) => !alreadySkipped.has(a.id));
    if (pendingToAttempt.length === 0) return;

    checkAndUnlockAchievements(authUser.uid, profile, alreadySkipped, pendingToAttempt).then(
      (unlockedNow) => {
        unlockedNow.forEach((id) => attemptedAchievementsRef.current.add(id));
      }
    );
  }, [authUser, profile, unlockedAchievements]);

  const loginWithGoogle = useCallback(async () => {
    // Prefer popup on every device. On mobile browsers, redirect-based OAuth can
    // return to the app without restoring the Firebase session when third-party
    // storage or the browser's in-app authentication hand-off is restricted.
    // Keep redirect as a fallback only when the browser explicitly blocks popups.
    try {
      await signInWithPopup(auth, googleAuthProvider);
    } catch (error) {
      const code =
        typeof error === 'object' && error !== null && 'code' in error
          ? String((error as { code?: unknown }).code || '')
          : '';
      if (code === 'auth/popup-blocked') {
        await signInWithRedirect(auth, googleAuthProvider);
        return;
      }
      throw error;
    }
  }, []);

  const loginWithEmail = useCallback(async (email: string, password: string) => {
    const credential = await signInWithEmailAndPassword(auth, email.trim(), password);
    if (!credential.user.emailVerified) {
      await sendEmailVerification(credential.user).catch(() => undefined);
      await signOut(auth);
      throw new Error('EMAIL_NOT_VERIFIED');
    }
  }, []);

  const registerWithEmail = useCallback(async (email: string, password: string) => {
    const credential = await createUserWithEmailAndPassword(auth, email.trim(), password);
    await sendEmailVerification(credential.user);
    await signOut(auth);
  }, []);

  const loginAsGuest = useCallback(async () => {
    await signInAnonymously(auth);
  }, []);

  const logout = useCallback(async () => {
    await signOut(auth);
  }, []);

  return {
    authUser,
    authReady,
    profile,
    profileLoading,
    userPrivate,
    wallet,
    inventory,
    transactions,
    marketListings,
    marketOrders,
    companies,
    companyLogs,
    properties,
    organizations,
    myOrgMember,
    orgMembers,
    orgRequests,
    myPendingOrgIds,
    orgTransactions,
    claimedMissions,
    claimedDailyToday,
    claimedContractsToday,
    unlockedAchievements,
    notifications,
    worldEvents,
    isOnline,
    language,
    setLanguageLocal,
    loginWithGoogle,
    loginWithEmail,
    registerWithEmail,
    loginAsGuest,
    logout,
  };
}
