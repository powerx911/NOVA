import { useEffect, useState } from 'react';
import { ArrowLeft, Ban, Flag, Globe2, MessageCircle, Search, Send, ShieldCheck, Users, UserRound } from 'lucide-react';
import { AVATARS } from '../../data/catalog';
import { timestampToMs } from '../../lib/economy';
import type { Language, Organization, OrganizationMember, PlayerProfile } from '../../types/game';
import {
  blockPlayer as blockPlayerOnSupabase,
  getPublicPlayerProfile,
  invitePlayerToOrganization,
  listBlockedPlayers,
  listDirectConversations,
  listDirectMessages,
  listGlobalChatMessages,
  listOrganizationInvites,
  openDirectConversation,
  reportPlayer as submitPlayerReport,
  respondOrganizationInvite,
  searchPlayers,
  sendDirectMessage,
  sendGlobalChatMessage,
  listOrganizationChatMessages,
  sendOrganizationChatMessage,
  unblockPlayer as unblockPlayerOnSupabase,
  getPlayersPresence,
} from '../../services/socialService';
import type {
  PublicPlayer,
  SocialConversation as Conversation,
  SocialDirectMessage as DirectMessage,
  SocialGlobalMessage as GlobalMessage,
  SocialOrganizationMessage,
  SocialOrgInvite as OrgInvite,
  SocialPresence,
} from '../../services/socialService';

interface SocialHubViewProps {
  profile: PlayerProfile;
  myOrgMember: OrganizationMember | null;
  organizations: Organization[];
  language: Language;
  onUnreadCountChange: (count: number) => void;
}

export function SocialHubView({ profile, myOrgMember, organizations, language, onUnreadCountChange }: SocialHubViewProps) {
  const ar = language === 'ar';
  const [section, setSection] = useState<'players' | 'communication'>('players');
  const [mode, setMode] = useState<'messages' | 'global' | 'organization'>('messages');
  const [search, setSearch] = useState('');
  const [players, setPlayers] = useState<PublicPlayer[]>([]);
  const [selectedPlayer, setSelectedPlayer] = useState<PublicPlayer | null>(null);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<string | null>(null);
  const [directMessages, setDirectMessages] = useState<DirectMessage[]>([]);
  const [globalMessages, setGlobalMessages] = useState<GlobalMessage[]>([]);
  const [organizationMessages, setOrganizationMessages] = useState<SocialOrganizationMessage[]>([]);
  const [orgChatReadAt, setOrgChatReadAt] = useState(() => { try { return Number(window.localStorage.getItem(`nova:org-chat-read:${profile.uid}:${profile.orgId || 'none'}`) || 0); } catch { return 0; } });
  const [invites, setInvites] = useState<OrgInvite[]>([]);
  const [blockedUids, setBlockedUids] = useState<string[]>([]);
  const [reportReason, setReportReason] = useState<'harassment' | 'spam' | 'inappropriate' | 'impersonation' | 'other'>('other');
  const [draft, setDraft] = useState('');
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [dismissedUnread, setDismissedUnread] = useState<Record<string, number>>(() => {
    try { return JSON.parse(window.localStorage.getItem(`nova:dm-read:${profile.uid}`) || '{}') as Record<string, number>; }
    catch { return {}; }
  });
  const [selectedOrganization, setSelectedOrganization] = useState<Organization | null>(null);
  const [presenceByUid, setPresenceByUid] = useState<Record<string, SocialPresence>>({});

  const presenceDuration = (value: unknown) => {
    const ms = timestampToMs(value, 0);
    if (!ms) return ar ? 'غير معروف' : 'unknown';
    const elapsed = Math.max(0, Date.now() - ms);
    const minutes = Math.floor(elapsed / 60_000);
    if (minutes < 1) return ar ? 'متصل الآن' : 'Online now';
    if (minutes < 60) return ar ? `منذ ${minutes} دقيقة` : `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return ar ? `منذ ${hours} ${hours === 1 ? 'ساعة' : 'ساعات'}` : `${hours}h`;
    const days = Math.min(7, Math.floor(hours / 24));
    return ar ? `منذ ${days} ${days === 1 ? 'يوم' : 'أيام'}` : `${days}d`;
  };
  const presenceLabel = (uid: string) => {
    const presence = presenceByUid[uid];
    if (!presence) return ar ? 'حالة الاتصال غير متاحة' : 'Status unavailable';
    if (presence.isOnline) return ar ? 'متصل الآن' : 'Online now';
    return presence.lastSeenAt ? (ar ? `آخر ظهور ${presenceDuration(presence.lastSeenAt)}` : `Last seen ${presenceDuration(presence.lastSeenAt)}`) : (ar ? 'غير متصل' : 'Offline');
  };
  const socialErrorMessage = (error: unknown, fallback: string) => {
    const code = error instanceof Error ? error.message : '';
    const messages: Record<string, string> = ar ? {
      CHAT_RATE_LIMIT: 'أرسلت رسالة قبل قليل. انتظر بضع ثوانٍ ثم حاول مجدداً.',
      INVALID_MESSAGE: 'الرسالة طويلة أكثر من المسموح. اختصرها ثم أعد الإرسال.',
      EMPTY_MESSAGE: 'اكتب رسالة أولاً قبل الإرسال.',
      PLAYER_BLOCKED: 'لا يمكن بدء محادثة لأن أحدكما حظر الآخر.',
      PLAYER_NOT_FOUND: 'هذا اللاعب لم يعد متاحاً.',
      CONVERSATION_ACCESS_DENIED: 'لا تملك صلاحية فتح هذه المحادثة.',
      INVITE_PERMISSION_REQUIRED: 'رتبتك الحالية لا تسمح بإرسال دعوات المنظمة.',
      TARGET_ALREADY_IN_ORG: 'هذا اللاعب عضو في منظمة بالفعل.',
      INVITE_ALREADY_PENDING: 'أرسلت لهذا اللاعب دعوة وما زالت بانتظار الرد.',
      INVITE_NOT_AVAILABLE: 'هذه الدعوة لم تعد متاحة.',
      REPORT_RATE_LIMIT: 'أرسلت بلاغاً قبل قليل. انتظر قليلاً ثم حاول مجدداً.',
      UNAUTHENTICATED: 'انتهت جلسة الدخول. سجّل الدخول مجدداً.',
    } : {
      CHAT_RATE_LIMIT: 'You sent a message recently. Wait a few seconds and try again.',
      INVALID_MESSAGE: 'The message is longer than allowed. Shorten it and retry.',
      EMPTY_MESSAGE: 'Write a message before sending.',
      PLAYER_BLOCKED: 'A conversation cannot be started because one of you blocked the other.',
      PLAYER_NOT_FOUND: 'This player is no longer available.',
      CONVERSATION_ACCESS_DENIED: 'You cannot access this conversation.',
      INVITE_PERMISSION_REQUIRED: 'Your role cannot send organization invites.',
      TARGET_ALREADY_IN_ORG: 'This player already belongs to an organization.',
      INVITE_ALREADY_PENDING: 'An invitation to this player is already pending.',
      INVITE_NOT_AVAILABLE: 'This invitation is no longer available.',
      REPORT_RATE_LIMIT: 'You submitted a report recently. Wait a little and retry.',
      UNAUTHENTICATED: 'Your session expired. Please sign in again.',
    };
    return messages[code] || fallback;
  };

  const avatarUrl = (avatarId: string | undefined) =>
    AVATARS.find((avatar) => avatar.id === avatarId)?.src || AVATARS[0]?.src || '';

  async function openPlayerProfile(targetUid: string) {
    try {
      const result = await getPublicPlayerProfile(targetUid);
      setSelectedPlayer(result);
      setSection('players');
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر فتح الملف الشخصي الآن.' : 'Could not open player profile right now.'));
    }
  }

  const canInvite = Boolean(myOrgMember && (
    myOrgMember.role === 'leader' ||
    myOrgMember.role === 'deputy' ||
    myOrgMember.permissions.includes('manage_members')
  ));

  const selectedConversationData = conversations.find((item) => item.id === selectedConversation) || null;
  const unreadConversations = conversations.filter((item) => item.lastSenderUid !== profile.uid && (!dismissedUnread[item.id] || timestampToMs(item.lastMessageAt, 0) > dismissedUnread[item.id]));
  useEffect(() => { try { window.localStorage.setItem(`nova:dm-read:${profile.uid}`, JSON.stringify(dismissedUnread)); } catch { /* Keep the current-session unread state if storage is unavailable. */ } }, [dismissedUnread, profile.uid]);
  const unreadOrganizationMessages = organizationMessages.filter((message) => message.senderUid !== profile.uid && timestampToMs(message.createdAt, 0) > orgChatReadAt);
  useEffect(() => { onUnreadCountChange(unreadConversations.length + (section === 'communication' && mode === 'organization' ? 0 : unreadOrganizationMessages.length)); }, [unreadConversations.length, unreadOrganizationMessages.length, section, mode, onUnreadCountChange]);
  useEffect(() => {
    if (section !== 'communication' || mode !== 'organization') return;
    const latest = Date.now();
    setOrgChatReadAt(latest);
    try { window.localStorage.setItem(`nova:org-chat-read:${profile.uid}:${profile.orgId || 'none'}`, String(latest)); } catch { /* Keep this session's read state. */ }
  }, [section, mode, profile.uid, profile.orgId, organizationMessages.length]);
  const targetUid = selectedConversationData?.participants.find((uid) => uid !== profile.uid) || '';

  useEffect(() => {
    if (!profile.orgId) { setOrganizationMessages([]); return; }
    let active = true;
    const refresh = async () => {
      try {
        const messages = await listOrganizationChatMessages(profile.orgId!);
        if (active) setOrganizationMessages(messages);
      } catch (error) {
        if (active) setError(socialErrorMessage(error, ar ? 'تعذر تحميل دردشة المنظمة.' : 'Could not load organization chat.'));
      }
    };
    void refresh();
    const timer = window.setInterval(() => { void refresh(); }, 3000);
    return () => { active = false; window.clearInterval(timer); };
  }, [profile.orgId, ar]);

  useEffect(() => {
    const ids = [...new Set([...conversations.flatMap((item) => item.participants), ...globalMessages.map((item) => item.senderUid), ...(selectedPlayer ? [selectedPlayer.uid] : [])])].filter(Boolean);
    if (ids.length === 0) return;
    let active = true;
    const refresh = async () => {
      try {
        const records = await getPlayersPresence(ids);
        if (active) setPresenceByUid(Object.fromEntries(records.map((item) => [item.uid, item])));
      } catch { /* Presence is supplementary; keep the last known status. */ }
    };
    void refresh();
    const timer = window.setInterval(() => { void refresh(); }, 15_000);
    return () => { active = false; window.clearInterval(timer); };
  }, [conversations, globalMessages, selectedPlayer?.uid]);

  useEffect(() => {
    let active = true;
    void listBlockedPlayers().then((blocked) => { if (active) setBlockedUids(blocked); }).catch(() => {
      if (active) setError(ar ? 'تعذر تحميل قائمة الحظر.' : 'Could not load blocked players.');
    });
    return () => { active = false; };
  }, [ar]);

  useEffect(() => {
    const prefix = search.trim().toLowerCase();
    if (prefix.length < 2) {
      setPlayers([]);
      return;
    }
    const timer = window.setTimeout(() => {
      void searchPlayers(prefix).then(setPlayers).catch((error) => setError(socialErrorMessage(error, ar ? 'تعذر البحث عن اللاعبين الآن.' : 'Player search failed right now.')));
    }, 300);
    return () => window.clearTimeout(timer);
  }, [search, ar]);

  useEffect(() => {
    let active = true;
    const refresh = async () => {
      try {
        const [nextConversations, nextGlobalMessages, nextInvites] = await Promise.all([
          listDirectConversations(), listGlobalChatMessages(), listOrganizationInvites(),
        ]);
        if (!active) return;
        setConversations(nextConversations.sort((a, b) =>
          timestampToMs(b.lastMessageAt, 0) - timestampToMs(a.lastMessageAt, 0)
        ));
        setGlobalMessages(nextGlobalMessages);
        setInvites(nextInvites);
      } catch (error) {
        if (active) setError(socialErrorMessage(error, ar ? 'تعذر تحديث بيانات التواصل الآن.' : 'Could not refresh social data right now.'));
      }
    };
    void refresh();
    const timer = window.setInterval(() => { void refresh(); }, 5000);
    return () => { active = false; window.clearInterval(timer); };
  }, [profile.uid, ar]);

  useEffect(() => {
    if (!selectedConversation) {
      setDirectMessages([]);
      return;
    }
    let active = true;
    const refresh = async () => {
      try {
        const messages = await listDirectMessages(selectedConversation);
        if (active) setDirectMessages(messages);
      } catch (error) {
        if (active) setError(socialErrorMessage(error, ar ? 'تعذر تحميل الرسائل الآن.' : 'Could not load messages right now.'));
      }
    };
    void refresh();
    const timer = window.setInterval(() => { void refresh(); }, 3000);
    return () => { active = false; window.clearInterval(timer); };
  }, [selectedConversation, ar]);

  const dateLabel = (value: unknown) => {
    const ms = timestampToMs(value, 0);
    if (!ms) return '';
    return new Date(ms).toLocaleTimeString(ar ? 'ar' : 'en', { hour: '2-digit', minute: '2-digit' });
  };

  async function openConversation(player: PublicPlayer) {
    setBusy('open');
    setError('');
    try {
      const result = await openDirectConversation(player.uid);
      setSelectedPlayer(player);
      setSelectedConversation(result.conversationId);
      setDismissedUnread((previous) => ({ ...previous, [result.conversationId]: timestampToMs(conversations.find((item) => item.id === result.conversationId)?.lastMessageAt, Date.now()) }));
      setSection('communication');
      setMode('messages');
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر فتح المحادثة الآن.' : 'Could not open conversation right now.'));
    } finally {
      setBusy(null);
    }
  }

  async function sendDirect() {
    const text = draft.trim();
    if (!text || !targetUid) return;
    setBusy('send_dm');
    try {
      await sendDirectMessage(targetUid, text);
      setDraft('');
      const [messages, nextConversations] = await Promise.all([
        listDirectMessages(selectedConversation || ''), listDirectConversations(),
      ]);
      setDirectMessages(messages);
      setConversations(nextConversations);
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر إرسال الرسالة الآن. تحقق من الاتصال وحاول مجدداً.' : 'Could not send the message. Check your connection and retry.'));
    } finally {
      setBusy(null);
    }
  }

  async function sendOrganization() {
    const text = draft.trim();
    if (!text || !profile.orgId) return;
    setBusy('send_org');
    try {
      await sendOrganizationChatMessage(profile.orgId, text);
      setDraft('');
      setOrganizationMessages(await listOrganizationChatMessages(profile.orgId));
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر إرسال رسالة المنظمة الآن.' : 'Could not send organization message.'));
    } finally {
      setBusy(null);
    }
  }

  async function sendGlobal() {
    const text = draft.trim();
    if (!text) return;
    setBusy('send_global');
    try {
      await sendGlobalChatMessage(text);
      setDraft('');
      setGlobalMessages(await listGlobalChatMessages());
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر إرسال الرسالة الآن. تحقق من الاتصال وحاول مجدداً.' : 'Could not send the message. Check your connection and retry.'));
    } finally {
      setBusy(null);
    }
  }

  async function togglePlayerBlock(player: PublicPlayer) {
    const isBlocked = blockedUids.includes(player.uid);
    setBusy('block');
    setError('');
    try {
      if (isBlocked) await unblockPlayerOnSupabase(player.uid);
      else await blockPlayerOnSupabase(player.uid);
      setBlockedUids((previous) => isBlocked
        ? previous.filter((uid) => uid !== player.uid)
        : [...previous, player.uid]);
      setError(isBlocked
        ? (ar ? 'تم إلغاء حظر اللاعب.' : 'Player unblocked.')
        : (ar ? 'تم حظر اللاعب ولن يتمكن الطرفان من تبادل الرسائل الخاصة.' : 'Player blocked. Neither player can send the other direct messages.'));
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر تحديث الحظر الآن.' : 'Could not update block settings right now.'));
    } finally {
      setBusy(null);
    }
  }

  async function reportPlayer(player: PublicPlayer) {
    setBusy('report');
    setError('');
    try {
      await submitPlayerReport(player.uid, reportReason);
      setError(ar ? 'تم إرسال البلاغ للمراجعة.' : 'Report submitted for review.');
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر إرسال البلاغ الآن. حاول لاحقاً.' : 'Could not submit report right now. Try again later.'));
    } finally {
      setBusy(null);
    }
  }

  async function invitePlayer(player: PublicPlayer) {
    setBusy('invite');
    try {
      await invitePlayerToOrganization(player.uid);
      setError(ar ? 'تم إرسال دعوة المنظمة.' : 'Organization invite sent.');
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر إرسال الدعوة الآن.' : 'Could not send the invitation right now.'));
    } finally {
      setBusy(null);
    }
  }

  async function respondInvite(inviteId: string, response: 'accept' | 'decline') {
    setBusy(inviteId);
    try {
      await respondOrganizationInvite(inviteId, response);
      setInvites((previous) => previous.filter((invite) => invite.id !== inviteId));
    } catch (error) {
      setError(socialErrorMessage(error, ar ? 'تعذر معالجة الدعوة الآن.' : 'Could not process the invitation right now.'));
    } finally {
      setBusy(null);
    }
  }

  const tabs = [
    { id: 'messages' as const, label: ar ? 'الرسائل' : 'Messages', icon: MessageCircle },
    { id: 'global' as const, label: ar ? 'الدردشة العامة' : 'Global chat', icon: Globe2 },
    { id: 'organization' as const, label: ar ? 'دردشة المنظمة' : 'Organization chat', icon: Users },
  ];

  return (
    <div className="space-y-4 pb-2">
      <header className="space-y-1">
        <h1 className="text-xl font-bold text-[#F4F5F7]">{ar ? 'التواصل' : 'Social'}</h1>
        <p className="text-xs text-[#9299A6]">{ar ? 'ابحث عن اللاعبين، أرسل الرسائل، وتابع الدردشة العامة.' : 'Find players, send private messages and join the global chat.'}</p>
      </header>

      {invites.length > 0 && (
        <section className="rounded-2xl border border-amber-400/20 bg-amber-400/5 p-4 space-y-3">
          <div className="flex items-center gap-2 text-sm font-semibold text-amber-200"><ShieldCheck className="w-4 h-4" />{ar ? 'دعوات المنظمات' : 'Organization invites'}</div>
          {invites.map((invite) => (
            <div key={invite.id} className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 rounded-xl bg-[#0B0D12]/70 p-3">
              <p className="text-xs text-[#F4F5F7]">{invite.orgName} <span className="text-amber-200">[{invite.orgTag}]</span> · {ar ? 'من' : 'From'} {invite.inviterName}</p>
              <div className="flex gap-2">
                <button type="button" disabled={busy === invite.id} onClick={() => void respondInvite(invite.id, 'accept')} className="min-h-[36px] px-3 rounded-lg bg-emerald-700 text-white text-xs">{ar ? 'قبول' : 'Accept'}</button>
                <button type="button" disabled={busy === invite.id} onClick={() => void respondInvite(invite.id, 'decline')} className="min-h-[36px] px-3 rounded-lg bg-[#252B36] text-white text-xs">{ar ? 'رفض' : 'Decline'}</button>
              </div>
            </div>
          ))}
        </section>
      )}

      <nav className="grid grid-cols-2 gap-2 rounded-xl bg-[#141821] p-1">
        <button type="button" onClick={() => { setSection('players'); setError(''); }} className={'min-h-[44px] rounded-lg text-xs font-bold ' + (section === 'players' ? 'bg-[#B91C32] text-white' : 'text-[#9299A6]')}>
          <UserRound className="inline w-4 h-4 me-1.5" />{ar ? 'اللاعبون' : 'Players'}
        </button>
        <button type="button" onClick={() => { setSection('communication'); setError(''); }} className={'min-h-[44px] rounded-lg text-xs font-bold ' + (section === 'communication' ? 'bg-[#B91C32] text-white' : 'text-[#9299A6]')}>
          <MessageCircle className="inline w-4 h-4 me-1.5" />{ar ? 'التواصل' : 'Communication'}
          {(unreadConversations.length + unreadOrganizationMessages.length) > 0 && <span className="ms-2 inline-flex min-w-5 h-5 px-1 rounded-full bg-red-600 text-white text-[10px] font-bold items-center justify-center">{unreadConversations.length + unreadOrganizationMessages.length}</span>}
        </button>
      </nav>
      {section === 'communication' && <nav className="grid grid-cols-3 gap-1 rounded-xl bg-[#141821] p-1">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return <button key={tab.id} type="button" onClick={() => { setMode(tab.id); setError(''); }} className={'min-h-[42px] flex items-center justify-center gap-1 rounded-lg text-[11px] font-semibold ' + (mode === tab.id ? 'bg-[#B91C32] text-white' : 'text-[#9299A6]')}>
            <Icon className="w-4 h-4" />{tab.label}
            {tab.id === 'messages' && unreadConversations.length > 0 && <span className="ms-1 inline-flex h-2 w-2 rounded-full bg-red-500" />}
            {tab.id === 'organization' && unreadOrganizationMessages.length > 0 && <span className="ms-1 inline-flex h-2 w-2 rounded-full bg-red-500" />}
          </button>;
        })}
      </nav>}
      {mode === 'messages' && unreadConversations.length > 0 && <div className="flex items-center justify-between gap-3 rounded-xl border border-red-500/20 bg-red-500/5 px-3 py-2"><p className="text-xs text-[#F4F5F7]">{ar ? `${unreadConversations.length} محادثة فيها رسائل جديدة` : `${unreadConversations.length} conversation(s) with new messages`}</p><button type="button" onClick={() => setDismissedUnread((previous) => ({ ...previous, ...Object.fromEntries(unreadConversations.map((item) => [item.id, timestampToMs(item.lastMessageAt, Date.now())])) }))} className="text-[11px] text-red-300 underline underline-offset-2">{ar ? 'إغلاق الإشعارات' : 'Dismiss notifications'}</button></div>}
      {error && <p className="rounded-xl border border-white/10 bg-[#141821] px-3 py-2 text-xs text-[#F4C66A]">{error}</p>}

      {section === 'players' && (
        <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div className="space-y-3">
            <div className="relative">
              <Search className="absolute start-3 top-3.5 w-4 h-4 text-[#9299A6]" />
              <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder={ar ? 'ابحث باسم اللاعب...' : 'Search player name...'}
                className="w-full min-h-[46px] rounded-xl border border-white/10 bg-[#141821] ps-10 pe-3 text-sm text-[#F4F5F7]" />
            </div>
            {players.map((player) => (
              <button key={player.uid} type="button" onClick={() => setSelectedPlayer(player)}
                className="w-full flex items-center justify-between gap-3 rounded-xl border border-white/8 bg-[#141821] p-3 text-start hover:border-white/20">
                <span className="flex min-w-0 items-center gap-3">
                  <img src={avatarUrl(player.avatarId)} alt="" className="h-10 w-10 rounded-xl object-cover bg-[#252B36]" />
                  <span className="min-w-0">
                    <span className="block text-sm font-semibold text-[#F4F5F7] truncate">{player.username}</span>
                  <span className="block mt-1 text-[11px] text-[#9299A6]">{ar ? 'المستوى' : 'Level'} {player.level} · {player.title}</span>
                  </span>
                </span>
                <span className="shrink-0 rounded-lg bg-[#0B0D12] px-2 py-1 text-xs font-mono-num text-amber-200">Lv.{player.level}</span>
              </button>
            ))}
            {search.trim().length >= 2 && players.length === 0 && <p className="text-xs text-[#9299A6]">{ar ? 'لا توجد نتائج مطابقة.' : 'No matching players found.'}</p>}
          </div>
          <div className="rounded-2xl border border-white/8 bg-[#141821] p-5">
            {selectedPlayer ? (
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <img src={avatarUrl(selectedPlayer.avatarId)} alt="" className="w-14 h-14 rounded-2xl object-cover bg-[#252B36]" />
                  <div>
                    <h2 className="text-base font-bold text-[#F4F5F7]">{selectedPlayer.username}</h2>
                    <p className="text-xs text-[#9299A6]">{selectedPlayer.title || (ar ? 'لا يوجد لقب' : 'No title')}</p><p className="mt-1 flex items-center gap-1.5 text-[11px] text-[#9299A6]"><span className={'h-2 w-2 rounded-full ' + (presenceByUid[selectedPlayer.uid]?.isOnline ? 'bg-emerald-400' : 'bg-[#667085]')} />{presenceLabel(selectedPlayer.uid)}</p>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div className="rounded-xl bg-[#0B0D12] p-3"><p className="text-[11px] text-[#9299A6]">{ar ? 'المستوى' : 'Level'}</p><p className="mt-1 text-lg font-bold">{selectedPlayer.level}</p></div>
                  <div className="rounded-xl bg-[#0B0D12] p-3"><p className="text-[11px] text-[#9299A6]">{ar ? 'السمعة' : 'Reputation'}</p><p className="mt-1 text-lg font-bold">{selectedPlayer.reputation}</p></div>
                  <div className="rounded-xl bg-[#0B0D12] p-3"><p className="text-[11px] text-[#9299A6]">{ar ? 'النفوذ' : 'Influence'}</p><p className="mt-1 text-lg font-bold">{selectedPlayer.influence}</p></div>
                  <div className="rounded-xl bg-[#0B0D12] p-3"><p className="text-[11px] text-[#9299A6]">{ar ? 'المنظمة' : 'Organization'}</p>{(() => { const org = organizations.find((item) => item.id === selectedPlayer.orgId); return org ? <button type="button" onClick={() => setSelectedOrganization(org)} className="mt-1 text-sm font-semibold text-amber-200 underline underline-offset-2 text-start">[{org.tag}] {org.name}</button> : <p className="mt-1 text-sm font-semibold">{ar ? 'بدون منظمة' : 'None'}</p>; })()}</div>
                </div>
                <button type="button" disabled={busy === 'open'} onClick={() => void openConversation(selectedPlayer)}
                  className="w-full min-h-[44px] rounded-xl bg-[#B91C32] text-white text-sm font-semibold flex items-center justify-center gap-2">
                  <MessageCircle className="w-4 h-4" />{ar ? 'إرسال رسالة' : 'Send message'}
                </button>
                <label className="block text-[11px] text-[#9299A6]">
                  {ar ? 'سبب الإبلاغ' : 'Report reason'}
                  <select value={reportReason} onChange={(event) => setReportReason(event.target.value as typeof reportReason)}
                    className="mt-1 w-full min-h-[40px] rounded-lg bg-[#0B0D12] border border-white/10 px-3 text-xs text-[#F4F5F7]">
                    <option value="harassment">{ar ? 'مضايقة أو إساءة' : 'Harassment'}</option>
                    <option value="spam">{ar ? 'رسائل مزعجة' : 'Spam'}</option>
                    <option value="inappropriate">{ar ? 'محتوى غير مناسب' : 'Inappropriate content'}</option>
                    <option value="impersonation">{ar ? 'انتحال شخصية' : 'Impersonation'}</option>
                    <option value="other">{ar ? 'سبب آخر' : 'Other'}</option>
                  </select>
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button type="button" disabled={busy === 'block'} onClick={() => void togglePlayerBlock(selectedPlayer)}
                    className="min-h-[42px] rounded-xl bg-[#252B36] border border-white/10 text-xs font-semibold flex items-center justify-center gap-2">
                    <Ban className="w-4 h-4" />{blockedUids.includes(selectedPlayer.uid) ? (ar ? 'إلغاء الحظر' : 'Unblock') : (ar ? 'حظر اللاعب' : 'Block player')}
                  </button>
                  <button type="button" disabled={busy === 'report'} onClick={() => void reportPlayer(selectedPlayer)}
                    className="min-h-[42px] rounded-xl bg-[#252B36] border border-white/10 text-xs font-semibold flex items-center justify-center gap-2">
                    <Flag className="w-4 h-4" />{ar ? 'إبلاغ' : 'Report'}
                  </button>
                </div>
                {canInvite && !selectedPlayer.orgId && (
                  <button type="button" disabled={busy === 'invite'} onClick={() => void invitePlayer(selectedPlayer)}
                    className="w-full min-h-[44px] rounded-xl bg-[#1B2230] border border-white/10 text-[#F4F5F7] text-sm font-semibold flex items-center justify-center gap-2">
                    <Users className="w-4 h-4" />{ar ? 'دعوة إلى المنظمة' : 'Invite to organization'}
                  </button>
                )}
                {!canInvite && <p className="text-[11px] text-[#9299A6]">{ar ? 'دعوات المنظمة متاحة للقائد والنائب والمدير المخوّل فقط.' : 'Organization invites are limited to leaders, deputies and authorized managers.'}</p>}
              </div>
            ) : (
              <div className="h-full min-h-48 flex flex-col items-center justify-center text-center text-[#9299A6] gap-2">
                <UserRound className="w-8 h-8 opacity-50" /><p className="text-xs">{ar ? 'اختر لاعباً لعرض ملفه العام.' : 'Select a player to view their public profile.'}</p>
              </div>
            )}
          </div>
        </section>
      )}

      {section === 'communication' && mode === 'messages' && (
        <section className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-3 min-h-[420px]">
          <div className={(selectedConversation ? 'hidden lg:block ' : '') + 'rounded-2xl border border-white/8 bg-[#141821] p-3 space-y-2'}>
            <div className="flex items-center justify-between gap-2 px-2 py-1"><h2 className="text-xs font-semibold text-[#9299A6]">{ar ? 'المحادثات' : 'Conversations'}</h2>{unreadConversations.length > 0 && <button type="button" onClick={() => setDismissedUnread((previous) => ({ ...previous, ...Object.fromEntries(unreadConversations.map((item) => [item.id, timestampToMs(item.lastMessageAt, Date.now())])) }))} className="text-[10px] font-semibold text-red-300 hover:text-red-200">{ar ? 'إغلاق إشعارات الرسائل' : 'Dismiss message alerts'}</button>}</div>
            {conversations.map((conversation) => {
              const otherUid = conversation.participants.find((uid) => uid !== profile.uid) || '';
              const name = conversation.participantNames?.[otherUid] || (ar ? 'لاعب' : 'Player');
              return (
                <button key={conversation.id} type="button" onClick={() => { setSelectedConversation(conversation.id); setDismissedUnread((previous) => ({ ...previous, [conversation.id]: timestampToMs(conversation.lastMessageAt, Date.now()) })); }}
                  className={'w-full rounded-xl border border-white/8 p-3 text-start transition-colors ' + (selectedConversation === conversation.id ? 'bg-[#252B36] border-white/20' : 'bg-[#0B0D12] hover:bg-[#1B2230]')}>
                  <span className="flex items-center gap-2 text-sm font-semibold text-[#F4F5F7]">
                    <img src={avatarUrl(conversation.participantAvatars?.[otherUid])} alt="" className="h-8 w-8 rounded-lg object-cover bg-[#252B36]" />
                    {name}
                  </span>
                  <span className="flex items-center justify-between gap-2 mt-1"><span className="text-[11px] text-[#9299A6] truncate">{conversation.lastMessage || (ar ? 'ابدأ المحادثة' : 'Start conversation')}</span>{unreadConversations.some((item) => item.id === conversation.id) && <span className="h-2 w-2 rounded-full bg-red-500 shrink-0" />}</span>
                </button>
              );
            })}
            {conversations.length === 0 && <p className="px-2 py-5 text-xs text-[#9299A6]">{ar ? 'لا توجد محادثات بعد. ابحث عن لاعب لبدء محادثة.' : 'No conversations yet. Find a player to start one.'}</p>}
          </div>
          <div className={(selectedConversation ? '' : 'hidden lg:flex ') + 'rounded-2xl border border-white/8 bg-[#141821] p-3 flex flex-col min-h-[420px]'}>
            {selectedConversation ? (
              <>
                <div className="flex items-center gap-2 border-b border-white/8 pb-3">
                  <button type="button" onClick={() => setSelectedConversation(null)} className="lg:hidden min-h-[38px] min-w-[38px] rounded-lg bg-[#252B36] flex items-center justify-center"><ArrowLeft className="w-4 h-4" /></button>
                  <div className="flex-1 min-w-0"><div className="flex items-center gap-2"><img src={avatarUrl(selectedConversationData?.participantAvatars?.[targetUid])} alt="" className="h-9 w-9 rounded-lg object-cover bg-[#252B36]" /><h2 className="text-sm font-semibold truncate">{selectedConversationData?.participantNames?.[targetUid] || (ar ? 'المحادثة' : 'Conversation')}</h2></div><p className="mt-1 ms-11 flex items-center gap-1.5 text-[10px] text-[#9299A6]"><span className={'h-2 w-2 rounded-full ' + (presenceByUid[targetUid]?.isOnline ? 'bg-emerald-400' : 'bg-[#667085]')} />{presenceLabel(targetUid)}</p></div>
                  <button type="button" onClick={() => void openPlayerProfile(targetUid)} className="min-h-[36px] px-3 rounded-lg bg-[#252B36] text-[11px] text-[#F4F5F7]">
                    {ar ? 'الملف الشخصي' : 'Profile'}
                  </button>
                </div>
                <div className="flex-1 min-h-[280px] max-h-[55vh] overflow-y-auto py-3 space-y-2">
                  {directMessages.map((message) => (
                    <div key={message.id} className={'max-w-[85%] rounded-xl p-3 text-xs ' + (message.senderUid === profile.uid ? 'ms-auto bg-[#54202B]' : 'me-auto bg-[#0B0D12]')}>
                      <p className="mb-1 text-[10px] text-[#D2A8AF]">{message.senderName} · {dateLabel(message.createdAt)}</p>
                      <p className="whitespace-pre-wrap break-words">{message.text}</p>
                    </div>
                  ))}
                </div>
                <div className="flex gap-2 pt-3 border-t border-white/8">
                  <input value={draft} onChange={(event) => setDraft(event.target.value)} maxLength={1000} onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); void sendDirect(); } }}
                    placeholder={ar ? 'اكتب رسالة...' : 'Write a message...'} className="flex-1 min-w-0 min-h-[44px] rounded-xl bg-[#0B0D12] border border-white/10 px-3 text-sm" />
                  <button type="button" disabled={!draft.trim() || busy === 'send_dm'} onClick={() => void sendDirect()} className="min-w-[44px] rounded-xl bg-[#B91C32] flex items-center justify-center disabled:opacity-40"><Send className="w-4 h-4" /></button>
                </div>
              </>
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-center text-[#9299A6] gap-2"><MessageCircle className="w-8 h-8 opacity-50" /><p className="text-xs">{ar ? 'اختر محادثة من القائمة.' : 'Choose a conversation from the list.'}</p></div>
            )}
          </div>
        </section>
      )}

      {selectedOrganization && <div className="fixed inset-0 z-50 bg-black/70 p-4 flex items-center justify-center" role="dialog" aria-modal="true"><div className="w-full max-w-md rounded-2xl border border-white/10 bg-[#141821] p-5 space-y-4"><div className="flex items-start justify-between gap-3"><div><p className="text-xs text-amber-200">[{selectedOrganization.tag}]</p><h2 className="text-lg font-bold text-[#F4F5F7]">{selectedOrganization.name}</h2><p className="text-xs text-[#9299A6] mt-1">{selectedOrganization.description || (ar ? 'لا يوجد وصف' : 'No description')}</p></div><button type="button" onClick={() => setSelectedOrganization(null)} className="rounded-lg bg-[#252B36] px-3 py-2 text-xs">{ar ? 'إغلاق' : 'Close'}</button></div><div className="grid grid-cols-2 gap-2">{[[ar ? 'المستوى' : 'Level', selectedOrganization.level],[ar ? 'الأعضاء' : 'Members', selectedOrganization.memberCount],[ar ? 'السمعة' : 'Reputation', selectedOrganization.reputation],[ar ? 'قائد المنظمة' : 'Leader', selectedOrganization.leaderName],[ar ? 'الخزينة' : 'Treasury', `${selectedOrganization.treasuryBalance.toLocaleString()}`]].map(([label,value]) => <div key={String(label)} className="rounded-xl bg-[#0B0D12] p-3"><p className="text-[11px] text-[#9299A6]">{label}</p><p className="mt-1 text-sm font-semibold text-[#F4F5F7]">{value}</p></div>)}</div></div></div>}

      {section === 'communication' && mode === 'organization' && (
        <section className="rounded-2xl border border-white/8 bg-[#141821] p-3 flex flex-col min-h-[520px]">
          <div className="flex items-center gap-2 border-b border-white/8 px-2 pb-3"><Users className="w-4 h-4 text-amber-200" /><h2 className="text-sm font-semibold">{ar ? 'دردشة المنظمة' : 'Organization chat'}</h2><span className="ms-auto text-[10px] text-[#9299A6]">{ar ? 'للأعضاء فقط' : 'Members only'}</span></div>
          {!profile.orgId ? <p className="flex-1 py-12 text-center text-xs text-[#9299A6]">{ar ? 'يجب أن تنضم إلى منظمة لاستخدام هذه الدردشة.' : 'Join an organization to use this chat.'}</p> : <>
            <div className="flex-1 min-h-[360px] max-h-[60vh] overflow-y-auto py-3 space-y-2">
              {organizationMessages.map((message) => <div key={message.id} className={'max-w-[85%] rounded-xl p-3 text-xs ' + (message.senderUid === profile.uid ? 'ms-auto bg-[#54202B]' : 'me-auto bg-[#0B0D12]')}>
                <p className="mb-1 text-[10px] text-[#D2A8AF]">{message.senderName} · {dateLabel(message.createdAt)}</p><p className="whitespace-pre-wrap break-words">{message.text}</p>
              </div>)}
              {organizationMessages.length === 0 && <p className="py-12 text-center text-xs text-[#9299A6]">{ar ? 'لا توجد رسائل بعد. ابدأ المحادثة مع أعضاء منظمتك.' : 'No messages yet. Start chatting with your organization.'}</p>}
            </div>
            <div className="flex gap-2 pt-3 border-t border-white/8">
              <input value={draft} onChange={(event) => setDraft(event.target.value)} maxLength={280} onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); void sendOrganization(); } }} placeholder={ar ? 'اكتب لأعضاء المنظمة...' : 'Message your organization...'} className="flex-1 min-w-0 min-h-[44px] rounded-xl bg-[#0B0D12] border border-white/10 px-3 text-sm" />
              <button type="button" disabled={!draft.trim() || busy === 'send_org' || !profile.orgId} onClick={() => void sendOrganization()} className="min-w-[44px] rounded-xl bg-[#B91C32] flex items-center justify-center disabled:opacity-40"><Send className="w-4 h-4" /></button>
            </div>
          </>}
        </section>
      )}

      {section === 'communication' && mode === 'global' && (
        <section className="rounded-2xl border border-white/8 bg-[#141821] p-3 flex flex-col min-h-[520px]">
          <div className="flex items-center gap-2 border-b border-white/8 px-2 pb-3"><Globe2 className="w-4 h-4 text-amber-200" /><h2 className="text-sm font-semibold">{ar ? 'الدردشة العامة' : 'Global chat'}</h2><span className="ms-auto text-[10px] text-[#9299A6]">{ar ? 'حد الإرسال: رسالة كل 3 ثوانٍ' : 'Rate limit: one message every 3 seconds'}</span></div>
          <div className="flex-1 min-h-[360px] max-h-[60vh] overflow-y-auto py-3 space-y-2">
            {globalMessages.filter((message) => !blockedUids.includes(message.senderUid)).map((message) => (
              <div key={message.id} className="rounded-xl bg-[#0B0D12] p-3">
                <div className="flex items-center gap-2 mb-1">
                  <button type="button" onClick={() => void openPlayerProfile(message.senderUid)} className="flex items-center gap-2 min-w-0 text-start hover:underline"><img src={avatarUrl(message.avatarId)} alt="" className="h-7 w-7 rounded-lg object-cover bg-[#252B36]" /><span className="text-xs font-semibold text-amber-200 truncate">{message.senderName}</span></button>
                  <span className="text-[10px] text-[#9299A6]">{presenceLabel(message.senderUid)} · {dateLabel(message.createdAt)}</span>
                </div>
                <p className="text-xs whitespace-pre-wrap break-words">{message.text}</p>
              </div>
            ))}
          </div>
          <div className="flex gap-2 pt-3 border-t border-white/8">
            <input value={draft} onChange={(event) => setDraft(event.target.value)} maxLength={280} onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); void sendGlobal(); } }}
              placeholder={ar ? 'اكتب للجميع...' : 'Message everyone...'} className="flex-1 min-w-0 min-h-[44px] rounded-xl bg-[#0B0D12] border border-white/10 px-3 text-sm" />
            <button type="button" disabled={!draft.trim() || busy === 'send_global'} onClick={() => void sendGlobal()} className="min-w-[44px] rounded-xl bg-[#B91C32] flex items-center justify-center disabled:opacity-40"><Send className="w-4 h-4" /></button>
          </div>
        </section>
      )}
    </div>
  );
}
