import { nexoraApi } from '../lib/nexoraApi';

export type PublicPlayer = {
  uid: string; username: string; avatarId: string; title: string;
  level: number; reputation: number; influence: number; orgId: string | null;
};
export type SocialConversation = {
  id: string; participants: string[]; participantNames: Record<string,string>;
  participantAvatars?: Record<string,string>; lastMessage: string;
  lastMessageAt: unknown; lastSenderUid: string;
};
export type SocialDirectMessage = {
  id: string; senderUid: string; senderName: string; text: string; createdAt: unknown;
};
export type SocialGlobalMessage = {
  id: string; senderUid: string; senderName: string; avatarId: string; text: string; createdAt: unknown;
};
export type SocialOrganizationMessage = { id: string; senderUid: string; senderName: string; text: string; createdAt: unknown };
export type SocialOrgInvite = {
  id: string; orgId: string; orgName: string; orgTag: string;
  inviterName: string; status: string; targetUid: string;
};

export const getPublicPlayerProfile = (targetUid: string) =>
  nexoraApi<PublicPlayer>('get_public_player_profile', { targetUid });
export const searchPlayers = async (prefix: string) =>
  (await nexoraApi<{players:PublicPlayer[]}>('search_players', { prefix })).players;
export const listBlockedPlayers = async () =>
  (await nexoraApi<{blockedUids:string[]}>('list_blocked_players')).blockedUids;
export const listDirectConversations = async () =>
  (await nexoraApi<{conversations:SocialConversation[]}>('list_direct_conversations')).conversations;
export const listDirectMessages = async (conversationId: string) =>
  (await nexoraApi<{messages:SocialDirectMessage[]}>('list_direct_messages', { conversationId })).messages;
export const listGlobalChatMessages = async () =>
  (await nexoraApi<{messages:SocialGlobalMessage[]}>('list_global_chat_messages')).messages;
export const listOrganizationChatMessages = async (orgId: string) =>
  (await nexoraApi<{messages:SocialOrganizationMessage[]}>('list_organization_chat_messages', { orgId })).messages;
export const sendOrganizationChatMessage = (orgId: string, text: string) =>
  nexoraApi<{ok:boolean}>('send_organization_chat_message', { orgId, text, requestId: crypto.randomUUID() });
export const listOrganizationInvites = async () =>
  (await nexoraApi<{invites:SocialOrgInvite[]}>('list_organization_invites')).invites;
export const openDirectConversation = (targetUid: string) =>
  nexoraApi<{conversationId:string}>('open_direct_conversation', { targetUid });
export const sendDirectMessage = (targetUid: string, text: string) =>
  nexoraApi<{ok:boolean}>('send_direct_message', { targetUid, text, requestId: crypto.randomUUID() });
export const sendGlobalChatMessage = (text: string) =>
  nexoraApi<{ok:boolean}>('send_global_chat_message', { text, requestId: crypto.randomUUID() });
export const blockPlayer = (targetUid: string) =>
  nexoraApi<{ok:boolean}>('block_player', { targetUid });
export const unblockPlayer = (targetUid: string) =>
  nexoraApi<{ok:boolean}>('unblock_player', { targetUid });
export const reportPlayer = (targetUid: string, reason: string) =>
  nexoraApi<{ok:boolean}>('submit_player_report', { targetUid, reason, requestId: crypto.randomUUID() });
export const invitePlayerToOrganization = (targetUid: string) =>
  nexoraApi<{ok:boolean}>('invite_player_to_organization', { targetUid });
export const respondOrganizationInvite = (inviteId: string, response: 'accept'|'decline') =>
  nexoraApi<{ok:boolean;status:string}>('respond_organization_invite', { inviteId, response });

export type SocialPresence = { uid: string; isOnline: boolean; onlineSince: unknown; lastSeenAt: unknown };
export const touchPlayerPresence = () => nexoraApi<{ok:boolean}>('touch_player_presence');
export const getPlayersPresence = async (userIds: string[]) =>
  (await nexoraApi<{players:SocialPresence[]}>('get_players_presence', { userIds: [...new Set(userIds)].slice(0, 60) })).players;
