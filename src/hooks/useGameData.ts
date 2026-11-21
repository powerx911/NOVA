import { createUserWithEmailAndPassword, getRedirectResult, onAuthStateChanged, sendEmailVerification, signInAnonymously, signInWithEmailAndPassword, signInWithPopup, signInWithRedirect, signOut, type User } from 'firebase/auth';
import { useCallback, useEffect, useRef, useState } from 'react';
import { auth, googleAuthProvider } from '../lib/firebase';
import { getUtcDateKey } from '../services/gameService';
import { nexoraApi } from '../lib/nexoraApi';
import type {
  Company,
  Factory,
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
  profileLoadError: boolean;
  retryProfileLoad: () => void;
  userPrivate: UserPrivate | null;
  wallet: Wallet | null;
  inventory: InventoryItem[];
  transactions: TransactionRecord[];
  marketListings: MarketListing[];
  marketOrders: MarketOrder[];
  companies: Company[];
  factories: Factory[];
  companyLogs: CompanyLog[];
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
  claimedAchievements: Set<string>;
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

export function useGameData(): GameDataState {
  const [authUser, setAuthUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [profile, setProfile] = useState<PlayerProfile | null>(null);
  const [profileLoading, setProfileLoading] = useState(true);
  const [profileLoadError, setProfileLoadError] = useState(false);
  const [bootstrapRetryKey, setBootstrapRetryKey] = useState(0);
  const [userPrivate, setUserPrivate] = useState<UserPrivate | null>(null);
  const [wallet, setWallet] = useState<Wallet | null>(null);
  const [inventory, setInventory] = useState<InventoryItem[]>([]);
  const [transactions, setTransactions] = useState<TransactionRecord[]>([]);
  const [marketListings, setMarketListings] = useState<MarketListing[]>([]);
  const [marketOrders, setMarketOrders] = useState<MarketOrder[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [factories, setFactories] = useState<Factory[]>([]);
  const [companyLogs, setCompanyLogs] = useState<CompanyLog[]>([]);
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
  const [claimedAchievements, setClaimedAchievements] = useState<Set<string>>(new Set());
  const [notifications, setNotifications] = useState<GameNotification[]>([]);
  useEffect(() => {
    const updateReadState = (event: Event, read: boolean) => {
      const detail = (event as CustomEvent<{ ids?: string[] }>).detail;
      const ids = new Set((detail?.ids ?? []).filter((id): id is string => typeof id === 'string'));
      if (ids.size === 0) return;
      setNotifications((current) => current.map((notification) =>
        ids.has(notification.id) ? { ...notification, read } : notification
      ));
    };
    const handleRead = (event: Event) => updateReadState(event, true);
    const handleUnread = (event: Event) => updateReadState(event, false);
    window.addEventListener('nova:notifications-read', handleRead);
    window.addEventListener('nova:notifications-unread', handleUnread);
    return () => {
      window.removeEventListener('nova:notifications-read', handleRead);
      window.removeEventListener('nova:notifications-unread', handleUnread);
    };
  }, []);

  const [worldEvents, setWorldEvents] = useState<WorldEvent[]>([]);
  const [utcDateKey, setUtcDateKey] = useState(() => getUtcDateKey());

  useEffect(() => {
    if (!profile?.uid) return;
    const heartbeat = () => { void nexoraApi('touch_player_presence').catch(() => undefined); };
    heartbeat();
    const timer = window.setInterval(heartbeat, 30_000);
    return () => window.clearInterval(timer);
  }, [profile?.uid]);
  const [isOnline, setIsOnline] = useState(() =>
    typeof navigator !== 'undefined' ? navigator.onLine : true
  );
  const [language, setLanguage] = useState<Language>('ar');
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
    setProfile(null);
    // Keep the app behind the loading screen during account switches so an
    // empty in-memory profile can never flash the new-character onboarding.
    setProfileLoading(true);
    setProfileLoadError(false);
    setUserPrivate(null);
    setWallet(null);
    setInventory([]);
    setTransactions([]);
    setMarketListings([]);
    setMarketOrders([]);
    setCompanies([]);
    setFactories([]);
    setCompanyLogs([]);
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
    setClaimedAchievements(new Set());
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
    let cancelled = false;
    const uid = authUser.uid;
    if (bootstrappedUidRef.current !== uid) {
      setProfileLoading(true);
      setProfileLoadError(false);
    }
    let refreshInFlight = false;

    const loadGameState = async () => {
      if (refreshInFlight) return;
      refreshInFlight = true;
      try {
        const data = await nexoraApi<Record<string, any>>('bootstrap');
        if (cancelled) return;
        setProfile(data.profile as PlayerProfile | null);
        setUserPrivate(data.userPrivate as UserPrivate | null);
        if (data.userPrivate?.language) setLanguageLocal(data.userPrivate.language as Language);
        setWallet(data.wallet as Wallet | null);
        setInventory((data.inventory ?? []) as InventoryItem[]);
        setTransactions((data.transactions ?? []) as TransactionRecord[]);
        setMarketListings((data.marketListings ?? []) as MarketListing[]);
        setMarketOrders((data.marketOrders ?? []) as MarketOrder[]);
        setCompanies((data.companies ?? []) as Company[]);
        setFactories((data.factories ?? []) as Factory[]);
        setCompanyLogs((data.companyLogs ?? []) as CompanyLog[]);
        setOrganizations((data.organizations ?? []) as Organization[]);
        setMyOrgMember(data.myOrgMember as OrganizationMember | null);
        setOrgMemberLoaded(true);
        setOrgMembers((data.orgMembers ?? []) as OrganizationMember[]);
        setOrgRequests((data.orgRequests ?? []) as OrganizationRequest[]);
        setMyPendingOrgIds(new Set((data.myPendingOrgIds ?? []) as string[]));
        setOrgTransactions((data.orgTransactions ?? []) as OrganizationTransaction[]);
        setClaimedMissions((data.playerMissions ?? []) as PlayerMissionClaim[]);
        setClaimedDailyToday(Boolean(data.claimedDailyToday));
        setClaimedContractsToday(new Set((data.claimedContractsToday ?? []) as string[]));
        const achievementRows = (data.playerAchievements ?? []) as Array<{ achievementId?: string; claimedAt?: string | null }>;
        setUnlockedAchievements(new Set(achievementRows.map((item) => item.achievementId).filter(Boolean) as string[]));
        setClaimedAchievements(new Set(achievementRows.filter((item) => Boolean(item.claimedAt)).map((item) => item.achievementId).filter(Boolean) as string[]));
        setNotifications((data.notifications ?? []) as GameNotification[]);
        setWorldEvents((data.worldEvents ?? []) as WorldEvent[]);
        bootstrappedUidRef.current = uid;
        setProfileLoadError(false);
        setProfileLoading(false);
      } catch (error) {
        if (cancelled) return;
        console.error('NOVA Supabase bootstrap failed:', error);
        // A failed bootstrap is NOT proof that the player has no character.
        // Preserve any loaded profile and block onboarding until a successful retry.
        setProfileLoadError(true);
        setProfileLoading(false);
      } finally {
        refreshInFlight = false;
      }
    };

    const refreshFromCharacterCreation = () => { void loadGameState(); };
    window.addEventListener('nova:refresh-game', refreshFromCharacterCreation);
    void loadGameState();
    const refresh = window.setInterval(() => { void loadGameState(); }, 30_000);
    return () => {
      cancelled = true;
      window.removeEventListener('nova:refresh-game', refreshFromCharacterCreation);
      window.clearInterval(refresh);
    };
  }, [authUser, setLanguageLocal, utcDateKey, bootstrapRetryKey]);

  const retryProfileLoad = useCallback(() => {
    setProfileLoadError(false);
    setProfileLoading(true);
    setBootstrapRetryKey((value) => value + 1);
  }, []);

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
    // Keep the newly created account signed in so the auth-state listener
    // routes it to character creation instead of treating it as a returning
    // player who must already have a profile.
    await sendEmailVerification(credential.user);
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
    profileLoadError,
    retryProfileLoad,
    userPrivate,
    wallet,
    inventory,
    transactions,
    marketListings,
    marketOrders,
    companies,
    factories,
    companyLogs,
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
    claimedAchievements,
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
